export type SessionUser = {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  role: string;
};

export type AuthResponsePayload = {
  access_token: string;
  refresh_token: string;
  token_type: string;
  user: SessionUser;
};

export type StoredSession = {
  accessToken: string;
  refreshToken: string;
  user: SessionUser | null;
};

const ACCESS_TOKEN_KEY = "vibe.access_token";
const REFRESH_TOKEN_KEY = "vibe.refresh_token";
const USER_KEY = "vibe.user";
let refreshPromise: Promise<AuthResponsePayload | null> | null = null;

export class UnauthorizedSessionError extends Error {
  constructor(message = "Sua sessão expirou. Faça login novamente.") {
    super(message);
    this.name = "UnauthorizedSessionError";
  }
}

function hasLocalStorage() {
  return typeof window !== "undefined" && typeof window.localStorage !== "undefined";
}

function readStoredUser(rawUser: string | null): SessionUser | null {
  if (!rawUser) {
    return null;
  }

  try {
    return JSON.parse(rawUser) as SessionUser;
  } catch {
    return null;
  }
}

export function getApiBaseUrl() {
  const apiBaseUrl = process.env.NEXT_PUBLIC_API_URL?.trim();

  if (!apiBaseUrl) {
    throw new Error("NEXT_PUBLIC_API_URL is not configured.");
  }

  return apiBaseUrl.replace(/\/$/, "");
}

export function persistSession(payload: AuthResponsePayload) {
  if (!hasLocalStorage()) {
    return;
  }

  window.localStorage.setItem(ACCESS_TOKEN_KEY, payload.access_token);
  window.localStorage.setItem(REFRESH_TOKEN_KEY, payload.refresh_token);
  window.localStorage.setItem(USER_KEY, JSON.stringify(payload.user));
}

export function persistStoredUser(user: SessionUser) {
  if (!hasLocalStorage()) {
    return;
  }

  window.localStorage.setItem(USER_KEY, JSON.stringify(user));
}

export function clearSession() {
  if (!hasLocalStorage()) {
    return;
  }

  window.localStorage.removeItem(ACCESS_TOKEN_KEY);
  window.localStorage.removeItem(REFRESH_TOKEN_KEY);
  window.localStorage.removeItem(USER_KEY);
}

export function getStoredSession(): StoredSession | null {
  if (!hasLocalStorage()) {
    return null;
  }

  const accessToken = window.localStorage.getItem(ACCESS_TOKEN_KEY);
  if (!accessToken) {
    return null;
  }

  return {
    accessToken,
    refreshToken: window.localStorage.getItem(REFRESH_TOKEN_KEY) || "",
    user: readStoredUser(window.localStorage.getItem(USER_KEY)),
  };
}

export function getStoredUser() {
  return getStoredSession()?.user || null;
}

export function isAuthenticated() {
  return Boolean(getStoredSession()?.accessToken);
}

export function getUserDisplayName(user: SessionUser | null) {
  if (!user) {
    return "OPERADOR";
  }

  const fullName = `${user.first_name} ${user.last_name}`.trim();
  return fullName || user.email;
}

async function performRefreshRequest() {
  const session = getStoredSession();
  if (!session?.refreshToken) {
    clearSession();
    return null;
  }

  const response = await fetch(`${getApiBaseUrl()}/auth/refresh`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ refresh_token: session.refreshToken }),
    cache: "no-store",
  });

  if (!response.ok) {
    clearSession();
    return null;
  }

  const payload = (await response.json()) as AuthResponsePayload;
  persistSession(payload);
  return payload;
}

export async function refreshStoredSession() {
  if (!refreshPromise) {
    refreshPromise = performRefreshRequest().finally(() => {
      refreshPromise = null;
    });
  }

  return refreshPromise;
}

export async function fetchWithAuth(path: string, init: RequestInit = {}, allowRefresh = true): Promise<Response> {
  const session = getStoredSession();
  if (!session?.accessToken) {
    throw new UnauthorizedSessionError();
  }

  const headers = new Headers(init.headers);
  headers.set("Authorization", `Bearer ${session.accessToken}`);

  const response = await fetch(`${getApiBaseUrl()}${path}`, {
    ...init,
    headers,
    cache: "no-store",
  });

  if (response.status !== 401) {
    return response;
  }

  if (allowRefresh && session.refreshToken) {
    const refreshedSession = await refreshStoredSession();
    if (refreshedSession) {
      return fetchWithAuth(path, init, false);
    }
  }

  clearSession();
  throw new UnauthorizedSessionError();
}

export async function ensureAuthenticatedSession() {
  if (!getStoredSession()?.accessToken) {
    return false;
  }

  const response = await fetchWithAuth("/auth/me");
  if (!response.ok) {
    return false;
  }

  const user = (await response.json()) as SessionUser;
  persistStoredUser(user);
  return true;
}
