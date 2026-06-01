import { Suspense } from "react";
import VerifyMagicLinkPage from "./verify-client";

export default function Page() {
  return (
    <Suspense>
      <VerifyMagicLinkPage />
    </Suspense>
  );
}
