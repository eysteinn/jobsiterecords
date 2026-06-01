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
      : undefined;
  return <AuthForm mode="login" error={error} />;
}
