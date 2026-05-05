import type { Metadata } from "next";
import { Suspense } from "react";

import AuthView from "@/views/AuthView";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Login",
  description: "Acesse sua conta do Vibe Studying.",
  robots: {
    index: false,
    follow: false,
  },
};

export default function AuthPage() {
  const turnstileSiteKey = (
    process.env.TURNSTILE_SITE_KEY ?? process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY ?? ""
  ).trim();

  return (
    <Suspense fallback={null}>
      <AuthView turnstileSiteKey={turnstileSiteKey} />
    </Suspense>
  );
}
