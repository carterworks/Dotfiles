import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { createFindTool, createGrepTool } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { resolve as resolvePath } from "node:path";
import {
  DEFAULT_LIMIT,
  appendUniqueTrimmedLines,
  buildBuiltinFallbackGrepInput,
  buildFindFilesQuery,
  buildGrepQuery,
  buildMultiGrepConstraints,
  normalizeLimit,
  normalizePatterns,
} from "./search-helpers";

const FFF_COMMAND =
  process.env.FFF_MCP_COMMAND || resolvePath(homedir(), ".local/bin/fff-mcp");
const FFF_PROTOCOL_VERSION = "2025-03-26";
const FFF_CLIENT_INFO = { name: "pi-fff-tools", version: "0.1.0" };

const MULTI_GREP_PARAMETERS = Type.Object({
  patterns: Type.Array(
    Type.String({
      description:
        "Literal patterns to search for. Use identifiers and simple text, not regex alternation.",
    }),
    {
      description: "Patterns to search for with OR semantics.",
      minItems: 1,
    },
  ),
  path: Type.Optional(
    Type.String({
      description:
        "Directory to search from. Defaults to the current working directory.",
    }),
  ),
  glob: Type.Optional(
    Type.String({
      description: "Optional glob constraint, e.g. **/*.{ts,tsx}.",
    }),
  ),
  limit: Type.Optional(
    Type.Number({ description: "Maximum number of matching lines to return." }),
  ),
});

/**
 * @typedef {{
 *   resolve: (value: any) => void,
 *   reject: (error: Error) => void,
 *   abortListener?: () => void,
 *   signal?: AbortSignal,
 * }} PendingRequest
 */

class FffMcpClient {
  /** @param {string} basePath */
  constructor(basePath) {
    this.basePath = basePath;
    this.command = FFF_COMMAND;
    this.child = spawn(this.command, [basePath], {
      stdio: ["pipe", "pipe", "pipe"],
    });
    this.nextId = 1;
    /** @type {Map<number, PendingRequest>} */
    this.pendingRequests = new Map();
    this.stdoutBuffer = Buffer.alloc(0);
    this.stderrChunks = [];
    this.toolNames = new Set();
    this.closed = false;

    this.child.stdout.on("data", (chunk) => {
      this.handleStdoutChunk(chunk);
    });

    this.child.stderr.on("data", (chunk) => {
      this.stderrChunks.push(String(chunk));
      if (this.stderrChunks.length > 50) this.stderrChunks.shift();
    });

    this.child.once("error", (error) => {
      this.rejectAllPending(
        error instanceof Error ? error : new Error(String(error)),
      );
    });

    this.child.once("exit", (code, signal) => {
      this.closed = true;
      const reason = this.buildExitReason(code, signal);
      this.rejectAllPending(new Error(reason));
    });
  }

  async initialize() {
    await this.sendRequest("initialize", {
      protocolVersion: FFF_PROTOCOL_VERSION,
      capabilities: {},
      clientInfo: FFF_CLIENT_INFO,
    });

    this.sendNotification("notifications/initialized", {});
    const toolsResult = await this.sendRequest("tools/list", {});
    const tools = Array.isArray(toolsResult?.tools) ? toolsResult.tools : [];
    this.toolNames = new Set(tools.map((tool) => tool?.name).filter(Boolean));
  }

  /** @param {string} toolName */
  hasTool(toolName) {
    return this.toolNames.has(toolName);
  }

  async close(reason = "closed by pi extension") {
    if (this.closed) return;
    this.closed = true;
    this.rejectAllPending(new Error(reason));
    this.child.kill("SIGTERM");
  }

  async callTool(toolName, args, signal) {
    const result = await this.sendRequest(
      "tools/call",
      {
        name: toolName,
        arguments: args,
      },
      signal,
    );

    if (result?.isError) {
      const message =
        renderMcpResultText(result) ||
        `fff-mcp reported an error for ${toolName}`;
      throw new Error(message);
    }

    return result;
  }

  handleStdoutChunk(chunk) {
    this.stdoutBuffer = Buffer.concat([this.stdoutBuffer, chunk]);

    for (;;) {
      const headerEnd = findHeaderEnd(this.stdoutBuffer);
      if (headerEnd === -1) return;

      const headerText = this.stdoutBuffer
        .subarray(0, headerEnd)
        .toString("utf8");
      const contentLength = parseContentLength(headerText);
      if (contentLength === undefined) {
        this.rejectAllPending(
          new Error(
            `fff-mcp sent a frame without Content-Length.\n${headerText}`,
          ),
        );
        return;
      }

      const separatorLength = getSeparatorLength(this.stdoutBuffer, headerEnd);
      const bodyStart = headerEnd + separatorLength;
      const bodyEnd = bodyStart + contentLength;
      if (this.stdoutBuffer.length < bodyEnd) return;

      const body = this.stdoutBuffer
        .subarray(bodyStart, bodyEnd)
        .toString("utf8");
      this.stdoutBuffer = this.stdoutBuffer.subarray(bodyEnd);

      let message;
      try {
        message = JSON.parse(body);
      } catch (error) {
        this.rejectAllPending(
          new Error(`fff-mcp returned invalid JSON: ${String(error)}\n${body}`),
        );
        return;
      }

      this.handleMessage(message);
    }
  }

  handleMessage(message) {
    if (!message || typeof message !== "object") return;
    if (Object.prototype.hasOwnProperty.call(message, "id")) {
      const entry = this.pendingRequests.get(Number(message.id));
      if (!entry) return;

      this.pendingRequests.delete(Number(message.id));
      if (entry.abortListener && entry.signal) {
        entry.signal.removeEventListener("abort", entry.abortListener);
      }

      if (message.error) {
        entry.reject(new Error(this.formatJsonRpcError(message.error)));
        return;
      }

      entry.resolve(message.result);
    }
  }

  formatJsonRpcError(error) {
    if (!error || typeof error !== "object") {
      return `fff-mcp returned an unknown JSON-RPC error.\n${this.getStderrTail()}`;
    }

    const code = Object.prototype.hasOwnProperty.call(error, "code")
      ? ` (${error.code})`
      : "";
    const message =
      typeof error.message === "string"
        ? error.message
        : "Unknown JSON-RPC error";
    const data = Object.prototype.hasOwnProperty.call(error, "data")
      ? `\n${safeJson(error.data)}`
      : "";
    return `${message}${code}${data}\n${this.getStderrTail()}`.trim();
  }

  getStderrTail() {
    const stderr = this.stderrChunks.join("").trim();
    return stderr ? `fff-mcp stderr:\n${stderr}` : "";
  }

  buildExitReason(code, signal) {
    const exitText = `fff-mcp exited${code !== null ? ` with code ${code}` : ""}${signal ? ` (signal ${signal})` : ""}`;
    const stderr = this.getStderrTail();
    return stderr ? `${exitText}\n${stderr}` : exitText;
  }

  rejectAllPending(error) {
    for (const entry of this.pendingRequests.values()) {
      if (entry.abortListener && entry.signal) {
        entry.signal.removeEventListener("abort", entry.abortListener);
      }
      entry.reject(error);
    }
    this.pendingRequests.clear();
  }

  sendNotification(method, params) {
    this.writeMessage({ jsonrpc: "2.0", method, params });
  }

  sendRequest(method, params, signal) {
    if (this.closed) {
      throw new Error(`Cannot call ${method}; fff-mcp is closed.`);
    }

    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      if (signal?.aborted) {
        reject(new Error(`${method} was aborted.`));
        return;
      }

      const entry = { resolve, reject };
      this.pendingRequests.set(id, entry);

      if (signal) {
        const abortListener = () => {
          this.pendingRequests.delete(id);
          reject(new Error(`${method} was aborted.`));
          try {
            this.sendNotification("notifications/cancelled", {
              requestId: id,
              reason: "aborted",
            });
          } catch {
            // Best-effort only.
          }
        };

        entry.abortListener = abortListener;
        entry.signal = signal;
        signal.addEventListener("abort", abortListener, { once: true });
      }

      try {
        this.writeMessage({ jsonrpc: "2.0", id, method, params });
      } catch (error) {
        this.pendingRequests.delete(id);
        if (entry.abortListener && entry.signal) {
          entry.signal.removeEventListener("abort", entry.abortListener);
        }
        reject(error instanceof Error ? error : new Error(String(error)));
      }
    });
  }

  writeMessage(message) {
    if (!this.child.stdin.writable) {
      throw new Error(
        `fff-mcp stdin is not writable.\n${this.getStderrTail()}`.trim(),
      );
    }

    const body = Buffer.from(JSON.stringify(message), "utf8");
    const header = Buffer.from(
      `Content-Length: ${body.length}\r\n\r\n`,
      "utf8",
    );
    this.child.stdin.write(Buffer.concat([header, body]));
  }
}

export default function fffToolsExtension(pi: ExtensionAPI) {
  let client = undefined;
  let fallbackWarningShown = false;

  async function closeClient(reason) {
    if (!client) return;
    const currentClient = client;
    client = undefined;
    await currentClient.close(reason);
  }

  async function ensureClient(cwd) {
    if (client && client.basePath === cwd) return client;
    if (client && client.basePath !== cwd) {
      await closeClient(`cwd changed from ${client.basePath} to ${cwd}`);
    }

    const nextClient = new FffMcpClient(cwd);
    try {
      await nextClient.initialize();
    } catch (error) {
      await nextClient.close("initialize failed");
      throw error;
    }

    client = nextClient;
    return nextClient;
  }

  async function callFffTool(toolName, args, ctx, signal) {
    const readyClient = await ensureClient(ctx.cwd);
    if (!readyClient.hasTool(toolName)) {
      throw new Error(`fff-mcp does not expose the ${toolName} tool.`);
    }
    return readyClient.callTool(toolName, args, signal);
  }

  async function runFindWithFallback(
    toolCallId,
    params,
    signal,
    onUpdate,
    ctx,
  ) {
    try {
      const result = await callFffTool(
        "find_files",
        {
          query: buildFindFilesQuery(params),
          maxResults: normalizeLimit(params.limit),
        },
        ctx,
        signal,
      );

      return convertMcpResult(result, "find_files", params);
    } catch (error) {
      await handleFallback("find", error, ctx);
      // return fallbackTool.execute(toolCallId, params, signal, onUpdate);
      throw error;
    }
  }

  async function runGrepWithFallback(
    toolCallId,
    params,
    signal,
    onUpdate,
    ctx,
  ) {
    try {
      const result = await callFffTool(
        "grep",
        {
          query: buildGrepQuery(params),
          maxResults: normalizeLimit(params.limit),
        },
        ctx,
        signal,
      );

      return convertMcpResult(result, "grep", params);
    } catch (error) {
      await handleFallback("grep", error, ctx);
      // return fallbackTool.execute(toolCallId, params, signal, onUpdate);
      throw error;
    }
  }

  async function runMultiGrepWithFallback(params, signal, ctx) {
    try {
      const patterns = normalizePatterns(params.patterns);
      const result = await callFffTool(
        "multi_grep",
        {
          patterns,
          constraints: buildMultiGrepConstraints(params),
          maxResults: normalizeLimit(params.limit),
        },
        ctx,
        signal,
      );

      return convertMcpResult(result, "multi_grep", params);
    } catch (error) {
      await handleFallback("multi_grep", error, ctx);
      // return runMultiGrepBuiltInFallback(params, signal, ctx);
      throw error;
    }
  }

  async function handleFallback(toolName, error, ctx) {
    await closeClient(`${toolName} failed`);
    if (fallbackWarningShown || !ctx.hasUI) return;
    fallbackWarningShown = true;
    ctx.ui.notify(
      `fff-mcp failed for ${toolName}; built-in fallback is currently disabled.`,
      "warning",
    );
  }

  pi.on("session_shutdown", async () => {
    await closeClient("session shutdown");
  });

  pi.registerCommand("fff-restart", {
    description:
      "Restart the fff-mcp subprocess used by overridden search tools.",
    handler: async (_args, ctx) => {
      fallbackWarningShown = false;
      await closeClient("manual restart");
      ctx.ui.notify(
        "Closed fff-mcp. It will restart on the next find/grep call.",
        "info",
      );
    },
  });

  pi.registerTool({
    name: "find",
    label: "find",
    description:
      "Find files by name or path. Searches recursively from the specified path and returns matching file paths.",
    parameters: createFindTool(process.cwd()).parameters,
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      return runFindWithFallback(toolCallId, params, signal, onUpdate, ctx);
    },
  });

  pi.registerTool({
    name: "grep",
    label: "grep",
    description:
      "Search file contents for a pattern. Prefer bare identifiers or short literals over complex regex when possible.",
    parameters: createGrepTool(process.cwd()).parameters,
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      return runGrepWithFallback(toolCallId, params, signal, onUpdate, ctx);
    },
  });

  pi.registerTool({
    name: "multi_grep",
    label: "multi_grep",
    description:
      "Search file contents for any of several literal patterns in a single call.",
    promptSnippet:
      "Search file contents for any of several literal patterns in one call.",
    promptGuidelines: [
      "Use multi_grep instead of repeated grep calls when you have multiple identifier variants to search for.",
    ],
    parameters: MULTI_GREP_PARAMETERS,
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      return runMultiGrepWithFallback(params, signal, ctx);
    },
  });
}

function findHeaderEnd(buffer) {
  const crlf = buffer.indexOf("\r\n\r\n");
  if (crlf !== -1) return crlf;
  return buffer.indexOf("\n\n");
}

function getSeparatorLength(buffer, headerEnd) {
  const separator = buffer.subarray(headerEnd, headerEnd + 4).toString("utf8");
  return separator === "\r\n\r\n" ? 4 : 2;
}

function parseContentLength(headerText) {
  const lines = headerText.split(/\r?\n/).filter(Boolean);
  for (const line of lines) {
    const match = /^content-length\s*:\s*(\d+)$/i.exec(line.trim());
    if (match) return Number(match[1]);
  }
  return undefined;
}

function convertMcpResult(result, toolName, input) {
  const text = renderMcpResultText(result);
  return {
    content: [{ type: "text", text }],
    details: {
      backend: "fff-mcp",
      toolName,
      input,
      raw: result,
    },
  };
}

function renderMcpResultText(result) {
  const textParts = [];
  for (const item of Array.isArray(result?.content) ? result.content : []) {
    if (item?.type === "text" && typeof item.text === "string") {
      textParts.push(item.text.trimEnd());
      continue;
    }
    if (
      item?.type === "resource" ||
      item?.type === "image" ||
      item?.type === "audio"
    ) {
      textParts.push(safeJson(item));
    }
  }

  if (textParts.length > 0) return textParts.join("\n\n").trim();
  if (result?.structuredContent !== undefined)
    return safeJson(result.structuredContent);
  return safeJson(result);
}

async function runMultiGrepBuiltInFallback(params, signal, ctx) {
  const grepTool = createGrepTool(ctx.cwd);
  const lines = [];
  const seen = new Set();
  const patterns = normalizePatterns(params.patterns);
  const maxResults = normalizeLimit(params.limit);

  for (const pattern of patterns) {
    if (lines.length >= maxResults) break;

    const result = await grepTool.execute(
      `multi_grep:${pattern}`,
      buildBuiltinFallbackGrepInput(params, pattern, maxResults - lines.length),
      signal,
    );

    appendUniqueTrimmedLines(lines, seen, extractPiText(result), maxResults);
  }

  return {
    content: [{ type: "text", text: lines.join("\n") || "No matches found." }],
    details: {
      backend: "builtin-fallback",
      patterns,
      maxResults,
    },
  };
}

function extractPiText(result) {
  if (!result || !Array.isArray(result.content)) return "";
  return result.content
    .filter((item) => item?.type === "text" && typeof item.text === "string")
    .map((item) => item.text)
    .join("\n");
}

function safeJson(value) {
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return String(value);
  }
}
