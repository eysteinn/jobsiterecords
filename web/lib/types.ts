export type User = {
  id: string;
  email: string;
  name?: string | null;
  created_at: string;
};

export type Workspace = {
  id: string;
  name: string;
  role: "owner" | "member";
  plan_sku: string;
  member_limit: number;
  created_at: string;
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
