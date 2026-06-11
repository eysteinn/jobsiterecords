"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { Session } from "@/lib/types";
import styles from "./mobile-bottom-nav.module.css";

const baseNav = [
  { href: "/jobs", label: "Jobs", icon: JobsIcon },
  { href: "/reports", label: "Reports", icon: ReportsIcon },
  { href: "/team", label: "Team", icon: TeamIcon, ownerOnly: true },
  { href: "/settings", label: "Settings", icon: SettingsIcon },
];

type Props = {
  session: Session;
};

export function MobileBottomNav({ session }: Props) {
  const pathname = usePathname();
  const workspace = session.workspaces[0];
  const nav = baseNav.filter((item) => !item.ownerOnly || workspace?.role === "owner");

  return (
    <nav className={`${styles.nav} mobileOnly`} aria-label="Main navigation">
      {nav.map((item) => {
        const active = pathname.startsWith(item.href);
        const Icon = item.icon;
        return (
          <Link
            key={item.href}
            href={item.href}
            className={active ? styles.itemActive : styles.item}
            aria-current={active ? "page" : undefined}
          >
            <Icon active={active} />
            <span>{item.label}</span>
          </Link>
        );
      })}
    </nav>
  );
}

function JobsIcon({ active }: { active: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <rect x="2" y="7" width="20" height="14" rx="2" />
      <path d="M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2" />
    </svg>
  );
}

function ReportsIcon({ active }: { active: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M18 20V10M12 20V4M6 20v-6" />
    </svg>
  );
}

function TeamIcon({ active }: { active: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" />
    </svg>
  );
}

function SettingsIcon({ active }: { active: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" aria-hidden>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" />
    </svg>
  );
}
