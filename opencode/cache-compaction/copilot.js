export function copilotCachePolicy(model, options = {}) {
  if (model.providerID !== "github-copilot") return;
  if (model.settings?.compaction?.type === "native") return;

  const ttl = Object.hasOwn(options.models ?? {}, model.id)
    ? options.models[model.id]
    : (model.settings?.cache?.ttl ?? options.ttl);
  if (typeof ttl !== "string") return;

  const match = ttl.match(/^(\d+)(ms|s|m|h|d)$/);
  if (!match) return;
  const units = { ms: 1, s: 1_000, m: 60_000, h: 3_600_000, d: 86_400_000 };
  const milliseconds = Number(match[1]) * units[match[2]];
  if (Number.isSafeInteger(milliseconds) && milliseconds > 0)
    return milliseconds;
}
