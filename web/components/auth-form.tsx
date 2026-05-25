"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, useState } from "react";
import styles from "./auth.module.css";

type Mode = "login" | "signup" | "magic";

type Props = {
  mode?: Mode;
  error?: string;
};

export function AuthForm({ mode: initialMode = "login", error }: Props) {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>(initialMode);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [devLink, setDevLink] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(error ?? null);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setFormError(null);
    setMessage(null);
    setDevLink(null);

    try {
      if (mode === "magic") {
        const res = await fetch("/api/auth/magic-link", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ email }),
        });
        const data = await res.json();
        if (!res.ok) {
          setFormError(data.message || "Could not send magic link");
          return;
        }
        setMessage(data.message);
        if (data.dev_link) setDevLink(data.dev_link);
        return;
      }

      const action = mode === "signup" ? "signup" : "login";
      const body =
        mode === "signup"
          ? { email, password, name: name || undefined }
          : { email, password };

      const res = await fetch(`/api/auth/${action}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      if (!res.ok) {
        setFormError(data.message || "Sign in failed");
        return;
      }
      router.push("/jobs");
      router.refresh();
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
            <h1>Job Site Records</h1>
            <p>Sign in to your workspace dashboard</p>
          </div>
        </div>

        <div className={styles.tabs} role="tablist">
          <button
            type="button"
            role="tab"
            aria-selected={mode === "login"}
            className={mode === "login" ? styles.tabActive : styles.tab}
            onClick={() => setMode("login")}
          >
            Password
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={mode === "magic"}
            className={mode === "magic" ? styles.tabActive : styles.tab}
            onClick={() => setMode("magic")}
          >
            Email me a link
          </button>
        </div>

        <form onSubmit={onSubmit} className={styles.form}>
          {mode === "signup" && (
            <label>
              Name
              <input
                value={name}
                onChange={(e) => setName(e.target.value)}
                autoComplete="name"
                placeholder="Optional"
              />
            </label>
          )}

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

          {mode !== "magic" && (
            <label>
              Password
              <input
                type="password"
                required
                minLength={10}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete={
                  mode === "signup" ? "new-password" : "current-password"
                }
              />
            </label>
          )}

          {formError && <p className={styles.error}>{formError}</p>}
          {message && <p className={styles.success}>{message}</p>}
          {devLink && (
            <p className={styles.devLink}>
              Dev link:{" "}
              <a href={devLink}>{devLink}</a>
            </p>
          )}

          <button type="submit" className={styles.primary} disabled={submitting}>
            {submitting
              ? "Working…"
              : mode === "magic"
                ? "Send sign-in link"
                : mode === "signup"
                  ? "Create account"
                  : "Sign in"}
          </button>
        </form>

        <div className={styles.footer}>
          {mode === "login" && (
            <>
              <Link href="/forgot-password">Forgot password?</Link>
              <span>·</span>
              <button
                type="button"
                className={styles.linkButton}
                onClick={() => setMode("signup")}
              >
                Create account
              </button>
            </>
          )}
          {mode === "signup" && (
            <button
              type="button"
              className={styles.linkButton}
              onClick={() => setMode("login")}
            >
              Already have an account? Sign in
            </button>
          )}
          {mode === "magic" && (
            <button
              type="button"
              className={styles.linkButton}
              onClick={() => setMode("login")}
            >
              Use password instead
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
