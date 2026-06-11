import { NextResponse } from "next/server";
import { apiBaseUrl } from "@/lib/types";
import { authenticatedProxy } from "@/lib/authenticated-proxy";

export async function GET(
  _request: Request,
  context: { params: Promise<{ workspaceId: string }> },
) {
  const { workspaceId } = await context.params;
  const res = await authenticatedProxy(`${apiBaseUrl()}/api/v1/workspaces/${workspaceId}/team`);
  const data = await res.json();
  return NextResponse.json(data, { status: res.status });
}
