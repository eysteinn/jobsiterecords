"use client";

import { useEffect, useState } from "react";
import type { WorkspaceBilling } from "@/lib/api-billing";
import { getWorkspaceBilling, openBillingPortal } from "@/lib/api-billing";
import { formatUsd, paddleClientToken, paddleEnvironment } from "@/lib/paddle-config";
import {
  CheckoutEventNames,
  initializePaddle,
  type Paddle,
  type PaddleEventData,
} from "@paddle/paddle-js";
import styles from "./billing-settings.module.css";

type Props = {
  workspaceId: string;
  ownerEmail: string;
  initial?: WorkspaceBilling | null;
};

function subscriptionLabel(status: string): string {
  switch (status) {
    case "active":
      return "Active";
    case "trialing":
      return "Trial";
    case "past_due":
      return "Past due";
    case "canceled":
      return "Canceled";
    default:
      return "Not subscribed";
  }
}

export function BillingSettings({ workspaceId, ownerEmail, initial = null }: Props) {
  const [billing, setBilling] = useState<WorkspaceBilling | null>(initial);
  const [paddle, setPaddle] = useState<Paddle | undefined>();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  useEffect(() => {
    const token = paddleClientToken();
    if (!token) return;
    let cancelled = false;
    initializePaddle({
      environment: paddleEnvironment(),
      token,
      eventCallback: (event: PaddleEventData) => {
        if (event.name === CheckoutEventNames.CHECKOUT_COMPLETED) {
          void refreshBilling()
            .then(() => setMessage("Your plan is updated."))
            .catch((err: Error) => setError(err.message));
        }
      },
    }).then((instance) => {
      if (!cancelled) setPaddle(instance);
    });
    return () => {
      cancelled = true;
    };
  }, [workspaceId]);

  useEffect(() => {
    if (initial) return;
    getWorkspaceBilling(workspaceId)
      .then(setBilling)
      .catch((err: Error) => setError(err.message));
  }, [workspaceId, initial]);

  async function refreshBilling() {
    const data = await getWorkspaceBilling(workspaceId);
    setBilling(data);
    return data;
  }

  async function onPlanChange(plan: WorkspaceBilling["plans"][number]) {
    if (!billing) return;
    const plans = billing.plans ?? [];
    if (!plan.price_id) {
      setError("This plan is not configured yet.");
      return;
    }

    const currentLimit =
      plans.find((entry) => entry.sku === billing.plan_sku)?.member_limit ?? billing.member_limit;
    const isDowngrade = plan.member_limit < currentLimit;
    const seatsUsed = billing.member_count + billing.pending_invite_count;

    if (isDowngrade && seatsUsed > plan.member_limit) {
      const removeCount = seatsUsed - plan.member_limit;
      const noun = removeCount === 1 ? "member/invite" : "members/invites";
      setError(`Remove ${removeCount} ${noun} before downgrading`);
      setMessage(null);
      return;
    }

    if (billing.has_subscription && isDowngrade) {
      setBusy(true);
      setError(null);
      setMessage(null);
      try {
        const url = await openBillingPortal(workspaceId, plan.sku);
        window.location.href = url;
      } catch (err) {
        setError(err instanceof Error ? err.message : "Could not open billing portal");
      } finally {
        setBusy(false);
      }
      return;
    }

    await onUpgrade(plan.price_id);
  }

  async function onUpgrade(priceId: string) {
    if (!priceId) {
      setError("This plan is not configured yet.");
      return;
    }
    if (!paddle?.Checkout) {
      setError("Checkout is still loading. Try again in a moment.");
      return;
    }
    setBusy(true);
    setError(null);
    setMessage(null);
    try {
      paddle.Checkout.open({
        items: [{ priceId, quantity: 1 }],
        customer: { email: ownerEmail },
        customData: { workspace_id: workspaceId },
        settings: { allowLogout: false },
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not open checkout");
    } finally {
      setBusy(false);
    }
  }

  async function onManageSubscription() {
    setBusy(true);
    setError(null);
    setMessage(null);
    try {
      const url = await openBillingPortal(workspaceId);
      window.location.href = url;
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not open billing portal");
    } finally {
      setBusy(false);
    }
  }

  if (!billing) {
    return (
      <section className={styles.card}>
        <h2>Subscription</h2>
        <p className={styles.muted}>Loading billing…</p>
      </section>
    );
  }

  const plans = billing.plans ?? [];
  const currentPlan = plans.find((plan) => plan.sku === billing.plan_sku);
  const lapsed = billing.has_subscription && ["past_due", "canceled"].includes(billing.subscription_status);

  return (
    <section className={styles.card}>
      <h2>Subscription</h2>
      <dl className={styles.summary}>
        <div>
          <dt>Current plan</dt>
          <dd>{billing.plan_display_name}</dd>
        </div>
        <div>
          <dt>Status</dt>
          <dd className={lapsed ? styles.statusBad : undefined}>
            {subscriptionLabel(billing.subscription_status)}
          </dd>
        </div>
        <div>
          <dt>Seats used</dt>
          <dd>
            {billing.member_count} / {billing.member_limit}
            {billing.pending_invite_count > 0 ? ` (${billing.pending_invite_count} pending)` : ""}
          </dd>
        </div>
      </dl>

      {lapsed && (
        <p className={styles.alert}>
          Your subscription needs attention. You can still view synced jobs, but edits and uploads are
          paused until billing is fixed.
        </p>
      )}

      {error && <p className={styles.error}>{error}</p>}
      {message && <p className={styles.message}>{message}</p>}

      <div className={styles.planGrid}>
        {plans.map((plan) => {
          const isCurrent = plan.sku === billing.plan_sku && billing.has_subscription;
          return (
            <article key={plan.sku} className={isCurrent ? styles.planCurrent : styles.plan}>
              <h3>{plan.display_name}</h3>
              <p className={styles.price}>
                {formatUsd(plan.price_cents)}
                <span>/month</span>
              </p>
              <p className={styles.muted}>
                {plan.member_limit === 1 ? "Owner only" : `Up to ${plan.member_limit} seats`}
              </p>
              {isCurrent ? (
                <span className={styles.currentBadge}>Current plan</span>
              ) : (
                <button
                  type="button"
                  className={styles.primaryButton}
                  disabled={busy || !plan.price_id}
                  onClick={() => void onPlanChange(plan)}
                >
                  {billing.has_subscription ? "Change plan" : "Subscribe"}
                </button>
              )}
            </article>
          );
        })}
      </div>

      {billing.has_subscription && (
        <button
          type="button"
          className={styles.secondaryButton}
          disabled={busy}
          onClick={onManageSubscription}
        >
          Manage subscription
        </button>
      )}

      {!paddleClientToken() && (
        <p className={styles.muted}>
          Paddle checkout is not configured. Set `NEXT_PUBLIC_PADDLE_CLIENT_TOKEN` and price IDs.
        </p>
      )}

      {currentPlan && !billing.has_subscription && (
        <p className={styles.muted}>
          You are on the {currentPlan.display_name} allowance while billing is in beta. Subscribe to
          lock in cloud sync and team seats through Paddle.
        </p>
      )}
    </section>
  );
}
