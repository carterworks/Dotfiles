"""Which programs get Tab completion in Fish vs the Fish-feel Zsh (zsh + carapace)?

A program counts as completed when Tab after "<cmd> " or "<cmd> -" offers anything,
probed from an empty directory so plain file completion contributes nothing.

Run: uv run --with tui-test python tests/zsh/completion_coverage.py [--label NAME] [--no-fish-bridge]
Writes artifacts/completion-coverage[-NAME].json and .html. Run once with
--label baseline --no-fish-bridge to show Zsh's coverage before the gap-closing work.
"""

import concurrent.futures as cf
import html
import json
import os
import re
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
ARTIFACTS = ROOT / "tests/zsh/artifacts"
EMPTY = Path(tempfile.mkdtemp(prefix="zff-cov-"))
NAME_OK = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._+@-]*$")
ZSH_ENV = os.environ | {
    "ZSH_USE_FZF_TAB": "0",
    "ZSH_FISH_FEEL_NO_DEFER": "1",
    "ZSH_FISH_FEEL_SIMPLE_PROMPT": "1",
    "ZSH_FISH_FEEL_SKIP_EXIT_SYNC": "1",
    "ZSH_FISH_FEEL_NO_DIRENV": "1",
}


def path_commands() -> list[str]:
    out = subprocess.run([str(ROOT / "zsh/try"), "-i", "-c", "print -rl -- ${(k)commands}"],
                         env=ZSH_ENV, capture_output=True, text=True, check=True).stdout
    return sorted({c for c in out.split() if NAME_OK.match(c)})


def usage_counts(commands: set[str]) -> Counter:
    """How often each PATH command starts a line in Atuin history (counted locally only)."""
    session = subprocess.run(["atuin", "uuid"], capture_output=True, text=True).stdout.strip()
    raw = subprocess.run(["atuin", "history", "list", "--cmd-only", "--print0"],
                         env=os.environ | {"ATUIN_SESSION": session}, capture_output=True).stdout
    counts = Counter()
    for entry in raw.decode(errors="ignore").split("\0"):
        words = [w for w in entry.split() if "=" not in w or w.startswith("-")]
        if words and words[0] in commands:
            counts[words[0]] += 1
    return counts


def fish_complete_path() -> list[str]:
    out = subprocess.run(["fish", "-i", "-c", 'printf "%s\\n" $fish_complete_path'],
                         capture_output=True, text=True).stdout
    return [p for p in out.splitlines() if p.startswith("/")]


FISH_PROBE = ('set -g fish_complete_path $argv[2..] $fish_complete_path; '
              'complete -C "$argv[1] "; echo __ZFF_SPLIT__; complete -C "$argv[1] -"')


def fish_probe(cmd: str, paths: list[str]) -> dict:
    try:
        out = subprocess.run(["timeout", "10", "fish", "--no-config", "-c", FISH_PROBE, cmd, *paths],
                             cwd=EMPTY, capture_output=True, text=True, timeout=15).stdout
    except subprocess.TimeoutExpired:
        return {"space": 0, "dash": 0, "sample": [], "timeout": True}
    space, _, dash = out.partition("__ZFF_SPLIT__")
    space = [l.split("\t")[0] for l in space.splitlines() if l.strip()]
    dash = [l.split("\t")[0] for l in dash.splitlines() if l.startswith("-")]
    return {"space": len(space), "dash": len(dash), "sample": (space + dash)[:4]}


def zsh_probe_all(commands: list[str], shards: int = 12) -> dict:
    chunks = [commands[i::shards] for i in range(shards)]
    procs = [subprocess.Popen([str(ROOT / "tests/zsh/zsh_complete_capture.zsh")], cwd=EMPTY, env=ZSH_ENV,
                              stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                              text=True) for _ in chunks]
    for p, chunk in zip(procs, chunks):
        p.stdin.write("\n".join(chunk) + "\n")
        p.stdin.close()
    result = {c: {"space": 0, "dash": 0, "sample": []} for c in commands}
    for p in procs:
        for line in p.stdout:
            cmd, probe, cand = (line.rstrip("\n").split("\t") + ["", ""])[:3]
            if cmd not in result or not cand:
                continue
            r = result[cmd]
            if cand == "<timeout>":
                r["timeout"] = True
            elif probe.endswith(" -"):
                if cand.startswith("-") or cand.startswith("<kept:"):
                    r["dash"] += 1
            else:
                r["space"] += 1
            if not cand.startswith("<") and len(r["sample"]) < 4:
                r["sample"].append(cand)
        p.wait()
    return result


def covered(r: dict) -> bool:
    return r["space"] + r["dash"] > 0


def render(rows, usage, label, base=None) -> str:
    n = len(rows)
    fish_n = sum(r["fish_ok"] for r in rows)
    zsh_n = sum(r["zsh_ok"] for r in rows)
    both = sum(r["fish_ok"] and r["zsh_ok"] for r in rows)
    total_uses = sum(usage.values()) or 1
    fish_uses = sum(usage[r["cmd"]] for r in rows if r["fish_ok"])
    zsh_uses = sum(usage[r["cmd"]] for r in rows if r["zsh_ok"])
    used = [r for r in rows if usage[r["cmd"]]]

    def pct(a, b):
        return f"{100 * a / b:.0f}%" if b else "–"

    fish_only = sorted((r for r in rows if r["fish_ok"] and not r["zsh_ok"]),
                       key=lambda r: (-usage[r["cmd"]], r["cmd"]))
    zsh_only = sorted((r for r in rows if r["zsh_ok"] and not r["fish_ok"]),
                      key=lambda r: (-usage[r["cmd"]], r["cmd"]))

    def card(title, f, z, sub, before=None):
        was = f'<div class="row was"><span>Zsh before</span><b>{before}</b></div>' if before else ""
        return (f'<div class="card"><div class="t">{title}</div>'
                f'<div class="row"><span>Fish</span><b>{f}</b></div>{was}'
                f'<div class="row"><span>Zsh</span><b>{z}</b></div><div class="s">{sub}</div></div>')

    b = {}
    if base:
        brows = base["rows"]
        bused = [r for r in brows if usage[r["cmd"]]]
        bz = sum(r["zsh_ok"] for r in brows)
        b = {"path": f"{bz} ({pct(bz, len(brows))})",
             "used": f"{sum(r['zsh_ok'] for r in bused)} / {len(bused)}",
             "runs": pct(sum(usage[r['cmd']] for r in brows if r['zsh_ok']), total_uses),
             "fish_only": sum(r["fish_ok"] and not r["zsh_ok"] for r in brows)}

    def chips(items):
        if not items:
            return '<p class="muted">None.</p>'
        return '<div class="chips">' + "".join(
            f'<span class="chip">{html.escape(r["cmd"])}'
            + (f'<i>{usage[r["cmd"]]}×</i>' if usage[r["cmd"]] else "") + "</span>" for r in items) + "</div>"

    top = sorted(used, key=lambda r: -usage[r["cmd"]])[:40]
    top_rows = "".join(
        f'<tr><td>{html.escape(r["cmd"])}</td><td class="n">{usage[r["cmd"]]}</td>'
        f'<td class="n {"ok" if r["fish_ok"] else "no"}">{r["fish"]["space"]} / {r["fish"]["dash"]}</td>'
        f'<td class="n {"ok" if r["zsh_ok"] else "no"}">{r["zsh"]["space"]} / {r["zsh"]["dash"]}</td></tr>'
        for r in top)
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
body{{font:14px/1.45 -apple-system,system-ui,sans-serif;margin:20px;color:#1d2330}}
h1{{font-size:20px;margin:0 0 4px}} h2{{font-size:15px;margin:22px 0 8px}} .muted,.sub{{color:#5b6472}}
.cards{{display:flex;gap:12px;flex-wrap:wrap}} .card{{background:#f3f5f8;border-radius:10px;padding:12px 14px;min-width:200px;flex:1}}
.card .t{{font-weight:600;margin-bottom:6px}} .row{{display:flex;justify-content:space-between}} .row b{{font-size:18px}}
.s{{color:#5b6472;font-size:12px;margin-top:4px}} .was{{color:#8a919c}} .was b{{font-size:14px}}
.chips{{display:flex;flex-wrap:wrap;gap:5px}} .chip{{background:#f8e5e7;color:#7d2f37;border-radius:6px;padding:2px 7px;font:12px ui-monospace,Menlo,monospace}}
.chip i{{font-style:normal;color:#a3444e;margin-left:4px}} .z .chip{{background:#e2edf9;color:#1d4f8a}} .z .chip i{{color:#1d5fa8}}
table{{border-collapse:collapse;width:100%}} td,th{{padding:5px 8px;border-bottom:1px solid #e6e9ee;text-align:left}}
th{{font-size:12px;color:#5b6472}} .n{{font-family:ui-monospace,Menlo,monospace;font-size:12.5px}} .ok{{color:#1f7a4d}} .no{{color:#a3444e}}
</style></head><body>
<h1>Command completion coverage: Fish vs Zsh{f" ({html.escape(label)})" if label else ""}</h1>
<div class="sub">A program counts as completed when Tab after <code>cmd␠</code> or <code>cmd -</code> offers anything,
probed in an empty directory so file completion doesn't count.</div>
<div class="cards" style="margin-top:14px">
{card("Programs on PATH", f"{fish_n} ({pct(fish_n, n)})", f"{zsh_n} ({pct(zsh_n, n)})", f"of {n}; both: {both}", b.get("path"))}
{card("Programs you use", f"{sum(r['fish_ok'] for r in used)} / {len(used)}", f"{sum(r['zsh_ok'] for r in used)} / {len(used)}", "commands that appear in your Atuin history", b.get("used"))}
{card("Your command runs", pct(fish_uses, total_uses), pct(zsh_uses, total_uses), f"share of {total_uses} history entries whose program completes", b.get("runs"))}
</div>
<h2>Fish completes, Zsh doesn't ({len(fish_only)}{f", was {b['fish_only']}" if b else ""})</h2>{chips(fish_only)}
<h2>Zsh completes, Fish doesn't ({len(zsh_only)})</h2><div class="z">{chips(zsh_only)}</div>
<h2>Your 40 most-used programs</h2>
<table><tr><th>Program</th><th>Runs</th><th>Fish candidates (cmd␠ / cmd -)</th><th>Zsh candidates (cmd␠ / cmd -)</th></tr>{top_rows}</table>
</body></html>"""


def main():
    label = sys.argv[sys.argv.index("--label") + 1] if "--label" in sys.argv else ""
    if "--no-fish-bridge" in sys.argv:
        ZSH_ENV["ZSH_FISH_FEEL_NO_FISH_BRIDGE"] = "1"
    commands = path_commands()
    usage = usage_counts(set(commands))
    paths = fish_complete_path()
    print(f"{len(commands)} programs on PATH, {len(usage)} used; probing…", flush=True)
    with cf.ThreadPoolExecutor(16) as pool:
        fish = dict(zip(commands, pool.map(lambda c: fish_probe(c, paths), commands)))
    zsh = zsh_probe_all(commands)
    rows = [{"cmd": c, "fish": fish[c], "zsh": zsh[c], "fish_ok": covered(fish[c]), "zsh_ok": covered(zsh[c])}
            for c in commands]
    suffix = f"-{label}" if label else ""
    ARTIFACTS.mkdir(exist_ok=True)
    (ARTIFACTS / f"completion-coverage{suffix}.json").write_text(
        json.dumps({"rows": rows, "usage": usage}, indent=1))
    base_file = ARTIFACTS / "completion-coverage-baseline.json"
    base = json.loads(base_file.read_text()) if label != "baseline" and base_file.exists() else None
    (ARTIFACTS / f"completion-coverage{suffix}.html").write_text(render(rows, usage, label, base))
    f = sum(r["fish_ok"] for r in rows)
    z = sum(r["zsh_ok"] for r in rows)
    fo = [r["cmd"] for r in rows if r["fish_ok"] and not r["zsh_ok"]]
    print(f"fish {f}/{len(rows)}  zsh {z}/{len(rows)}  fish-only {len(fo)}  "
          f"timeouts fish={sum('timeout' in r['fish'] for r in rows)} zsh={sum('timeout' in r['zsh'] for r in rows)}")
    print("fish-only by usage:", sorted(fo, key=lambda c: -usage[c])[:30])


if __name__ == "__main__":
    main()
