import { motion } from "framer-motion";
import { Download, LogOut, Rocket, ShieldCheck, Smartphone, Zap } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { toast } from "sonner";

import { clearSession, getStoredUser, getUserDisplayName } from "@/lib/auth";

const ANDROID_APP_URL = import.meta.env.VITE_ANDROID_APP_URL || "";
const FLUTTER_ANDROID_URL = import.meta.env.VITE_FLUTTER_ANDROID_URL || "";

const downloadCards = [
  {
    title: "APP_ANDROID",
    subtitle: "Instalador Android pronto para usuário final.",
    buttonLabel: "BAIXAR_APP_ANDROID",
    tag: "NODE::ANDROID",
    href: ANDROID_APP_URL,
    icon: Smartphone,
    accentClass: "border-primary/40 hover:border-primary hover:glow-pink",
    badgeClass: "text-primary border-primary/40",
  },
  {
    title: "FLUTTER_ANDROID",
    subtitle: "Build Android do client Flutter para distribuição mobile.",
    buttonLabel: "BAIXAR_FLUTTER_ANDROID",
    tag: "NODE::FLUTTER",
    href: FLUTTER_ANDROID_URL,
    icon: Rocket,
    accentClass: "border-secondary/40 hover:border-secondary hover:glow-cyan",
    badgeClass: "text-secondary border-secondary/40",
  },
] as const;

const Portal = () => {
  const navigate = useNavigate();
  const user = getStoredUser();
  const displayName = getUserDisplayName(user);

  const handleLogout = () => {
    clearSession();
    toast.success("Sessão encerrada.");
    navigate("/", { replace: true });
  };

  const handleDownload = (href: string, label: string) => {
    if (!href) {
      toast.error(`${label} ainda não possui link configurado.`);
      return;
    }

    window.open(href, "_blank", "noopener,noreferrer");
  };

  return (
    <main className="relative min-h-screen overflow-hidden scanlines">
      <div className="absolute inset-0 -z-10" style={{ background: "var(--gradient-glow)" }} />
      <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top,_rgba(255,0,170,0.15),_transparent_30%),radial-gradient(circle_at_bottom_right,_rgba(255,149,0,0.12),_transparent_30%)]" />

      <div className="container py-8 sm:py-12">
        <header className="mb-10 flex flex-col gap-6 border border-primary/30 bg-card/55 p-5 backdrop-blur-xl sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div className="mb-3 inline-flex items-center gap-2 border border-secondary/40 px-3 py-1 font-mono-vibe text-[11px] text-secondary">
              <span className="h-2 w-2 rounded-full bg-secondary animate-pulse" />
              SESSION::AUTHORIZED
            </div>
            <div className="flex items-center gap-3">
              <span className="flex h-10 w-10 items-center justify-center rounded-sm border border-primary/40 bg-primary/10 glow-pink">
                <Zap className="h-5 w-5 text-primary animate-pulse-neon" aria-hidden="true" />
              </span>
              <div>
                <p className="font-display text-2xl sm:text-3xl tracking-wider">
                  COMMAND<span className="text-gradient-vibe">_CENTER</span>
                </p>
                <p className="font-mono-vibe text-xs text-muted-foreground">
                  Bem-vindo, <span className="text-foreground">{displayName}</span>.
                </p>
              </div>
            </div>
          </div>

          <button
            type="button"
            onClick={handleLogout}
            className="inline-flex items-center justify-center gap-2 self-start border border-primary/30 px-4 py-3 font-mono-vibe text-xs text-foreground transition-all hover:border-primary hover:bg-primary/10"
          >
            <LogOut className="h-4 w-4" />
            ENCERRAR_SESSAO
          </button>
        </header>

        <section className="grid gap-6 lg:grid-cols-[1.3fr_0.7fr]">
          <motion.div
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.55 }}
            className="border border-primary/30 bg-card/55 p-6 backdrop-blur-xl sm:p-8"
          >
            <div className="mb-4 font-mono-vibe text-xs text-secondary">// DOWNLOAD_PORTAL</div>
            <h1 className="mb-5 max-w-3xl font-display text-4xl leading-none sm:text-5xl">
              Baixe os clients <span className="text-gradient-vibe">Android</span> direto do HUD principal.
            </h1>
            <p className="max-w-2xl text-sm text-muted-foreground sm:text-base">
              O login agora conversa com o backend Django Ninja. Depois da autenticação, esta central libera os atalhos para distribuição do app Android e da build Flutter Android.
            </p>

            <div className="mt-6 flex flex-wrap gap-3 font-mono-vibe text-[11px] uppercase tracking-wide">
              <span className="border border-primary/30 px-3 py-2 text-primary">role::{(user?.role || "student").toUpperCase()}</span>
              <span className="border border-secondary/30 px-3 py-2 text-secondary">auth::jwt_custom</span>
              <span className="border border-accent/40 px-3 py-2 text-accent">target::android</span>
            </div>

            <div className="mt-8 grid gap-4 xl:grid-cols-2">
              {downloadCards.map(({ title, subtitle, buttonLabel, tag, href, icon: Icon, accentClass, badgeClass }, index) => (
                <motion.article
                  key={title}
                  initial={{ opacity: 0, y: 18 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.45, delay: 0.1 + index * 0.1 }}
                  className={`group border bg-background/70 p-5 transition-all ${accentClass}`}
                >
                  <div className="mb-4 flex items-start justify-between gap-4">
                    <div>
                      <div className={`inline-flex border px-2 py-1 font-mono-vibe text-[10px] ${badgeClass}`}>{tag}</div>
                      <h2 className="mt-4 font-display text-2xl tracking-wide">{title}</h2>
                    </div>
                    <span className="flex h-11 w-11 items-center justify-center border border-white/10 bg-card/80">
                      <Icon className="h-5 w-5 text-foreground" aria-hidden="true" />
                    </span>
                  </div>

                  <p className="min-h-14 text-sm text-muted-foreground">{subtitle}</p>

                  <button
                    type="button"
                    onClick={() => handleDownload(href, title)}
                    className="mt-6 inline-flex w-full items-center justify-center gap-2 bg-primary px-4 py-3 font-mono-vibe text-xs text-primary-foreground transition-all hover:scale-[1.01]"
                  >
                    <Download className="h-4 w-4" />
                    {buttonLabel}
                  </button>

                  <p className="mt-3 font-mono-vibe text-[10px] text-muted-foreground">
                    {href ? "LINK::ONLINE" : "LINK::PENDING_CONFIG"}
                  </p>
                </motion.article>
              ))}
            </div>
          </motion.div>

          <motion.aside
            initial={{ opacity: 0, x: 24 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.55, delay: 0.1 }}
            className="space-y-6"
          >
            <section className="border border-secondary/30 bg-card/55 p-6 backdrop-blur-xl">
              <div className="mb-3 inline-flex items-center gap-2 font-mono-vibe text-xs text-secondary">
                <ShieldCheck className="h-4 w-4" />
                ACCESS_STATUS
              </div>
              <div className="space-y-4 font-mono-vibe text-xs text-muted-foreground">
                <div className="border border-white/10 p-3">
                  <div className="text-[10px] text-secondary">IDENTITY</div>
                  <div className="mt-2 break-all text-foreground">{user?.email || "unknown@node"}</div>
                </div>
                <div className="border border-white/10 p-3">
                  <div className="text-[10px] text-primary">PROFILE_ROLE</div>
                  <div className="mt-2 text-foreground">{(user?.role || "student").toUpperCase()}</div>
                </div>
                <div className="border border-white/10 p-3">
                  <div className="text-[10px] text-accent">DOWNLOAD_QUEUE</div>
                  <div className="mt-2 text-foreground">2 pacotes monitorados</div>
                </div>
              </div>
            </section>

            <section className="border border-primary/30 bg-card/55 p-6 backdrop-blur-xl">
              <div className="mb-4 font-mono-vibe text-xs text-primary">// OPS_NOTES</div>
              <ul className="space-y-3 text-sm text-muted-foreground">
                <li>Use os botões abaixo para abrir os links de distribuição em uma nova aba.</li>
                <li>Se um botão acusar `LINK::PENDING_CONFIG`, configure a URL correspondente no `.env` do frontend.</li>
                <li>O visual cyberpunk foi mantido para o fluxo autenticado e para a landing pública.</li>
              </ul>
            </section>
          </motion.aside>
        </section>
      </div>
    </main>
  );
};

export default Portal;
