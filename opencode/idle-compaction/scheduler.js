export function createScheduler({
  compact,
  canCompact,
  onError,
  onDiagnostic = () => {},
  maxLatenessMs = 60_000,
}) {
  if (!Number.isSafeInteger(maxLatenessMs) || maxLatenessMs <= 0) {
    throw new Error("Idle compaction lateness must be a positive safe integer");
  }

  const sessions = new Map();
  let disposed = false;

  function cancel(sessionID, reason) {
    const state = sessions.get(sessionID);
    if (state && reason) onDiagnostic("cancelled", { sessionID, reason });
    clearTimeout(state?.timer);
    sessions.delete(sessionID);
  }

  function skip(sessionID, reason, details = {}) {
    onDiagnostic("skipped", { sessionID, reason, ...details });
    cancel(sessionID);
  }

  async function fire(sessionID, state) {
    try {
      if (Date.now() >= state.deadline + maxLatenessMs) {
        skip(sessionID, "timer-too-late", {
          deadline: state.deadline,
          maxLatenessMs,
        });
        return;
      }
      const eligibility = await canCompact(sessionID, state.model);
      if (sessions.get(sessionID) !== state) return;
      if (eligibility !== true) {
        skip(
          sessionID,
          typeof eligibility === "string" ? eligibility : "session-ineligible",
        );
        return;
      }
      if (Date.now() >= state.deadline + maxLatenessMs) {
        skip(sessionID, "timer-too-late", {
          deadline: state.deadline,
          maxLatenessMs,
        });
        return;
      }
      cancel(sessionID);
      await compact(sessionID);
    } catch (error) {
      onError(error, { sessionID, operation: "idle-deadline" });
    } finally {
      if (sessions.get(sessionID) === state) cancel(sessionID);
    }
  }

  function arm(sessionID, state) {
    if (!state.eligible || !state.idle || state.timer !== undefined) return;
    const delay = state.deadline - Date.now();
    if (delay < 0 || delay > 2_147_483_647) {
      skip(sessionID, delay < 0 ? "deadline-passed" : "timer-out-of-range", {
        deadline: state.deadline,
      });
      return;
    }
    state.timer = setTimeout(() => {
      void fire(sessionID, state);
    }, delay);
    state.timer.unref?.();
    onDiagnostic("scheduled", {
      sessionID,
      model: state.model,
      deadline: state.deadline,
      minInputTokens: state.minInputTokens,
    });
  }

  return {
    begin(sessionID, model, policy, startedAt = Date.now()) {
      cancel(sessionID, "new-model-request");
      if (
        disposed ||
        !Number.isSafeInteger(policy?.afterMs) ||
        policy.afterMs <= 0 ||
        !Number.isSafeInteger(policy.minInputTokens) ||
        policy.minInputTokens <= 0
      ) {
        if (!disposed) skip(sessionID, "invalid-policy");
        return;
      }
      sessions.set(sessionID, {
        model,
        deadline: startedAt + policy.afterMs,
        minInputTokens: policy.minInputTokens,
        eligible: false,
        idle: false,
      });
      onDiagnostic("tracking", {
        sessionID,
        model,
        deadline: startedAt + policy.afterMs,
        minInputTokens: policy.minInputTokens,
      });
    },
    complete(sessionID, tokens) {
      const state = sessions.get(sessionID);
      if (!state) return;
      const counts = [tokens?.input, tokens?.cache?.read, tokens?.cache?.write];
      if (!counts.every((n) => Number.isFinite(n) && n >= 0)) {
        skip(sessionID, "invalid-token-usage");
        return;
      }
      const inputTokens = counts.reduce((sum, n) => sum + n, 0);
      if (inputTokens < state.minInputTokens) {
        skip(sessionID, "below-token-threshold", {
          inputTokens,
          minInputTokens: state.minInputTokens,
        });
        return;
      }
      if (counts[1] + counts[2] === 0) {
        skip(sessionID, "no-cache-evidence", { inputTokens });
        return;
      }
      state.eligible = true;
      arm(sessionID, state);
    },
    idle(sessionID) {
      const state = sessions.get(sessionID);
      if (!state) return;
      state.idle = true;
      arm(sessionID, state);
    },
    cancel,
    dispose() {
      disposed = true;
      for (const sessionID of sessions.keys()) cancel(sessionID, "plugin-unloaded");
    },
  };
}
