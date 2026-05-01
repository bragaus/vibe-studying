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

type StoredSession = {
  accessToken: string;
  refreshToken: string;
  user: SessionUser | null;
};

const ACCESS_TOKEN_KEY = "vibe.access_token";
const REFRESH_TOKEN_KEY = "vibe.refresh_token";
const USER_KEY = "vibe.user";

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
  const apiBaseUrl = import.meta.env.VITE_API_URL?.trim();

  if (!apiBaseUrl) {
    throw new Error("VITE_API_URL is not configured.");
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
