import { motion } from "framer-motion";
import { ArrowRight } from "lucide-react";
import heroImage from "@/assets/hero-vibe.jpg";
import { Link } from "react-router-dom";

const Hero = () => {
  return (
    <section
      id="top"
      className="relative flex min-h-screen items-center overflow-hidden pb-16 pt-40 scanlines sm:pb-20 md:pt-24"
    >
      {/* Background image */}
      <div className="absolute inset-0 -z-10">
        <img
          src={heroImage}
          alt="Estudante anime cyberpunk com fones neon estudando com painéis holográficos"
          className="w-full h-full object-cover opacity-40"
          width={1920}
          height={1080}
        />
        <div className="absolute inset-0" style={{ background: "var(--gradient-glow)" }} />
        <div className="absolute inset-0 bg-gradient-to-b from-background/70 via-background/50 to-background" />
      </div>

      <div className="container grid items-center gap-12 lg:grid-cols-12 lg:gap-10">
        <div className="lg:col-span-7">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8 }}
            className="font-mono-vibe text-xs text-secondary mb-6 inline-flex items-center gap-2 border border-secondary/40 px-3 py-1"
          >
            <span className="h-2 w-2 bg-secondary rounded-full animate-pulse" />
            Estudar pode ser legal:
          </motion.div>

          <motion.h1
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.9, delay: 0.1 }}
            className="mb-6 font-display text-[clamp(3rem,12vw,5.5rem)] leading-[0.95]"
          >
            <span className="glitch text-foreground" data-text="ESTUDE">ESTUDE</span>{" "}
            <span className="text-gradient-vibe">NA VIBE.</span>
            <br />
            <span className="font-sans text-[clamp(1.5rem,7vw,2.25rem)] font-normal tracking-normal text-muted-foreground lg:text-4xl">
              <em className="not-italic text-secondary">Aprendizado viciante</em>.
            </span>
          </motion.h1>

          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.9, delay: 0.3 }}
            className="mb-10 max-w-xl text-base text-muted-foreground sm:text-lg"
          >
            Aprenda com <strong className="text-foreground">músicas, filmes, animes e desenhos</strong> do seu interesse.
            O Vibe Studying transforma o estudo em uma experiência leve, visual e feita para prender a sua atenção.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.5 }}
            className="flex flex-col items-stretch gap-4 sm:flex-row sm:items-center"
          >
            <Link
              id="cta"
              to="/auth"
              className="group inline-flex items-center justify-center gap-2 bg-primary px-6 py-4 font-mono-vibe text-sm text-primary-foreground transition-transform hover:scale-[1.02] glow-pink"
            >
              LOGIN
              <ArrowRight className="h-4 w-4 group-hover:translate-x-1 transition-transform" />
            </Link>
            <p className="font-display text-center text-xl text-gradient-vibe sm:text-left sm:text-2xl">
              Aprenda qualquer idioma na vibe.
            </p>
          </motion.div>
        </div>

        {/* Phone mock */}
        <motion.div
          initial={{ opacity: 0, x: 30 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 1, delay: 0.4 }}
          className="lg:col-span-5 hidden lg:flex justify-center"
        >
          <div className="relative w-72 h-[560px] rounded-[2.5rem] border-2 border-primary/60 bg-card p-3 animate-float" style={{ boxShadow: "var(--shadow-card)" }}>
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-32 h-6 bg-background rounded-b-2xl border-x-2 border-b-2 border-primary/60" />
            <div className="w-full h-full rounded-[2rem] overflow-hidden bg-background relative scanlines">
              <div className="p-5 space-y-4 font-mono-vibe text-xs">
                <div className="flex items-center justify-between text-secondary">
                  <span>● FEED_LIVE</span>
                  <span>23:47</span>
                </div>
                <div className="border border-primary/40 p-3 space-y-2">
                  <div className="text-[10px] text-muted-foreground">CENA · JUJUTSU KAISEN</div>
                  <div className="text-foreground text-sm">"Throughout heaven and earth, I alone am the honored one."</div>
                  <div className="flex gap-2 pt-2">
                    <button className="flex-1 bg-primary text-primary-foreground py-2 text-[10px]">REPETIR 🎤</button>
                    <button className="px-3 border border-secondary text-secondary py-2 text-[10px]">▶</button>
                  </div>
                </div>
                <div className="border border-secondary/40 p-3">
                  <div className="text-[10px] text-secondary mb-1">PRONÚNCIA · IA</div>
                  <div className="h-2 bg-muted rounded-full overflow-hidden">
                    <div className="h-full w-[87%]" style={{ background: "var(--gradient-vibe)" }} />
                  </div>
                  <div className="text-right text-[10px] text-neon-yellow mt-1">87% · NICE</div>
                </div>
                <div className="border border-neon-yellow/40 p-3 text-[11px]">
                  <div className="text-neon-yellow text-[10px] mb-1">🎵 LYRIC DROP</div>
                  "I'm just a kid and life is a nightmare..."
                </div>
              </div>
              <div className="absolute bottom-0 left-0 right-0 h-20 bg-gradient-to-t from-background to-transparent pointer-events-none" />
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
};

export default Hero;
