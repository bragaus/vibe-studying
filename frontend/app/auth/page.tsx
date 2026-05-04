import type { Metadata } from "next";
import { Suspense } from "react";

import AuthView from "@/views/AuthView";

export const metadata: Metadata = {
  title: "Login",
  description: "Acesse sua conta do Vibe Studying.",
  robots: {
    index: false,
    follow: false,
  },
};

export default function AuthPage() {
  return (
    <Suspense fallback={null}>
      <AuthView />
    </Suspense>
  );
}
