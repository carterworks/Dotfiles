export const DEFAULT_LIMIT = 200;

export interface FindFilesParams {
  path?: string;
  pattern?: string;
}

export interface GrepParams {
  path?: string;
  glob?: string;
  pattern?: string;
}

export interface MultiGrepParams {
  patterns: string[];
  path?: string;
  glob?: string;
  limit?: number;
}

export function buildFindFilesQuery(params: FindFilesParams): string {
  const parts: string[] = [];
  const pathConstraint = toPathConstraint(params.path);
  const pattern = normalizeString(params.pattern);

  if (pathConstraint) parts.push(pathConstraint);
  if (pattern) parts.push(pattern);
  return parts.join(" ").trim();
}

export function buildGrepQuery(params: GrepParams): string {
  const parts: string[] = [];
  const pathConstraint = toPathConstraint(params.path);
  const globConstraint = normalizeString(params.glob);
  const pattern = normalizeString(params.pattern);

  if (pathConstraint) parts.push(pathConstraint);
  if (globConstraint) parts.push(globConstraint);
  if (pattern) parts.push(pattern);
  return parts.join(" ").trim();
}

export function buildMultiGrepConstraints(params: Pick<MultiGrepParams, "path" | "glob">): string {
  const parts: string[] = [];
  const pathConstraint = toPathConstraint(params.path);
  const globConstraint = normalizeString(params.glob);

  if (pathConstraint) parts.push(pathConstraint);
  if (globConstraint) parts.push(globConstraint);
  return parts.join(" ").trim();
}

export function toPathConstraint(pathValue: unknown): string {
  const value = normalizeString(pathValue);
  if (!value || value === ".") return "";
  return value.endsWith("/") ? value : `${value.replace(/\/+$/, "")}/`;
}

export function normalizeString(value: unknown): string {
  if (typeof value !== "string") return "";

  const trimmed = value.trim();
  return trimmed.startsWith("@") ? trimmed.slice(1).trim() : trimmed;
}

export function normalizePatterns(values: string[]): string[] {
  return values.map((value) => normalizeString(value)).filter(Boolean);
}

export function normalizeLimit(value: unknown): number {
  return Number.isFinite(value) && Number(value) > 0
    ? Number(value)
    : DEFAULT_LIMIT;
}

export function buildBuiltinFallbackGrepInput(
  params: Pick<MultiGrepParams, "path" | "glob">,
  pattern: string,
  remainingLimit: number,
) {
  return {
    pattern,
    path: params.path,
    glob: params.glob,
    literal: true,
    limit: remainingLimit,
  };
}

const NO_MATCHES_LINES = new Set(["No matches found", "No matches found."]);

export function appendUniqueTrimmedLines(
  lines: string[],
  seen: Set<string>,
  text: string,
  maxResults: number,
): void {
  for (const line of text.split("\n")) {
    const trimmed = line.trimEnd();
    if (!trimmed || NO_MATCHES_LINES.has(trimmed) || seen.has(trimmed)) {
      continue;
    }
    seen.add(trimmed);
    lines.push(trimmed);
    if (lines.length >= maxResults) return;
  }
}
