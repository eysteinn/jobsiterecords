import type { PublicBillingPlan } from "@/lib/paddle-config";

export type WorkspaceBilling = {
  plan_sku: string;
  plan_display_name: string;
  member_limit: number;
  subscription_status: string;
  has_subscription: boolean;
  paddle_customer_id?: string | null;
  member_count: number;
  pending_invite_count: number;
  plans: Array<{
    sku: string;
    display_name: string;
    member_limit: number;
    price_id: string;
    price_cents: number;
  }>;
};

export async function getWorkspaceBilling(workspaceId: string): Promise<WorkspaceBilling> {
  const res = await fetch(`/api/workspaces/${workspaceId}/billing`, { cache: "no-store" });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.message || "Could not load billing");
  }
  return data;
}

export async function openBillingPortal(
  workspaceId: string,
  targetPlanSku?: string,
): Promise<string> {
  const res = await fetch(`/api/workspaces/${workspaceId}/billing/portal`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(targetPlanSku ? { target_plan_sku: targetPlanSku } : {}),
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.message || "Could not open billing portal");
  }
  return data.url as string;
}

export function toPublicPlans(plans: WorkspaceBilling["plans"]): PublicBillingPlan[] {
  return plans.map((plan) => ({
    sku: plan.sku as PublicBillingPlan["sku"],
    displayName: plan.display_name,
    memberLimit: plan.member_limit,
    priceCents: plan.price_cents,
    priceId: plan.price_id,
  }));
}
