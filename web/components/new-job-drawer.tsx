"use client";

import { useRouter } from "next/navigation";
import { FormEvent, useState } from "react";
import styles from "./job-form.module.css";

type Props = {
  workspaceId: string;
  onClose: () => void;
};

export function NewJobDrawer({ workspaceId, onClose }: Props) {
  const router = useRouter();
  const [name, setName] = useState("");
  const [clientName, setClientName] = useState("");
  const [address, setAddress] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    try {
      const id = crypto.randomUUID();
      const now = new Date().toISOString();
      const res = await fetch(`/api/workspaces/${workspaceId}/jobs/${id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          workspace_id: workspaceId,
          name,
          client_name: clientName || null,
          address: address || null,
          status: "in_progress",
          created_at: now,
          updated_at: now,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.message || "Could not create job");
      router.push(`/jobs/${id}`);
      router.refresh();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not create job");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className={styles.backdrop} onClick={onClose}>
      <aside className={styles.drawer} onClick={(e) => e.stopPropagation()}>
        <header>
          <h2>New job</h2>
          <button type="button" onClick={onClose} aria-label="Close">
            ×
          </button>
        </header>
        <form onSubmit={onSubmit} className={styles.form}>
          <label>
            Job name
            <input required value={name} onChange={(e) => setName(e.target.value)} />
          </label>
          <label>
            Client
            <input value={clientName} onChange={(e) => setClientName(e.target.value)} />
          </label>
          <label>
            Address
            <input value={address} onChange={(e) => setAddress(e.target.value)} />
          </label>
          {error && <p className={styles.error}>{error}</p>}
          <button type="submit" className={styles.primary} disabled={saving}>
            {saving ? "Creating…" : "Create job"}
          </button>
        </form>
      </aside>
    </div>
  );
}
