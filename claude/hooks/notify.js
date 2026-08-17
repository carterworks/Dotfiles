#!/usr/bin/env node
import { execFile } from "node:child_process";
import { promisify, parseArgs } from "node:util";

const execFileAsync = promisify(execFile);
const { values, positionals } = parseArgs({
  options: {
    title: { type: "string", short: "t" },
    emoji: { type: "string", short: "e" },
  },
  allowPositionals: true,
});

if (!positionals[0]) throw new Error("message is required");

const body = values.emoji
  ? `${values.emoji} ${positionals[0]}`
  : positionals[0];
const script = values.title
  ? `display notification ${JSON.stringify(body)} with title ${JSON.stringify(values.title)}`
  : `display notification ${JSON.stringify(body)}`;

await execFileAsync("osascript", ["-e", script]);
