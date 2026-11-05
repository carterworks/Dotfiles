export function createScheduler({
  compact,
  canCompact,
  onError,
  maxLatenessMs = 60_000,
}) {
  if (!Number.isSafeInteger(maxLatenessMs) || maxLatenessMs <= 0) {
    throw new Error("Idle compaction lateness must be a positive safe integer");
  }

  const sessions = new Map();
  let disposed = false;

  function cancel(sessionID) {
    clearTimeout(sessions.get(sessionID)?.timer);
    sessions.delete(sessionID);
  }

  async function fire(sessionID, state) {
    try {
      if (Date.now() >= state.deadline + maxLatenessMs) return;
      if (!(await canCompact(sessionID, state.model))) return;
      if (
        sessions.get(sessionID) !== state ||
        Date.now() >= state.deadline + maxLatenessMs
      )
        return;
      cancel(sessionID);
      await compact(sessionID);
    } catch (error) {
      onError(error);
    } finally {
      if (sessions.get(sessionID) === state) cancel(sessionID);
    }
  }

  function arm(sessionID, state) {
    if (!state.eligible || !state.idle || state.timer !== undefined) return;
    const delay = state.deadline - Date.now();
    if (delay < 0 || delay > 2_147_483_647) {
      cancel(sessionID);
      return;
    }
    state.timer = setTimeout(() => {
      void fire(sessionID, state);
    }, delay);
    state.timer.unref?.();
  }

  return {
    begin(sessionID, model, policy, startedAt = Date.now()) {
      cancel(sessionID);
      if (
        disposed ||
        !Number.isSafeInteger(policy?.afterMs) ||
        policy.afterMs <= 0 ||
        !Number.isSafeInteger(policy.minInputTokens) ||
        policy.minInputTokens <= 0
      )
        return;
      sessions.set(sessionID, {
        model,
        deadline: startedAt + policy.afterMs,
        minInputTokens: policy.minInputTokens,
        eligible: false,
        idle: false,
      });
    },
    complete(sessionID, tokens) {
      const state = sessions.get(sessionID);
      if (!state) return;
      const counts = [tokens?.input, tokens?.cache?.read, tokens?.cache?.write];
      state.eligible =
        counts.every((n) => Number.isFinite(n) && n >= 0) &&
        counts.reduce((sum, n) => sum + n, 0) >= state.minInputTokens &&
        counts[1] + counts[2] > 0;
      if (!state.eligible) cancel(sessionID);
      else arm(sessionID, state);
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
      for (const sessionID of sessions.keys()) cancel(sessionID);
    },
  };
}
