import { copilotIdlePolicy } from "./copilot.js";
import { createLogger } from "./logger.js";
import { createScheduler } from "./scheduler.js";

const invalidatingEvents = [
  "session.model.selected",
  "session.agent.selected",
  "session.archived",
  "session.deleted",
  "session.moved",
  "session.execution.started",
  "session.execution.failed",
  "session.execution.interrupted",
  "session.step.failed",
  "session.compaction.started",
  "session.revert.staged",
  "session.inbox.enqueued",
];

function sameModel(left, right) {
  return (
    left?.providerID === right?.providerID &&
    left?.id === right?.id &&
    left?.variant === right?.variant
  );
}

export default {
  id: "dotfiles.idle-compaction",
  async setup(ctx) {
    const options = ctx.options ?? {};
    const { log, warn, level: logLevel } = createLogger(options);
    const policies = [copilotIdlePolicy];
    const scheduler = createScheduler({
      maxLatenessMs: options.maxLatenessMs,
      onError: warn,
      onDiagnostic: log,
      compact: async (sessionID) => {
        await ctx.session.compact({ sessionID, delivery: "queue" });
        log("admitted", { sessionID });
      },
      canCompact: async (sessionID, model) => {
        const session = await ctx.session.get({ sessionID });
        if (session.parentID) return "subagent";
        if (session.time.archived) return "archived";
        if (session.time.busy > (session.time.idle ?? 0)) return "session-busy";
        if (session.location.directory !== ctx.location.directory)
          return "location-changed";
        const selected = session.model ?? (await ctx.model.default()).data;
        if (!sameModel(selected, model)) return "model-changed";
        const agent = (await ctx.agent.get({ agentID: "compaction" })).data;
        return !agent.model || sameModel(agent.model, model)
          ? true
          : "compaction-model-mismatch";
      },
    });
    const controller = new AbortController();
    const registrations = [];
    const cleanup = async () => {
      controller.abort();
      scheduler.dispose();
      await Promise.all(
        registrations.map((registration) => registration.dispose()),
      );
    };

    try {
      registrations.push(
        await ctx.session.hook("prompt", ({ sessionID }) =>
          scheduler.cancel(sessionID, "prompt"),
        ),
      );
      registrations.push(
        await ctx.session.hook("model.request", async (event) => {
          if (event.kind !== "primary") return;
          scheduler.cancel(event.sessionID, "new-model-request");
          const startedAt = Date.now();
          const skip = (reason) =>
            log("skipped", {
              sessionID: event.sessionID,
              model: event.model,
              reason,
            });
          try {
            const session = await ctx.session.get({
              sessionID: event.sessionID,
            });
            if (session.parentID) {
              skip("subagent");
              return;
            }
            const models = (await ctx.model.list()).data;
            const model = models.find((candidate) =>
              sameModel({ ...event.model, variant: undefined }, candidate),
            );
            if (!model) {
              skip("model-not-found");
              return;
            }
            const variant = model.variants?.find(
              (candidate) => candidate.id === event.model.variant,
            );
            const settings = { ...model.settings, ...variant?.settings };
            const resolved = { ...model, settings };
            const policy = policies
              .map((policy) => policy(resolved, options))
              .find((policy) => policy !== undefined);
            if (!policy) {
              skip(
                model.providerID !== "github-copilot"
                  ? "unsupported-provider"
                  : settings.compaction?.type === "native"
                    ? "native-compaction"
                    : options.models?.[model.id] === false
                      ? "model-disabled"
                      : "unsupported-or-invalid-policy",
              );
              return;
            }
            scheduler.begin(event.sessionID, event.model, policy, startedAt);
          } catch (error) {
            warn(error, { sessionID: event.sessionID, operation: "model.request" });
          }
        }),
      );
      registrations.push(
        await ctx.session.hook(
          "experimental.idle",
          ({ sessionID, background }) => {
            if (background.length) {
              scheduler.cancel(sessionID, "background-work");
              log("skipped", {
                sessionID,
                reason: "background-work",
                backgroundJobs: background.length,
              });
            } else scheduler.idle(sessionID);
          },
        ),
      );

      void (async () => {
        try {
          for await (const event of ctx.event.subscribe({
            types: ["session.step.ended", ...invalidatingEvents],
            signal: controller.signal,
          })) {
            if (event.type === "session.step.ended")
              scheduler.complete(event.data.sessionID, event.data.tokens);
            else scheduler.cancel(event.data.sessionID, event.type);
          }
        } catch (error) {
          if (!controller.signal.aborted)
            warn(error, { operation: "event-subscription" });
        } finally {
          scheduler.dispose();
          log("stopped", {
            reason: controller.signal.aborted
              ? "plugin-unloaded"
              : "event-subscription-ended",
          });
        }
      })();
      log("ready", { logLevel, directory: ctx.location.directory });
      return cleanup;
    } catch (error) {
      await cleanup();
      throw error;
    }
  },
};
