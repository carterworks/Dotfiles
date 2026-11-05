export function copilotIdlePolicy(model, options = {}) {
  if (model.providerID !== "github-copilot") return;
  if (model.settings?.compaction?.type === "native") return;

  const override = options.models?.[model.id];
  if (override === false) return;
  if (
    override !== undefined &&
    (!override || typeof override !== "object" || Array.isArray(override))
  )
    return;

  let defaultAfter;
  if (/^gpt-(?:5\.6|6|6\.1)-(?:sol|luna|terra)$/.test(model.id)) {
    // User-selected 54m policy, inspired by Claude Code's 54m/1h schedule; not a Copilot TTL guarantee.
    // https://code.claude.com/docs/en/changelog#2-1-299
    defaultAfter = "54m";
  } else if (model.id.startsWith("claude-")) {
    // Three minutes leaves 2m within Anthropic's default 5m lifetime; Copilot retention is unverified.
    // https://platform.claude.com/docs/en/build-with-claude/prompt-caching
    defaultAfter = "3m";
  }
  const after =
    override?.after !== undefined
      ? override.after
      : options.after !== undefined
        ? options.after
        : defaultAfter;
  if (typeof after !== "string") return;
  const match = after.match(/^(\d+)(ms|s|m|h|d)$/);
  if (!match) return;
  const units = { ms: 1, s: 1_000, m: 60_000, h: 3_600_000, d: 86_400_000 };
  const milliseconds = Number(match[1]) * units[match[2]];
  const minInputTokens =
    override?.minInputTokens ?? options.minInputTokens ?? 200_000;
  if (
    Number.isSafeInteger(milliseconds) &&
    milliseconds > 0 &&
    Number.isSafeInteger(minInputTokens) &&
    minInputTokens > 0
  )
    return { afterMs: milliseconds, minInputTokens };
}
