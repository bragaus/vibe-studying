import { motion } from "framer-motion";
import { Headphones, Mic, Sparkles, Infinity as InfinityIcon, Film, Brain } from "lucide-react";

const features = [
  {
    icon: InfinityIcon,
    title: "Feed infinito que ensina",
    desc: "Substitui o scroll vazio por pílulas de conhecimento de 30s a 3min. Aprenda enquanto procrastina.",
    cls: "border-primary text-primary",
  },
  {
    icon: Mic,
    title: "Voz avaliada por IA",
    desc: "OpenAI Whisper escuta sua pronúncia em tempo real e te dá feedback nível nativo.",
    cls: "border-secondary text-secondary",
  },
  {
    icon: Film,
    title: "Anime · Música · Filme",
    desc: "Aprenda inglês com Jujutsu Kaisen, Billie Eilish ou Tarantino. Cultura pop como currículo.",
    cls: "border-neon-yellow text-neon-yellow",
  },
  {
    icon: Brain,
    title: "Microlearning ativo",
    desc: "Spaced repetition + gatilhos emocionais. Você não memoriza, você vibra.",
    cls: "border-neon-purple text-neon-purple",
  },
  {
    icon: Headphones,
    title: "Offline-first mobile",
    desc: "App em Flutter com cache inteligente. Estude no metrô, no avião, no banheiro.",
    cls: "border-secondary text-secondary",
  },
  {
    icon: Sparkles,
    title: "Estética wired",
    desc: "Alto contraste, neon e glitch. Um app que parece um boss fight de cyberpunk.",
    cls: "border-primary text-primary",
  },
];

const FeedSection = () => {
  return (
    <section id="feed" className="container py-28">
      <div className="max-w-3xl mb-16">
        <div className="font-mono-vibe text-xs text-secondary mb-4">// 02_THE_FEED</div>
        <h2 className="font-display text-4xl sm:text-5xl mb-6">
          Não é app de estudo. <br />
          É <span className="text-gradient-vibe">vício produtivo.</span>
        </h2>
        <p className="text-muted-foreground text-lg">
          A educação tradicional é entediante. O feed é viciante. O Vibe Studying junta os dois num
          experimento de UX que sequestra sua atenção — e devolve em forma de aprendizado.
        </p>
      </div>

      <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-px bg-primary/20 border border-primary/20">
        {features.map((f, i) => (
          <motion.article
            key={f.title}
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: i * 0.05 }}
            className="bg-background p-8 group hover:bg-card transition-colors relative"
          >
            <div className={`inline-flex h-12 w-12 items-center justify-center border ${f.cls} mb-5 group-hover:scale-110 transition-transform`}>
              <f.icon className="h-5 w-5" />
            </div>
            <h3 className="font-display text-xl mb-3">{f.title}</h3>
            <p className="text-sm text-muted-foreground leading-relaxed">{f.desc}</p>
            <div className="absolute top-4 right-4 font-mono-vibe text-[10px] text-muted-foreground">
              0{i + 1}/06
            </div>
          </motion.article>
        ))}
      </div>
    </section>
  );
};

export default FeedSection;
