import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";

const faqs = [
  {
    q: "O Vibe Studying é gratuito?",
    a: "O acesso ao beta é 100% gratuito. Após o lançamento oficial, teremos um plano free generoso e um Vibe+ com avaliação de IA ilimitada e conteúdo premium.",
  },
  {
    q: "Quais idiomas posso aprender?",
    a: "Hoje o Vibe Studying trabalha a experiência para inglês, japonês, chinês e francês, seguindo a mesma proposta de aprendizado dentro da sua vibe.",
  },
  {
    q: "Tem app mobile?",
    a: "Sim, é no app que você vai entrar na vibe.",
  },
  {
    q: "Vai virar mais um app que esqueço em uma semana?",
    a: "É justamente o que estamos atacando. O design é construído sobre os mesmos gatilhos do TikTok e do Instagram, só que agora o feed viciante ensina.",
  },
];

const FAQ = () => {
  return (
    <section id="faq" className="container max-w-4xl py-20 sm:py-28">
      <div className="mb-12">
        <div className="font-mono-vibe text-xs text-secondary mb-4">// 05_FAQ</div>
        <h2 className="font-display text-3xl sm:text-5xl">
          Perguntas <span className="text-gradient-vibe">frequentes.</span>
        </h2>
      </div>

      <Accordion type="single" collapsible className="space-y-3">
        {faqs.map((f, i) => (
          <AccordionItem
            key={i}
            value={`item-${i}`}
            className="border border-primary/30 bg-card/40 px-4 sm:px-5"
          >
            <AccordionTrigger className="font-display text-left text-base hover:text-primary hover:no-underline sm:text-lg">
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
