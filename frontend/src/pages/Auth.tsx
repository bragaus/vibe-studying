import { useState } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { motion } from "framer-motion";
import { Zap, ArrowRight, Mail, Lock, User as UserIcon } from "lucide-react";
import { toast } from "sonner";

import { getApiBaseUrl, isAuthenticated, persistSession, type AuthResponsePayload } from "@/lib/auth";

const API_BASE_URL = getApiBaseUrl();

function getErrorMessage(payload: unknown, fallback: string) {
  if (!payload || typeof payload !== "object") {
    return fallback;
  }

  const detail = "detail" in payload ? payload.detail : null;

  if (typeof detail === "string") {
    return detail;
  }

  if (Array.isArray(detail) && typeof detail[0] === "object" && detail[0] !== null) {
    const firstMessage = "msg" in detail[0] ? detail[0].msg : null;
    if (typeof firstMessage === "string") {
      return firstMessage;
    }
  }

  return fallback;
}

const Auth = () => {
  const navigate = useNavigate();
  const [isLoginState, setIsLoginState] = useState(true);
  const [isLoading, setIsLoading] = useState(false);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");

  if (isAuthenticated()) {
    return <Navigate to="/" replace />;
  }

  const handleAuthenticationProcess = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    const endpoint = isLoginState ? "/auth/login" : "/auth/register";
    const payload = isLoginState
      ? { email, password }
      : { email, password, first_name: firstName, last_name: lastName };

    try {
      const response = await fetch(`${API_BASE_URL}${endpoint}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      const data = (await response.json()) as AuthResponsePayload | { detail?: unknown };

      if (!response.ok) {
        throw new Error(getErrorMessage(data, "Erro na autenticação do sistema."));
      }

      persistSession(data as AuthResponsePayload);

      toast.success(
        isLoginState ? "Acesso autorizado. Console liberado." : "Cadastro concluído. Sessão iniciada.",
      );
      navigate("/", { replace: true });
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : "Falha de comunicação com o backend.";
      toast.error(`Acesso negado: ${message}`);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <main className="min-h-screen flex items-center justify-center relative overflow-hidden scanlines bg-background">
      <div className="absolute inset-0 z-0">
        <div className="absolute top-0 left-0 w-full h-full bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-primary/10 via-background to-background" />
      </div>

      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.5 }}
        className="relative z-10 w-full max-w-md p-8 rounded-xl border border-primary/40 bg-card/60 backdrop-blur-md shadow-[0_0_30px_rgba(var(--primary),0.1)]"
      >
        <div className="flex justify-center mb-8">
          <Link to="/" className="flex items-center gap-2 group">
            <span className="relative flex h-10 w-10 items-center justify-center rounded-sm bg-primary/10 border border-primary/40 group-hover:glow-pink transition-all">
              <Zap className="h-5 w-5 text-primary animate-pulse-neon" aria-hidden="true" />
            </span>
          </Link>
        </div>

        <div className="text-center mb-8">
          <h1 className="font-display text-3xl mb-2 glitch" data-text={isLoginState ? "SYSTEM_LOGIN" : "INITIALIZE_USER"}>
            {isLoginState ? "SYSTEM_LOGIN" : "INITIALIZE_USER"}
          </h1>
          <p className="font-mono-vibe text-xs text-muted-foreground">
            {isLoginState
              ? "Insira suas credenciais para acessar o hub principal."
              : "Crie seu perfil e desbloqueie a central Android."}
          </p>
        </div>

        <form onSubmit={handleAuthenticationProcess} className="space-y-4 font-mono-vibe">
          {!isLoginState && (
            <div className="grid grid-cols-2 gap-4">
              <div className="relative">
                <UserIcon className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                <input
                  type="text"
                  placeholder="Nome"
                  value={firstName}
                  onChange={(e) => setFirstName(e.target.value)}
                  className="w-full bg-background/50 border border-primary/20 p-3 pl-10 text-xs text-foreground focus:border-primary focus:shadow-[0_0_10px_rgba(var(--primary),0.3)] transition-all outline-none"
                  required
                />
              </div>
              <div className="relative">
                <UserIcon className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                <input
                  type="text"
                  placeholder="Sobrenome"
                  value={lastName}
                  onChange={(e) => setLastName(e.target.value)}
                  className="w-full bg-background/50 border border-primary/20 p-3 pl-10 text-xs text-foreground focus:border-primary focus:shadow-[0_0_10px_rgba(var(--primary),0.3)] transition-all outline-none"
                  required
                />
              </div>
            </div>
          )}

          <div className="relative">
            <Mail className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
            <input
              type="email"
              placeholder="user@protocol.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full bg-background/50 border border-primary/20 p-3 pl-10 text-xs text-foreground focus:border-primary focus:shadow-[0_0_10px_rgba(var(--primary),0.3)] transition-all outline-none"
              required
            />
          </div>

          <div className="relative">
            <Lock className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
            <input
              type="password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full bg-background/50 border border-primary/20 p-3 pl-10 text-xs text-foreground focus:border-primary focus:shadow-[0_0_10px_rgba(var(--primary),0.3)] transition-all outline-none"
              required
            />
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full flex items-center justify-center gap-2 bg-primary text-primary-foreground p-3 text-xs uppercase tracking-widest glow-pink hover:scale-[1.02] transition-transform disabled:opacity-50"
          >
            {isLoading ? "PROCESSANDO..." : (isLoginState ? "AUTENTICAR" : "CADASTRAR")}
            {!isLoading && <ArrowRight className="h-4 w-4" />}
          </button>
        </form>

        <div className="mt-6 text-center font-mono-vibe text-[10px]">
          <button
            type="button"
            onClick={() => setIsLoginState(!isLoginState)}
            className="text-secondary hover:text-primary transition-colors"
          >
            {isLoginState
              ? "> Não possui acesso? Inicialize seu cadastro"
              : "> Já possui registro? Iniciar sessão"}
          </button>
        </div>
      </motion.div>
    </main>
  );
};

export default Auth;
