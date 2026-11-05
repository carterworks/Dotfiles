export function createScheduler({
  compact,
  canCompact,
  onError,
  marginMs = 60_000,
  minInputTokens = 32_000,
}) {
  for (const value of [marginMs, minInputTokens]) {
    if (!Number.isSafeInteger(value) || value <= 0) {
      throw new Error(
        "Cache compaction timing and size options must be positive safe integers",
      );
    }
  }

  const sessions = new Map();
  let disposed = false;

  function cancel(sessionID) {
    clearTimeout(sessions.get(sessionID)?.timer);
    sessions.delete(sessionID);
  }

  async function fire(sessionID, state) {
    try {
      if (Date.now() >= state.expiresAt) return;
      if (!(await canCompact(sessionID, state.model))) return;
      if (sessions.get(sessionID) !== state || Date.now() >= state.expiresAt)
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
    const delay = state.expiresAt - marginMs - Date.now();
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
    begin(sessionID, model, ttlMs, startedAt = Date.now()) {
      cancel(sessionID);
      if (disposed || !Number.isSafeInteger(ttlMs) || ttlMs <= marginMs) return;
      sessions.set(sessionID, {
        model,
        expiresAt: startedAt + ttlMs,
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
        counts.reduce((sum, n) => sum + n, 0) >= minInputTokens &&
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
