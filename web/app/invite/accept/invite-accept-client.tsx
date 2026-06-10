"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import type { InvitePreview } from "@/lib/api-team";
import styles from "@/components/auth.module.css";

type Props = {
  token: string;
  signedInEmail?: string;
};

export function InviteAcceptClient({ token, signedInEmail }: Props) {
  const router = useRouter();
  const [preview, setPreview] = useState<InvitePreview | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [accepted, setAccepted] = useState(false);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const res = await fetch(`/api/invites/preview?token=${encodeURIComponent(token)}`);
        const data = await res.json();
        if (!res.ok) {
          if (!cancelled) setError(data.message || "Invalid or expired invite");
          return;
        }
        if (!cancelled) setPreview(data);
      } catch {
        if (!cancelled) setError("Could not load invite");
      }
    }
    void load();
    return () => {
      cancelled = true;
    };
  }, [token]);

  const emailMismatch =
    signedInEmail &&
    preview &&
    signedInEmail.toLowerCase() !== preview.email.toLowerCase();

  async function acceptInvite() {
    setBusy(true);
    setError(null);
    try {
      const res = await fetch("/api/invites/accept", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.message || "Could not accept invite");
        return;
      }
      setAccepted(true);
      router.refresh();
      setTimeout(() => router.push("/jobs"), 1200);
    } catch {
      setError("Could not accept invite");
    } finally {
      setBusy(false);
    }
  }

  const next = `/invite/accept?token=${encodeURIComponent(token)}`;

  return (
    <div className={styles.wrap}>
      <div className={styles.card}>
        <div className={styles.brand}>
          <span className={styles.logoMark} aria-hidden />
          <div>
            <h1>Workspace invite</h1>
            <p>Join your team on Job Site Records</p>
          </div>
        </div>

        {error && <p className={styles.error}>{error}</p>}

        {accepted && (
          <p className={styles.success}>
            You joined {preview?.workspace_name}. Redirecting to jobs…
          </p>
        )}

        {!accepted && preview && (
          <>
            <p>
              You&apos;ve been invited to <strong>{preview.workspace_name}</strong> as a{" "}
              <strong>{preview.role}</strong>.
            </p>
            <p style={{ color: "var(--muted)", fontSize: "0.875rem" }}>
              Invite sent to {preview.email}
            </p>

            {!signedInEmail && (
              <>
                <p>Sign in with that email to accept the invite.</p>
                <Link
                  href={`/login?next=${encodeURIComponent(next)}`}
                  className={styles.primary}
                  style={{ display: "inline-block", textAlign: "center", textDecoration: "none" }}
                >
                  Sign in
                </Link>
                <p className={styles.footer}>
                  <Link href={`/login?next=${encodeURIComponent(next)}`}>Create account</Link>
                </p>
              </>
            )}

            {signedInEmail && emailMismatch && (
              <>
                <p className={styles.error}>
                  You&apos;re signed in as {signedInEmail}, but this invite is for {preview.email}.
                  Sign in with the invited email to continue.
                </p>
                <Link
                  href={`/login?next=${encodeURIComponent(next)}`}
                  className={styles.primary}
                  style={{ display: "inline-block", textAlign: "center", textDecoration: "none" }}
                >
                  Switch account
                </Link>
              </>
            )}

            {signedInEmail && !emailMismatch && (
              <button
                type="button"
                className={styles.primary}
                disabled={busy}
                onClick={() => void acceptInvite()}
              >
                {busy ? "Joining…" : "Accept invite"}
              </button>
            )}
          </>
        )}

        {!accepted && !preview && !error && <p>Loading invite…</p>}
      </div>
    </div>
  );
}
