const stack = [
  { layer: "BACKEND", name: "Django + Django Ninja", note: "API tipada e veloz", cls: "text-primary" },
  { layer: "WEB / SaaS", name: "Next.js (React)", note: "SSR, SEO e performance", cls: "text-secondary" },
  { layer: "MOBILE", name: "Flutter", note: "Offline-first, UI fluida", cls: "text-neon-yellow" },
  { layer: "WORKFLOWS", name: "Temporal.io", note: "Processamento assíncrono", cls: "text-neon-purple" },
  { layer: "IA / VOZ", name: "OpenAI Whisper", note: "Pronúncia em tempo real", cls: "text-primary" },
];

const StackSection = () => {
  return (
    <section id="stack" className="py-28 relative overflow-hidden">
      <div className="absolute inset-0 -z-10 opacity-40" style={{ background: "var(--gradient-glow)" }} />
      <div className="container">
        <div className="max-w-3xl mb-16">
          <div className="font-mono-vibe text-xs text-secondary mb-4">// 03_TECH_STACK</div>
          <h2 className="font-display text-4xl sm:text-5xl mb-6">
            Construído para <span className="text-gradient-vibe">escalar a vibe.</span>
          </h2>
          <p className="text-muted-foreground text-lg">
            Stack moderna, tipada e assíncrona. Da API de baixa latência ao app mobile offline-first —
            cada camada otimizada para entregar microlearning sem fricção.
          </p>
        </div>

        <div className="space-y-px bg-border/40">
          {stack.map((s, i) => (
            <div
              key={s.name}
              className="bg-background hover:bg-card transition-colors grid grid-cols-12 items-center gap-4 px-6 py-6 group"
            >
              <div className="col-span-1 font-mono-vibe text-xs text-muted-foreground">
                {String(i + 1).padStart(2, "0")}
              </div>
              <div className={`col-span-3 font-mono-vibe text-xs ${s.cls}`}>{s.layer}</div>
              <div className="col-span-5 font-display text-xl">{s.name}</div>
              <div className="col-span-3 text-sm text-muted-foreground text-right">{s.note}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};

export default StackSection;
