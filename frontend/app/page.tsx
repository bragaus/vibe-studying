import type { Metadata } from "next";

import LandingView from "@/views/LandingView";

const structuredData = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "Vibe Studying",
  applicationCategory: "EducationalApplication",
  operatingSystem: "Web, Android",
  description:
    "Aprenda idiomas com músicas, filmes, animes e desenhos em uma experiência visual pensada para transformar estudo em hábito.",
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "BRL",
  },
};

export const metadata: Metadata = {
  title: "Aprenda idiomas com música, anime e filmes",
  description:
    "Aprenda inglês, japonês e outros idiomas com músicas, filmes, animes e desenhos em uma landing otimizada para descoberta e SEO.",
  alternates: {
    canonical: "/",
  },
};

export default function HomePage() {
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />
      <LandingView />
    </>
  );
}
