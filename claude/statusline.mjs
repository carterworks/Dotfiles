#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { styleText } from "node:util";

const defaultConfig = {
  widgets: ["version", "clock"],
  separator: "  ",
};

function loadConfig() {
  try {
    return {
      ...defaultConfig,
      ...JSON.parse(readFileSync(join(homedir(), ".claude", "statusline.json"), "utf8")),
    };
  } catch {
    return defaultConfig;
  }
}

function version(data) {
  return data.version
    ? styleText(["dim", "blue"], `v${data.version.replace(/^v/, "")}`)
    : null;
}

function clock(data) {
  const milliseconds = data.cost?.total_duration_ms;
  if (milliseconds == null) return null;
  const totalMinutes = Math.floor(milliseconds / 60_000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  const label = totalMinutes < 1
    ? "<1m"
    : hours > 0
      ? minutes ? `${hours}hr ${minutes}m` : `${hours}hr`
      : `${totalMinutes}m`;
  return styleText("cyan", label);
}

function effort(data) {
  const tokens = data.thinking?.budget_tokens ?? data.effort?.budget_tokens;
  if (tokens == null) return null;
  const label = tokens >= 1000 ? `${Math.round(tokens / 1000)}k` : String(tokens);
  return styleText(["bold", "yellow"], `effort ${label}`);
}

const widgets = { version, clock, effort };

// Directory, git, model, context, and cost are rendered natively by starship's
// `claude-code` profile (see ~/.config/starship.toml), fed the raw session JSON.
function starship(cwd, input) {
  if (!cwd) return null;
  try {
    return execFileSync(
      "starship",
      ["statusline", "claude-code", "--path", cwd, "--logical-path", cwd, "--terminal-width", "120"],
      {
        cwd,
        input,
        stdio: ["pipe", "pipe", "pipe"],
        timeout: 3000,
        env: { ...process.env, TERM: "xterm-256color", FORCE_COLOR: "1" },
      },
    )
      .toString()
      .replace(/\x1b\[J/g, "")
      .split(/\r?\n/)
      .map((line) => line.trimEnd())
      .filter((line) => line.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").trim() !== "")
      .join("  ") || null;
  } catch {
    return null;
  }
}

const chunks = [];
for await (const chunk of process.stdin) chunks.push(chunk);
const raw = Buffer.concat(chunks).toString().trim() || "{}";

let data;
try {
  data = JSON.parse(raw);
} catch {
  process.exit(0);
}

const cwd = data.workspace?.current_dir ?? data.cwd ?? "";
const parts = [];
const prompt = starship(cwd, raw);
if (prompt) parts.push(prompt);
else if (cwd) parts.push(styleText("cyan", cwd.split("/").filter(Boolean).at(-1)));

const config = loadConfig();
for (const name of config.widgets ?? defaultConfig.widgets) {
  const value = widgets[name]?.(data);
  if (value) parts.push(value);
}

process.stdout.write(parts.join(config.separator ?? defaultConfig.separator));
