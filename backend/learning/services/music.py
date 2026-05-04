"""Pipeline musical inicial para montar runs com playlist sequencial."""

from __future__ import annotations

from dataclasses import dataclass
import json
import logging
import re
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from accounts.models import StudentProfile
from learning.models import ExerciseLine, Lesson, MusicCatalogEntry
from learning.services.letras import LetrasScrapeError, fetch_letras_song_data
from learning.services.ollama import OllamaClient, OllamaError


logger = logging.getLogger(__name__)

_DEFAULT_SEGMENT_DURATION_MS = 30_000
_MAX_TRACKS_PER_RUN = 3
_MIN_LINES_PER_TRACK = 4
_MAX_LINES_PER_TRACK = 12
_SEGMENT_GAP_MS = 900


class MusicLookupError(RuntimeError):
    """Falha operacional ao resolver uma faixa ou letra."""


@dataclass(slots=True)
class TrackCandidate:
    track_title: str
    artist_name: str
    audio_url: str
    source_url: str
    cover_image_url: str
    duration_ms: int = _DEFAULT_SEGMENT_DURATION_MS


@dataclass(slots=True)
class LyricLine:
    text: str
    start_ms: int


@dataclass(slots=True)
class LyricsDocument:
    source_url: str
    lines: list[LyricLine]


def build_music_catalog_key(track_title: str, artist_name: str) -> str:
    return f"{_normalize_spaces(artist_name).lower()}::{_normalize_spaces(track_title).lower()}"[:255]


def _read_json(url: str, *, timeout: int) -> object:
    request = Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": settings.PERSONALIZED_FEED_HTTP_USER_AGENT,
        },
    )
    try:
        with urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except Exception as exc:
        raise MusicLookupError(str(exc)) from exc


def _normalize_spaces(value: str) -> str:
    return " ".join(str(value).split())


def _is_meaningful_lyric_line(text: str) -> bool:
    normalized = _normalize_spaces(text)
    if not normalized:
        return False
    lowered = normalized.lower()
    if lowered in {
        "[instrumental]",
        "instrumental",
        "[chorus]",
        "[verse]",
        "[intro]",
        "[outro]",
    }:
        return False
    return any(character.isalpha() for character in normalized)


class ITunesTrackSearchClient:
    base_url = "https://itunes.apple.com/search"

    def __init__(self, timeout: int | None = None):
        self.timeout = timeout or settings.PERSONALIZED_FEED_SEARCH_TIMEOUT_SECONDS

    def search(self, query: str, limit: int = 5) -> list[TrackCandidate]:
        params = urlencode(
            {
                "term": query,
                "media": "music",
                "entity": "song",
                "limit": limit,
            }
        )
        payload = _read_json(f"{self.base_url}?{params}", timeout=self.timeout)
        results: list[TrackCandidate] = []
        raw_results = payload.get("results", []) if isinstance(payload, dict) else []
        for item in raw_results:
            audio_url = str(item.get("previewUrl") or "").strip()
            track_title = _normalize_spaces(item.get("trackName") or "")
            artist_name = _normalize_spaces(item.get("artistName") or "")
            if not audio_url or not track_title or not artist_name:
                continue
            results.append(
                TrackCandidate(
                    track_title=track_title,
                    artist_name=artist_name,
                    audio_url=audio_url,
                    source_url=str(item.get("trackViewUrl") or item.get("collectionViewUrl") or "").strip(),
                    cover_image_url=str(item.get("artworkUrl100") or item.get("artworkUrl60") or "").strip(),
                    duration_ms=min(
                        int(item.get("previewDurationMillis") or _DEFAULT_SEGMENT_DURATION_MS),
                        _DEFAULT_SEGMENT_DURATION_MS,
                    ),
                )
            )
        return results


class LrcLibLyricsClient:
    base_url = "https://lrclib.net/api/search"

    def __init__(self, timeout: int | None = None):
        self.timeout = timeout or settings.PERSONALIZED_FEED_FETCH_TIMEOUT_SECONDS

    def search(self, track_title: str, artist_name: str) -> LyricsDocument | None:
        params = urlencode({"track_name": track_title, "artist_name": artist_name})
        payload = _read_json(f"{self.base_url}?{params}", timeout=self.timeout)
        candidates = payload if isinstance(payload, list) else []
        best_item = next(
            (
                item
                for item in candidates
                if isinstance(item, dict)
                and _normalize_spaces(item.get("syncedLyrics") or item.get("plainLyrics") or "")
            ),
            None,
        )
        if not best_item:
            return None

        raw_lyrics = str(best_item.get("syncedLyrics") or best_item.get("plainLyrics") or "")
        lines = parse_lyric_lines(raw_lyrics)
        if len(lines) < _MIN_LINES_PER_TRACK:
            return None
        source_url = str(best_item.get("plainLyricsUrl") or best_item.get("source") or "https://lrclib.net").strip()
        return LyricsDocument(source_url=source_url, lines=lines)


def _normalize_line_pairs(raw_pairs: list[dict]) -> list[dict[str, str]]:
    normalized_pairs: list[dict[str, str]] = []
    for item in raw_pairs:
        if not isinstance(item, dict):
            continue
        text_en = _normalize_spaces(item.get("text_en") or "")[:255]
        text_pt = _normalize_spaces(item.get("text_pt") or "")[:255]
        if not _is_meaningful_lyric_line(text_en):
            continue
        normalized_pairs.append({"text_en": text_en, "text_pt": text_pt})
    return normalized_pairs


def get_or_sync_music_catalog_entry(track: TrackCandidate) -> MusicCatalogEntry | None:
    catalog_key = build_music_catalog_key(track.track_title, track.artist_name)
    entry, _ = MusicCatalogEntry.objects.get_or_create(
        normalized_key=catalog_key,
        defaults={
            "track_title": track.track_title,
            "artist_name": track.artist_name,
            "preview_audio_url": track.audio_url,
            "cover_image_url": track.cover_image_url,
            "duration_ms": track.duration_ms,
        },
    )

    cached_pairs = _normalize_line_pairs((entry.lyrics_manifest or {}).get("line_pairs") or [])
    if entry.status == MusicCatalogEntry.Status.READY and cached_pairs:
        dirty_fields: list[str] = []
        if entry.preview_audio_url != track.audio_url:
            entry.preview_audio_url = track.audio_url
            dirty_fields.append("preview_audio_url")
        if track.cover_image_url and entry.cover_image_url != track.cover_image_url:
            entry.cover_image_url = track.cover_image_url
            dirty_fields.append("cover_image_url")
        if track.duration_ms and entry.duration_ms != track.duration_ms:
            entry.duration_ms = track.duration_ms
            dirty_fields.append("duration_ms")
        if dirty_fields:
            dirty_fields.append("updated_at")
            entry.save(update_fields=dirty_fields)
        return entry

    try:
        song_data = fetch_letras_song_data(track.track_title, track.artist_name)
    except LetrasScrapeError as exc:
        entry.track_title = track.track_title
        entry.artist_name = track.artist_name
        entry.preview_audio_url = track.audio_url
        entry.cover_image_url = track.cover_image_url
        entry.duration_ms = track.duration_ms
        entry.status = MusicCatalogEntry.Status.FAILED
        entry.last_error = str(exc)
        entry.save(
            update_fields=[
                "track_title",
                "artist_name",
                "preview_audio_url",
                "cover_image_url",
                "duration_ms",
                "status",
                "last_error",
                "updated_at",
            ]
        )
        logger.warning(
            "music catalog sync failed",
            extra={
                "track_title": track.track_title,
                "artist_name": track.artist_name,
                "error": str(exc),
            },
        )
        return None

    line_pairs = _normalize_line_pairs(song_data.line_pairs)
    if line_pairs and all(not item["text_pt"] for item in line_pairs):
        translations = translate_lyric_lines([item["text_en"] for item in line_pairs])
        line_pairs = [
            {
                "text_en": item["text_en"],
                "text_pt": translations[index] if index < len(translations) else "",
            }
            for index, item in enumerate(line_pairs)
        ]

    if len(line_pairs) < _MIN_LINES_PER_TRACK:
        entry.status = MusicCatalogEntry.Status.FAILED
        entry.last_error = "Could not build enough lyric lines from Letras."
        entry.save(update_fields=["status", "last_error", "updated_at"])
        return None

    entry.track_title = song_data.track_title or track.track_title
    entry.artist_name = song_data.artist_name or track.artist_name
    entry.source_url = song_data.source_url or track.source_url
    entry.translation_url = song_data.translation_url
    entry.listen_url = song_data.listen_url
    entry.preview_audio_url = track.audio_url
    entry.youtube_url = song_data.youtube_url
    entry.cover_image_url = song_data.cover_image_url or track.cover_image_url
    entry.language_code = song_data.language_code
    entry.duration_ms = track.duration_ms
    entry.lyrics_manifest = {
        "line_pairs": line_pairs,
        "source_provider": "letras",
    }
    entry.status = MusicCatalogEntry.Status.READY
    entry.last_error = ""
    entry.last_synced_at = timezone.now()
    entry.save(
        update_fields=[
            "track_title",
            "artist_name",
            "source_url",
            "translation_url",
            "listen_url",
            "preview_audio_url",
            "youtube_url",
            "cover_image_url",
            "language_code",
            "duration_ms",
            "lyrics_manifest",
            "status",
            "last_error",
            "last_synced_at",
            "updated_at",
        ]
    )
    return entry


def parse_lyric_lines(raw_lyrics: str) -> list[LyricLine]:
    if not _normalize_spaces(raw_lyrics):
        return []

    lrc_pattern = re.compile(r"\[(?P<minutes>\d+):(?P<seconds>\d+(?:\.\d+)?)\](?P<text>.+)")
    synced_lines: list[LyricLine] = []
    for raw_line in raw_lyrics.splitlines():
        match = lrc_pattern.match(raw_line.strip())
        if not match:
            continue
        text = _normalize_spaces(match.group("text"))
        if not _is_meaningful_lyric_line(text):
            continue
        start_ms = int((int(match.group("minutes")) * 60 + float(match.group("seconds"))) * 1000)
        synced_lines.append(LyricLine(text=text[:255], start_ms=start_ms))

    if synced_lines:
        return synced_lines

    filtered_lines = [
        _normalize_spaces(item)[:255]
        for item in raw_lyrics.splitlines()
        if _is_meaningful_lyric_line(item)
    ]
    if not filtered_lines:
        return []

    step_ms = max(int(_DEFAULT_SEGMENT_DURATION_MS / max(len(filtered_lines), 1)), 1800)
    return [LyricLine(text=text, start_ms=index * step_ms) for index, text in enumerate(filtered_lines)]


def translate_lyric_lines(lines: list[str]) -> list[str]:
    if not lines:
        return []

    client = OllamaClient()
    try:
        payload = client.generate_json(
            system_prompt=(
                "You translate song lyric lines into concise Brazilian Portuguese. "
                "Return valid JSON only. Keep the same order and preserve tone. "
                "Each translation must stay under 120 characters."
            ),
            user_prompt=json.dumps(
                {
                    "instructions": {
                        "shape": {"translations": ["string"]},
                        "line_count": len(lines),
                    },
                    "lines": lines,
                },
                ensure_ascii=True,
            ),
        )
    except OllamaError as exc:
        logger.warning("music line translation failed", extra={"error": str(exc)})
        return ["" for _ in lines]

    translations = payload.get("translations") if isinstance(payload, dict) else None
    if not isinstance(translations, list):
        return ["" for _ in lines]

    normalized = [_normalize_spaces(item)[:255] for item in translations[: len(lines)]]
    while len(normalized) < len(lines):
        normalized.append("")
    return normalized


def _build_track_queries(profile: StudentProfile) -> list[str]:
    queries: list[str] = []
    seen: set[str] = set()

    for raw_value in profile.favorite_songs[:4]:
        query = _normalize_spaces(raw_value)
        if query and query.lower() not in seen:
            seen.add(query.lower())
            queries.append(query)

    for raw_value in profile.favorite_artists[:4]:
        artist = _normalize_spaces(raw_value)
        if not artist:
            continue
        query = f"{artist} top songs"
        if query.lower() in seen:
            continue
        seen.add(query.lower())
        queries.append(query)

    return queries


def _guess_difficulty(profile: StudentProfile) -> str:
    mapping = {
        StudentProfile.EnglishLevel.BEGINNER: Lesson.Difficulty.EASY,
        StudentProfile.EnglishLevel.INTERMEDIATE: Lesson.Difficulty.MEDIUM,
        StudentProfile.EnglishLevel.ADVANCED: Lesson.Difficulty.HARD,
    }
    return mapping.get(profile.english_level, Lesson.Difficulty.EASY)


def _select_track_lines(lines: list[LyricLine]) -> list[LyricLine]:
    meaningful = [line for line in lines if _is_meaningful_lyric_line(line.text)]
    if len(meaningful) <= _MAX_LINES_PER_TRACK:
        return meaningful

    midpoint = max(len(meaningful) // 2, _MAX_LINES_PER_TRACK // 2)
    start = max(midpoint - (_MAX_LINES_PER_TRACK // 2), 0)
    return meaningful[start : start + _MAX_LINES_PER_TRACK]


def _select_catalog_line_pairs(line_pairs: list[dict[str, str]]) -> list[dict[str, str]]:
    if len(line_pairs) <= _MAX_LINES_PER_TRACK:
        return line_pairs

    midpoint = max(len(line_pairs) // 2, _MAX_LINES_PER_TRACK // 2)
    start = max(midpoint - (_MAX_LINES_PER_TRACK // 2), 0)
    return line_pairs[start : start + _MAX_LINES_PER_TRACK]


def _build_line_items(track: TrackCandidate, catalog_entry: MusicCatalogEntry, *, segment_index: int, offset_ms: int) -> list[dict]:
    available_pairs = _normalize_line_pairs((catalog_entry.lyrics_manifest or {}).get("line_pairs") or [])
    selected_pairs = _select_catalog_line_pairs(available_pairs)
    if len(selected_pairs) < _MIN_LINES_PER_TRACK:
        return []

    usable_duration_ms = max(track.duration_ms - 2000, 6_000)
    spacing_ms = max(int(usable_duration_ms / max(len(selected_pairs), 1)), 1800)
    line_items: list[dict] = []

    for index, pair in enumerate(selected_pairs):
        relative_start_ms = index * spacing_ms
        start_ms = offset_ms + max(relative_start_ms, 0)
        if index + 1 < len(selected_pairs):
            next_relative_start_ms = (index + 1) * spacing_ms
            end_ms = offset_ms + max(next_relative_start_ms - 220, relative_start_ms + 1200)
        else:
            end_ms = offset_ms + max(usable_duration_ms, relative_start_ms + 1500)
        line_items.append(
            {
                "text_en": pair["text_en"],
                "text_pt": pair["text_pt"],
                "phonetic_hint": "",
                "track_title": catalog_entry.track_title or track.track_title,
                "artist_name": catalog_entry.artist_name or track.artist_name,
                "segment_index": segment_index,
                "reference_start_ms": start_ms,
                "reference_end_ms": end_ms,
            }
        )

    return line_items


def backfill_music_lesson_translations(lesson: Lesson) -> None:
    if lesson.content_type != Lesson.ContentType.MUSIC or not hasattr(lesson, "exercise"):
        return

    lines = list(lesson.exercise.lines.all())
    missing_lines = [line for line in lines if not _normalize_spaces(line.text_pt)]
    if not missing_lines:
        return

    translations = translate_lyric_lines([line.text_en for line in missing_lines])
    if not any(_normalize_spaces(item) for item in translations):
        return

    for index, line in enumerate(missing_lines):
        if index < len(translations):
            line.text_pt = _normalize_spaces(translations[index])[:255]

    translated_lines = [line for line in missing_lines if _normalize_spaces(line.text_pt)]
    if not translated_lines:
        return

    with transaction.atomic():
        ExerciseLine.objects.bulk_update(translated_lines, ["text_pt"])
        first_line = lines[0] if lines else None
        if first_line is not None and _normalize_spaces(first_line.text_pt):
            lesson.exercise.expected_phrase_pt = first_line.text_pt
            lesson.exercise.save(update_fields=["expected_phrase_pt", "updated_at"])


def _format_music_run_title(tracks: list[TrackCandidate]) -> str:
    artist_names: list[str] = []
    for track in tracks:
        if track.artist_name not in artist_names:
            artist_names.append(track.artist_name)
    if not artist_names:
        return "Music Run"
    if len(artist_names) == 1:
        return f"Music Run: {artist_names[0]}"
    return f"Music Run: {' + '.join(artist_names[:3])}"


def generate_music_payloads(profile: StudentProfile, target_count: int) -> list[dict]:
    if target_count <= 0:
        return []

    queries = _build_track_queries(profile)
    if not queries:
        return []

    track_client = ITunesTrackSearchClient()
    selected_tracks: list[tuple[TrackCandidate, MusicCatalogEntry]] = []
    seen_track_keys: set[str] = set()

    for query in queries:
        try:
            candidates = track_client.search(query, limit=5)
        except MusicLookupError as exc:
            logger.warning("music track lookup failed", extra={"query": query, "error": str(exc)})
            continue

        for candidate in candidates:
            track_key = f"{candidate.artist_name.lower()}::{candidate.track_title.lower()}"
            if track_key in seen_track_keys:
                continue
            catalog_entry = get_or_sync_music_catalog_entry(candidate)
            if catalog_entry is None:
                continue

            seen_track_keys.add(track_key)
            selected_tracks.append((candidate, catalog_entry))
            break

        if len(selected_tracks) >= _MAX_TRACKS_PER_RUN:
            break

    if not selected_tracks:
        return []

    playlist_items: list[dict] = []
    line_items: list[dict] = []
    offset_ms = 0
    built_tracks: list[TrackCandidate] = []
    primary_source_url = ""
    for segment_index, (track, catalog_entry) in enumerate(selected_tracks, start=1):
        segment_lines = _build_line_items(track, catalog_entry, segment_index=segment_index, offset_ms=offset_ms)
        if len(segment_lines) < _MIN_LINES_PER_TRACK:
            continue

        built_tracks.append(track)
        if not primary_source_url:
            primary_source_url = catalog_entry.source_url or track.source_url
        playlist_items.append(
            {
                "title": catalog_entry.track_title or track.track_title,
                "artist_name": catalog_entry.artist_name or track.artist_name,
                "audio_url": track.audio_url,
                "source_url": catalog_entry.source_url or track.source_url,
                "cover_image_url": catalog_entry.cover_image_url or track.cover_image_url,
                "duration_ms": track.duration_ms,
                "offset_ms": offset_ms,
            }
        )
        line_items.extend(segment_lines)
        offset_ms += track.duration_ms + _SEGMENT_GAP_MS

    if not playlist_items or not line_items:
        return []

    first_track = built_tracks[0]
    return [
        {
            "title": _format_music_run_title(built_tracks),
            "description": (
                "Run musical em sequencia com trechos dos artistas e musicas favoritas do aluno. "
                "A letra original aparece em destaque e a traducao PT-BR segue embaixo."
            ),
            "content_type": Lesson.ContentType.MUSIC,
            "difficulty": _guess_difficulty(profile),
            "tags": ["music-run", *[track.artist_name for track in built_tracks]],
            "media_url": first_track.audio_url,
            "media_manifest": {
                "type": "audio_playlist",
                "playback": "sequential",
                "speed_up_every_ms": 30_000,
                "items": playlist_items,
            },
            "source_url": primary_source_url or first_track.source_url or "https://www.letras.com/",
            "source_title": first_track.track_title,
            "cover_image_url": first_track.cover_image_url,
            "match_reason": "Based on favorite songs and artists",
            "instruction_text": (
                "Siga a letra descendo como um music run. O texto original fica em cima e a traducao PT-BR embaixo. "
                "A cada 30 segundos a leitura pede mais ritmo."
            ),
            "expected_phrase_en": line_items[0]["text_en"],
            "expected_phrase_pt": line_items[0]["text_pt"],
            "line_items": line_items,
        }
    ]
