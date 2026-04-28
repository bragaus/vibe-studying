import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";

const faqs = [
  {
    q: "O Vibe Studying é gratuito?",
    a: "O acesso ao beta é 100% gratuito. Após o lançamento oficial, teremos um plano free generoso e um Vibe+ com avaliação de IA ilimitada e conteúdo premium.",
  },
  {
    q: "Quais idiomas posso aprender?",
    a: "No beta, focamos em inglês via cultura pop japonesa e americana. Espanhol e japonês entram em breve no roadmap.",
  },
  {
    q: "Como funciona a avaliação de pronúncia?",
    a: "Usamos OpenAI Whisper rodando em pipelines assíncronos no Temporal.io. Você fala a frase do anime/música e em segundos recebe um score fonético detalhado.",
  },
  {
    q: "Tem app mobile?",
    a: "Sim — o app Flutter é offline-first. Baixe seu feed pela manhã e estude sem internet o dia inteiro.",
  },
  {
    q: "Vai virar mais um app que esqueço em uma semana?",
    a: "É justamente o que estamos atacando. O design é construído sobre os mesmos gatilhos do TikTok/Instagram — só que o que vicia, ensina.",
  },
];

const FAQ = () => {
  return (
    <section id="faq" className="container py-28 max-w-4xl">
      <div className="mb-12">
        <div className="font-mono-vibe text-xs text-secondary mb-4">// 05_FAQ</div>
        <h2 className="font-display text-4xl sm:text-5xl">
          Perguntas <span className="text-gradient-vibe">frequentes.</span>
        </h2>
      </div>

      <Accordion type="single" collapsible className="space-y-3">
        {faqs.map((f, i) => (
          <AccordionItem
            key={i}
            value={`item-${i}`}
            className="border border-primary/30 bg-card/40 px-5"
          >
            <AccordionTrigger className="font-display text-left text-lg hover:text-primary hover:no-underline">
              {f.q}
            </AccordionTrigger>
            <AccordionContent className="text-muted-foreground text-base leading-relaxed">
              {f.a}
            </AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </section>
  );
};

export default FAQ;
