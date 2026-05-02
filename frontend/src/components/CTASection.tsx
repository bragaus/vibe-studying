"use client";

import { type FormEvent, useState } from "react";
import { toast } from "sonner";

import { getApiBaseUrl } from "@/lib/auth";

const CTASection = () => {
  const [email, setEmail] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!email.includes("@")) {
      toast.error("ERR :: email inválido");
      return;
    }

    setIsSubmitting(true);
    try {
      const apiBaseUrl = getApiBaseUrl();
      const response = await fetch(`${apiBaseUrl}/waitlist`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, source: "landing_cta" }),
      });
      const payload = (await response.json()) as { detail?: string; already_registered?: boolean };

      if (!response.ok) {
        throw new Error(payload.detail || "Nao foi possivel entrar na waitlist.");
      }

      toast.success(
        payload.already_registered ? "JA ESTAVA NA WAITLIST" : "BEM-VINDO A VIBE",
        {
          description: payload.already_registered
            ? `${email} ja estava registrado e foi mantido na fila.`
            : `${email} entrou na waitlist com sucesso.`,
        },
      );
      setEmail("");
    } catch (error) {
      const message = error instanceof Error ? error.message : "Falha ao registrar e-mail.";
      toast.error(`ERR :: ${message}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <section className="container py-20 sm:py-28">
      <div
        className="relative overflow-hidden border border-primary/40 p-6 text-center scanlines sm:p-10 lg:p-16"
        style={{ background: "var(--gradient-glow)" }}
      >
        <div className="font-mono-vibe text-xs text-secondary mb-4">// experimente sem pagar nada</div>
        <h2 className="mb-6 font-display text-3xl sm:text-6xl">
          Pronto para <span className="text-gradient-vibe">entrar na vibe?</span>
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
            disabled={isSubmitting}
            className="inline-flex w-full items-center justify-center gap-2 bg-primary px-6 py-4 font-mono-vibe text-sm text-primary-foreground transition-transform hover:scale-[1.02] glow-pink sm:w-auto"
          >
            {isSubmitting ? "ENVIANDO" : "ENTRAR NO BETA ->"}
          </button>
        </form>
      </div>
    </section>
  );
};

export default CTASection;
