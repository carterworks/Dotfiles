#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { styleText } from "node:util";

const defaultConfig = {
  widgets: ["context", "model", "version", "cost", "clock"],
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

function formatTokens(value) {
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}m`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(1)}k`;
  return String(value);
}

function context(data) {
  const window = data.context_window ?? {};
  const size = window.context_window_size ?? 0;
  let count = (window.total_input_tokens ?? 0) + (window.total_output_tokens ?? 0);
  if (count === 0 && window.used_percentage != null && size) {
    count = Math.round((window.used_percentage / 100) * size);
  }
  const percentage = window.used_percentage ?? (size ? (count / size) * 100 : 0);
  const color = percentage < 50 ? "green" : percentage < 75 ? "yellow" : "red";
  return styleText(["bold", color], `${formatTokens(count)} (${percentage.toFixed(1)}%)`);
}

function model(data) {
  const value = data.model;
  if (!value) return null;
  const name = typeof value === "object" ? (value.display_name ?? value.id ?? "") : String(value);
  const trimmed = name.trim().replace(/^claude-/, "");
  return trimmed ? styleText(["bold", "magenta"], trimmed) : null;
}

function version(data) {
  return data.version
    ? styleText(["dim", "blue"], `v${data.version.replace(/^v/, "")}`)
    : null;
}

function cost(data) {
  const value = data.cost?.total_cost_usd;
  return value == null ? null : styleText(["bold", "green"], `$${value.toFixed(4)}`);
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

const widgets = { context, model, version, cost, clock, effort };

function starship(cwd) {
  if (!cwd) return null;
  try {
    return execFileSync(
      "starship",
      ["prompt", "--path", cwd, "--terminal-width", "120"],
      {
        cwd,
        stdio: ["pipe", "pipe", "pipe"],
        timeout: 3000,
        env: { ...process.env, TERM: "xterm-256color", FORCE_COLOR: "1" },
      },
    )
      .toString()
      .replace(/\x1b\[J/g, "")
      .split(/\r?\n/)
      .filter((line) => {
        const text = line.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").trim();
        return text !== "" && !/^[>$%#\s]+$/.test(text);
      })
      .join("  ") || null;
  } catch {
    return null;
  }
}

const chunks = [];
for await (const chunk of process.stdin) chunks.push(chunk);

let data;
try {
  data = JSON.parse(Buffer.concat(chunks).toString().trim() || "{}");
} catch {
  process.exit(0);
}

const cwd = data.workspace?.current_dir ?? data.cwd ?? "";
const parts = [];
const prompt = starship(cwd);
if (prompt) parts.push(prompt);
else if (cwd) parts.push(styleText("cyan", cwd.split("/").filter(Boolean).at(-1)));

const config = loadConfig();
for (const name of config.widgets ?? defaultConfig.widgets) {
  const value = widgets[name]?.(data);
  if (value) parts.push(value);
}

process.stdout.write(parts.join(config.separator ?? defaultConfig.separator));
