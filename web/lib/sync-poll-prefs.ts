"use client";

import type { PollSpeed } from "@/lib/sync-poll-config";

const AUTO_KEY = "dashboard_auto_refresh";
const SPEED_KEY = "dashboard_poll_speed";

export type DashboardSyncPrefs = {
  autoRefresh: boolean;
  speed: PollSpeed;
};

export function loadDashboardSyncPrefs(): DashboardSyncPrefs {
  if (typeof window === "undefined") {
    return { autoRefresh: true, speed: "normal" };
  }
  const autoRaw = localStorage.getItem(AUTO_KEY);
  const speedRaw = localStorage.getItem(SPEED_KEY);
  return {
    autoRefresh: autoRaw !== "false",
    speed: speedRaw === "slower" ? "slower" : "normal",
  };
}

export function saveDashboardSyncPrefs(prefs: DashboardSyncPrefs) {
  localStorage.setItem(AUTO_KEY, prefs.autoRefresh ? "true" : "false");
  localStorage.setItem(SPEED_KEY, prefs.speed);
}
