const Manifesto = () => {
  return (
    <section id="manifesto" className="py-28 border-y border-primary/20">
      <div className="container max-w-4xl text-center">
        <div className="font-mono-vibe text-xs text-secondary mb-6">// 04_MANIFESTO</div>
        <blockquote className="font-display text-3xl sm:text-5xl leading-tight mb-8">
          "Educação tradicional é <span className="line-through text-muted-foreground">chata</span>.
          O feed é <span className="text-primary">viciante</span>. <br />
          Por que não <span className="text-gradient-vibe">combinar os dois?</span>"
        </blockquote>
        <p className="font-mono-vibe text-sm text-muted-foreground cursor-blink">
          — vibe_studying.manifesto.txt
        </p>
      </div>
    </section>
  );
};

export default Manifesto;
