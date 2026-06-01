"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import styles from "@/components/auth.module.css";

export default function VerifyMagicLinkPage() {
  const router = useRouter();
  const params = useSearchParams();
  const token = params.get("token");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!token) {
      setError("Missing sign-in token.");
      return;
    }
    (async () => {
      const res = await fetch("/api/auth/verify-magic-link", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        setError(data.message || "Invalid or expired link");
        return;
      }
      router.replace("/jobs");
      router.refresh();
    })();
  }, [token, router]);

  return (
    <div className={styles.wrap}>
      <div className={styles.card}>
        <div className={styles.brand}>
          <span className={styles.logoMark} aria-hidden />
          <div>
            <h1>Signing you in…</h1>
            <p>{error ?? "One moment while we verify your link."}</p>
          </div>
        </div>
      </div>
    </div>
  );
}
