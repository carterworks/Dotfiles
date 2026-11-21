"""Drive real Fish and the Fish-feel Zsh through identical keystrokes and score parity.

Run: uv run --with tui-test python tests/zsh/parity_scorecard.py
Writes artifacts/parity-scorecard.json and artifacts/parity-scorecard.html.
"""

import asyncio
import html
import json
import os
import shutil
import statistics
import subprocess
import tempfile
import time
from pathlib import Path

from tui_test import TuiTest

ROOT = Path(__file__).resolve().parent.parent.parent
ARTIFACTS = ROOT / "tests/zsh/artifacts"
SCRATCH = Path(tempfile.mkdtemp(prefix="zff-parity-"))
FISH_HISTORY_NAME = "zffparity"

# Both shells record commands into Atuin; point it at a throwaway DB so the
# scorecard never writes into the user's real history.
ISOLATED_ATUIN = {
    "ATUIN_DB_PATH": str(SCRATCH / "atuin.db"),
    "ATUIN_RECORD_STORE_PATH": str(SCRATCH / "atuin-records.db"),
}

SENTINEL = "echo /usr/local/bin/alpha-beta-gamma"
KILL_LINE = "echo /opt/kill-test/one-two"


def make_fixture() -> Path:
    ws = SCRATCH / "ws"
    ws.mkdir()
    run = lambda *a: subprocess.run(a, cwd=ws, check=True, capture_output=True)
    run("git", "init", "-b", "main")
    run("git", "config", "user.email", "t@example.com")
    run("git", "config", "user.name", "T")
    (ws / "package.json").write_text(json.dumps({"name": "fx", "scripts": {
        "build": "vite build", "dev": "vite", "lint:fix": "eslint --fix .", "test:e2e": "playwright test"}}))
    (ws / "pyproject.toml").write_text(
        '[project]\nname = "fx"\nversion = "0.1.0"\n\n[project.scripts]\ndemo-cli = "demo:main"\n')
    (ws / "README.md").write_text("# fx\n")
    (ws / "subdir").mkdir()
    (ws / "subdir" / ".keep").write_text("")
    run("git", "add", ".")
    run("git", "commit", "-m", "initial")
    run("git", "branch", "feat/auth-flow")
    run("git", "branch", "fix/tab-complete")
    return ws


class Term:
    def __init__(self, shell: str, tui: TuiTest):
        self.shell, self.t = shell, tui

    async def settle(self, s: float = 0.35):
        await asyncio.sleep(s)

    async def type(self, s: str):
        await self.t.type(s)
        await self.settle()

    async def key(self, k: str, s: float = 0.35):
        await self.t.press(k)
        await self.settle(s)

    async def raw(self, b: str, s: float = 0.35):
        await self.t.write(b)
        await self.settle(s)

    async def run_cmd(self, cmd: str):
        await self.t.type(cmd)
        await self.t.press("Enter")
        await self.settle(0.6)

    async def screen(self) -> str:
        return await self.t.text()

    async def cx(self) -> int:
        return (await self.t.get_cursor())["x"]

    async def line(self) -> str:
        y = (await self.t.get_cursor())["y"]
        rows = (await self.screen()).splitlines()
        return rows[y] if y < len(rows) else ""

    async def buffer(self) -> str:
        # Text left of the cursor, so trailing ghost suggestions aren't counted as typed.
        return (await self.line())[2:await self.cx()].rstrip()

    async def cell(self, x: int):
        y = (await self.t.get_cursor())["y"]
        return (await self.t.cells(x, y))[0]


async def open_shell(shell: str, ws: Path, hist: dict) -> Term:
    tui = TuiTest.ephemeral(f"parity-{shell}")
    env = os.environ | {"TERM": "xterm-256color"} | ISOLATED_ATUIN
    if shell == "fish":
        env["fish_history"] = FISH_HISTORY_NAME
        setup = ("function fish_prompt; echo -n '$ '; end; function fish_right_prompt; end; "
                 f"set -g fish_greeting; set -g fish_history {FISH_HISTORY_NAME}")
        await tui.run("fish", "-i", "-C", setup, cwd=str(ws), env=env, cols=110, rows=30)
    else:
        env |= {
            "ZSH_FISH_FEEL_SIMPLE_PROMPT": "1",
            "ZSH_FISH_FEEL_SKIP_EXIT_SYNC": "1",
            "ZSH_FISH_FEEL_NO_DIRENV": "1",
            "ZSH_FISH_FEEL_HISTFILE": hist["zsh"],
            "ZSH_FISH_FEEL_ATUIN_HIST": hist["atuin"],
        }
        await tui.run(str(ROOT / "zsh/try"), "-i", cwd=str(ws), env=env, cols=110, rows=30)
    await tui.get_by_text("$").expect(timeout=8000)
    await asyncio.sleep(0.6)
    return Term(shell, tui)


def is_red(fg) -> bool:
    if isinstance(fg, int):
        return fg in (1, 9, 160, 161, 196)
    if isinstance(fg, str) and fg.startswith("#") and len(fg) == 7:
        r, g, b = (int(fg[i:i + 2], 16) for i in (1, 3, 5))
        return r > g + 40 and r > b + 40
    return False


async def suggested_line(t: Term) -> int:
    await t.run_cmd(SENTINEL)
    await t.type("echo /usr/")
    return await t.cx()


async def c_suggest(t):
    await suggested_line(t)
    return "alpha-beta-gamma" in await t.line()


async def c_ghost_distinct(t):
    x = await suggested_line(t)
    return (await t.cell(x)).fg != (await t.cell(2)).fg


async def accept_delta(t, keys):
    x0 = await suggested_line(t)
    for k in keys:
        await (t.raw(k) if k.startswith("\x1b") or len(k) == 1 else t.key(k))
    return await t.cx() - x0


async def c_right(t):
    return await accept_delta(t, ["Right"])


async def c_alt_right(t):
    return await accept_delta(t, ["Alt+Right"])


async def c_ctrl_right(t):
    return await accept_delta(t, ["Ctrl+Right"])


async def c_ctrl_e(t):
    return await accept_delta(t, ["\x05"])


async def c_alt_left(t):
    x0 = await suggested_line(t)
    await t.key("Right")
    x1 = await t.cx()
    await t.key("Alt+Left")
    return x1 - await t.cx() if x1 > x0 else "no accept"


async def kill(t, seq):
    await t.type(KILL_LINE)
    await t.raw(seq)
    return await t.buffer()


async def c_alt_bs(t):
    return await kill(t, "\x1b\x7f")


async def c_ctrl_w(t):
    return await kill(t, "\x17")


async def c_ctrl_u(t):
    return await kill(t, "\x15")


async def c_ctrl_c(t):
    await t.type("echo nope")
    await t.raw("\x03", 0.6)
    return await t.buffer()


ATUIN_MARKERS = ("GLOBAL", "HOST", "SESSION", "DIRECTORY", "Atuin")


async def c_up_atuin(t):
    await t.run_cmd("echo up-seed")
    await t.raw("\x1b[A", 1.2)
    screen = await t.screen()
    return any(m in screen for m in ATUIN_MARKERS)


async def c_ctrl_r(t):
    await t.raw("\x12", 1.2)
    screen = await t.screen()
    return any(m in screen for m in ATUIN_MARKERS)


async def tab_screen(t, typed, wait=1.4):
    await t.type(typed)
    await t.key("Tab", wait)
    return await t.screen()


async def c_git_branches(t):
    s = await tab_screen(t, "git switch ")
    return sorted(b for b in ("main", "feat/auth-flow", "fix/tab-complete") if b in s)


async def c_pnpm_scripts(t):
    s = await tab_screen(t, "pnpm run ")
    return sorted(x for x in ("build", "dev", "lint:fix", "test:e2e") if x in s)


async def c_uv_scripts(t):
    return "demo-cli" in await tab_screen(t, "uv run dem")


async def c_flag_desc(t):
    s = await tab_screen(t, "rg --h")
    return {"--hidden listed": "--hidden" in s, "has description": "hidden files" in s.lower()}


async def c_subcmd_desc(t):
    s = await tab_screen(t, "git sw")
    if "git switch" in (await t.line()):
        return "completed inline"
    return "listed"


async def tab_buffer(t, typed):
    await tab_screen(t, typed, 1.0)
    return await t.buffer()


async def c_unique_path(t):
    return await tab_buffer(t, "cat READ")


async def c_case_insensitive(t):
    return await tab_buffer(t, "cat read")


async def c_substring(t):
    return await tab_buffer(t, "cat EADME")


async def c_dir_slash(t):
    return await tab_buffer(t, "cd subd")


async def c_unknown_red(t):
    await t.type("notacommandxyz")
    await t.settle(0.4)
    return is_red((await t.cell(2)).fg)


async def c_valid_not_red(t):
    await t.type("echo")
    await t.settle(0.4)
    return is_red((await t.cell(2)).fg)


async def c_path_underline(t):
    await t.type("ls README.md")
    await t.settle(0.4)
    return (await t.cell(6)).underline


async def c_quote_color(t):
    await t.type('echo plain "quoted"')
    await t.settle(0.4)
    return (await t.cell(7)).fg != (await t.cell(13)).fg


async def c_implicit_cd(t):
    await t.run_cmd("subdir/")
    await t.run_cmd("pwd")
    return any(r.rstrip().endswith("/subdir") for r in (await t.screen()).splitlines())


async def c_bang_inline(t):
    await t.run_cmd("echo bang-ok")
    await t.type("!!")
    return await t.buffer()


async def c_bang_runs(t):
    await t.run_cmd("echo bang-ok")
    await t.run_cmd("!!")
    return sum(r.strip() == "bang-ok" for r in (await t.screen()).splitlines())


async def c_ctrl_d(t):
    await t.raw("\x04", 0.2)
    try:
        await t.t.wait_exit(timeout=3000)
        return True
    except Exception:
        return False


HL_LINE = 'echo "q" $HOME README.md | grep x'
HL_AT = {"command": 0, "quote": 6, "variable": 10, "path": 16, "pipe": 25, "argument": 32}


def hl_check(element):
    async def check(t):
        await t.type(HL_LINE)
        await t.settle(0.5)
        y = (await t.t.get_cursor())["y"]
        c = (await t.t.cells(2 + HL_AT[element], y))[0]
        return f"{c.fg}{' underline' if c.underline else ''}{' bold' if c.bold else ''}"

    check.__name__ = f"c_hl_{element}"
    return check


async def c_error_color(t):
    await t.type("nosuchcmd")
    await t.settle(0.5)
    return (await t.cell(2)).fg


async def c_ghost_color(t):
    x = await suggested_line(t)
    return (await t.cell(x)).fg


async def pager(t, presses=1):
    await t.type("git switch ")
    for _ in range(presses):
        await t.key("Tab", 1.2)
    rows = (await t.screen()).splitlines()
    y = next((i for i, r in enumerate(rows) if "fix/tab-complete" in r), None)
    return rows, y


async def c_pager_bg(t):
    rows, y = await pager(t)
    if y is None:
        return "no pager"
    return (await t.t.cells(rows[y].index("fix/"), y))[0].bg


async def c_pager_desc(t):
    rows, y = await pager(t)
    if y is None:
        return "no pager"
    rest = rows[y][rows[y].index("fix/tab-complete") + len("fix/tab-complete"):]
    if "(" not in rest:
        return "no parenthesized description"
    x = rows[y].index("(", rows[y].index("fix/tab-complete")) + 1
    return f"(…) in {(await t.t.cells(x, y))[0].fg}"


async def c_pager_selected_bg(t):
    rows, _ = await pager(t, presses=2)
    bgs = set()
    for b in ("main", "feat/auth-flow", "fix/tab-complete"):
        y = next((i for i, r in enumerate(rows) if b in r and not r.startswith("$")), None)
        if y is not None:
            bgs.add((await t.t.cells(rows[y].index(b), y))[0].bg)
    return sorted(map(str, bgs))


async def c_pager_counter(t):
    rows, y = await pager(t)
    return any("3/3" in r or "of 3" in r for r in rows)


async def c_pager_layout(t):
    rows, _ = await pager(t)
    used = {i for i, r in enumerate(rows) for b in ("main", "feat/auth-flow", "fix/tab-complete")
            if b in r and not r.startswith("$")}
    return "columns" if len(used) < 3 else "one per row"


EXACT, MORE = "exact", "more-is-better"

CHECKS = [
    ("Inline suggestions", "Ghost text from history", c_suggest, EXACT),
    ("Inline suggestions", "Ghost text visually distinct", c_ghost_distinct, EXACT),
    ("Inline suggestions", "Right accepts whole suggestion (cols)", c_right, EXACT),
    ("Inline suggestions", "Alt+Right accepts one word (cols)", c_alt_right, EXACT),
    ("Inline suggestions", "Ctrl+Right accepts (cols)", c_ctrl_right, EXACT),
    ("Inline suggestions", "Ctrl+E accepts (cols)", c_ctrl_e, EXACT),
    ("Inline suggestions", "Alt+Left word boundary (cols)", c_alt_left, EXACT),
    ("Line editing", "Alt+Backspace result", c_alt_bs, EXACT),
    ("Line editing", "Ctrl+W result", c_ctrl_w, EXACT),
    ("Line editing", "Ctrl+U result", c_ctrl_u, EXACT),
    ("Line editing", "Ctrl+C clears line", c_ctrl_c, EXACT),
    ("Line editing", "Ctrl+D exits on empty line", c_ctrl_d, EXACT),
    ("History (Atuin)", "Up opens Atuin", c_up_atuin, EXACT),
    ("History (Atuin)", "Ctrl+R opens Atuin", c_ctrl_r, EXACT),
    ("Tab completion", "git switch → branches", c_git_branches, MORE),
    ("Tab completion", "pnpm run → package.json scripts", c_pnpm_scripts, MORE),
    ("Tab completion", "uv run → pyproject scripts", c_uv_scripts, MORE),
    ("Tab completion", "Flags with descriptions (rg --h)", c_flag_desc, EXACT),
    ("Tab completion", "Unique subcommand prefix (git sw)", c_subcmd_desc, EXACT),
    ("Tab completion", "Unique path completes (cat READ)", c_unique_path, EXACT),
    ("Tab completion", "Case-insensitive path (cat read)", c_case_insensitive, EXACT),
    ("Tab completion", "Substring path (cat EADME)", c_substring, EXACT),
    ("Tab completion", "Directory gets trailing slash", c_dir_slash, EXACT),
    ("Syntax highlighting", "Unknown command is red", c_unknown_red, EXACT),
    ("Syntax highlighting", "Valid command is red", c_valid_not_red, EXACT),
    ("Syntax highlighting", "Existing path underlined", c_path_underline, EXACT),
    ("Syntax highlighting", "Quoted string colored differently", c_quote_color, EXACT),
    ("Visual style", "Command color", hl_check("command"), EXACT),
    ("Visual style", "Quoted string color", hl_check("quote"), EXACT),
    ("Visual style", "Variable color", hl_check("variable"), EXACT),
    ("Visual style", "Existing path style", hl_check("path"), EXACT),
    ("Visual style", "Pipe color", hl_check("pipe"), EXACT),
    ("Visual style", "Plain argument color", hl_check("argument"), EXACT),
    ("Visual style", "Unknown command color", c_error_color, EXACT),
    ("Visual style", "Ghost text color", c_ghost_color, EXACT),
    ("Visual style", "Pager row background", c_pager_bg, EXACT),
    ("Visual style", "Pager description format and color", c_pager_desc, EXACT),
    ("Visual style", "Pager selected/unselected backgrounds", c_pager_selected_bg, EXACT),
    ("Visual style", "Pager shows match counter", c_pager_counter, EXACT),
    ("Visual style", "Pager layout", c_pager_layout, EXACT),
    ("Navigation", "Implicit cd (subdir/)", c_implicit_cd, EXACT),
    ("Navigation", "!! expands inline before Enter", c_bang_inline, EXACT),
    ("Navigation", "!! re-runs previous command (output count)", c_bang_runs, EXACT),
]


def judge(fish, zsh, mode):
    """match: same observable. ahead: Zsh does everything Fish does and more. gap: Zsh falls short."""
    if fish == zsh:
        return "match"
    if mode == "more-is-better":
        if isinstance(fish, list) and set(zsh) >= set(fish):
            return "ahead"
        if fish is False and zsh is True:
            return "ahead"
    return "gap"


def median_ms(cmd, env, runs=7):
    subprocess.run(cmd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    samples = []
    for _ in range(runs):
        t0 = time.perf_counter()
        subprocess.run(cmd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        samples.append((time.perf_counter() - t0) * 1000)
    return round(statistics.median(samples), 1)


NOTES = {
    "Alt+Right accepts one word (cols)": "Zsh forward-word also takes the trailing /; Fish stops before it.",
    "Ctrl+Right accepts (cols)": "Fish binds forward-token (whole argument); Zsh binds forward-word.",
    "Ctrl+W result": "Fish deletes a whole path component; Zsh deletes one word.",
    "!! expands inline before Enter": "Fish's bang-bang plugin rewrites the line; Zsh expands only on Enter.",
    "Pager row background": "fzf can only tint the list by also tinting the command line row or adding a border row; the command line stays clean.",
    "Pager selected/unselected backgrounds": "Selected row matches (#d8dee9); unselected rows lack the pager tint for the same fzf reason.",
    "Pager layout": "Fish packs candidates into columns; the fzf picker lists one per row so it can filter.",
    "pnpm run → package.json scripts": "Your Fish completion for pnpm doesn't list package.json scripts.",
    "uv run → pyproject scripts": "Your Fish completion for uv doesn't list pyproject scripts.",
}

VERDICT_STYLE = {"match": ("Match", "#1f7a4d", "#e3f4ea"), "ahead": ("Zsh ahead", "#1d5fa8", "#e2edf9"),
                 "gap": ("Gap", "#a3444e", "#f8e5e7"), "error": ("Error", "#7a5a00", "#fbf1d6")}


def fmt(v):
    if isinstance(v, bool):
        return "yes" if v else "no"
    if isinstance(v, list):
        return ", ".join(v) if v else "(none)"
    if isinstance(v, dict):
        return ", ".join(f"{k}: {fmt(x)}" for k, x in v.items())
    if v == "":
        return "(empty)"
    return str(v)


def render_html(rows) -> str:
    counts = {k: sum(r["verdict"] == k for r in rows) for k in VERDICT_STYLE}
    total = len(rows)
    parity = round(100 * (counts["match"] + counts["ahead"]) / total)
    cards = "".join(
        f'<div class="card" style="background:{bg};color:{fg}"><b>{counts[k]}</b><span>{label}</span></div>'
        for k, (label, fg, bg) in VERDICT_STYLE.items() if counts[k] or k != "error")
    body, current = [], None
    for r in rows:
        if r["category"] != current:
            current = r["category"]
            sub = [x for x in rows if x["category"] == current]
            ok = sum(x["verdict"] in ("match", "ahead") for x in sub)
            body.append(f'<tr class="cat"><td colspan="4">{html.escape(current)}'
                        f'<span class="catscore">{ok}/{len(sub)}</span></td></tr>')
        label, fg, bg = VERDICT_STYLE[r["verdict"]]
        note = NOTES.get(r["check"], "") if r["verdict"] != "match" else ""
        body.append(
            f'<tr><td>{html.escape(r["check"])}'
            + (f'<div class="note">{html.escape(note)}</div>' if note else "")
            + f'</td><td class="obs">{html.escape(fmt(r["fish"]))}</td>'
            f'<td class="obs">{html.escape(fmt(r["zsh"]))}</td>'
            f'<td><span class="pill" style="color:{fg};background:{bg}">{label}</span></td></tr>')
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
body{{font:14px/1.45 -apple-system,system-ui,sans-serif;margin:20px;color:#1d2330;background:#fff}}
h1{{font-size:20px;margin:0 0 4px}} .sub{{color:#5b6472;margin-bottom:16px}}
.cards{{display:flex;gap:10px;margin-bottom:18px}}
.card{{border-radius:10px;padding:10px 14px;min-width:96px;display:flex;flex-direction:column}}
.card b{{font-size:24px;line-height:1.1}} .card span{{font-size:12px}}
.big{{background:#1d2330;color:#fff}}
table{{border-collapse:collapse;width:100%}} td,th{{padding:7px 8px;border-bottom:1px solid #e6e9ee;vertical-align:top;text-align:left}}
th{{font-size:12px;color:#5b6472;font-weight:600}}
tr.cat td{{background:#f3f5f8;font-weight:600;padding-top:9px}} .catscore{{float:right;color:#5b6472;font-weight:500}}
.obs{{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12.5px;color:#39404d}}
.note{{color:#6b7380;font-size:12px;margin-top:2px}}
.pill{{border-radius:999px;padding:2px 9px;font-size:12px;font-weight:600;white-space:nowrap}}
</style></head><body>
<h1>Fish behavioral parity: Fish-feel Zsh</h1>
<div class="sub">Measured by driving real Fish and the new Zsh through identical keystrokes in tui-test.
Parity counts both Match and Zsh ahead.</div>
<div class="cards"><div class="card big"><b>{parity}%</b><span>parity ({counts['match'] + counts['ahead']}/{total})</span></div>{cards}</div>
<table><tr><th>Check</th><th>Fish</th><th>Zsh</th><th>Verdict</th></tr>{''.join(body)}</table>
</body></html>"""


async def observe(shell, fn, ws, hist):
    t = await open_shell(shell, ws, hist)
    try:
        return await fn(t)
    except Exception as e:  # report broken checks instead of aborting the whole card
        return f"error: {type(e).__name__}: {str(e)[:80]}"
    finally:
        await t.t.close_quiet()


async def main():
    ws = make_fixture()
    hist = {"zsh": str(SCRATCH / "zsh_history"), "atuin": str(SCRATCH / "atuin-export.zsh")}
    Path(hist["atuin"]).write_text("")
    subprocess.run([str(ROOT / "zsh/try"), "--warmup"], check=True,
                   env=os.environ | {"ZSH_FISH_FEEL_ATUIN_HIST": hist["atuin"]})

    rows = []
    for category, name, fn, mode in CHECKS:
        fish = await observe("fish", fn, ws, hist)
        zsh = await observe("zsh", fn, ws, hist)
        verdict = judge(fish, zsh, mode)
        if any(isinstance(v, str) and v.startswith("error") for v in (fish, zsh)):
            verdict = "error"
        rows.append({"category": category, "check": name, "fish": fish, "zsh": zsh, "verdict": verdict})
        print(f"[{verdict:7}] {category} / {name}: fish={fish!r} zsh={zsh!r}")

    zenv = os.environ | ISOLATED_ATUIN | {"ZSH_FISH_FEEL_SKIP_EXIT_SYNC": "1", "ZSH_FISH_FEEL_NO_DIRENV": "1",
                                          "ZSH_FISH_FEEL_ATUIN_HIST": hist["atuin"]}
    fish_ms = median_ms(["fish", "-i", "-c", "exit"], os.environ | ISOLATED_ATUIN)
    zsh_ms = median_ms([str(ROOT / "zsh/try"), "-i", "-c", "exit"], zenv)
    rows.append({"category": "Performance", "check": "Interactive startup median (ms)",
                 "fish": fish_ms, "zsh": zsh_ms, "verdict": "ahead" if zsh_ms <= fish_ms else "gap"})
    print(f"startup fish={fish_ms} zsh={zsh_ms}")

    ARTIFACTS.mkdir(exist_ok=True)
    (ARTIFACTS / "parity-scorecard.json").write_text(json.dumps(rows, indent=2, default=str))
    (ARTIFACTS / "parity-scorecard.html").write_text(render_html(rows))
    fish_hist = Path.home() / ".local/share/fish" / f"{FISH_HISTORY_NAME}_history"
    fish_hist.unlink(missing_ok=True)
    shutil.rmtree(SCRATCH, ignore_errors=True)


if __name__ == "__main__":
    import sys

    if "--render-only" in sys.argv:
        saved = json.loads((ARTIFACTS / "parity-scorecard.json").read_text())
        (ARTIFACTS / "parity-scorecard.html").write_text(render_html(saved))
        shutil.rmtree(SCRATCH, ignore_errors=True)
    else:
        asyncio.run(main())
