import assert from "node:assert/strict";
import fs from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { createLogger } from "./logger.js";

test("filtered logs are persisted without retaining error messages or stacks", (t) => {
  const directory = fs.mkdtempSync(join(tmpdir(), "idle-compaction-"));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  t.mock.method(console, "info", () => {});
  t.mock.method(console, "warn", () => {});
  const logger = createLogger({}, directory);
  logger.log("skipped", { sessionID: "one", reason: "below-token-threshold" });
  logger.log("admitted", { sessionID: "one" });
  logger.warn(new Error("secret response body"), { sessionID: "one" });
  const path = join(directory, "idle-compaction.log");
  const lines = fs.readFileSync(path, "utf8").trim().split("\n");
  const logs = lines.map((line) =>
    JSON.parse(line.slice("[idle-compaction] ".length)),
  );
  assert.deepEqual(
    logs.map((log) => log.event),
    ["admitted", "error"],
  );
  assert.equal(logs[1].error, "Error");
  assert.ok(logs.every((log) => !Number.isNaN(Date.parse(log.time))));
  assert.ok(!lines.join("\n").includes("secret response body"));
  assert.equal(fs.statSync(path).mode & 0o777, 0o600);
});

test("debug diagnostics are persisted and error-only logging filters admissions", (t) => {
  const directory = fs.mkdtempSync(join(tmpdir(), "idle-compaction-"));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  t.mock.method(console, "info", () => {});
  t.mock.method(console, "warn", () => {});
  createLogger({ logLevel: "debug" }, directory).log("skipped", {
    reason: "no-cache-evidence",
  });
  const logger = createLogger({ logLevel: "error" }, directory);
  logger.log("admitted");
  logger.warn(new Error("private"));
  const lines = fs
    .readFileSync(join(directory, "idle-compaction.log"), "utf8")
    .trim()
    .split("\n");
  assert.equal(lines.length, 2);
  assert.ok(lines[0].includes("no-cache-evidence"));
  assert.ok(lines[1].includes('"event":"error"'));
});

test("file failures do not disrupt scheduling or repeatedly retry writes", (t) => {
  const info = t.mock.method(console, "info", () => {});
  const warn = t.mock.method(console, "warn", () => {});
  const mkdir = t.mock.method(fs, "mkdirSync", () => {
    throw new Error("private path");
  });
  const logger = createLogger({ logLevel: "debug" }, "/unavailable");
  assert.doesNotThrow(() => logger.log("ready"));
  assert.doesNotThrow(() => logger.log("scheduled", { sessionID: "one" }));
  assert.equal(mkdir.mock.calls.length, 1);
  assert.equal(info.mock.calls.length, 2);
  assert.equal(warn.mock.calls.length, 1);
  assert.ok(!JSON.stringify(warn.mock.calls[0].arguments).includes("private path"));
});
