import crypto from "node:crypto";
import os from "node:os";
import {
  RECENCY_REMINDER,
  SYSTEM_PROMPT,
  TOOL_DESCRIPTION,
  buildTriagePrompt,
} from "./prompts.js";
import {
  appendEntry,
  defaultHarnessPath,
  findGitRoot,
  resolveBoxPath,
} from "./store.js";

const CATEGORIES = [
  "tool",
  "mcp",
  "skill",
  "instructions",
  "environment",
  "permissions",
  "codebase",
  "infra",
  "other",
];

function formatModel(model) {
  if (!model) return undefined;
  if (typeof model === "string") return model;
  if (!model.providerID || !model.id) return undefined;
  const base = `${model.providerID}/${model.id}`;
  return model.variant ? `${base}#${model.variant}` : base;
}

function countUserMessages(messages) {
  if (!Array.isArray(messages)) return 0;
  let count = 0;
  for (const msg of messages) {
    if (msg?.role === "user") count += 1;
  }
  return count;
}

export default {
  id: "dotfiles.complaints-box",
  async setup(ctx) {
    const options = ctx.options ?? {};
    const harnessPath = options.harnessPath || defaultHarnessPath();
    const projectDir =
      ctx.location?.project?.canonical ||
      (ctx.location?.directory ? findGitRoot(ctx.location.directory) : process.cwd());

    const lastModelBySession = new Map();
    const userTurnBySession = new Map();
    const loggedTurnBySession = new Map();

    async function resolveModel(sessionID) {
      if (sessionID && lastModelBySession.has(sessionID)) {
        return lastModelBySession.get(sessionID);
      }
      if (!sessionID || !ctx.session?.get) return "unknown";
      try {
        const session = await ctx.session.get({ sessionID });
        const formatted = formatModel(session?.model ?? session?.data?.model);
        if (formatted) {
          lastModelBySession.set(sessionID, formatted);
          return formatted;
        }
      } catch {
        // Fall through to "unknown" so signing never fails the tool call.
      }
      return "unknown";
    }

    const registrations = [];

    registrations.push(
      await ctx.tool.transform((editor) => {
        editor.add({
          name: "complaints_box",
          description: TOOL_DESCRIPTION,
          input: {
            type: "object",
            properties: {
              scope: {
                type: "string",
                enum: ["harness", "codebase"],
                description:
                  "'harness' for OpenCode/OS/shell/MCP/skills/global setup; 'codebase' for this repository's code, tests, scripts, docs, or infra",
              },
              summary: {
                type: "string",
                description: "Short one-line title of the issue or suggestion",
              },
              details: {
                type: "string",
                description: "What happened or what you noticed",
              },
              category: {
                type: "string",
                enum: CATEGORIES,
                description: "Optional category (defaults to 'other')",
              },
              workaround: {
                type: "string",
                description: "How you worked around it, if applicable",
              },
              suggestion: {
                type: "string",
                description: "Concrete improvement idea, if obvious",
              },
              severity: {
                type: "string",
                enum: ["minor", "annoying", "blocking"],
                description: "Optional severity",
              },
            },
            required: ["scope", "summary", "details"],
            additionalProperties: false,
          },
          options: { codemode: false },
          execute: async (input, context) => {
            const sessionID = context?.sessionID;
            if (sessionID) {
              loggedTurnBySession.set(
                sessionID,
                userTurnBySession.get(sessionID) ?? 0,
              );
            }
            const model = await resolveModel(sessionID);
            const scope = input.scope === "codebase" ? "codebase" : "harness";
            const filePath = resolveBoxPath({ scope, projectDir, harnessPath });
            const entry = {
              id: crypto.randomUUID(),
              timestamp: new Date().toISOString(),
              scope,
              category: CATEGORIES.includes(input.category) ? input.category : "other",
              summary: input.summary,
              details: input.details,
              ...(input.workaround ? { workaround: input.workaround } : {}),
              ...(input.suggestion ? { suggestion: input.suggestion } : {}),
              ...(input.severity ? { severity: input.severity } : {}),
              model,
              agent: context?.agent ?? "unknown",
              sessionID: sessionID ?? null,
              cwd: ctx.location?.directory ?? null,
              project: projectDir,
              hostname: os.hostname(),
              opencodeVersion: ctx.app?.version ?? null,
            };

            const result = appendEntry(filePath, entry);
            if (!result.ok) {
              return {
                content: `Could not write to complaints box (${result.error}); continuing.`,
              };
            }
            return {
              content: `Dropped in the ${scope} complaints box (signed by ${model}).`,
            };
          },
        });
      }),
    );

    registrations.push(
      await ctx.session.hook("context", (event) => {
        if (event.sessionID && event.model) {
          const formatted = formatModel(event.model);
          if (formatted) lastModelBySession.set(event.sessionID, formatted);
        }

        event.system.push({ type: "text", text: SYSTEM_PROMPT });

        const messages = event.messages;
        if (!Array.isArray(messages) || messages.length < 2) return;

        const userTurn = countUserMessages(messages);
        if (event.sessionID) {
          userTurnBySession.set(event.sessionID, userTurn);
        }

        const alreadyLogged =
          event.sessionID &&
          loggedTurnBySession.get(event.sessionID) === userTurn;
        if (alreadyLogged) return;

        const last = messages[messages.length - 1];
        if (last?.role === "tool") {
          messages.push({
            role: "user",
            content: [{ type: "text", text: RECENCY_REMINDER }],
          });
        }
      }),
    );

    registrations.push(
      await ctx.command.transform((editor) => {
        editor.add({
          name: "complaints-triage",
          description: "Review and triage entries in the harness and codebase complaints boxes",
          execute: async ({ sessionID, prompt, delivery }) => {
            const codebasePath = resolveBoxPath({
              scope: "codebase",
              projectDir,
              harnessPath,
            });
            await ctx.session.prompt({
              ...prompt,
              sessionID,
              text: buildTriagePrompt({
                harnessPath,
                codebasePath,
                extraText: prompt?.text,
              }),
              delivery,
            });
          },
        });
      }),
    );

    return async () => {
      await Promise.all(registrations.map((reg) => reg.dispose()));
    };
  },
};
