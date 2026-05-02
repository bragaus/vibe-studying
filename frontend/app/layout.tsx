import type { Metadata, Viewport } from "next";
import { Bungee, JetBrains_Mono, Space_Grotesk } from "next/font/google";

import { Providers } from "./providers";
import "./globals.css";

const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  variable: "--font-space-grotesk",
  display: "swap",
});

const jetBrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-jetbrains-mono",
  display: "swap",
});

const bungee = Bungee({
  subsets: ["latin"],
  weight: "400",
  variable: "--font-bungee",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://vibestudying.app"),
  title: {
    default: "Vibe Studying | Aprenda idiomas com música, anime e filmes",
    template: "%s | Vibe Studying",
  },
  description:
    "Aprenda idiomas com músicas, animes, filmes e desenhos em uma experiência visual feita para engajar mais e ensinar melhor.",
  applicationName: "Vibe Studying",
  keywords: [
    "aprender idiomas",
    "inglês",
    "japonês",
    "anime",
    "música",
    "filmes",
    "vibe studying",
  ],
  authors: [{ name: "Vibe Studying" }],
  manifest: "/site.webmanifest",
  icons: {
    icon: "/favicon.ico",
    shortcut: "/favicon.ico",
    apple: "/favicon.ico",
  },
  openGraph: {
    type: "website",
    locale: "pt_BR",
    url: "https://vibestudying.app/",
    siteName: "Vibe Studying",
    title: "Vibe Studying | Aprenda idiomas com música, anime e filmes",
    description:
      "Aprenda idiomas com músicas, animes, filmes e desenhos em uma experiência visual feita para engajar mais e ensinar melhor.",
  },
  twitter: {
    card: "summary_large_image",
    title: "Vibe Studying | Aprenda idiomas com música, anime e filmes",
    description:
      "Aprenda idiomas com músicas, animes, filmes e desenhos em uma experiência visual feita para engajar mais e ensinar melhor.",
  },
};

export const viewport: Viewport = {
  themeColor: "#16061e",
  colorScheme: "dark",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html
      lang="pt-BR"
      suppressHydrationWarning
      className={`${spaceGrotesk.variable} ${jetBrainsMono.variable} ${bungee.variable}`}
    >
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
