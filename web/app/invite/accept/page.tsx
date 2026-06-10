import { InviteAcceptClient } from "./invite-accept-client";
import { getServerSession } from "@/lib/server-session";
import { redirect } from "next/navigation";

export default async function InviteAcceptPage({
  searchParams,
}: {
  searchParams: Promise<{ token?: string }>;
}) {
  const params = await searchParams;
  if (!params.token) {
    redirect("/login");
  }

  const session = await getServerSession();
  return (
    <InviteAcceptClient token={params.token} signedInEmail={session?.user.email} />
  );
}
