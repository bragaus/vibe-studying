import { Zap } from "lucide-react";

const Navbar = () => {
  return (
    <header className="fixed top-0 left-0 right-0 z-50 backdrop-blur-md bg-background/60 border-b border-primary/20">
      <nav className="container flex items-center justify-between h-16" aria-label="Navegação principal">
        <a href="#top" className="flex items-center gap-2 group">
          <span className="relative flex h-8 w-8 items-center justify-center rounded-sm bg-primary/10 border border-primary/40 group-hover:glow-pink transition-all">
            <Zap className="h-4 w-4 text-primary animate-pulse-neon" aria-hidden="true" />
          </span>
          <span className="font-display text-sm tracking-widest">
            VIBE<span className="text-primary">_</span>STUDYING
          </span>
        </a>
        <ul className="hidden md:flex items-center gap-8 text-sm font-mono-vibe">
          <li><a href="#feed" className="hover:text-primary transition-colors">// feed</a></li>
          <li><a href="#stack" className="hover:text-secondary transition-colors">// stack</a></li>
          <li><a href="#manifesto" className="hover:text-neon-yellow transition-colors">// manifesto</a></li>
          <li><a href="#faq" className="hover:text-primary transition-colors">// faq</a></li>
        </ul>
        <a
          href="#cta"
          className="font-mono-vibe text-xs px-4 py-2 border border-primary text-primary hover:bg-primary hover:text-primary-foreground transition-all glow-pink"
        >
          [ JOIN BETA ]
        </a>
      </nav>
    </header>
  );
};

export default Navbar;
