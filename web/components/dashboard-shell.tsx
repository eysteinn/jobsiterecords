"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import type { Session } from "@/lib/types";
import { CommandPalette } from "./command-palette";
import { MobileBottomNav } from "./mobile-bottom-nav";
import {
  ChevronLeftIcon,
  JobsNavIcon,
  ReportsNavIcon,
  SearchIcon,
  SettingsNavIcon,
  TeamNavIcon,
} from "./nav-icons";
import styles from "./dashboard-shell.module.css";

const nav = [
  { href: "/jobs", label: "Jobs", Icon: JobsNavIcon },
  { href: "/reports", label: "Reports", Icon: ReportsNavIcon },
  { href: "/team", label: "Team", Icon: TeamNavIcon },
  { href: "/settings", label: "Settings", Icon: SettingsNavIcon },
];

type Props = {
  session: Session;
  children: React.ReactNode;
};

function initialsFromEmail(email: string): string {
  const local = email.split("@")[0] ?? "";
  const parts = local.split(/[._-]/).filter(Boolean);
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return local.slice(0, 2).toUpperCase();
}

export function DashboardShell({ session, children }: Props) {
  const pathname = usePathname();
  const router = useRouter();
  const [menuOpen, setMenuOpen] = useState(false);
  const [paletteOpen, setPaletteOpen] = useState(false);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const workspace = session.workspaces[0];
  const isJobsList = pathname === "/jobs";
  const isJobDetail = /^\/jobs\/[^/]+$/.test(pathname);
  const userInitials = initialsFromEmail(session.user.email);

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
    <div
      className={`${styles.shell} ${sidebarCollapsed ? styles.shellCollapsed : ""}`}
      data-sidebar-collapsed={sidebarCollapsed ? "true" : undefined}
    >
      <aside className={`${styles.sidebar} desktopOnly`}>
        <div className={styles.sidebarBrand}>
          <span className={styles.logoMark} aria-hidden />
          {!sidebarCollapsed && <span>Job Site Records</span>}
        </div>
        <nav className={styles.nav} aria-label="Sidebar">
          {nav.map((item) => {
            const active = pathname.startsWith(item.href);
            const Icon = item.Icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={active ? styles.navActive : styles.navItem}
                title={sidebarCollapsed ? item.label : undefined}
              >
                <Icon />
                {!sidebarCollapsed && <span>{item.label}</span>}
              </Link>
            );
          })}
        </nav>
        <button
          type="button"
          className={styles.collapseBtn}
          onClick={() => setSidebarCollapsed((v) => !v)}
          aria-label={sidebarCollapsed ? "Expand sidebar" : "Collapse sidebar"}
        >
          <ChevronLeftIcon />
          {!sidebarCollapsed && <span>Collapse</span>}
        </button>
      </aside>

      <div className={styles.main}>
        <header className={`${styles.header} desktopOnly`}>
          <div className={styles.headerLeft}>
            {workspace ? (
              <div className={styles.workspaceSwitcher}>
                <span className={styles.workspaceLabel}>Workspace</span>
                <button type="button" className={styles.workspaceName}>
                  <strong>{workspace.name}</strong>
                  <span className={styles.workspaceCaret} aria-hidden>
                    ▾
                  </span>
                </button>
              </div>
            ) : (
              <span className={styles.muted}>No workspace</span>
            )}
          </div>
          <div className={styles.headerRight}>
            <button
              type="button"
              className={styles.searchField}
              onClick={() => setPaletteOpen(true)}
              aria-label="Open search"
            >
              <SearchIcon />
              <span className={styles.searchPlaceholder}>Search</span>
              <kbd>⌘K</kbd>
            </button>
            <div className={styles.userMenu}>
              <button
                type="button"
                className={styles.userButton}
                onClick={() => setMenuOpen((v) => !v)}
                aria-expanded={menuOpen}
              >
                <span className={styles.userAvatar} aria-hidden>
                  {userInitials}
                </span>
                <span className={styles.userEmail}>{session.user.email}</span>
                <span className={styles.userCaret} aria-hidden>
                  ▾
                </span>
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

        {!isJobsList && !isJobDetail && (
          <div className={`${styles.mobileAccountBar} mobileOnly`}>
            <div className={styles.userMenu}>
              <button
                type="button"
                className={styles.mobileAccountBtn}
                onClick={() => setMenuOpen((v) => !v)}
                aria-expanded={menuOpen}
                aria-label="Account menu"
              >
                <AccountIcon />
              </button>
              {menuOpen && (
                <div className={styles.userDropdown}>
                  <p className={styles.dropdownEmail}>{session.user.email}</p>
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
        )}

        <main className={styles.content}>{children}</main>
      </div>

      <MobileBottomNav />

      <CommandPalette
        open={paletteOpen}
        onClose={() => setPaletteOpen(false)}
        workspaceId={workspace?.id}
      />
    </div>
  );
}

function AccountIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
      <circle cx="12" cy="7" r="4" />
    </svg>
  );
}
