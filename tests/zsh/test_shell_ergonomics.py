import asyncio
import json
import os
import statistics
import subprocess
import time
from pathlib import Path

import pytest
from tui_test import TuiTest

ROOT = Path(__file__).resolve().parent.parent.parent
ZDOTDIR = ROOT / "zsh/dev"
ARTIFACTS = ROOT / "tests/zsh/artifacts"
ARTIFACTS.mkdir(exist_ok=True)


@pytest.fixture(scope="session")
def launcher_ready() -> Path:
    # ZSH_TRY runs the suite against another launcher, such as an installed config.
    launcher = Path(os.environ.get("ZSH_TRY", ROOT / "zsh/try"))
    subprocess.run([str(launcher), "--sync", "--warmup"], check=True)
    return launcher


@pytest.fixture(scope="session")
def fixture_workspace(tmp_path_factory: pytest.TempPathFactory) -> Path:
    ws = tmp_path_factory.mktemp("shell_fixture")
    subprocess.run(["git", "init", "-b", "main"], cwd=ws, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=ws, check=True)
    subprocess.run(["git", "config", "user.name", "Test User"], cwd=ws, check=True)

    (ws / "package.json").write_text(
        json.dumps(
            {
                "name": "fixture-app",
                "version": "1.0.0",
                "scripts": {
                    "dev": "vite",
                    "build": "vite build",
                    "lint:fix": "eslint --fix .",
                    "test:e2e": "playwright test",
                },
            },
            indent=2,
        )
        + "\n"
    )
    (ws / "pyproject.toml").write_text(
        '[project]\n'
        'name = "fixture-py"\n'
        'version = "0.1.0"\n'
        'requires-python = ">=3.12"\n\n'
        '[project.scripts]\n'
        'demo-cli = "demo:main"\n'
    )
    (ws / "hello.py").write_text('print("hello")\n')
    (ws / "README.md").write_text("# Fixture\n")

    subprocess.run(["git", "add", "."], cwd=ws, check=True, capture_output=True)
    subprocess.run(["git", "commit", "-m", "initial"], cwd=ws, check=True, capture_output=True)
    subprocess.run(["git", "branch", "feat/auth-flow"], cwd=ws, check=True, capture_output=True)
    subprocess.run(["git", "branch", "fix/tab-complete"], cwd=ws, check=True, capture_output=True)
    return ws


@pytest.fixture(scope="session")
def sample_atuin_command(launcher_ready: Path) -> str:
    histfile = ZDOTDIR / ".cache/atuin-history.zsh"
    raw_lines = histfile.read_text(errors="ignore").splitlines()
    lines = []
    for raw in raw_lines:
        line = raw.strip()
        if line.endswith("\\"):
            continue
        if line and len(line) >= 14 and " " in line and not line.startswith("#"):
            lines.append(line)
    assert lines, "Expected synced Atuin history in zsh/dev/.cache/atuin-history.zsh"
    for line in reversed(lines):
        if line.isascii() and "\t" not in line and len(line) <= 60 and "alpha-beta-gamma" not in line and "STRAT:" not in line:
            return line
    return lines[-1]


def _launcher_env(histfile: Path | None = None, simple_prompt: bool = True) -> dict[str, str]:
    env = os.environ.copy()
    env.update(
        {
            "TERM": "xterm-256color",
            "ZSH_FISH_FEEL_SKIP_EXIT_SYNC": "1",
            "ZSH_FISH_FEEL_NO_DIRENV": "1",
        }
    )
    if simple_prompt:
        env["ZSH_FISH_FEEL_SIMPLE_PROMPT"] = "1"
    if histfile is not None:
        env["ZSH_FISH_FEEL_HISTFILE"] = str(histfile)
    return env


def _measure_cmd_ms(cmd: list[str], env: dict[str, str], runs: int = 7) -> float:
    subprocess.run(cmd, env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    samples = []
    for _ in range(runs):
        t0 = time.perf_counter()
        subprocess.run(cmd, env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        samples.append((time.perf_counter() - t0) * 1000.0)
    return statistics.median(samples)


async def _open_zsh(launcher: Path, cwd: Path, histfile: Path | None = None, simple_prompt: bool = True) -> TuiTest:
    term = TuiTest.ephemeral("zsh-ergo")
    env = _launcher_env(histfile=histfile, simple_prompt=simple_prompt)
    await term.run(str(launcher), "-i", cwd=str(cwd), env=env, cols=110, rows=32)
    await term.get_by_text("$" if simple_prompt else "❯").expect(timeout=5000)
    return term


async def _open_fish(cwd: Path) -> TuiTest:
    term = TuiTest.ephemeral("fish-ref")
    env = os.environ.copy()
    env["TERM"] = "xterm-256color"
    await term.run("fish", "-i", "-C", "function fish_prompt; echo -n '$ '; end", cwd=str(cwd), env=env, cols=110, rows=32)
    await term.get_by_text("$").expect(timeout=5000)
    return term


async def _wait_cursor_x_change(term: TuiTest, prev_x: int, timeout_s: float = 2.0) -> int:
    deadline = time.perf_counter() + timeout_s
    while time.perf_counter() < deadline:
        x = (await term.get_cursor())["x"]
        if x != prev_x:
            return x
        await asyncio.sleep(0.02)
    return (await term.get_cursor())["x"]


def test_startup_speed_and_pty_readiness(launcher_ready: Path, fixture_workspace: Path) -> None:
    zsh_exit_ms = _measure_cmd_ms(
        [str(launcher_ready), "-i", "-c", "exit"],
        _launcher_env(simple_prompt=False),
    )
    fish_exit_ms = _measure_cmd_ms(["fish", "-i", "-c", "exit"], os.environ.copy())

    async def _pty_first_prompt_ms() -> float:
        t0 = time.perf_counter()
        term = await _open_zsh(launcher_ready, fixture_workspace, simple_prompt=True)
        try:
            # Verify deferred Carapace + Atuin are also usable immediately after first prompt
            await term.type("git switch ")
            await term.press("Tab")
            await term.get_by_text("feat/auth-flow").expect(timeout=5000)
            return (time.perf_counter() - t0) * 1000.0
        finally:
            await term.close_quiet()

    pty_ready_and_tab_ms = asyncio.run(_pty_first_prompt_ms())
    print(
        f"\n[startup] zsh/try -i -c exit median={zsh_exit_ms:.1f}ms | "
        f"fish median={fish_exit_ms:.1f}ms | "
        f"PTY launch + first git Tab={pty_ready_and_tab_ms:.1f}ms"
    )
    assert zsh_exit_ms < 250.0, f"zsh/try startup too slow: {zsh_exit_ms:.1f}ms"
    assert zsh_exit_ms < fish_exit_ms * 0.5, f"Expected Zsh ({zsh_exit_ms:.1f}ms) to be >2x faster than Fish ({fish_exit_ms:.1f}ms)"
    assert pty_ready_and_tab_ms < 2500.0, f"PTY launch + first Tab too slow: {pty_ready_and_tab_ms:.1f}ms"


def test_zero_fork_autosuggest_strategy_preserved_after_atuin(
    launcher_ready: Path, fixture_workspace: Path
) -> None:
    async def _run() -> None:
        term = await _open_zsh(launcher_ready, fixture_workspace)
        try:
            # Wait briefly for deferred ZLE init (_zff_load_atuin) to complete, then inspect strategy
            await asyncio.sleep(0.25)
            await term.type('print "STRAT:${ZSH_AUTOSUGGEST_STRATEGY[*]}"')
            await term.press("Enter")
            await term.get_by_text("STRAT:history completion").expect(timeout=3000)
            screen = await term.text()
            assert "STRAT:atuin" not in screen, f"Atuin overrode ZSH_AUTOSUGGEST_STRATEGY:\n{screen}"
        finally:
            await term.close_quiet()

    asyncio.run(_run())


def test_sync_uses_separate_atuin_export_without_touching_zsh_histfile(tmp_path: Path) -> None:
    zsh_hist = tmp_path / "owned.zsh_history"
    atuin_export = tmp_path / "atuin-history.zsh"
    unique_cmd = "echo zff_preserve_local_zsh_entry_98765"
    zsh_hist.write_text(f"{unique_cmd}\n")

    subprocess.run([str(ROOT / "zsh/sync-atuin-history"), str(atuin_export), "50"], check=True)
    # Zsh's own HISTFILE is completely untouched (zero race with HIST_FCNTL_LOCK)
    assert zsh_hist.read_text() == f"{unique_cmd}\n"
    exported_lines = atuin_export.read_text(errors="ignore").splitlines()
    # Count logical records (multiline commands end with '\' continuation lines)
    logical_records = sum(1 for ln in exported_lines if not ln.endswith("\\"))
    assert 0 < logical_records <= 50, f"Expected bounded Atuin export, got {logical_records} logical records"


def test_failed_cache_generator_not_cached(tmp_path: Path) -> None:
    cache_dir = tmp_path / "cache"
    cache_dir.mkdir()
    script = (
        'source zsh/zshrc.zsh 2>/dev/null || true; '
        'fail_gen() { print "echo partial"; return 1; }; '
        '_zff_cache_source broken /bin/sh fail_gen; '
        'rc=$?; '
        'print "RC=$rc"; '
        '[[ -e "$cache_dir/broken.zsh" || -e "$cache_dir/broken.meta" ]] && print "CACHED" || print "CLEAN"'
    )
    out = subprocess.check_output(
        ["zsh", "-f", "-c", f'cache_dir="{cache_dir}"; {script}'],
        cwd=str(ROOT),
        text=True,
        env=os.environ | {
            "ZSH_FISH_FEEL_CACHE": str(cache_dir),
            "ZSH_FISH_FEEL_HISTFILE": str(tmp_path / "history"),
            "ZSH_FISH_FEEL_SKIP_EXIT_SYNC": "1",
        },
    )
    assert "RC=1" in out and "CLEAN" in out, f"Failed generator should not be cached, got:\n{out}"


def test_inline_autosuggestion_and_fish_arrow_parity(
    launcher_ready: Path, fixture_workspace: Path, sample_atuin_command: str
) -> None:
    sentinel = "printf 'OUT:%s\\n' /usr/local/bin/alpha-beta-gamma"

    async def _run() -> None:
        # 1. Measure Fish's exact Alt+Left word-boundary delta on the same path
        fish = await _open_fish(fixture_workspace)
        try:
            await fish.type(sentinel)
            await fish.get_by_text("alpha-beta-gamma").expect(timeout=3000)
            await asyncio.sleep(0.15)
            fish_end_x = (await fish.get_cursor())["x"]
            await fish.press("Alt+Left")
            fish_after_alt_left_x = await _wait_cursor_x_change(fish, fish_end_x)
            fish_back_delta = fish_end_x - fish_after_alt_left_x
        finally:
            await fish.close_quiet()

        # 2. Verify Zsh: synced Atuin suggestion + Alt+Right partial accept + Right full accept + exact Alt+Left parity
        test_hist = fixture_workspace / ".test_zsh_history"
        test_hist.write_text(f"{sentinel}\n")

        zsh = await _open_zsh(launcher_ready, fixture_workspace, histfile=test_hist)
        try:
            # Synced Atuin history command shows up as inline ghost suggestion
            await asyncio.sleep(0.25)
            prefix = sample_atuin_command[:8]
            await zsh.type(prefix)
            await zsh.get_by_text(sample_atuin_command[:12]).expect(timeout=3000)
            await zsh.write("\x03")
            await zsh.wait_idle(timeout=1000)

            # Partial acceptance with Alt+Right (word/path segment) and full acceptance with Right
            typed_prefix = "printf 'OUT:%s\\n' /usr/"
            await zsh.type(typed_prefix)
            await zsh.get_by_text("alpha-beta-gamma").expect(timeout=3000)
            await asyncio.sleep(0.15)
            await zsh.screenshot(str(ARTIFACTS / "zsh-autosuggest.svg"))

            c0 = (await zsh.get_cursor())["x"]
            assert c0 >= len(typed_prefix), f"Cursor did not finish typing prefix: c0={c0}"

            # Alt+Right accepts one word ("local") instead of the whole path
            await zsh.press("Alt+Right")
            c1 = await _wait_cursor_x_change(zsh, c0)
            assert 5 <= (c1 - c0) <= 6, f"Expected Alt+Right to accept 'local' (5-6 chars), got delta={c1 - c0}"

            # Right accepts the entire remaining suggestion ("bin/alpha-beta-gamma")
            await zsh.press("Right")
            c2 = await _wait_cursor_x_change(zsh, c1)
            assert c2 - c0 == len("local/bin/alpha-beta-gamma"), (
                f"Expected Right to reach end of sentinel (delta={len('local/bin/alpha-beta-gamma')}), got {c2 - c0}"
            )

            # Alt+Left stops at the exact same dash boundary ("gamma") as Fish
            await zsh.press("Alt+Left")
            c3 = await _wait_cursor_x_change(zsh, c2)
            zsh_back_delta = c2 - c3
            assert zsh_back_delta == fish_back_delta, (
                f"Alt+Left word boundary mismatch: zsh={zsh_back_delta} vs fish={fish_back_delta}"
            )

            # Execute the accepted buffer and assert stdout-only marker (distinct from typed command)
            await zsh.press("Enter")
            await zsh.get_by_text("OUT:/usr/local/bin/alpha-beta-gamma").expect(timeout=3000)
        finally:
            await zsh.close_quiet()

    asyncio.run(_run())


async def _wait_first_line_change(term: TuiTest, prev_line: str, timeout_s: float = 2.0) -> str:
    deadline = time.perf_counter() + timeout_s
    while time.perf_counter() < deadline:
        line = (await term.text()).splitlines()[0]
        if line != prev_line:
            return line
        await asyncio.sleep(0.02)
    return (await term.text()).splitlines()[0]


def test_git_branch_completions_and_menu_selection(launcher_ready: Path, fixture_workspace: Path) -> None:
    async def _run() -> None:
        fish = await _open_fish(fixture_workspace)
        try:
            await fish.type("git switch ")
            await fish.press("Tab")
            await fish.get_by_text("feat/auth-flow").expect(timeout=5000)
            await fish.get_by_text("fix/tab-complete").expect(timeout=5000)
        finally:
            await fish.close_quiet()

        zsh = await _open_zsh(launcher_ready, fixture_workspace)
        try:
            await zsh.type("git switch ")
            await zsh.press("Tab")
            await zsh.get_by_text("feat/auth-flow").expect(timeout=5000)
            await zsh.get_by_text("fix/tab-complete").expect(timeout=5000)
            await zsh.screenshot(str(ARTIFACTS / "zsh-git-branches.svg"))

            # Navigate inside fzf-tab picker with Down/Up (must NOT trigger Atuin), filter to feat/auth-flow, accept with Enter
            await zsh.press("Down")
            await asyncio.sleep(0.15)
            await zsh.press("Up")
            await asyncio.sleep(0.15)
            screen_in_picker = await zsh.text()
            assert "Atuin" not in screen_in_picker and "GLOBAL" not in screen_in_picker, (
                f"Up in fzf-tab triggered Atuin:\n{screen_in_picker}"
            )
            await zsh.type("feat/auth")
            await asyncio.sleep(0.15)
            await zsh.press("Enter")
            await zsh.get_by_text("git switch feat/auth-flow").expect(timeout=3000)
        finally:
            await zsh.close_quiet()

    asyncio.run(_run())


def test_large_completion_list_uses_fzf_picker_without_prompt_corruption(
    launcher_ready: Path, fixture_workspace: Path
) -> None:
    async def _run() -> None:
        # Use real Starship prompt (simple_prompt=False) to catch prompt-redraw duplication bugs
        zsh = await _open_zsh(launcher_ready, fixture_workspace, simple_prompt=False)
        try:
            await zsh.get_by_text("❯").expect(timeout=5000)
            await asyncio.sleep(0.25)
            await zsh.type("pnpm ")
            await zsh.press("Tab")
            await zsh.get_by_text("install").expect(timeout=5000)
            screen = await zsh.text()
            assert "do you wish to see all" not in screen, f"Expected fzf-tab picker, not LISTMAX prompt:\n{screen}"
            assert "pnpm pnpm" not in screen, f"Duplicate command prefix detected:\n{screen}"

            await zsh.press("Escape")
            await asyncio.sleep(0.2)
            after_esc = await zsh.text()
            assert "pnpm pnpm" not in after_esc, f"Duplicate prefix stuck after Escape:\n{after_esc}"
        finally:
            await zsh.close_quiet()

    asyncio.run(_run())


@pytest.mark.parametrize(
    ("line", "expected"),
    [
        ("pnpm ", "install"),
        ("pnpm run ", "lint:fix"),
        ("git switch ", "feat/auth-flow"),
        ("eza --", "--absolute"),
    ],
)
def test_picker_is_inline_and_uniform_in_short_pane(
    launcher_ready: Path, fixture_workspace: Path, line: str, expected: str
) -> None:
    async def _run() -> None:
        term = TuiTest.ephemeral("zsh-picker")
        env = _launcher_env(simple_prompt=True)
        await term.run(str(launcher_ready), "-i", cwd=str(fixture_workspace), env=env, cols=110, rows=14)
        try:
            await term.get_by_text("$").expect(timeout=5000)
            await asyncio.sleep(0.3)
            await term.type(line)
            await term.press("Tab")
            await term.get_by_text(expected).expect(timeout=5000)
            await asyncio.sleep(0.2)
            screen = await term.text()
            rows = screen.splitlines()
            command_rows = [i for i, r in enumerate(rows) if r.startswith(f"$ {line.strip()}")]
            assert len(command_rows) == 1, f"Picker input should be merged into the one command line:\n{screen}"
            assert rows[command_rows[0] + 1].strip() and "─" not in rows[command_rows[0] + 1], (
                f"Candidates should start directly under the command line:\n{screen}"
            )
            assert not any(ch in screen for ch in "╭╰─│"[:2]), f"Picker frame present:\n{screen}"
            assert not any(r.lstrip("▌ ").startswith("·") for r in rows), f"Group prefix markers present:\n{screen}"
            assert "[" not in screen.split(expected)[0].split(line.strip(), 1)[-1], (
                f"Group header row present above candidates:\n{screen}"
            )
            await term.press("Escape")
        finally:
            await term.close_quiet()

    asyncio.run(_run())


async def _typed_cells(term: TuiTest, text: str) -> list:
    await term.type(text)
    await asyncio.sleep(0.6)
    y = (await term.get_cursor())["y"]
    return await term.cells(2, y, len(text), 1)


@pytest.mark.parametrize("line", ['echo "q" $HOME README.md | grep x', "nosuchcmd arg"])
def test_syntax_highlighting_matches_fish_cell_for_cell(
    launcher_ready: Path, fixture_workspace: Path, line: str
) -> None:
    def look(c):
        # Foreground on a blank cell is invisible, so only compare it on glyphs.
        return (c.char, c.fg if c.char.strip() else None, c.bg, c.bold, c.underline)

    async def _run() -> None:
        fish = await _open_fish(fixture_workspace)
        try:
            fish_cells = [look(c) for c in await _typed_cells(fish, line)]
        finally:
            await fish.close_quiet()
        zsh = await _open_zsh(launcher_ready, fixture_workspace)
        try:
            await asyncio.sleep(0.4)
            zsh_cells = [look(c) for c in await _typed_cells(zsh, line)]
        finally:
            await zsh.close_quiet()
        diffs = [(i, f, z) for i, (f, z) in enumerate(zip(fish_cells, zsh_cells)) if f != z]
        assert not diffs, "cells differ (index, fish, zsh):\n" + "\n".join(map(str, diffs))

    asyncio.run(_run())


def test_picker_uses_fish_pager_colors_and_paren_descriptions(
    launcher_ready: Path, fixture_workspace: Path
) -> None:
    async def _run() -> None:
        zsh = await _open_zsh(launcher_ready, fixture_workspace)
        try:
            await asyncio.sleep(0.4)
            await zsh.type("git switch ")
            await zsh.press("Tab")
            await zsh.get_by_text("(initial)").expect(timeout=5000)
            rows = (await zsh.text()).splitlines()
            y = next(i for i, r in enumerate(rows) if "fix/tab-complete" in r)
            x = rows[y].index("(initial)")
            desc = (await zsh.cells(x, y))[0]
            word = (await zsh.cells(rows[y].index("fix/"), y))[0]
            assert desc.fg == "#4c566a", f"description should use fish_pager_color_description: {desc}"
            cur = await zsh.get_cursor()
            command_row = (await zsh.cells(3, cur["y"]))[0]
            # fzf can only tint the list by also tinting its input row; the command line wins.
            assert command_row.bg == "default", f"command line should keep the terminal background: {command_row}"
            assert "-- initial" not in "\n".join(rows)
        finally:
            await zsh.close_quiet()

    asyncio.run(_run())


@pytest.mark.parametrize("typed", ["cat read", "cat EADME"])
def test_file_completion_is_case_insensitive_and_substring_like_fish(
    launcher_ready: Path, fixture_workspace: Path, typed: str
) -> None:
    async def _run() -> None:
        zsh = await _open_zsh(launcher_ready, fixture_workspace)
        try:
            await asyncio.sleep(0.4)
            await zsh.type(typed)
            await zsh.press("Tab")
            await asyncio.sleep(1.0)
            cur = await zsh.get_cursor()
            row = (await zsh.text()).splitlines()[cur["y"]]
            assert row[2:cur["x"]].rstrip() == "cat README.md", f"got {row!r}"
        finally:
            await zsh.close_quiet()

    asyncio.run(_run())


@pytest.mark.parametrize(
    ("typed", "expected"),
    [
        ("claude ", "mcp"),  # no zsh or carapace completion; Fish has one
        ("dust -", "--apparent-size"),  # Fish's man-page-generated completion
        ("cd -", "-P"),  # zsh's _cd offers nothing here; Fish lists options
        ("fnox ", "activate"),  # neither shell ships one; fnox prints its own
        ("opencode2 ", "serve"),  # its script registers "opencode", not "opencode2"
        # ~/.local/bin Fish script declaring --wraps='git add --all --patch'; --patch is
        # already given, so git add's other --pa* flag is what's left to offer.
        ("gap --pa", "--pathspec-from-file"),
        ("pnpx --pack", "--package"),  # completes as `pnpm dlx`
    ],
)
def test_fish_completions_fill_gaps_zsh_cannot_complete(
    launcher_ready: Path, fixture_workspace: Path, typed: str, expected: str
) -> None:
    async def _run() -> None:
        zsh = await _open_zsh(launcher_ready, fixture_workspace)
        try:
            await asyncio.sleep(0.4)
            await zsh.type(typed)
            await zsh.press("Tab")
            await zsh.get_by_text(expected).expect(timeout=6000)
        finally:
            await zsh.close_quiet()

    asyncio.run(_run())


def test_shared_longer_prefix_opens_picker_on_it_like_fish(launcher_ready: Path, fixture_workspace: Path) -> None:
    async def _run() -> None:
        zsh = await _open_zsh(launcher_ready, fixture_workspace)
        try:
            await asyncio.sleep(0.4)
            await zsh.type("git add --pa")
            await zsh.press("Tab")
            await zsh.get_by_text("--pathspec-from-file").expect(timeout=6000)
            screen = await zsh.text()
            # --patch, --pathspec-file-nul and --pathspec-from-file share "--pat". Tools such
            # as fnox may print a line above the prompt, so find the prompt's row.
            command_row = next(r for r in screen.splitlines() if r.startswith("$ "))
            assert command_row.rstrip() == "$ git add --pat", screen
            assert "--patch" in screen
        finally:
            await zsh.close_quiet()

    asyncio.run(_run())


def test_npm_and_pnpm_script_completions(launcher_ready: Path, fixture_workspace: Path) -> None:
    async def _run() -> None:
        zsh = await _open_zsh(launcher_ready, fixture_workspace)
        try:
            await zsh.type("npm run ")
            await zsh.press("Tab")
            await zsh.get_by_text("lint:fix").expect(timeout=5000)
            await zsh.get_by_text("test:e2e").expect(timeout=5000)
            await zsh.screenshot(str(ARTIFACTS / "zsh-npm-scripts.svg"))
        finally:
            await zsh.close_quiet()

        zsh2 = await _open_zsh(launcher_ready, fixture_workspace)
        try:
            await zsh2.type("pnpm run ")
            await zsh2.press("Tab")
            await zsh2.get_by_text("lint:fix").expect(timeout=5000)
            await zsh2.get_by_text("test:e2e").expect(timeout=5000)
        finally:
            await zsh2.close_quiet()

    asyncio.run(_run())


def test_uv_subcommands_scripts_and_flags(launcher_ready: Path, fixture_workspace: Path) -> None:
    async def _run() -> None:
        zsh = await _open_zsh(launcher_ready, fixture_workspace)
        try:
            await zsh.type("uv ")
            await zsh.press("Tab")
            await zsh.get_by_text("add").expect(timeout=5000)
            await zsh.type("sync")
            await zsh.get_by_text("sync").expect(timeout=3000)
        finally:
            await zsh.close_quiet()

        zsh2 = await _open_zsh(launcher_ready, fixture_workspace)
        try:
            await zsh2.type("uv run --")
            await zsh2.press("Tab")
            await zsh2.type("with")
            await zsh2.get_by_text("--with").expect(timeout=5000)
            await zsh2.screenshot(str(ARTIFACTS / "zsh-uv-flags.svg"))
        finally:
            await zsh2.close_quiet()

        zsh3 = await _open_zsh(launcher_ready, fixture_workspace)
        try:
            await zsh3.type("uv run demo")
            await zsh3.press("Tab")
            await zsh3.get_by_text("demo-cli").expect(timeout=5000)
        finally:
            await zsh3.close_quiet()

    asyncio.run(_run())


def test_program_argument_completions(launcher_ready: Path, fixture_workspace: Path) -> None:
    async def _run() -> None:
        zsh = await _open_zsh(launcher_ready, fixture_workspace)
        try:
            await zsh.type("rg --h")
            await zsh.press("Tab")
            await zsh.get_by_text("--hidden").expect(timeout=5000)
            await zsh.screenshot(str(ARTIFACTS / "zsh-rg-flags.svg"))
        finally:
            await zsh.close_quiet()

        zsh2 = await _open_zsh(launcher_ready, fixture_workspace)
        try:
            await zsh2.type("rg --g")
            await zsh2.press("Tab")
            await zsh2.get_by_text("--glob").expect(timeout=5000)
        finally:
            await zsh2.close_quiet()

    asyncio.run(_run())


def test_atuin_ctrl_r_and_up_arrow_integration(launcher_ready: Path, fixture_workspace: Path) -> None:
    async def _run() -> None:
        hist = fixture_workspace / ".atuin_test_history"
        zsh = await _open_zsh(launcher_ready, fixture_workspace, histfile=hist)
        try:
            await asyncio.sleep(0.35)
            await zsh.write("\x12")
            await zsh.get_by_text("GLOBAL", regex=False).expect(timeout=5000)
            await zsh.press("Escape")
            await asyncio.sleep(0.25)

            # Up arrow outside completion menu should also invoke Atuin (matching Fish bind up _atuin_bind_up)
            await zsh.press("Up")
            await zsh.get_by_text("GLOBAL", regex=False).expect(timeout=5000)
            await zsh.press("Escape")
            await asyncio.sleep(0.25)
            await zsh.type("echo ok")
            await zsh.press("Enter")
            await zsh.get_by_text("ok").expect(timeout=3000)
        finally:
            await zsh.close_quiet()

    asyncio.run(_run())
