"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { motion } from "framer-motion";
import {
  AudioLines,
  BrainCircuit,
  Camera,
  Clapperboard,
  Film,
  LoaderCircle,
  LogOut,
  MessageCircle,
  Music2,
  PencilLine,
  Plus,
  Save,
  Sparkles,
  Trash2,
  Tv,
  UserRound,
  WandSparkles,
  X,
  Zap,
} from "lucide-react";
import { useRouter } from "next/navigation";
import Cropper, { type Area } from "react-easy-crop";
import "react-easy-crop/react-easy-crop.css";
import { type ChangeEvent, type ReactNode, useEffect, useMemo, useRef, useState } from "react";
import { toast } from "sonner";

import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Slider } from "@/components/ui/slider";
import { clearSession, getStoredUser, getUserDisplayName, isAuthenticated, type SessionUser } from "@/lib/auth";
import {
  createStudentPost,
  createStudentPostComment,
  deleteMyAvatar,
  deleteStudentPost,
  energizeStudentPost,
  getMyProfile,
  getStudentPosts,
  normalizeTag,
  removeEnergyFromStudentPost,
  type EnglishLevel,
  type ProfileUpdatePayload,
  type StudentPost,
  type StudentProfile,
  updateMyProfile,
  updateStudentPost,
  uploadMyAvatar,
} from "@/lib/student-profile";
import { UnauthorizedSessionError } from "@/lib/auth";

type PreferenceField =
  | "favorite_songs"
  | "favorite_movies"
  | "favorite_series"
  | "favorite_anime"
  | "favorite_artists"
  | "favorite_genres";

type ProfileFormState = ProfileUpdatePayload;
type TagInputState = Record<PreferenceField, string>;

const preferenceConfigs: Array<{
  field: PreferenceField;
  label: string;
  hint: string;
  icon: ReactNode;
}> = [
  {
    field: "favorite_songs",
    label: "Musicas favoritas",
    hint: "Uma musica por vez. Ex.: Numb, Yellow, Blinding Lights",
    icon: <Music2 className="h-4 w-4" />,
  },
  {
    field: "favorite_movies",
    label: "Filmes favoritos",
    hint: "Ex.: Interstellar, Your Name, Spider-Man",
    icon: <Film className="h-4 w-4" />,
  },
  {
    field: "favorite_series",
    label: "Series favoritas",
    hint: "Ex.: Dark, Arcane, Stranger Things",
    icon: <Tv className="h-4 w-4" />,
  },
  {
    field: "favorite_anime",
    label: "Animes favoritos",
    hint: "Ex.: Naruto, Attack on Titan, One Piece",
    icon: <Sparkles className="h-4 w-4" />,
  },
  {
    field: "favorite_artists",
    label: "Artistas e bandas",
    hint: "Ex.: Linkin Park, Taylor Swift, YOASOBI",
    icon: <AudioLines className="h-4 w-4" />,
  },
  {
    field: "favorite_genres",
    label: "Generos favoritos",
    hint: "Ex.: rock, sci-fi, romance, shounen",
    icon: <Clapperboard className="h-4 w-4" />,
  },
];

const emptyTagInputs: TagInputState = {
  favorite_songs: "",
  favorite_movies: "",
  favorite_series: "",
  favorite_anime: "",
  favorite_artists: "",
  favorite_genres: "",
};

const emptyForm: ProfileFormState = {
  english_level: "beginner",
  bio: "",
  favorite_songs: [],
  favorite_movies: [],
  favorite_series: [],
  favorite_anime: [],
  favorite_artists: [],
  favorite_genres: [],
};

function profileToForm(profile: StudentProfile): ProfileFormState {
  return {
    english_level: profile.english_level,
    bio: profile.bio || "",
    favorite_songs: profile.favorite_songs || [],
    favorite_movies: profile.favorite_movies || [],
    favorite_series: profile.favorite_series || [],
    favorite_anime: profile.favorite_anime || [],
    favorite_artists: profile.favorite_artists || [],
    favorite_genres: profile.favorite_genres || [],
  };
}

function formatDateTime(value: string) {
  return new Date(value).toLocaleString("pt-BR", {
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function createImage(source: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const image = new Image();
    image.addEventListener("load", () => resolve(image));
    image.addEventListener("error", () => reject(new Error("Nao foi possivel carregar a imagem selecionada.")));
    image.src = source;
  });
}

async function createCroppedAvatarFile(source: string, croppedAreaPixels: Area, originalFileName: string) {
  const image = await createImage(source);
  const canvas = document.createElement("canvas");
  const context = canvas.getContext("2d");

  if (!context) {
    throw new Error("Nao foi possivel preparar o editor de avatar.");
  }

  const outputSize = 512;
  canvas.width = outputSize;
  canvas.height = outputSize;

  context.imageSmoothingEnabled = true;
  context.imageSmoothingQuality = "high";
  context.drawImage(
    image,
    croppedAreaPixels.x,
    croppedAreaPixels.y,
    croppedAreaPixels.width,
    croppedAreaPixels.height,
    0,
    0,
    outputSize,
    outputSize,
  );

  const baseName = originalFileName.replace(/\.[^.]+$/, "") || "avatar";

  return new Promise<File>((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (!blob) {
          reject(new Error("Nao foi possivel gerar a imagem final do avatar."));
          return;
        }

        resolve(new File([blob], `${baseName}.png`, { type: "image/png" }));
      },
      "image/png",
      0.95,
    );
  });
}

function AvatarShell({
  avatarUrl,
  displayName,
  size = "lg",
}: {
  avatarUrl: string;
  displayName: string;
  size?: "sm" | "lg";
}) {
  const [hasImageError, setHasImageError] = useState(false);
  const sizeClass = size === "sm" ? "h-11 w-11 text-sm" : "h-24 w-24 text-2xl";
  const shellClassName = `${sizeClass} relative z-10 overflow-hidden rounded-2xl border border-primary/40 shadow-[0_0_30px_rgba(255,0,170,0.18)]`;
  const initials = displayName
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("") || "VS";

  useEffect(() => {
    setHasImageError(false);
  }, [avatarUrl]);

  return avatarUrl && !hasImageError ? (
    <div className={shellClassName}>
      <img
        src={avatarUrl}
        alt={`Avatar de ${displayName}`}
        className="block h-full w-full object-cover"
        onError={() => setHasImageError(true)}
      />
    </div>
  ) : (
    <div className={`${shellClassName} flex items-center justify-center bg-primary/10 font-display text-primary`}>
      {initials}
    </div>
  );
}

function StatCard({ label, value, accent }: { label: string; value: string | number; accent: string }) {
  return (
    <div className="min-w-0 border border-white/10 bg-background/60 p-4 backdrop-blur-xl">
      <div className={`font-mono-vibe text-[10px] uppercase tracking-[0.2em] ${accent}`}>{label}</div>
      <div className="mt-3 font-display text-3xl text-foreground">{value}</div>
    </div>
  );
}

function TagEditor({
  icon,
  label,
  hint,
  values,
  inputValue,
  onInputChange,
  onAdd,
  onRemove,
}: {
  icon: ReactNode;
  label: string;
  hint: string;
  values: string[];
  inputValue: string;
  onInputChange: (value: string) => void;
  onAdd: () => void;
  onRemove: (value: string) => void;
}) {
  return (
    <div className="border border-white/10 bg-background/50 p-4">
      <div className="flex items-center gap-2 font-mono-vibe text-xs text-secondary">
        {icon}
        {label}
      </div>
      <p className="mt-2 text-xs text-muted-foreground">{hint}</p>
      <div className="mt-4 flex gap-2 max-[420px]:flex-col">
        <input
          value={inputValue}
          onChange={(event) => onInputChange(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === "Enter") {
              event.preventDefault();
              onAdd();
            }
          }}
          placeholder="Digite e pressione Enter"
          className="w-full border border-primary/20 bg-background/80 px-3 py-3 text-sm outline-none transition-colors focus:border-primary"
        />
        <button
          type="button"
          onClick={onAdd}
          className="inline-flex h-12 w-12 items-center justify-center border border-primary/40 bg-primary/10 text-primary transition-colors hover:bg-primary hover:text-primary-foreground max-[420px]:w-full"
          aria-label={`Adicionar item em ${label}`}
        >
          <Plus className="h-4 w-4" />
        </button>
      </div>
      {values.length > 0 && (
        <div className="mt-4 flex flex-wrap gap-2">
          {values.map((value) => (
            <button
              key={value}
              type="button"
              onClick={() => onRemove(value)}
              className="inline-flex items-center gap-2 border border-primary/30 bg-primary/10 px-3 py-2 font-mono-vibe text-[11px] text-primary transition-colors hover:border-primary hover:bg-primary hover:text-primary-foreground"
            >
              <span>{value}</span>
              <X className="h-3.5 w-3.5" />
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

export default function StudentProfileView() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const [isReady, setIsReady] = useState(false);
  const [storedUser, setStoredUser] = useState<SessionUser | null>(null);
  const [form, setForm] = useState<ProfileFormState>(emptyForm);
  const [tagInputs, setTagInputs] = useState<TagInputState>(emptyTagInputs);
  const [newPostContent, setNewPostContent] = useState("");
  const [editingPostId, setEditingPostId] = useState<number | null>(null);
  const [editingPostContent, setEditingPostContent] = useState("");
  const [commentDrafts, setCommentDrafts] = useState<Record<number, string>>({});
  const [avatarEditorOpen, setAvatarEditorOpen] = useState(false);
  const [avatarEditorImageUrl, setAvatarEditorImageUrl] = useState<string | null>(null);
  const [avatarEditorFileName, setAvatarEditorFileName] = useState("avatar.png");
  const [avatarCrop, setAvatarCrop] = useState({ x: 0, y: 0 });
  const [avatarZoom, setAvatarZoom] = useState(1);
  const [avatarCroppedAreaPixels, setAvatarCroppedAreaPixels] = useState<Area | null>(null);

  useEffect(() => {
    return () => {
      if (avatarEditorImageUrl) {
        URL.revokeObjectURL(avatarEditorImageUrl);
      }
    };
  }, [avatarEditorImageUrl]);

  useEffect(() => {
    if (!isAuthenticated()) {
      router.replace("/auth");
      return;
    }

    setStoredUser(getStoredUser());
    setIsReady(true);
  }, [router]);

  const profileQuery = useQuery({
    queryKey: ["student-profile"],
    queryFn: getMyProfile,
    enabled: isReady,
    retry: false,
  });

  const postsQuery = useQuery({
    queryKey: ["student-social-posts"],
    queryFn: getStudentPosts,
    enabled: isReady,
    retry: false,
  });

  useEffect(() => {
    const profileError = profileQuery.error;
    const postsError = postsQuery.error;
    const hasUnauthorizedError = profileError instanceof UnauthorizedSessionError || postsError instanceof UnauthorizedSessionError;

    if (!hasUnauthorizedError) {
      return;
    }

    toast.error("Sua sessão expirou. Faça login novamente.");
    router.replace("/auth");
  }, [postsQuery.error, profileQuery.error, router]);

  useEffect(() => {
    if (!profileQuery.data) {
      return;
    }

    setForm(profileToForm(profileQuery.data.profile));
  }, [profileQuery.data]);

  const invalidateDashboard = async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ["student-profile"] }),
      queryClient.invalidateQueries({ queryKey: ["student-social-posts"] }),
    ]);
  };

  const updateProfileMutation = useMutation({
    mutationFn: updateMyProfile,
    onSuccess: async () => {
      toast.success("Perfil sincronizado com o backend.");
      await invalidateDashboard();
    },
    onError: (error: Error) => {
      toast.error(error.message);
    },
  });

  const uploadAvatarMutation = useMutation({
    mutationFn: uploadMyAvatar,
    onSuccess: async () => {
      toast.success("Avatar atualizado.");
      await invalidateDashboard();
    },
    onError: (error: Error) => {
      toast.error(error.message);
    },
  });

  const deleteAvatarMutation = useMutation({
    mutationFn: deleteMyAvatar,
    onSuccess: async () => {
      toast.success("Avatar removido.");
      await invalidateDashboard();
    },
    onError: (error: Error) => {
      toast.error(error.message);
    },
  });

  const createPostMutation = useMutation({
    mutationFn: createStudentPost,
    onSuccess: async () => {
      setNewPostContent("");
      toast.success("Post publicado no mural.");
      await invalidateDashboard();
    },
    onError: (error: Error) => {
      toast.error(error.message);
    },
  });

  const updatePostMutation = useMutation({
    mutationFn: ({ postId, content }: { postId: number; content: string }) => updateStudentPost(postId, content),
    onSuccess: async () => {
      setEditingPostId(null);
      setEditingPostContent("");
      toast.success("Post atualizado.");
      await invalidateDashboard();
    },
    onError: (error: Error) => {
      toast.error(error.message);
    },
  });

  const deletePostMutation = useMutation({
    mutationFn: deleteStudentPost,
    onSuccess: async () => {
      toast.success("Post removido.");
      await invalidateDashboard();
    },
    onError: (error: Error) => {
      toast.error(error.message);
    },
  });

  const energyMutation = useMutation({
    mutationFn: ({ postId, energized }: { postId: number; energized: boolean }) =>
      energized ? removeEnergyFromStudentPost(postId) : energizeStudentPost(postId),
    onSuccess: async () => {
      await invalidateDashboard();
    },
    onError: (error: Error) => {
      toast.error(error.message);
    },
  });

  const commentMutation = useMutation({
    mutationFn: ({ postId, content }: { postId: number; content: string }) => createStudentPostComment(postId, content),
    onSuccess: async (_, variables) => {
      setCommentDrafts((current) => ({ ...current, [variables.postId]: "" }));
      toast.success("Comentario enviado.");
      await invalidateDashboard();
    },
    onError: (error: Error) => {
      toast.error(error.message);
    },
  });

  const currentUser = profileQuery.data?.user || storedUser;
  const profile = profileQuery.data?.profile;
  const displayName = getUserDisplayName(currentUser);
  const posts = postsQuery.data || [];

  const totalTasteItems = useMemo(
    () =>
      preferenceConfigs.reduce((sum, config) => {
        return sum + form[config.field].length;
      }, 0),
    [form],
  );

  const completeness = useMemo(() => {
    const checks = [
      Boolean(profile?.avatar_url),
      form.bio.trim().length >= 20,
      form.favorite_songs.length > 0,
      form.favorite_movies.length > 0,
      form.favorite_series.length > 0,
      form.favorite_anime.length > 0,
      form.favorite_artists.length > 0,
      form.favorite_genres.length > 0,
    ];

    return Math.round((checks.filter(Boolean).length / checks.length) * 100);
  }, [form, profile?.avatar_url]);

  const isBusy =
    updateProfileMutation.isPending ||
    uploadAvatarMutation.isPending ||
    deleteAvatarMutation.isPending ||
    createPostMutation.isPending ||
    updatePostMutation.isPending ||
    deletePostMutation.isPending ||
    energyMutation.isPending ||
    commentMutation.isPending;

  const handleLogout = () => {
    clearSession();
    toast.success("Sessão encerrada.");
    router.replace("/");
  };

  const addTag = (field: PreferenceField) => {
    const value = normalizeTag(tagInputs[field]);
    if (!value) {
      return;
    }

    setForm((current) => {
      const alreadyExists = current[field].some((item) => item.toLowerCase() === value.toLowerCase());
      if (alreadyExists) {
        return current;
      }

      return {
        ...current,
        [field]: [...current[field], value],
      };
    });

    setTagInputs((current) => ({
      ...current,
      [field]: "",
    }));
  };

  const removeTag = (field: PreferenceField, value: string) => {
    setForm((current) => ({
      ...current,
      [field]: current[field].filter((item) => item !== value),
    }));
  };

  const handleAvatarSelection = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) {
      return;
    }

    if (!file.type.startsWith("image/")) {
      toast.error("Selecione um arquivo de imagem valido.");
      event.target.value = "";
      return;
    }

    if (avatarEditorImageUrl) {
      URL.revokeObjectURL(avatarEditorImageUrl);
    }

    setAvatarEditorImageUrl(URL.createObjectURL(file));
    setAvatarEditorFileName(file.name || "avatar.png");
    setAvatarCrop({ x: 0, y: 0 });
    setAvatarZoom(1);
    setAvatarCroppedAreaPixels(null);
    setAvatarEditorOpen(true);
    event.target.value = "";
  };

  const closeAvatarEditor = () => {
    setAvatarEditorOpen(false);
    if (avatarEditorImageUrl) {
      URL.revokeObjectURL(avatarEditorImageUrl);
    }
    setAvatarEditorImageUrl(null);
    setAvatarCroppedAreaPixels(null);
    setAvatarZoom(1);
    setAvatarCrop({ x: 0, y: 0 });
  };

  const handleConfirmAvatarCrop = async () => {
    if (!avatarEditorImageUrl || !avatarCroppedAreaPixels) {
      toast.error("Ajuste a foto antes de salvar.");
      return;
    }

    try {
      const croppedFile = await createCroppedAvatarFile(avatarEditorImageUrl, avatarCroppedAreaPixels, avatarEditorFileName);
      await uploadAvatarMutation.mutateAsync(croppedFile);
      closeAvatarEditor();
    } catch (error) {
      const message = error instanceof Error ? error.message : "Falha ao preparar a foto.";
      toast.error(message);
    }
  };

  const handleSaveProfile = () => {
    updateProfileMutation.mutate({
      english_level: form.english_level,
      bio: form.bio.trim(),
      favorite_songs: form.favorite_songs,
      favorite_movies: form.favorite_movies,
      favorite_series: form.favorite_series,
      favorite_anime: form.favorite_anime,
      favorite_artists: form.favorite_artists,
      favorite_genres: form.favorite_genres,
    });
  };

  const handlePublishPost = () => {
    const content = newPostContent.trim();
    if (!content) {
      toast.error("Escreva algo antes de publicar.");
      return;
    }

    createPostMutation.mutate(content);
  };

  if (!isReady) {
    return null;
  }

  if (profileQuery.isLoading || postsQuery.isLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <div className="inline-flex items-center gap-3 font-mono-vibe text-sm text-secondary">
          <LoaderCircle className="h-5 w-5 animate-spin" />
          SINCRONIZANDO_IDENTIDADE...
        </div>
      </main>
    );
  }

  if (profileQuery.error instanceof UnauthorizedSessionError || postsQuery.error instanceof UnauthorizedSessionError) {
    return null;
  }

  if (profileQuery.isError || postsQuery.isError || !profile) {
    const errorMessage = profileQuery.error instanceof Error ? profileQuery.error.message : "Falha ao carregar perfil.";

    return (
      <main className="container flex min-h-screen items-center justify-center py-12">
        <div className="max-w-xl border border-red-500/40 bg-red-500/10 p-6 text-center">
          <p className="font-display text-2xl text-red-400">FALHA_NA_SINCRONIZACAO</p>
          <p className="mt-4 text-sm text-muted-foreground">{errorMessage}</p>
          <button
            type="button"
            onClick={() => void invalidateDashboard()}
            className="mt-6 inline-flex items-center gap-2 border border-primary/40 px-4 py-3 font-mono-vibe text-xs text-primary transition-colors hover:bg-primary hover:text-primary-foreground"
          >
            <WandSparkles className="h-4 w-4" />
            TENTAR_NOVAMENTE
          </button>
        </div>
      </main>
    );
  }

  return (
    <main className="relative min-h-screen overflow-hidden pb-16">
      <div className="absolute inset-0 -z-10" style={{ background: "var(--gradient-glow)" }} />
      <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top_left,_rgba(0,255,255,0.11),_transparent_28%),radial-gradient(circle_at_bottom_right,_rgba(255,0,170,0.15),_transparent_35%)]" />
      <div className="absolute inset-0 -z-10 scanlines" aria-hidden="true" />

      <div className="container py-6 sm:py-10">
        <motion.section
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.45 }}
          className="overflow-hidden border border-primary/30 bg-card/55 backdrop-blur-xl"
        >
          <div className="border-b border-primary/20 bg-[linear-gradient(135deg,rgba(255,0,170,0.15),rgba(0,255,255,0.08))] px-4 py-6 sm:px-8 sm:py-8">
            <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div className="inline-flex w-full flex-wrap items-center justify-center gap-2 border border-secondary/40 px-3 py-2 text-center font-mono-vibe text-[10px] text-secondary min-[360px]:text-[11px] sm:w-auto sm:justify-start sm:text-left">
                <span className="h-2 w-2 rounded-full bg-secondary animate-pulse" />
                VIBERSTUDANT::ONLINE
              </div>
              <button
                type="button"
                onClick={handleLogout}
                className="inline-flex w-full items-center justify-center gap-2 border border-primary/30 px-3 py-3 font-mono-vibe text-[11px] text-foreground transition-all hover:border-primary hover:bg-primary/10 sm:w-auto sm:px-4 sm:text-xs"
              >
                <LogOut className="h-4 w-4" />
                <span className="max-[360px]:hidden">ENCERRAR_SESSAO</span>
                <span className="hidden max-[360px]:inline">SAIR</span>
              </button>
            </div>

            <div className="grid gap-8 lg:grid-cols-[1fr_320px]">
              <div className="min-w-0 flex flex-col gap-6 sm:flex-row sm:items-start">
                <div className="space-y-4 sm:w-auto">
                  <AvatarShell avatarUrl={profile.avatar_url} displayName={displayName} />
                  <div className="grid grid-cols-1 gap-2 min-[420px]:grid-cols-2 sm:grid-cols-1">
                    <button
                      type="button"
                      onClick={() => fileInputRef.current?.click()}
                      className="inline-flex min-w-0 w-full items-center justify-center gap-2 border border-primary/40 bg-primary/10 px-3 py-3 font-mono-vibe text-[10px] text-primary transition-colors hover:bg-primary hover:text-primary-foreground min-[360px]:text-[11px]"
                    >
                      <Camera className="h-3.5 w-3.5" />
                      <span className="truncate">TROCAR_FOTO</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => deleteAvatarMutation.mutate()}
                      disabled={!profile.avatar_url || deleteAvatarMutation.isPending}
                      className="inline-flex min-w-0 w-full items-center justify-center gap-2 border border-white/10 px-3 py-3 font-mono-vibe text-[10px] text-muted-foreground transition-colors hover:border-red-400 hover:text-red-300 disabled:opacity-40 min-[360px]:text-[11px]"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                      <span className="truncate">REMOVER</span>
                    </button>
                  </div>
                  <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={handleAvatarSelection} />
                </div>

                <div className="min-w-0 max-w-3xl">
                  <div className="mb-3 flex flex-wrap gap-2 font-mono-vibe text-[10px] uppercase tracking-[0.14em] min-[360px]:text-[11px] min-[360px]:tracking-[0.18em]">
                    <span className="border border-primary/30 px-3 py-2 text-primary">role::{currentUser?.role || "student"}</span>
                    <span className="border border-secondary/30 px-3 py-2 text-secondary">energy::{profile.energy_received_count}</span>
                    <span className="border border-accent/40 px-3 py-2 text-accent">posts::{profile.posts_count}</span>
                  </div>
                  <h1 className="max-w-2xl font-display text-[clamp(1.9rem,7vw,3.6rem)] leading-[0.96] tracking-[0.01em] text-foreground [overflow-wrap:anywhere]">
                    {displayName || "Student"}
                  </h1>
                  <p className="mt-4 max-w-2xl break-words text-sm text-muted-foreground sm:text-base">
                    Aqui a sua identidade fica alinhada com o que move sua atenção. O que você atualizar aqui conversa com o mesmo perfil do app mobile e deixa a personalização mais certeira.
                  </p>
                  <div className="mt-6 min-w-0 border border-white/10 bg-background/40 p-4">
                    <div className="font-mono-vibe text-[10px] uppercase tracking-[0.2em] text-secondary">BIO_SIGNAL</div>
                    <p className="mt-2 whitespace-pre-wrap break-words text-sm text-foreground [overflow-wrap:anywhere]">
                      {profile.bio || "Sem bio ainda. Conta o que te prende em músicas, filmes, séries e animes."}
                    </p>
                  </div>
                </div>
              </div>

              <div className="grid gap-4 min-[420px]:grid-cols-3 lg:grid-cols-1">
                <StatCard label="COMPLETUDE" value={`${completeness}%`} accent="text-primary" />
                <StatCard label="ENERGIA RECEBIDA" value={profile.energy_received_count} accent="text-secondary" />
                <StatCard label="COMENTARIOS" value={profile.comments_received_count} accent="text-accent" />
              </div>
            </div>
          </div>
        </motion.section>

        <section className="mt-6 grid gap-6 xl:grid-cols-[1fr_1.1fr]">
          <motion.div
            initial={{ opacity: 0, y: 18 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.45, delay: 0.05 }}
            className="space-y-6"
          >
            <section className="border border-primary/30 bg-card/55 p-4 backdrop-blur-xl sm:p-6">
              <div className="mb-4 flex items-center gap-2 font-mono-vibe text-xs text-primary">
                <BrainCircuit className="h-4 w-4" />
                CORE_PROFILE
              </div>
              <div className="grid gap-4">
                <div>
                  <label className="mb-2 block font-mono-vibe text-xs text-secondary">Nivel de ingles</label>
                  <select
                    value={form.english_level}
                    onChange={(event) => {
                      const value = event.target.value as EnglishLevel;
                      setForm((current) => ({ ...current, english_level: value }));
                    }}
                    className="w-full border border-primary/20 bg-background/80 px-3 py-3 text-sm outline-none transition-colors focus:border-primary"
                  >
                    <option value="beginner">Beginner</option>
                    <option value="intermediate">Intermediate</option>
                    <option value="advanced">Advanced</option>
                  </select>
                </div>
                <div>
                  <label className="mb-2 block font-mono-vibe text-xs text-secondary">Bio</label>
                  <textarea
                    value={form.bio}
                    onChange={(event) => setForm((current) => ({ ...current, bio: event.target.value }))}
                    maxLength={280}
                    rows={5}
                    placeholder="Descreva sua vibe: estilos, universo visual, tipo de narrativa e o que mais te faz estudar sem perceber."
                    className="w-full resize-none border border-primary/20 bg-background/80 px-3 py-3 text-sm outline-none transition-colors focus:border-primary"
                  />
                  <div className="mt-2 text-right font-mono-vibe text-[10px] text-muted-foreground">{form.bio.length}/280</div>
                </div>
              </div>
            </section>

            <section className="border border-secondary/30 bg-card/55 p-4 backdrop-blur-xl sm:p-6">
              <div className="mb-2 flex items-center gap-2 font-mono-vibe text-xs text-secondary">
                <WandSparkles className="h-4 w-4" />
                MOBILE_ONBOARDING_SYNC
              </div>
              <p className="mb-5 text-sm text-muted-foreground">
                O formulário abaixo usa o mesmo conjunto de dados do app mobile. O que você editar aqui muda diretamente a base que alimenta o feed personalizado.
              </p>

              <div className="space-y-4">
                {preferenceConfigs.map((config) => (
                  <TagEditor
                    key={config.field}
                    icon={config.icon}
                    label={config.label}
                    hint={config.hint}
                    values={form[config.field]}
                    inputValue={tagInputs[config.field]}
                    onInputChange={(value) =>
                      setTagInputs((current) => ({
                        ...current,
                        [config.field]: value,
                      }))
                    }
                    onAdd={() => addTag(config.field)}
                    onRemove={(value) => removeTag(config.field, value)}
                  />
                ))}
              </div>

              <div className="mt-6 flex flex-wrap items-center justify-between gap-4 border-t border-white/10 pt-6">
                <div className="font-mono-vibe text-xs text-muted-foreground">
                  {totalTasteItems} tags ativos mapeando sua vibe de estudo.
                </div>
                <button
                  type="button"
                  onClick={handleSaveProfile}
                  disabled={updateProfileMutation.isPending}
                  className="inline-flex w-full items-center justify-center gap-2 bg-primary px-5 py-3 font-mono-vibe text-xs text-primary-foreground transition-transform hover:scale-[1.01] disabled:opacity-60 sm:w-auto"
                >
                  {updateProfileMutation.isPending ? <LoaderCircle className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
                  SALVAR_IDENTIDADE
                </button>
              </div>
            </section>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 18 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.45, delay: 0.1 }}
            className="space-y-6"
          >
            <section className="border border-primary/30 bg-card/55 p-4 backdrop-blur-xl sm:p-6">
              <div className="mb-2 flex items-center gap-2 font-mono-vibe text-xs text-primary">
                <PencilLine className="h-4 w-4" />
                ENERGY_POST_COMPOSER
              </div>
              <p className="mb-4 text-sm text-muted-foreground">
                Solta uma observação, uma referência ou um recorte da sua semana. O mural ajuda a revelar padrões de gosto e aproxima a comunidade em torno da mesma energia cultural.
              </p>
              <textarea
                value={newPostContent}
                onChange={(event) => setNewPostContent(event.target.value)}
                rows={5}
                maxLength={1200}
                placeholder="Ex.: Hoje entrei numa espiral de sci-fi com Interstellar, trilha do Hans Zimmer e openings que me deixam no modo foco absurdo..."
                className="w-full resize-none border border-primary/20 bg-background/80 px-4 py-4 text-sm outline-none transition-colors focus:border-primary"
              />
              <div className="mt-4 flex flex-wrap items-center justify-between gap-4">
                <div className="font-mono-vibe text-[10px] text-muted-foreground">{newPostContent.trim().length}/1200</div>
                <button
                  type="button"
                  onClick={handlePublishPost}
                  disabled={createPostMutation.isPending}
                  className="inline-flex w-full items-center justify-center gap-2 bg-primary px-5 py-3 font-mono-vibe text-xs text-primary-foreground transition-transform hover:scale-[1.01] disabled:opacity-60 sm:w-auto"
                >
                  {createPostMutation.isPending ? <LoaderCircle className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
                  PUBLICAR_NO_MURAL
                </button>
              </div>
            </section>

            <section className="border border-secondary/30 bg-card/55 p-4 backdrop-blur-xl sm:p-6">
              <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <div className="font-mono-vibe text-xs text-secondary">COMMUNITY_SIGNAL</div>
                  <h2 className="mt-2 font-display text-2xl sm:text-3xl">Mural de energia dos estudantes</h2>
                </div>
                <div className="font-mono-vibe text-[10px] text-muted-foreground">{posts.length} posts carregados</div>
              </div>

              <div className="space-y-4">
                {posts.length === 0 && (
                  <div className="border border-dashed border-primary/30 bg-background/40 p-6 text-sm text-muted-foreground">
                    Ainda não há posts no mural. Publique o primeiro sinal da sua vibe.
                  </div>
                )}

                {posts.map((post) => {
                  const commentDraft = commentDrafts[post.id] || "";
                  const isEditing = editingPostId === post.id;

                  return (
                    <article key={post.id} className="border border-white/10 bg-background/55 p-4 sm:p-5">
                      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                        <div className="min-w-0 flex items-start gap-3">
                          <AvatarShell avatarUrl={post.author.avatar_url} displayName={post.author.display_name} size="sm" />
                          <div className="min-w-0">
                            <div className="font-display text-lg leading-none break-words [overflow-wrap:anywhere]">{post.author.display_name}</div>
                            <div className="mt-2 flex flex-wrap gap-2 font-mono-vibe text-[10px] uppercase tracking-[0.2em] text-muted-foreground">
                              <span>{post.author.role}</span>
                              <span>{formatDateTime(post.created_at)}</span>
                            </div>
                          </div>
                        </div>

                        {post.is_owner && (
                          <div className="flex flex-wrap gap-2">
                            <button
                              type="button"
                              onClick={() => {
                                setEditingPostId(post.id);
                                setEditingPostContent(post.content);
                              }}
                              className="inline-flex items-center gap-2 border border-white/10 px-3 py-2 font-mono-vibe text-[10px] text-muted-foreground transition-colors hover:border-primary hover:text-primary"
                            >
                              <PencilLine className="h-3.5 w-3.5" />
                              EDITAR
                            </button>
                            <button
                              type="button"
                              onClick={() => deletePostMutation.mutate(post.id)}
                              className="inline-flex items-center gap-2 border border-white/10 px-3 py-2 font-mono-vibe text-[10px] text-muted-foreground transition-colors hover:border-red-400 hover:text-red-300"
                            >
                              <Trash2 className="h-3.5 w-3.5" />
                              EXCLUIR
                            </button>
                          </div>
                        )}
                      </div>

                      <div className="mt-5 min-w-0 border-l-2 border-primary/30 pl-4">
                        {isEditing ? (
                          <div className="space-y-3">
                            <textarea
                              value={editingPostContent}
                              onChange={(event) => setEditingPostContent(event.target.value)}
                              rows={4}
                              className="w-full resize-none border border-primary/20 bg-background/80 px-3 py-3 text-sm outline-none transition-colors focus:border-primary"
                            />
                            <div className="flex flex-wrap gap-2">
                              <button
                                type="button"
                                onClick={() => updatePostMutation.mutate({ postId: post.id, content: editingPostContent.trim() })}
                                className="inline-flex items-center gap-2 bg-primary px-4 py-2 font-mono-vibe text-[11px] text-primary-foreground"
                              >
                                <Save className="h-3.5 w-3.5" />
                                SALVAR_POST
                              </button>
                              <button
                                type="button"
                                onClick={() => {
                                  setEditingPostId(null);
                                  setEditingPostContent("");
                                }}
                                className="inline-flex items-center gap-2 border border-white/10 px-4 py-2 font-mono-vibe text-[11px] text-muted-foreground"
                              >
                                <X className="h-3.5 w-3.5" />
                                CANCELAR
                              </button>
                            </div>
                          </div>
                        ) : (
                          <p className="whitespace-pre-wrap break-words text-sm leading-relaxed text-foreground [overflow-wrap:anywhere]">{post.content}</p>
                        )}
                      </div>

                      <div className="mt-5 flex flex-wrap items-center gap-3 border-t border-white/10 pt-4">
                        <button
                          type="button"
                          onClick={() => energyMutation.mutate({ postId: post.id, energized: post.energized_by_me })}
                          className={`inline-flex items-center gap-2 border px-3 py-2 font-mono-vibe text-[11px] transition-colors ${
                            post.energized_by_me
                              ? "border-primary bg-primary text-primary-foreground"
                              : "border-primary/30 bg-primary/10 text-primary hover:border-primary"
                          }`}
                        >
                          <Zap className="h-3.5 w-3.5" />
                          ENERGIA::{post.energy_count}
                        </button>
                        <div className="inline-flex items-center gap-2 border border-secondary/30 bg-secondary/10 px-3 py-2 font-mono-vibe text-[11px] text-secondary">
                          <MessageCircle className="h-3.5 w-3.5" />
                          COMENTARIOS::{post.comment_count}
                        </div>
                      </div>

                      <div className="mt-4 space-y-3">
                        {post.comments.map((comment) => (
                          <div key={comment.id} className="border border-white/10 bg-card/45 p-3">
                            <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                              <div className="min-w-0 flex items-center gap-2 font-mono-vibe text-[10px] uppercase tracking-[0.2em] text-muted-foreground">
                                <UserRound className="h-3.5 w-3.5" />
                                <span className="break-words [overflow-wrap:anywhere]">{comment.author.display_name}</span>
                              </div>
                              <span className="font-mono-vibe text-[10px] text-muted-foreground">{formatDateTime(comment.created_at)}</span>
                            </div>
                            <p className="mt-3 break-words text-sm text-foreground [overflow-wrap:anywhere]">{comment.content}</p>
                          </div>
                        ))}
                      </div>

                      <div className="mt-4 flex gap-2 max-[420px]:flex-col">
                        <input
                          value={commentDraft}
                          onChange={(event) =>
                            setCommentDrafts((current) => ({
                              ...current,
                              [post.id]: event.target.value,
                            }))
                          }
                          onKeyDown={(event) => {
                            if (event.key === "Enter") {
                              event.preventDefault();
                              const content = commentDraft.trim();
                              if (!content) {
                                return;
                              }

                              commentMutation.mutate({ postId: post.id, content });
                            }
                          }}
                          placeholder="Adicionar comentario"
                          className="w-full border border-primary/20 bg-background/80 px-3 py-3 text-sm outline-none transition-colors focus:border-primary"
                        />
                        <button
                          type="button"
                          onClick={() => {
                            const content = commentDraft.trim();
                            if (!content) {
                              return;
                            }

                            commentMutation.mutate({ postId: post.id, content });
                          }}
                          className="inline-flex items-center justify-center gap-2 border border-primary/40 bg-primary/10 px-4 py-3 font-mono-vibe text-[11px] text-primary transition-colors hover:bg-primary hover:text-primary-foreground max-[420px]:w-full"
                        >
                          <MessageCircle className="h-3.5 w-3.5" />
                          ENVIAR
                        </button>
                      </div>
                    </article>
                  );
                })}
              </div>
            </section>
          </motion.div>
        </section>

        {isBusy && (
          <div className="pointer-events-none fixed bottom-6 right-6 inline-flex items-center gap-2 border border-primary/30 bg-background/90 px-4 py-3 font-mono-vibe text-xs text-primary shadow-[0_0_30px_rgba(255,0,170,0.16)] backdrop-blur-xl">
            <LoaderCircle className="h-4 w-4 animate-spin" />
            SYNCING_PROFILE_GRAPH...
          </div>
        )}

        <Dialog open={avatarEditorOpen} onOpenChange={(open) => (!open ? closeAvatarEditor() : setAvatarEditorOpen(open))}>
          <DialogContent className="max-w-4xl border-primary/30 bg-card text-foreground">
            <DialogHeader>
              <DialogTitle className="font-display text-2xl">Ajuste sua foto de perfil</DialogTitle>
              <DialogDescription>
                Arraste a imagem para posicionar e use o zoom para encontrar o corte ideal antes de salvar.
              </DialogDescription>
            </DialogHeader>

            <div className="grid gap-6 lg:grid-cols-[1.3fr_0.7fr]">
              <div className="relative h-[380px] overflow-hidden border border-primary/20 bg-background/70">
                {avatarEditorImageUrl && (
                  <Cropper
                    image={avatarEditorImageUrl}
                    crop={avatarCrop}
                    zoom={avatarZoom}
                    aspect={1}
                    cropShape="round"
                    showGrid={false}
                    onCropChange={setAvatarCrop}
                    onZoomChange={setAvatarZoom}
                    onCropComplete={(_, croppedAreaPixels) => setAvatarCroppedAreaPixels(croppedAreaPixels)}
                  />
                )}
              </div>

              <div className="space-y-6">
                <div className="border border-secondary/20 bg-background/60 p-4">
                  <div className="font-mono-vibe text-xs text-secondary">PAINEL_DE_AJUSTE</div>
                  <p className="mt-3 text-sm text-muted-foreground">
                    O recorte final sai em formato quadrado e com qualidade suficiente para o perfil web e futuras integrações com o app.
                  </p>
                </div>

                <div className="border border-primary/20 bg-background/60 p-4">
                  <label className="mb-3 block font-mono-vibe text-xs text-primary">Zoom da imagem</label>
                  <Slider
                    value={[avatarZoom]}
                    min={1}
                    max={3}
                    step={0.01}
                    onValueChange={(values) => setAvatarZoom(values[0] ?? 1)}
                  />
                  <div className="mt-3 font-mono-vibe text-[11px] text-muted-foreground">AMPLIACAO::{avatarZoom.toFixed(2)}x</div>
                </div>

                <div className="flex flex-wrap gap-3">
                  <button
                    type="button"
                    onClick={() => void handleConfirmAvatarCrop()}
                    disabled={uploadAvatarMutation.isPending}
                    className="inline-flex items-center gap-2 bg-primary px-5 py-3 font-mono-vibe text-xs text-primary-foreground transition-transform hover:scale-[1.01] disabled:opacity-60"
                  >
                    {uploadAvatarMutation.isPending ? <LoaderCircle className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
                    SALVAR_RECORTE
                  </button>
                  <button
                    type="button"
                    onClick={closeAvatarEditor}
                    className="inline-flex items-center gap-2 border border-white/10 px-5 py-3 font-mono-vibe text-xs text-muted-foreground transition-colors hover:border-primary hover:text-primary"
                  >
                    <X className="h-4 w-4" />
                    CANCELAR
                  </button>
                </div>
              </div>
            </div>
          </DialogContent>
        </Dialog>
      </div>
    </main>
  );
}
