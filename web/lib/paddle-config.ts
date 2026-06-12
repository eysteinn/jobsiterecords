export type BillingPlanSKU = "solo_1" | "crew_5" | "team_15";

export type PublicBillingPlan = {
  sku: BillingPlanSKU;
  displayName: string;
  memberLimit: number;
  priceCents: number;
  priceId: string;
};

export function paddleEnvironment(): "sandbox" | "production" {
  return process.env.NEXT_PUBLIC_PADDLE_ENV === "production" ? "production" : "sandbox";
}

export function paddleClientToken(): string {
  return process.env.NEXT_PUBLIC_PADDLE_CLIENT_TOKEN ?? "";
}

export function publicBillingPlans(): PublicBillingPlan[] {
  return [
    {
      sku: "solo_1",
      displayName: "Solo",
      memberLimit: 1,
      priceCents: 1900,
      priceId: process.env.NEXT_PUBLIC_PADDLE_PRICE_ID_SOLO_1_MONTHLY ?? "",
    },
    {
      sku: "crew_5",
      displayName: "Crew",
      memberLimit: 5,
      priceCents: 4900,
      priceId: process.env.NEXT_PUBLIC_PADDLE_PRICE_ID_CREW_5_MONTHLY ?? "",
    },
    {
      sku: "team_15",
      displayName: "Team",
      memberLimit: 15,
      priceCents: 9900,
      priceId: process.env.NEXT_PUBLIC_PADDLE_PRICE_ID_TEAM_15_MONTHLY ?? "",
    },
  ];
}

export function formatUsd(cents: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0,
  }).format(cents / 100);
}

export function planDisplayName(sku: string): string {
  return publicBillingPlans().find((plan) => plan.sku === sku)?.displayName ?? sku;
}
