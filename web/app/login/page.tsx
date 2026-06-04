import { AuthForm } from "@/components/auth-form";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const error =
    params.error === "invalid_link"
      ? "That sign-in link is invalid or expired."
      : params.error === "oauth_failed"
        ? "Google sign-in failed. Try again or use email."
        : params.error === "oauth_state"
          ? "Sign-in expired. Try again."
          : params.error === "oauth_not_configured"
            ? "Google sign-in is not configured on this server."
            : undefined;
  return <AuthForm mode="login" error={error} />;
}
