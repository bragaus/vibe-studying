import type { Metadata } from "next";

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
  return <AuthView />;
}
