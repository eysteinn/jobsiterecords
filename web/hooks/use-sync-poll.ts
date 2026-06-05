"use client";

import { useEffect, useRef } from "react";
import { SYNC_POLL } from "@/lib/sync-poll-config";
import { loadDashboardSyncPrefs } from "@/lib/sync-poll-prefs";
import type { CursorPollResult } from "@/lib/sync-cursor";

type Options = {
  /** When false, polling is fully disabled regardless of dashboard prefs. */
  enabled?: boolean;
  baseIntervalMs: number;
  poll: (etag: string | null) => Promise<CursorPollResult>;
  onChanged: (result: CursorPollResult) => void | Promise<void>;
};

export function useSyncPoll({ enabled = true, baseIntervalMs, poll, onChanged }: Options) {
  const etagRef = useRef<string | null>(null);
  const idleRoundsRef = useRef(0);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const inFlightRef = useRef(false);
  const pollRef = useRef(poll);
  const onChangedRef = useRef(onChanged);
  pollRef.current = poll;
  onChangedRef.current = onChanged;

  useEffect(() => {
    const clearTimer = () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
        timerRef.current = null;
      }
    };

    const nextDelay = () => {
      const prefs = loadDashboardSyncPrefs();
      const base = prefs.speed === "slower" ? baseIntervalMs * 2 : baseIntervalMs;
      return Math.min(SYNC_POLL.maxBackoffMs, base * Math.pow(2, Math.min(idleRoundsRef.current, 2)));
    };

    const schedule = (delayMs: number) => {
      clearTimer();
      timerRef.current = setTimeout(() => {
        void tick();
      }, delayMs);
    };

    const tick = async () => {
      const prefs = loadDashboardSyncPrefs();
      if (!enabled || !prefs.autoRefresh || inFlightRef.current) {
        schedule(nextDelay());
        return;
      }
      if (document.visibilityState !== "visible") {
        return;
      }

      inFlightRef.current = true;
      try {
        const result = await pollRef.current(etagRef.current);
        if (result.etag) etagRef.current = result.etag;
        if (result.changed) {
          idleRoundsRef.current = 0;
          await onChangedRef.current(result);
        } else {
          idleRoundsRef.current += 1;
        }
      } catch {
        idleRoundsRef.current += 1;
      } finally {
        inFlightRef.current = false;
        schedule(nextDelay());
      }
    };

    if (!enabled) {
      clearTimer();
      return;
    }

    const onVisible = () => {
      if (document.visibilityState === "visible") {
        void tick();
      } else {
        clearTimer();
      }
    };

    const onFocus = () => {
      void tick();
    };

    document.addEventListener("visibilitychange", onVisible);
    window.addEventListener("focus", onFocus);
    schedule(0);

    return () => {
      clearTimer();
      document.removeEventListener("visibilitychange", onVisible);
      window.removeEventListener("focus", onFocus);
    };
  }, [baseIntervalMs, enabled]);
}
