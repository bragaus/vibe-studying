import type { Metadata } from "next";

import StudentProfileView from "@/views/StudentProfileView";

export const metadata: Metadata = {
  title: "Viberstudant",
  description: "Perfil social e cultural do estudante no Vibe Studying.",
  robots: {
    index: false,
    follow: false,
  },
};

export default function ViberstudantPage() {
  return <StudentProfileView />;
}
