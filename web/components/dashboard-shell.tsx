"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import type { Session } from "@/lib/types";
import { CommandPalette } from "./command-palette";
import styles from "./dashboard-shell.module.css";

const nav = [
  { href: "/jobs", label: "Jobs" },
  { href: "/reports", label: "Reports" },
  { href: "/team", label: "Team" },
  { href: "/settings", label: "Settings" },
];

type Props = {
  session: Session;
  children: React.ReactNode;
};

export function DashboardShell({ session, children }: Props) {
  const pathname = usePathname();
  const router = useRouter();
  const [menuOpen, setMenuOpen] = useState(false);
  const [paletteOpen, setPaletteOpen] = useState(false);
  const workspace = session.workspaces[0];

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setPaletteOpen(true);
      }
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  async function signOut() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.push("/login");
    router.refresh();
  }

  return (
    <div className={styles.shell}>
      <aside className={styles.sidebar}>
        <div className={styles.sidebarBrand}>
          <span className={styles.logoMark} aria-hidden />
          <span>Job Site Records</span>
        </div>
        <nav className={styles.nav}>
          {nav.map((item) => {
            const active = pathname.startsWith(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                className={active ? styles.navActive : styles.navItem}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
      </aside>

      <div className={styles.main}>
        <header className={styles.header}>
          <div className={styles.headerLeft}>
            {workspace ? (
              <div className={styles.workspaceSwitcher}>
                <span className={styles.workspaceLabel}>Workspace</span>
                <strong>{workspace.name}</strong>
              </div>
            ) : (
              <span className={styles.muted}>No workspace</span>
            )}
          </div>
          <div className={styles.headerRight}>
            <button
              type="button"
              className={styles.paletteButton}
              onClick={() => setPaletteOpen(true)}
            >
              Search <kbd>⌘K</kbd>
            </button>
            <div className={styles.userMenu}>
              <button
                type="button"
                className={styles.userButton}
                onClick={() => setMenuOpen((v) => !v)}
                aria-expanded={menuOpen}
              >
                Signed in as {session.user.email}
              </button>
              {menuOpen && (
                <div className={styles.userDropdown}>
                  <Link href="/settings" onClick={() => setMenuOpen(false)}>
                    Account settings
                  </Link>
                  <button type="button" onClick={signOut}>
                    Sign out
                  </button>
                </div>
              )}
            </div>
          </div>
        </header>
        <main className={styles.content}>{children}</main>
      </div>

      <CommandPalette open={paletteOpen} onClose={() => setPaletteOpen(false)} />
    </div>
  );
}
