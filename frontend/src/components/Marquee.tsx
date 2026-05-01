const languages = [
  { label: "Inglês", flag: "🇺🇸" },
  { label: "Japonês", flag: "🇯🇵" },
  { label: "Chinês", flag: "🇨🇳" },
  { label: "Francês", flag: "🇫🇷" },
];

const Marquee = () => {
  return (
    <section
      aria-label="Idiomas que o Vibe Studying ensina"
      className="overflow-hidden border-y border-primary/20 bg-card/40 py-4 sm:py-5"
    >
      <div className="marquee font-display text-xl text-muted-foreground sm:text-2xl">
        {[...languages, ...languages].map((language, i) => (
          <span key={i} className="flex items-center gap-12 whitespace-nowrap">
            <span>{language.label}</span>
            <span>{language.flag}</span>
            <span className="text-primary">✦</span>
          </span>
        ))}
      </div>
    </section>
  );
};

export default Marquee;
