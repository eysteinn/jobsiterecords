"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import type { Item, Job } from "@/lib/api-jobs";
import { formatDate, formatDayKey, formatTime } from "@/lib/format";
import { PageShell } from "@/components/page-shell";
import styles from "./job-detail.module.css";

type Props = {
  job: Job;
  items: Item[];
  workspaceId: string;
};

export function JobDetailClient({ job, items: initialItems, workspaceId }: Props) {
  const router = useRouter();
  const [items, setItems] = useState(initialItems ?? []);
  const [noteBody, setNoteBody] = useState("");
  const [noteCaption, setNoteCaption] = useState("");
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function addNote() {
    if (!noteBody.trim()) return;
    setSaving(true);
    setMessage(null);
    try {
      const id = crypto.randomUUID();
      const now = new Date().toISOString();
      const res = await fetch(`/api/jobs/${job.id}/items/${id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          kind: "note",
          body: noteBody.trim(),
          caption: noteCaption.trim() || null,
          captured_at: now,
          created_at: now,
          updated_at: now,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.message || "Could not add note");
      setItems((prev) => [data, ...prev]);
      setNoteBody("");
      setNoteCaption("");
      setMessage("Saved");
      router.refresh();
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Could not save");
    } finally {
      setSaving(false);
    }
  }

  async function saveCaption(item: Item, caption: string) {
    const now = new Date().toISOString();
    const res = await fetch(`/api/jobs/${job.id}/items/${item.id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        kind: item.kind,
        body: item.body,
        caption: caption || null,
        captured_at: item.captured_at,
        created_at: item.created_at,
        updated_at: now,
      }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not save");
    setItems((prev) => prev.map((it) => (it.id === item.id ? data : it)));
    router.refresh();
  }

  const grouped = groupByDate(items);

  return (
    <PageShell
      title={job.name}
      subtitle={[job.client_name, job.address].filter(Boolean).join(" · ") || "Job timeline"}
      action={
        <Link href="/jobs" className={styles.backLink}>
          ← All jobs
        </Link>
      }
    >
      <section className={styles.compose}>
        <h2>Add text note</h2>
        <input
          placeholder="Caption (optional)"
          value={noteCaption}
          onChange={(e) => setNoteCaption(e.target.value)}
        />
        <textarea
          placeholder="Note body"
          rows={3}
          value={noteBody}
          onChange={(e) => setNoteBody(e.target.value)}
        />
        <div className={styles.composeActions}>
          <button type="button" className={styles.primary} disabled={saving} onClick={addNote}>
            {saving ? "Saving…" : "Add note"}
          </button>
          {message && <span className={styles.saved}>{message}</span>}
        </div>
      </section>

      {items.length === 0 ? (
        <p className={styles.empty}>No timeline items yet.</p>
      ) : (
        Object.entries(grouped).map(([dayKey, dayItems]) => (
          <section key={dayKey} className={styles.dayGroup}>
            <h3>{formatDate(`${dayKey}T12:00:00.000Z`)}</h3>
            <ul className={styles.timeline}>
              {dayItems.map((item) => (
                <li key={item.id} className={styles.item}>
                  <div className={styles.itemMeta}>
                    <span className={styles.kind}>{item.kind}</span>
                    <time>{formatTime(item.captured_at)}</time>
                  </div>
                  <InlineCaption item={item} onSave={saveCaption} />
                  {item.body && <p className={styles.body}>{item.body}</p>}
                </li>
              ))}
            </ul>
          </section>
        ))
      )}
    </PageShell>
  );
}

function InlineCaption({
  item,
  onSave,
}: {
  item: Item;
  onSave: (item: Item, caption: string) => Promise<void>;
}) {
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(item.caption || "");
  const [error, setError] = useState<string | null>(null);

  async function commit() {
    try {
      await onSave(item, value);
      setEditing(false);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save");
    }
  }

  if (editing) {
    return (
      <div className={styles.inlineEdit}>
        <input value={value} onChange={(e) => setValue(e.target.value)} autoFocus />
        <button type="button" onClick={commit}>
          Save
        </button>
        <button type="button" onClick={() => setEditing(false)}>
          Cancel
        </button>
        {error && <span className={styles.error}>{error}</span>}
      </div>
    );
  }

  return (
    <button type="button" className={styles.captionBtn} onClick={() => setEditing(true)}>
      {item.caption || "Add caption…"}
    </button>
  );
}

function groupByDate(items: Item[]) {
  return items.reduce<Record<string, Item[]>>((acc, item) => {
    const day = formatDayKey(item.captured_at);
    acc[day] ??= [];
    acc[day].push(item);
    return acc;
  }, {});
}
