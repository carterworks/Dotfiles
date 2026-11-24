import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const TOOL_DESCRIPTION =
  "Office complaints/suggestion box. Call when you hit harness/tooling/doc friction or spot codebase/infra warts worth improving later. Never call for normal user-requested bug/feature work.";

const SYSTEM_PROMPT = `# Complaints box
Alongside completing the user's request, act as an observant teammate using the \`complaints_box\` tool.
Call \`complaints_box\` whenever you hit unexpected friction OR spot something outside your requested change that the owner should improve later:
- Harness or environment friction (tools, MCPs, skills, permissions, scripts, or outdated/conflicting instructions).
- Codebase or infra rough edges outside your current task (awkward DX, brittle patterns, recurring footguns, slow/clumsy workflows, or architectural warts).
- Anything else worth flagging for later (use \`category: "other"\`).
Do NOT call \`complaints_box\` for the normal bug/feature/lint fix the user asked for, or when the task went smoothly with nothing notable.`;

const RECENCY_REMINDER =
  "<system-reminder>Complaints box check: did anything you just ran or read reveal unexpected harness/tool/doc friction, OR an unrelated codebase/infra rough edge worth improving later? If yes, call `complaints_box` once; if this is just normal user-requested work, ignore this.</system-reminder>";

export function defaultBoxPath() {
  const stateHome = process.env.XDG_STATE_HOME || path.join(os.homedir(), ".local", "state");
  return path.join(stateHome, "opencode", "complaints-box.jsonl");
}

function formatModel(model) {
  if (!model) return undefined;
  if (typeof model === "string") return model;
  if (!model.providerID || !model.id) return undefined;
  return model.variant ? `${model.providerID}/${model.id}#${model.variant}` : `${model.providerID}/${model.id}`;
}

export default {
  id: "dotfiles.complaints-box",
  async setup(ctx) {
    const boxPath = ctx.options?.path || defaultBoxPath();
    const project = ctx.location?.project?.canonical ?? ctx.location?.directory ?? null;
    const modelBySession = new Map();
    const turnBySession = new Map();
    const loggedTurnBySession = new Map();

    async function resolveModel(sessionID) {
      if (sessionID && modelBySession.has(sessionID)) return modelBySession.get(sessionID);
      try {
        const session = sessionID && (await ctx.session?.get?.({ sessionID }));
        const formatted = formatModel(session?.model ?? session?.data?.model);
        if (formatted) {
          modelBySession.set(sessionID, formatted);
          return formatted;
        }
      } catch {}
      return "unknown";
    }

    const registrations = [
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
                description: "'harness' for OpenCode/OS/shell/MCP/skills/global setup; 'codebase' for this repo",
              },
              summary: { type: "string", description: "Short one-line title" },
              details: { type: "string", description: "What happened or what you noticed" },
              category: {
                type: "string",
                enum: ["tool", "mcp", "skill", "instructions", "environment", "permissions", "codebase", "infra", "other"],
                description: "Optional category (defaults to 'other')",
              },
              workaround: { type: "string", description: "How you worked around it, if applicable" },
              suggestion: { type: "string", description: "Concrete improvement idea, if obvious" },
            },
            required: ["scope", "summary", "details"],
            additionalProperties: false,
          },
          options: { codemode: false },
          execute: async (input, context) => {
            const sessionID = context?.sessionID ?? null;
            if (sessionID) loggedTurnBySession.set(sessionID, turnBySession.get(sessionID) ?? 0);
            const model = await resolveModel(sessionID);
            const entry = {
              id: crypto.randomUUID(),
              timestamp: new Date().toISOString(),
              category: "other",
              ...input,
              model,
              agent: context?.agent ?? "unknown",
              sessionID,
              project,
              cwd: ctx.location?.directory ?? null,
            };
            try {
              fs.mkdirSync(path.dirname(boxPath), { recursive: true });
              fs.appendFileSync(boxPath, `${JSON.stringify(entry)}\n`, "utf8");
              return { content: `Dropped in the complaints box (${input.scope}, signed by ${model}).` };
            } catch (error) {
              return { content: `Could not write to complaints box (${error?.message ?? error}); continuing.` };
            }
          },
        });
      }),

      await ctx.session.hook("context", (event) => {
        const formatted = formatModel(event.model);
        if (event.sessionID && formatted) modelBySession.set(event.sessionID, formatted);
        event.system.push({ type: "text", text: SYSTEM_PROMPT });

        const messages = event.messages;
        if (!Array.isArray(messages) || messages.length < 2) return;

        const turn = messages.filter((m) => m?.role === "user").length;
        if (event.sessionID) turnBySession.set(event.sessionID, turn);
        if (event.sessionID && loggedTurnBySession.get(event.sessionID) === turn) return;

        if (messages[messages.length - 1]?.role === "tool") {
          messages.push({ role: "user", content: [{ type: "text", text: RECENCY_REMINDER }] });
        }
      }),

      await ctx.command.transform((editor) => {
        editor.add({
          name: "complaints-triage",
          description: "Review and triage entries in the complaints box",
          execute: async ({ sessionID, prompt, delivery }) => {
            const extra = prompt?.text?.trim() ? `\n\nAdditional focus: ${prompt.text.trim()}` : "";
            await ctx.session.prompt({
              ...prompt,
              sessionID,
              delivery,
              text: `Review ${boxPath} and help me triage it (current project: ${project ?? "none"}). Group related entries, note which \`model\` signed each one, and propose concrete fixes.${extra}`,
            });
          },
        });
      }),
    ];

    return () => Promise.all(registrations.map((reg) => reg.dispose()));
  },
};
