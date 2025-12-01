/**
 * osgrep OpenCode Plugin
 *
 * Integrates osgrep semantic code search with OpenCode.
 * - Auto-starts osgrep serve on session creation
 * - Auto-stops osgrep serve on session end
 * - Provides osgrep search as a custom tool
 */

import { tool } from "@opencode-ai/plugin";
import { spawn } from "node:child_process";
import { readFileSync, existsSync, unlinkSync } from "node:fs";
import { join } from "node:path";

export const OsgrepPlugin = async ({
  project,
  client,
  $,
  directory,
  worktree,
}) => {
  let serverStarted = false;

  /**
   * Start osgrep serve in background
   */
  const startServer = async () => {
    if (serverStarted) return;

    try {
      // Start osgrep serve as detached background process
      const child = spawn("osgrep", ["serve"], {
        cwd: directory,
        detached: true,
        stdio: "ignore",
      });

      child.unref();
      serverStarted = true;
    } catch (error) {
      console.error("[OsgrepPlugin] Failed to start osgrep serve:", error);
    }
  };

  /**
   * Stop osgrep serve
   */
  const stopServer = async () => {
    if (!serverStarted) return;

    try {
      const lockPath = join(directory, ".osgrep", "server.json");

      // Try to read PID from lock file and kill it
      if (existsSync(lockPath)) {
        const data = JSON.parse(readFileSync(lockPath, "utf-8"));
        const pid = data?.pid;

        if (typeof pid === "number") {
          try {
            process.kill(pid, "SIGTERM");
          } catch (err) {
            // Process may already be dead
          }
        }

        // Clean up lock file
        try {
          unlinkSync(lockPath);
        } catch (err) {
          // Ignore if already deleted
        }
      }

      // Fallback: pkill
      await $`pkill -f "osgrep serve" || true`;

      serverStarted = false;
    } catch (error) {
      console.error("[OsgrepPlugin] Error stopping osgrep serve:", error);
    }
  };

  return {
    // Start server when session is created
    "session.created": async ({ event }) => {
      await startServer();
    },

    // Stop server when OpenCode exits
    "session.deleted": async ({ event }) => {
      await stopServer();
    },

    // Provide osgrep as a custom tool
    tool: {
      osgrep: tool({
        description:
          "Semantic code search using osgrep. Searches codebase using natural language queries to find relevant code sections. Prefer this over grep for concept-based searches.",
        args: {
          query: tool.schema
            .string()
            .describe(
              "Natural language query describing what to search for (e.g., 'authentication logic', 'error handling')",
            ),
          maxResults: tool.schema
            .number()
            .optional()
            .describe("Maximum number of results to return (default: 25)"),
          perFile: tool.schema
            .number()
            .optional()
            .describe("Maximum matches per file (default: 1)"),
          showScores: tool.schema
            .boolean()
            .optional()
            .describe("Show relevance scores (default: false)"),
          compact: tool.schema
            .boolean()
            .optional()
            .describe("Show file paths only (default: false)"),
        },
        async execute(args, ctx) {
          try {
            // Build command
            const cmdArgs = ["--json", args.query];

            if (args.maxResults) {
              cmdArgs.push("-m", String(args.maxResults));
            }

            if (args.perFile) {
              cmdArgs.push("--per-file", String(args.perFile));
            }

            if (args.showScores) {
              cmdArgs.push("--scores");
            }

            if (args.compact) {
              cmdArgs.push("--compact");
            }

            // Execute osgrep search
            const result = await $`osgrep ${cmdArgs}`.cwd(directory).text();

            if (!result || result.trim() === "") {
              return "No results found for query: " + args.query;
            }

            // Parse JSON response
            try {
              const data = JSON.parse(result);
              return JSON.stringify(data, null, 2);
            } catch (parseErr) {
              // If JSON parsing fails, return raw output
              return result;
            }
          } catch (error) {
            return `Error executing osgrep: ${error.message}`;
          }
        },
      }),
    },
  };
};
