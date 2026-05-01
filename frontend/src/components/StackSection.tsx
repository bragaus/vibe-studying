const stack = [
  { layer: "BACKEND", name: "Django + Django Ninja", note: "API tipada e veloz", cls: "text-primary" },
  { layer: "WEB", name: "React + Vite", note: "Landing e auth web atuais", cls: "text-secondary" },
  { layer: "MOBILE", name: "Flutter", note: "Aluno, onboarding e feed", cls: "text-neon-yellow" },
  { layer: "DADOS", name: "PostgreSQL", note: "Fonte principal de dados", cls: "text-neon-purple" },
  { layer: "ROADMAP", name: "Redis + Workers", note: "Assincronia, cache e jobs", cls: "text-primary" },
];

const StackSection = () => {
  return (
    <section id="stack" className="relative overflow-hidden py-20 sm:py-28">
      <div className="absolute inset-0 -z-10 opacity-40" style={{ background: "var(--gradient-glow)" }} />
      <div className="container">
        <div className="mb-12 max-w-3xl sm:mb-16">
          <div className="font-mono-vibe text-xs text-secondary mb-4">// 03_TECH_STACK</div>
          <h2 className="mb-6 font-display text-3xl sm:text-5xl">
            Construído para <span className="text-gradient-vibe">escalar a vibe.</span>
          </h2>
          <p className="text-muted-foreground text-lg">
            Stack real do monorepo atual, com base pronta para evoluir em direcao a offline-first,
            jobs assincronos e distribuicao mais robusta.
          </p>
        </div>

        <div className="space-y-px bg-border/40">
          {stack.map((s, i) => (
            <div
              key={s.name}
              className="bg-background transition-colors hover:bg-card"
            >
              <div className="flex min-w-0 flex-col gap-3 px-4 py-5 sm:px-6 lg:grid lg:grid-cols-12 lg:items-center lg:gap-4 lg:py-6">
                <div className="flex items-center justify-between gap-4 lg:col-span-4 lg:justify-start">
                  <div className="shrink-0 font-mono-vibe text-xs text-muted-foreground">
                    {String(i + 1).padStart(2, "0")}
                  </div>
                  <div className={`min-w-0 text-right font-mono-vibe text-xs sm:text-sm lg:ml-6 lg:text-left ${s.cls}`}>
                    {s.layer}
                  </div>
                </div>
                <div className="min-w-0 break-words font-display text-[clamp(1.75rem,7vw,3rem)] leading-none lg:col-span-5 lg:text-[clamp(1.5rem,2.1vw,2.25rem)]">
                  {s.name}
                </div>
                <div className="max-w-prose text-sm leading-relaxed text-muted-foreground lg:col-span-3 lg:ml-auto lg:max-w-none lg:text-right">
                  {s.note}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};

export default StackSection;
