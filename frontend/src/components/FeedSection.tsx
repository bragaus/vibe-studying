import { motion } from "framer-motion";
import { Mic, Infinity as InfinityIcon, Film, Brain } from "lucide-react";

const features = [
  {
    icon: InfinityIcon,
    title: "Feed infinito que ensina",
    desc: "Transforma o seu interesse em um fluxo contínuo de estudo com conteúdo que você realmente quer consumir.",
    cls: "border-primary text-primary",
  },
  {
    icon: Mic,
    title: "Prática guiada",
    desc: "Exercícios gamificados com feedback automatizado para ensinar a pronúncia correta do idioma.",
    cls: "border-secondary text-secondary",
  },
  {
    icon: Film,
    title: "Música · Anime · Desenho · Filme",
    desc: "Aprenda japonês com Naruto, inglês com Billie Eilish ou com o seu personagem favorito.",
    cls: "border-neon-yellow text-neon-yellow",
  },
  {
    icon: Brain,
    title: "Aprendizado ativo",
    desc: "O estudo acontece dentro do que você gosta de assistir, ouvir e repetir, sem depender de uma aula engessada.",
    cls: "border-neon-purple text-neon-purple",
  },
];

const FeedSection = () => {
  return (
    <section id="feed" className="container py-20 sm:py-28">
      <div className="mx-auto mb-12 max-w-5xl text-center sm:mb-16">
        <div className="font-mono-vibe text-xs text-secondary mb-4">// 01_THE_FEED</div>
        <h2 className="mb-6 font-display text-3xl sm:text-5xl">
          Não é app de estudo. <br />
          É <span className="text-gradient-vibe">vício produtivo.</span>
        </h2>
        <p className="mx-auto max-w-4xl text-lg text-muted-foreground">
          A educação tradicional é entediante; o feed é viciante. O{" "}
          <span className="font-display font-bold text-gradient-vibe">VIBE_STUDYING</span> junta o aprendizado com músicas,
          filmes, animes e desenhos do seu interesse e transforma tudo em um feed viciante.
        </p>
      </div>

      <div className="mx-auto grid max-w-5xl gap-px border border-primary/20 bg-primary/20 sm:grid-cols-2">
        {features.map((f, i) => (
          <motion.article
            key={f.title}
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: i * 0.05 }}
            className="relative min-h-[240px] bg-background p-6 transition-colors group hover:bg-card sm:p-8"
          >
            <div className={`inline-flex h-12 w-12 items-center justify-center border ${f.cls} mb-5 group-hover:scale-110 transition-transform`}>
              <f.icon className="h-5 w-5" />
            </div>
            <h3 className="mb-3 font-display text-lg sm:text-xl">{f.title}</h3>
            <p className="text-sm text-muted-foreground leading-relaxed">{f.desc}</p>
            <div className="absolute top-4 right-4 font-mono-vibe text-[10px] text-muted-foreground">
              0{i + 1}/04
            </div>
          </motion.article>
        ))}
      </div>
    </section>
  );
};

export default FeedSection;
