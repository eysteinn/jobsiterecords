"use client";

import { useEffect, useState } from "react";
import {
  loadDashboardSyncPrefs,
  saveDashboardSyncPrefs,
  type DashboardSyncPrefs,
} from "@/lib/sync-poll-prefs";
import styles from "./dashboard-sync-settings.module.css";

export function DashboardSyncSettings() {
  const [prefs, setPrefs] = useState<DashboardSyncPrefs | null>(null);

  useEffect(() => {
    setPrefs(loadDashboardSyncPrefs());
  }, []);

  if (!prefs) return null;

  function update(patch: Partial<DashboardSyncPrefs>) {
    const next = { ...prefs!, ...patch };
    setPrefs(next);
    saveDashboardSyncPrefs(next);
  }

  return (
    <section className={styles.card}>
      <h2>Live updates</h2>
      <p className={styles.lead}>
        The dashboard checks for new field captures while this tab is open. Manual refresh always works.
      </p>
      <label className={styles.row}>
        <input
          type="checkbox"
          checked={prefs.autoRefresh}
          onChange={(e) => update({ autoRefresh: e.target.checked })}
        />
        <span>Auto-refresh while this tab is visible</span>
      </label>
      <fieldset className={styles.fieldset} disabled={!prefs.autoRefresh}>
        <legend>Check frequency</legend>
        <label className={styles.row}>
          <input
            type="radio"
            name="poll-speed"
            checked={prefs.speed === "normal"}
            onChange={() => update({ speed: "normal" })}
          />
          <span>Normal (~20 s on a job, ~60 s on the list)</span>
        </label>
        <label className={styles.row}>
          <input
            type="radio"
            name="poll-speed"
            checked={prefs.speed === "slower"}
            onChange={() => update({ speed: "slower" })}
          />
          <span>Slower (half the server checks)</span>
        </label>
      </fieldset>
    </section>
  );
}
