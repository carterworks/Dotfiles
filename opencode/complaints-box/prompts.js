export const TOOL_DESCRIPTION =
  "Office complaints/suggestion box. Call when you hit harness/tooling/doc friction or spot codebase/infra warts worth improving later. Never call for normal user-requested bug/feature work.";

export const SYSTEM_PROMPT = [
  "# Complaints box",
  "Alongside completing the user's request, act as an observant teammate using the `complaints_box` tool.",
  "Call `complaints_box` whenever you hit unexpected friction OR spot something outside your requested change that the owner should improve later:",
  "- Harness or environment friction (tools, MCPs, skills, permissions, scripts, or outdated/conflicting instructions).",
  "- Codebase or infra rough edges outside your current task (awkward DX, brittle patterns, recurring footguns, slow/clumsy workflows, or architectural warts).",
  '- Anything else worth flagging for later (use `category: "other"`).',
  "Do NOT call `complaints_box` for the normal bug/feature/lint fix the user asked for, or when the task went smoothly with nothing notable.",
].join("\n");

export const RECENCY_REMINDER =
  "<system-reminder>Complaints box check: did anything you just ran or read reveal unexpected harness/tool/doc friction, OR an unrelated codebase/infra rough edge worth improving later? If yes, call `complaints_box` once; if this is just normal user-requested work, ignore this.</system-reminder>";

export function buildTriagePrompt({ harnessPath, codebasePath, extraText }) {
  const lines = [
    "Review the complaints box logs and help me triage them:",
    `- Harness box: ${harnessPath}`,
    `- Codebase box: ${codebasePath}`,
    "",
    "Read whichever files exist, group duplicate or related entries, and note which `model` signed each complaint so I can weigh signal quality.",
    "Summarize the highest-value improvements, propose concrete fixes, and ask which ones I want to act on or clear.",
  ];
  if (extraText?.trim()) {
    lines.push("", `Additional focus: ${extraText.trim()}`);
  }
  return lines.join("\n");
}
