import { useState } from "react";
import { ArrowRight } from "lucide-react";
import { toast } from "sonner";

const CTASection = () => {
  const [email, setEmail] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.includes("@")) {
      toast.error("ERR :: email inválido");
      return;
    }
    toast.success("BEM-VINDO À VIBE", { description: `${email} entrou na waitlist.` });
    setEmail("");
  };

  return (
    <section className="container py-28">
      <div
        className="relative overflow-hidden border border-primary/40 p-10 sm:p-16 text-center scanlines"
        style={{ background: "var(--gradient-glow)" }}
      >
        <div className="font-mono-vibe text-xs text-secondary mb-4">// 06_JOIN_BETA</div>
        <h2 className="font-display text-4xl sm:text-6xl mb-6">
          Pronto pra <span className="text-gradient-vibe">entrar na vibe?</span>
        </h2>
        <p className="text-muted-foreground max-w-xl mx-auto mb-10">
          Vagas limitadas no beta fechado. Garanta a sua antes que vire mainstream.
        </p>

        <form
          onSubmit={handleSubmit}
          className="flex flex-col sm:flex-row gap-3 max-w-lg mx-auto"
        >
          <input
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="seu@email.com"
            aria-label="Seu email"
            className="flex-1 bg-input border border-primary/40 px-4 py-4 font-mono-vibe text-sm focus:outline-none focus:border-primary focus:glow-pink transition-all"
          />
          <button
            type="submit"
            className="inline-flex items-center justify-center gap-2 bg-primary text-primary-foreground font-mono-vibe text-sm px-6 py-4 hover:scale-[1.02] transition-transform glow-pink"
          >
            ENTRAR <ArrowRight className="h-4 w-4" />
          </button>
        </form>
      </div>
    </section>
  );
};

export default CTASection;
