const Manifesto = () => {
  return (
    <section id="manifesto" className="border-y border-primary/20 py-20 sm:py-28">
      <div className="container max-w-4xl text-center">
        <div className="font-mono-vibe text-xs text-secondary mb-6">// 04_MANIFESTO</div>
        <blockquote className="mb-8 font-display text-2xl leading-tight sm:text-5xl">
          "Educação tradicional é <span className="line-through text-muted-foreground">chata</span>.
          O feed é <span className="text-primary">viciante</span>. <br />
          Por que não <span className="text-gradient-vibe">combinar os dois?</span>"
        </blockquote>
        <p className="font-mono-vibe text-sm text-muted-foreground">
          <span className="text-primary">$</span> Você entra na hora que quiser e quantas vezes quiser.
        </p>
      </div>
    </section>
  );
};

export default Manifesto;
