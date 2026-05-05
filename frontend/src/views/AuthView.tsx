"use client";

import { type FormEvent, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { AnimatePresence, motion } from "framer-motion";
import {
  ArrowRight,
  Chrome,
  Eye,
  EyeOff,
  Lock,
  Mail,
  User as UserIcon,
  Zap,
} from "lucide-react";
import { toast } from "sonner";

import TurnstileWidget, { type TurnstileWidgetHandle } from "@/components/TurnstileWidget";
import {
  ensureAuthenticatedSession,
  getApiBaseUrl,
  isAuthenticated,
  persistSession,
  type AuthResponsePayload,
  type AuthorizationUrlPayload,
} from "@/lib/auth";

type AuthViewProps = {
  turnstileSiteKey: string;
};


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


function getSocialErrorMessage(code: string | null) {
  if (code === "social_cancelled") {
    return "Login com Google cancelado antes da confirmacao.";
  }

  if (code === "social_failed") {
    return "Nao foi possivel concluir o login com Google. Tente novamente.";
  }

  return "Falha ao concluir autenticacao social.";
}


const AuthView = ({ turnstileSiteKey }: AuthViewProps) => {
  const router = useRouter();
  const searchParams = useSearchParams();
  const turnstileRef = useRef<TurnstileWidgetHandle>(null);
  const handledRedirectRef = useRef<string | null>(null);

  const [isLoginState, setIsLoginState] = useState(true);
  const [isSubmittingCredentials, setIsSubmittingCredentials] = useState(false);
  const [activeSocialProvider, setActiveSocialProvider] = useState<"google" | null>(null);
  const [isPasswordVisible, setIsPasswordVisible] = useState(false);
  const [isCheckingSession, setIsCheckingSession] = useState(true);
  const [isResolvingWebSession, setIsResolvingWebSession] = useState(false);
  const [credentialError, setCredentialError] = useState("");
  const [turnstileToken, setTurnstileToken] = useState<string | null>(null);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");

  const normalizedTurnstileSiteKey = turnstileSiteKey.trim();
  const isTurnstileConfigured = Boolean(normalizedTurnstileSiteKey);

  const clearCredentialError = () => setCredentialError("");

  const resetTurnstile = () => {
    setTurnstileToken(null);
    turnstileRef.current?.reset();
  };

  const requireTurnstileToken = () => {
    if (!isTurnstileConfigured) {
      throw new Error("NEXT_PUBLIC_TURNSTILE_SITE_KEY is not configured.");
    }

    if (!turnstileToken) {
      throw new Error("Confirme no Turnstile que voce nao e um robo.");
    }

    return turnstileToken;
  };

  useEffect(() => {
    let isMounted = true;

    const verifySession = async () => {
      if (!isAuthenticated()) {
        if (isMounted) {
          setIsCheckingSession(false);
        }
        return;
      }

      try {
        const hasActiveSession = await ensureAuthenticatedSession();
        if (!isMounted) {
          return;
        }

        if (hasActiveSession) {
          router.replace("/viberstudant");
          return;
        }
      } catch {
        // Invalid local session should only bring the user back to login.
      }

      if (isMounted) {
        setIsCheckingSession(false);
      }
    };

    void verifySession();

    return () => {
      isMounted = false;
    };
  }, [router]);

  useEffect(() => {
    if (isCheckingSession) {
      return;
    }

    const pendingSession = searchParams?.get("session") ?? null;
    const authError = searchParams?.get("auth_error") ?? null;

    if (!pendingSession && !authError) {
      return;
    }

    const redirectSignature = `${pendingSession ?? ""}:${authError ?? ""}`;
    if (handledRedirectRef.current === redirectSignature) {
      return;
    }
    handledRedirectRef.current = redirectSignature;

    router.replace("/auth");

    if (authError) {
      toast.error(getSocialErrorMessage(authError));
    }

    if (pendingSession) {
      void (async () => {
        setIsResolvingWebSession(true);

        try {
          const apiBaseUrl = getApiBaseUrl();
          const response = await fetch(
            `${apiBaseUrl}/auth/web/session?${new URLSearchParams({ session_token: pendingSession }).toString()}`,
            { cache: "no-store" },
          );
          const data = (await response.json()) as AuthResponsePayload | { detail?: unknown };

          if (!response.ok) {
            throw new Error(getErrorMessage(data, "Sua sessao temporaria de autenticacao expirou."));
          }

          persistSession(data as AuthResponsePayload);
          toast.success("Login com Google concluido.");
          router.replace("/viberstudant");
        } catch (error: unknown) {
          const message = error instanceof Error ? error.message : "Falha ao concluir o login com Google.";
          toast.error(message);
        } finally {
          setIsResolvingWebSession(false);
        }
      })();
    }
  }, [isCheckingSession, router, searchParams]);

  if (isCheckingSession) {
    return null;
  }

  const handleAuthenticationProcess = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    clearCredentialError();
    setIsSubmittingCredentials(true);

    try {
      const verifiedTurnstileToken = requireTurnstileToken();
      const endpoint = isLoginState ? "/auth/web/login" : "/auth/web/register";
      const payload = isLoginState
        ? { email, password, turnstile_token: verifiedTurnstileToken }
        : { email, password, first_name: firstName, last_name: lastName, turnstile_token: verifiedTurnstileToken };

      const apiBaseUrl = getApiBaseUrl();
      const response = await fetch(`${apiBaseUrl}${endpoint}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      const data = (await response.json()) as AuthResponsePayload | { detail?: unknown };

      if (!response.ok) {
        if (isLoginState && response.status === 401) {
          setCredentialError("USUARIO OU SENHA INCORRETOS");
          return;
        }

        throw new Error(getErrorMessage(data, "Erro na autenticacao do sistema."));
      }

      persistSession(data as AuthResponsePayload);
      toast.success(isLoginState ? "Acesso autorizado." : "Cadastro concluido com sucesso.");
      router.replace("/viberstudant");
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : "Falha de comunicacao com o backend.";
      toast.error(`Acesso negado: ${message}`);
    } finally {
      resetTurnstile();
      setIsSubmittingCredentials(false);
    }
  };

  const handleSocialLoginStart = async () => {
    clearCredentialError();
    setActiveSocialProvider("google");

    try {
      const verifiedTurnstileToken = requireTurnstileToken();
      const apiBaseUrl = getApiBaseUrl();
      const response = await fetch(`${apiBaseUrl}/auth/social/google/start`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ turnstile_token: verifiedTurnstileToken }),
      });
      const data = (await response.json()) as AuthorizationUrlPayload | { detail?: unknown };

      if (!response.ok) {
        throw new Error(getErrorMessage(data, "Nao foi possivel iniciar login com Google."));
      }

      window.location.assign((data as AuthorizationUrlPayload).authorization_url);
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : "Falha ao iniciar autenticacao social.";
      toast.error(message);
      setActiveSocialProvider(null);
    } finally {
      resetTurnstile();
    }
  };

  const isCredentialActionBusy = isSubmittingCredentials || Boolean(activeSocialProvider) || isResolvingWebSession;

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
          <Link href="/" className="flex items-center gap-2 group">
            <span className="relative flex h-10 w-10 items-center justify-center rounded-sm bg-primary/10 border border-primary/40 group-hover:glow-pink transition-all">
              <Zap className="h-5 w-5 text-primary animate-pulse-neon" aria-hidden="true" />
            </span>
          </Link>
        </div>

        <div className="text-center mb-8">
          <h1
            className="font-display text-3xl mb-2 glitch"
            data-text={isLoginState ? "SYSTEM_LOGIN" : "INITIALIZE_USER"}
          >
            {isLoginState ? "SYSTEM_LOGIN" : "INITIALIZE_USER"}
          </h1>
          <p className="font-mono-vibe text-xs text-muted-foreground">
            {isLoginState
              ? "Entre com seu e-mail e senha ou continue com Google."
              : "Crie seu perfil com e-mail e senha ou use Google para entrar."}
          </p>
        </div>

        <div className="space-y-3 font-mono-vibe">
          <button
            type="button"
            onClick={() => void handleSocialLoginStart()}
            disabled={isCredentialActionBusy || !turnstileToken}
            className="w-full flex items-center justify-center gap-2 border border-primary/30 bg-background/50 p-3 text-xs uppercase tracking-widest text-foreground transition-colors hover:border-primary disabled:opacity-50"
          >
            <Chrome className="h-4 w-4" />
            {activeSocialProvider === "google" ? "CONECTANDO GOOGLE..." : "ENTRAR COM GOOGLE"}
          </button>
        </div>

        <div className="my-4 flex items-center gap-3 font-mono-vibe text-[10px] uppercase tracking-[0.3em] text-muted-foreground">
          <div className="h-px flex-1 bg-primary/20" />
          <span>ou continue por e-mail</span>
          <div className="h-px flex-1 bg-primary/20" />
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
                  onChange={(e) => {
                    clearCredentialError();
                    setFirstName(e.target.value);
                  }}
                  autoComplete="given-name"
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
                  onChange={(e) => {
                    clearCredentialError();
                    setLastName(e.target.value);
                  }}
                  autoComplete="family-name"
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
              onChange={(e) => {
                clearCredentialError();
                setEmail(e.target.value);
              }}
              autoComplete="email"
              className="w-full bg-background/50 border border-primary/20 p-3 pl-10 text-xs text-foreground focus:border-primary focus:shadow-[0_0_10px_rgba(var(--primary),0.3)] transition-all outline-none"
              required
            />
          </div>

          <div className="relative">
            <Lock className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
            <input
              type={isPasswordVisible ? "text" : "password"}
              placeholder="••••••••"
              value={password}
              onChange={(e) => {
                clearCredentialError();
                setPassword(e.target.value);
              }}
              autoComplete={isLoginState ? "current-password" : "new-password"}
              className="w-full bg-background/50 border border-primary/20 p-3 pl-10 pr-12 text-xs text-foreground focus:border-primary focus:shadow-[0_0_10px_rgba(var(--primary),0.3)] transition-all outline-none"
              required
            />
            <button
              type="button"
              onClick={() => setIsPasswordVisible((current) => !current)}
              aria-label={isPasswordVisible ? "Ocultar senha" : "Mostrar senha"}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground transition-colors hover:text-primary"
            >
              {isPasswordVisible ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
            </button>
          </div>

          <AnimatePresence>
            {credentialError && (
              <motion.div
                initial={{ opacity: 0, y: -6 }}
                animate={{ opacity: 1, y: 0, x: [0, -4, 4, -2, 2, 0] }}
                exit={{ opacity: 0, y: -6 }}
                transition={{
                  opacity: { duration: 0.18 },
                  y: { duration: 0.18 },
                  x: { duration: 0.45, repeat: Infinity, repeatDelay: 1.2 },
                }}
                className="rounded-md border border-red-500/50 bg-red-500/10 px-3 py-2 text-center"
              >
                <p className="glitch glitch-danger font-display text-sm tracking-[0.18em] text-red-400" data-text={credentialError}>
                  {credentialError}
                </p>
              </motion.div>
            )}
          </AnimatePresence>

          <div className="rounded-lg border border-primary/20 bg-background/40 p-3">
            <TurnstileWidget ref={turnstileRef} siteKey={normalizedTurnstileSiteKey} onTokenChange={setTurnstileToken} />
            {!isTurnstileConfigured && (
              <p className="mt-2 text-center text-[10px] text-red-400">
                Configure <code>NEXT_PUBLIC_TURNSTILE_SITE_KEY</code> para liberar o login web.
              </p>
            )}
          </div>

          <button
            type="submit"
            disabled={isCredentialActionBusy || !turnstileToken}
            className="w-full flex items-center justify-center gap-2 bg-primary text-primary-foreground p-3 text-xs uppercase tracking-widest glow-pink hover:scale-[1.02] transition-transform disabled:opacity-50"
          >
            {isSubmittingCredentials || isResolvingWebSession ? "PROCESSANDO..." : (isLoginState ? "AUTENTICAR" : "CRIAR CONTA")}
            {!isSubmittingCredentials && !isResolvingWebSession && <ArrowRight className="h-4 w-4" />}
          </button>
        </form>

        <div className="mt-6 text-center font-mono-vibe text-[10px]">
          <button
            type="button"
            onClick={() => {
              clearCredentialError();
              setIsLoginState(!isLoginState);
            }}
            className="text-secondary hover:text-primary transition-colors"
          >
            {isLoginState
              ? "> Nao possui acesso? Inicialize seu cadastro"
              : "> Ja possui registro? Iniciar sessao"}
          </button>
        </div>
      </motion.div>
    </main>
  );
};

export default AuthView;
