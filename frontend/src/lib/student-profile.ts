import { fetchWithAuth, type SessionUser } from "@/lib/auth";

export type EnglishLevel = "beginner" | "intermediate" | "advanced";

export type StudentProfile = {
  onboarding_completed: boolean;
  english_level: EnglishLevel;
  bio: string;
  avatar_url: string;
  posts_count: number;
  energy_received_count: number;
  comments_received_count: number;
  favorite_songs: string[];
  favorite_movies: string[];
  favorite_series: string[];
  favorite_anime: string[];
  favorite_artists: string[];
  favorite_genres: string[];
};

export type StudentProfileResponse = {
  user: SessionUser;
  profile: StudentProfile;
};

export type StudentIdentity = {
  id: number;
  display_name: string;
  role: string;
  avatar_url: string;
  bio: string;
};

export type StudentPostComment = {
  id: number;
  content: string;
  created_at: string;
  updated_at: string;
  is_owner: boolean;
  author: StudentIdentity;
};

export type StudentPost = {
  id: number;
  content: string;
  created_at: string;
  updated_at: string;
  is_owner: boolean;
  energy_count: number;
  comment_count: number;
  energized_by_me: boolean;
  author: StudentIdentity;
  comments: StudentPostComment[];
};

export type ProfileUpdatePayload = {
  english_level: EnglishLevel;
  bio: string;
  favorite_songs: string[];
  favorite_movies: string[];
  favorite_series: string[];
  favorite_anime: string[];
  favorite_artists: string[];
  favorite_genres: string[];
};

function extractErrorMessage(payload: unknown, fallback: string) {
  if (!payload || typeof payload !== "object") {
    return fallback;
  }

  const detail = "detail" in payload ? payload.detail : null;
  if (typeof detail === "string") {
    return detail;
  }

  return fallback;
}

async function authorizedRequest<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);

  if (init.body && !(init.body instanceof FormData) && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  const response = await fetchWithAuth(path, {
    ...init,
    headers,
  });

  const contentType = response.headers.get("content-type") || "";
  const payload = contentType.includes("application/json") ? ((await response.json()) as unknown) : null;

  if (!response.ok) {
    throw new Error(extractErrorMessage(payload, "Falha de comunicação com o backend."));
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return payload as T;
}

export function normalizeTag(value: string) {
  return value.trim();
}

export async function getMyProfile() {
  return authorizedRequest<StudentProfileResponse>("/profile/me");
}

export async function updateMyProfile(payload: ProfileUpdatePayload) {
  return authorizedRequest<StudentProfileResponse>("/profile/me", {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export async function uploadMyAvatar(file: File) {
  const formData = new FormData();
  formData.append("avatar", file);

  return authorizedRequest<StudentProfileResponse>("/profile/me/avatar", {
    method: "POST",
    body: formData,
  });
}

export async function deleteMyAvatar() {
  return authorizedRequest<StudentProfileResponse>("/profile/me/avatar", {
    method: "DELETE",
  });
}

export async function getStudentPosts() {
  return authorizedRequest<StudentPost[]>("/profile/posts");
}

export async function createStudentPost(content: string) {
  return authorizedRequest<StudentPost>("/profile/posts", {
    method: "POST",
    body: JSON.stringify({ content }),
  });
}

export async function updateStudentPost(postId: number, content: string) {
  return authorizedRequest<StudentPost>(`/profile/posts/${postId}`, {
    method: "PATCH",
    body: JSON.stringify({ content }),
  });
}

export async function deleteStudentPost(postId: number) {
  return authorizedRequest<void>(`/profile/posts/${postId}`, {
    method: "DELETE",
  });
}

export async function energizeStudentPost(postId: number) {
  return authorizedRequest<StudentPost>(`/profile/posts/${postId}/energy`, {
    method: "POST",
  });
}

export async function removeEnergyFromStudentPost(postId: number) {
  return authorizedRequest<StudentPost>(`/profile/posts/${postId}/energy`, {
    method: "DELETE",
  });
}

export async function createStudentPostComment(postId: number, content: string) {
  return authorizedRequest<StudentPost>(`/profile/posts/${postId}/comments`, {
    method: "POST",
    body: JSON.stringify({ content }),
  });
}
