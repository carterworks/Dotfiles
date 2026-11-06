import fs from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export function createLogger(
  options = {},
  directory = join(
    process.env.XDG_DATA_HOME ?? join(homedir(), ".local", "share"),
    "opencode",
    "log",
  ),
) {
  const level = ["error", "info", "debug"].includes(options.logLevel)
    ? options.logLevel
    : "info";
  let fileReady = false;
  let fileFailed = false;

  function write(event, details) {
    const line = JSON.stringify({
      time: new Date().toISOString(),
      event,
      ...details,
    });
    if (event === "error") console.warn("[idle-compaction]", line);
    else console.info("[idle-compaction]", line);
    if (fileFailed) return;
    try {
      if (!fileReady) {
        fs.mkdirSync(directory, { recursive: true });
        fileReady = true;
      }
      fs.appendFileSync(
        join(directory, "idle-compaction.log"),
        `[idle-compaction] ${line}\n`,
        { mode: 0o600 },
      );
    } catch (error) {
      fileFailed = true;
      console.warn(
        "[idle-compaction] Log file unavailable:",
        error?.name ?? "Error",
      );
    }
  }

  return {
    level,
    log(event, details = {}) {
      if (level === "error" || (event !== "admitted" && level !== "debug"))
        return;
      write(event, details);
    },
    warn(error, details = {}) {
      write("error", { error: error?.name ?? "Error", ...details });
    },
  };
}
