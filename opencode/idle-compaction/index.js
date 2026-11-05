import { copilotIdlePolicy } from "./copilot.js";
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
    const options = ctx.options;
    const policies = [copilotIdlePolicy];
    const warn = (error) =>
      console.warn(
        "[idle-compaction] Operation failed:",
        error?.name ?? "Error",
      );
    const scheduler = createScheduler({
      maxLatenessMs: options.maxLatenessMs,
      onError: warn,
      compact: async (sessionID) => {
        await ctx.session.compact({ sessionID, delivery: "queue" });
        console.info(
          "[idle-compaction] Admitted compaction at idle deadline:",
          sessionID,
        );
      },
      canCompact: async (sessionID, model) => {
        const session = await ctx.session.get({ sessionID });
        if (
          session.parentID ||
          session.time.archived ||
          session.time.busy > (session.time.idle ?? 0)
        )
          return false;
        if (session.location.directory !== ctx.location.directory) return false;
        const selected = session.model ?? (await ctx.model.default()).data;
        if (!sameModel(selected, model)) return false;
        const agent = (await ctx.agent.get({ agentID: "compaction" })).data;
        return !agent.model || sameModel(agent.model, model);
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
          scheduler.cancel(sessionID),
        ),
      );
      registrations.push(
        await ctx.session.hook("model.request", async (event) => {
          if (event.kind !== "primary") return;
          scheduler.cancel(event.sessionID);
          const startedAt = Date.now();
          try {
            const session = await ctx.session.get({
              sessionID: event.sessionID,
            });
            if (session.parentID) return;
            const models = (await ctx.model.list()).data;
            const model = models.find((candidate) =>
              sameModel({ ...event.model, variant: undefined }, candidate),
            );
            if (!model) return;
            const variant = model.variants?.find(
              (candidate) => candidate.id === event.model.variant,
            );
            const settings = { ...model.settings, ...variant?.settings };
            const resolved = { ...model, settings };
            const policy = policies
              .map((policy) => policy(resolved, options))
              .find((policy) => policy !== undefined);
            scheduler.begin(event.sessionID, event.model, policy, startedAt);
          } catch (error) {
            warn(error);
          }
        }),
      );
      registrations.push(
        await ctx.session.hook(
          "experimental.idle",
          ({ sessionID, background }) => {
            if (background.length) scheduler.cancel(sessionID);
            else scheduler.idle(sessionID);
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
            else scheduler.cancel(event.data.sessionID);
          }
        } catch (error) {
          if (!controller.signal.aborted) warn(error);
        } finally {
          scheduler.dispose();
        }
      })();
      return cleanup;
    } catch (error) {
      await cleanup();
      throw error;
    }
  },
};
