"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";
import styles from "@/components/auth.module.css";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [devLink, setDevLink] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    setMessage(null);
    setDevLink(null);
    try {
      const res = await fetch("/api/auth/forgot-password", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.message || "Request failed");
        return;
      }
      setMessage(data.message);
      if (data.dev_link) setDevLink(data.dev_link);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className={styles.wrap}>
      <div className={styles.card}>
        <div className={styles.brand}>
          <span className={styles.logoMark} aria-hidden />
          <div>
            <h1>Reset password</h1>
            <p>We&apos;ll email you a reset link</p>
          </div>
        </div>
        <form onSubmit={onSubmit} className={styles.form}>
          <label>
            Email
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
            />
          </label>
          {error && <p className={styles.error}>{error}</p>}
          {message && <p className={styles.success}>{message}</p>}
          {devLink && (
            <p className={styles.devLink}>
              Dev link: <a href={devLink}>{devLink}</a>
            </p>
          )}
          <button type="submit" className={styles.primary} disabled={submitting}>
            {submitting ? "Sending…" : "Send reset link"}
          </button>
        </form>
        <div className={styles.footer}>
          <Link href="/login">Back to sign in</Link>
        </div>
      </div>
    </div>
  );
}
