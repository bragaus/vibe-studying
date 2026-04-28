const logos = [
  "ANIME.CORE",
  "LYRIC//SYNC",
  "WHISPER.AI",
  "TEMPORAL.IO",
  "DJANGO++",
  "FLUTTER.OS",
  "NEON.FEED",
  "WIRED.EDU",
];

const Marquee = () => {
  return (
    <section
      aria-label="Tecnologias e parceiros"
      className="border-y border-primary/20 py-5 overflow-hidden bg-card/40"
    >
      <div className="marquee font-display text-2xl text-muted-foreground">
        {[...logos, ...logos].map((l, i) => (
          <span key={i} className="flex items-center gap-12 whitespace-nowrap">
            {l}
            <span className="text-primary">✦</span>
          </span>
        ))}
      </div>
    </section>
  );
};

export default Marquee;
