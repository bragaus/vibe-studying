import { Zap } from "lucide-react";

const Footer = () => {
  return (
    <footer className="border-t border-primary/20 bg-card/30">
      <div className="container py-12 grid sm:grid-cols-3 gap-8">
        <div>
          <div className="flex items-center gap-2 mb-3">
            <Zap className="h-4 w-4 text-primary" />
            <span className="font-display text-sm tracking-widest">VIBE_STUDYING</span>
          </div>
          <p className="text-xs text-muted-foreground font-mono-vibe">
            Estude na vibe. © {new Date().getFullYear()}
          </p>
        </div>
        <div className="font-mono-vibe text-xs space-y-2">
          <div className="text-secondary mb-2">// PRODUTO</div>
          <a href="#feed" className="block text-muted-foreground hover:text-primary">Feed</a>
          <a href="#stack" className="block text-muted-foreground hover:text-primary">Stack</a>
          <a href="#faq" className="block text-muted-foreground hover:text-primary">FAQ</a>
        </div>
        <div className="font-mono-vibe text-xs space-y-2">
          <div className="text-secondary mb-2">// SOCIAL</div>
          <a href="#" className="block text-muted-foreground hover:text-primary">GitHub</a>
          <a href="#" className="block text-muted-foreground hover:text-primary">Twitter / X</a>
          <a href="#" className="block text-muted-foreground hover:text-primary">Discord</a>
        </div>
      </div>
      <div className="border-t border-primary/10 py-4 text-center font-mono-vibe text-[10px] text-muted-foreground">
        SYS::EOF — built with neon and caffeine
      </div>
    </footer>
  );
};

export default Footer;
