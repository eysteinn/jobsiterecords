/** Dashboard sync polling defaults (see docs/sync-strategy-plan.md §7.1). */
export const SYNC_POLL = {
  jobDetailMs: 10_000,
  jobsListMs: 60_000,
  maxBackoffMs: 60_000,
  updatedBannerMs: 5_000,
} as const;

export type PollSpeed = "normal" | "slower";

export function pollInterval(baseMs: number, speed: PollSpeed): number {
  return speed === "slower" ? baseMs * 2 : baseMs;
}
