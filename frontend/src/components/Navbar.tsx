import { Link } from "react-router-dom";
import { Zap } from "lucide-react";

const Navbar = () => {
  return (
    <header className="fixed top-0 left-0 right-0 z-50 backdrop-blur-md bg-background/60 border-b border-primary/20">
      <nav
        className="container relative flex min-h-16 flex-wrap items-center justify-between gap-x-4 gap-y-3 py-3 md:h-16 md:flex-nowrap md:py-0"
        aria-label="Navegação principal"
      >
        <a href="#top" className="flex min-w-0 items-center gap-2 group">
          <span className="relative flex h-8 w-8 items-center justify-center rounded-sm bg-primary/10 border border-primary/40 group-hover:glow-pink transition-all">
            <Zap className="h-4 w-4 text-primary animate-pulse-neon" aria-hidden="true" />
          </span>
          <span className="font-display text-xs tracking-[0.18em] sm:text-sm">
            VIBE<span className="text-primary">_</span>STUDYING
          </span>
        </a>
        <Link
          to="/auth"
          className="shrink-0 self-center border border-primary px-3 py-2 font-mono-vibe text-[11px] text-primary transition-all hover:bg-primary hover:text-primary-foreground glow-pink sm:px-4 sm:text-xs"
        >
          LOGIN
        </Link>
        <ul className="flex w-full items-center justify-center gap-3 overflow-x-auto pb-1 font-mono-vibe text-[11px] md:absolute md:left-1/2 md:top-1/2 md:w-auto md:-translate-x-1/2 md:-translate-y-1/2 md:gap-8 md:overflow-visible md:pb-0 md:text-sm">
          <li className="shrink-0"><a href="#feed" className="hover:text-primary transition-colors">// feed</a></li>
          <li className="shrink-0"><a href="#manifesto" className="hover:text-neon-yellow transition-colors">// manifesto</a></li>
          <li className="shrink-0"><a href="#faq" className="hover:text-primary transition-colors">// faq</a></li>
        </ul>
      </nav>
    </header>
  );
};

export default Navbar;
