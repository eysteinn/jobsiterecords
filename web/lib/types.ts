export type User = {
  id: string;
  email: string;
  name?: string | null;
  created_at: string;
};

export type WorkspaceAccessMode = "active" | "trial" | "grace" | "read_only";

export type Workspace = {
  id: string;
  name: string;
  role: "owner" | "member";
  plan_sku: string;
  member_limit: number;
  subscription_status: string;
  has_subscription: boolean;
  created_at: string;
  access_mode: WorkspaceAccessMode;
  writable: boolean;
  sync_push_allowed: boolean;
  trial_ends_at?: string | null;
  grace_ends_at?: string | null;
  grace_days_remaining?: number;
  trial_job_limit?: number;
  trial_item_limit?: number;
};

export type Session = {
  user: User;
  workspaces: Workspace[];
};

export type ApiError = {
  error: string;
  message: string;
  details?: Record<string, unknown>;
};

export function apiBaseUrl(): string {
  return (
    process.env.API_INTERNAL_URL ??
    process.env.NEXT_PUBLIC_API_URL ??
    "http://localhost:8080"
  );
}
