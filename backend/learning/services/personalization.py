"""Pipeline de descoberta web + LLM para montar lessons privadas."""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from urllib.parse import urlparse

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
import logging

from accounts.models import StudentProfile
from learning.models import Exercise, ExerciseLine, Lesson
from learning.services.music import generate_music_payloads
from learning.services.ollama import OllamaClient, OllamaError
from learning.services.web import ExtractedSource, MultiSearchClient, WebSearchError, extract_source_document


logger = logging.getLogger(__name__)


class PersonalizationError(RuntimeError):
    """Erro do pipeline de bootstrap personalizado."""


@dataclass(slots=True)
class QuerySpec:
    seed: str
    query: str
    match_reason: str
    content_type: str


def build_profile_signature(profile: StudentProfile) -> str:
    payload = {
        "english_level": profile.english_level,
        "favorite_songs": profile.favorite_songs,
        "favorite_movies": profile.favorite_movies,
        "favorite_series": profile.favorite_series,
        "favorite_anime": profile.favorite_anime,
        "favorite_artists": profile.favorite_artists,
        "favorite_genres": profile.favorite_genres,
    }
    serialized = json.dumps(payload, ensure_ascii=True, sort_keys=True)
    return hashlib.sha256(serialized.encode("utf-8")).hexdigest()


def _normalize_spaces(value: str) -> str:
    return " ".join(str(value).split())


def _clean_tags(values: list[str] | None) -> list[str]:
    if not values:
        return []

    tags: list[str] = []
    seen: set[str] = set()
    for value in values:
        cleaned = _normalize_spaces(value).strip("# ")
        if not cleaned:
            continue
        lowered = cleaned.lower()
        if lowered in seen:
            continue
        seen.add(lowered)
        tags.append(cleaned[:50])
    return tags[:8]


def _guess_difficulty(profile: StudentProfile) -> str:
    mapping = {
        StudentProfile.EnglishLevel.BEGINNER: Lesson.Difficulty.EASY,
        StudentProfile.EnglishLevel.INTERMEDIATE: Lesson.Difficulty.MEDIUM,
        StudentProfile.EnglishLevel.ADVANCED: Lesson.Difficulty.HARD,
    }
    return mapping.get(profile.english_level, Lesson.Difficulty.EASY)


def build_query_specs(profile: StudentProfile, target_count: int) -> list[QuerySpec]:
    specs: list[QuerySpec] = []
    seen: set[str] = set()

    def add(values: list[str], *, query_suffix: str, match_prefix: str, content_type: str, per_bucket: int = 2):
        for raw_value in values[:per_bucket]:
            value = _normalize_spaces(raw_value)
            if not value:
                continue
            normalized_key = f"{content_type}:{value.lower()}:{query_suffix}"
            if normalized_key in seen:
                continue
            seen.add(normalized_key)
            specs.append(
                QuerySpec(
                    seed=value,
                    query=f'{value} {query_suffix}'.strip(),
                    match_reason=f'{match_prefix}: {value}',
                    content_type=content_type,
                )
            )

    add(
        profile.favorite_songs,
        query_suffix='lyrics meaning iconic line',
        match_prefix='Based on favorite song',
        content_type=Lesson.ContentType.MUSIC,
    )
    add(
        profile.favorite_movies,
        query_suffix='famous quote scene recap',
        match_prefix='Based on favorite movie',
        content_type=Lesson.ContentType.MOVIE_CLIP,
    )
    add(
        profile.favorite_series,
        query_suffix='famous quote scene recap',
        match_prefix='Based on favorite series',
        content_type=Lesson.ContentType.SERIES_CLIP,
    )
    add(
        profile.favorite_anime,
        query_suffix='famous quote scene recap',
        match_prefix='Based on favorite anime',
        content_type=Lesson.ContentType.ANIME_CLIP,
    )
    add(
        profile.favorite_artists,
        query_suffix='songs iconic lyric meaning',
        match_prefix='Based on favorite artist',
        content_type=Lesson.ContentType.MUSIC,
    )

    for genre in profile.favorite_genres[:2]:
        cleaned_genre = _normalize_spaces(genre)
        if not cleaned_genre:
            continue
        add(
            [cleaned_genre],
            query_suffix='best pop culture quote english',
            match_prefix='Based on favorite genre',
            content_type=Lesson.ContentType.CHARGE,
            per_bucket=1,
        )

    if not specs:
        specs.append(
            QuerySpec(
                seed='pop culture',
                query='pop culture quote english practice',
                match_reason='Based on your onboarding answers',
                content_type=Lesson.ContentType.CHARGE,
            )
        )

    return specs[: max(target_count * 2, 6)]


def collect_source_documents(profile: StudentProfile, target_count: int) -> list[ExtractedSource]:
    search_client = MultiSearchClient()
    query_specs = build_query_specs(profile, target_count)
    extracted_sources: list[ExtractedSource] = []
    seen_urls: set[str] = set()
    max_sources = settings.PERSONALIZED_FEED_MAX_SOURCES

    for spec in query_specs:
        search_results = _search_with_variants(search_client, spec)
        for result in search_results:
            normalized_url = result.url.rstrip("/")
            if normalized_url in seen_urls:
                continue
            seen_urls.add(normalized_url)
            try:
                extracted_sources.append(
                    extract_source_document(
                        result.url,
                        query=spec.query,
                        match_reason=spec.match_reason,
                        content_type=spec.content_type,
                        fallback_title=result.title,
                        fallback_snippet=result.snippet,
                        fallback_image_url=result.thumbnail_url,
                    )
                )
            except WebSearchError:
                continue

            if len(extracted_sources) >= max_sources:
                return extracted_sources

    return extracted_sources


def _normalize_search_key(value: str) -> str:
    return " ".join("".join(ch if ch.isalnum() else " " for ch in value.lower()).split())


def _build_query_variants(spec: QuerySpec) -> list[str]:
    variants = [spec.seed]
    if spec.content_type == Lesson.ContentType.MUSIC:
        variants.append(f"{spec.seed} song lyrics")
    elif spec.content_type in {
        Lesson.ContentType.MOVIE_CLIP,
        Lesson.ContentType.SERIES_CLIP,
        Lesson.ContentType.ANIME_CLIP,
    }:
        variants.append(f"{spec.seed} quote")
    variants.append(spec.query)

    deduplicated: list[str] = []
    seen: set[str] = set()
    for item in variants:
        normalized = _normalize_search_key(item)
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        deduplicated.append(item)
    return deduplicated


def _result_matches_seed(result, seed: str) -> bool:
    normalized_seed = _normalize_search_key(seed)
    if not normalized_seed:
        return True

    haystack = _normalize_search_key(" ".join([result.title, result.snippet, result.url]))
    if normalized_seed in haystack:
        return True

    seed_tokens = [token for token in normalized_seed.split() if len(token) >= 3]
    if not seed_tokens:
        return True
    return sum(1 for token in seed_tokens if token in haystack) >= min(len(seed_tokens), 2)


def _search_with_variants(search_client: MultiSearchClient, spec: QuerySpec):
    last_error: WebSearchError | None = None
    for query in _build_query_variants(spec):
        try:
            raw_results = search_client.search(
                query,
                limit=settings.PERSONALIZED_FEED_SEARCH_RESULTS_PER_QUERY,
            )
        except WebSearchError as exc:
            last_error = exc
            continue

        filtered_results = [item for item in raw_results if _result_matches_seed(item, spec.seed)]
        if filtered_results:
            return filtered_results
        if raw_results:
            return raw_results

    if last_error is not None:
        raise last_error
    return []


def _build_system_prompt() -> str:
    return (
        'You are curating English micro-lessons for a student app. '
        'Return valid JSON only. Use only the supplied source material. '
        'Every item must become a practical pronunciation lesson with 1 to 3 short lines. '
        'Do not copy long copyrighted excerpts. Keep each English line under 12 words. '
        'Prefer catchy, memorable, culturally relevant phrases. '
        'Use concise Brazilian Portuguese translations.'
    )


def _build_user_prompt(profile: StudentProfile, sources: list[ExtractedSource], target_count: int) -> str:
    source_payload = []
    for index, source in enumerate(sources, start=1):
        source_payload.append(
            {
                "id": index,
                "query": source.query,
                "match_reason": source.match_reason,
                "content_type": source.content_type,
                "source_title": source.source_title,
                "source_url": source.url,
                "source_domain": source.source_domain,
                "cover_image_url": source.cover_image_url,
                "snippet": source.snippet,
                "text_excerpt": source.text_excerpt,
            }
        )

    instructions = {
        "target_items": target_count,
        "english_level": profile.english_level,
        "allowed_content_types": [choice for choice, _ in Lesson.ContentType.choices],
        "allowed_difficulties": [choice for choice, _ in Lesson.Difficulty.choices],
        "required_shape": {
            "items": [
                {
                    "title": "string",
                    "description": "string",
                    "content_type": "music|movie_clip|series_clip|anime_clip|charge",
                    "difficulty": "easy|medium|hard",
                    "tags": ["string"],
                    "source_url": "https://...",
                    "source_title": "string",
                    "cover_image_url": "https://... or empty string",
                    "match_reason": "string",
                    "instruction_text": "string",
                    "expected_phrase_en": "string",
                    "expected_phrase_pt": "string",
                    "line_items": [
                        {
                            "text_en": "string",
                            "text_pt": "string",
                            "phonetic_hint": "string",
                            "reference_start_ms": 0,
                            "reference_end_ms": 2200,
                        }
                    ],
                }
            ]
        },
        "rules": [
            "Use only URLs from the provided sources.",
            "Create lessons that are practice-ready for the mobile app.",
            "Prefer one memorable quote or lyric fragment per lesson.",
            "If an image is not trustworthy, return an empty string for cover_image_url.",
            "Do not invent media or sources.",
        ],
    }
    return json.dumps({"instructions": instructions, "sources": source_payload}, ensure_ascii=True)


def _is_http_url(value: str) -> bool:
    parsed = urlparse(value)
    return parsed.scheme in {"http", "https"} and bool(parsed.netloc)


def _normalize_line_items(raw_line_items: list[dict], expected_phrase_en: str, expected_phrase_pt: str) -> list[dict]:
    normalized_items: list[dict] = []
    for index, item in enumerate(raw_line_items[:3], start=1):
        text_en = _normalize_spaces(item.get("text_en") or "")[:255]
        text_pt = _normalize_spaces(item.get("text_pt") or "")[:255]
        if not text_en:
            continue
        start_ms = max(int(item.get("reference_start_ms") or (index - 1) * 2500), 0)
        end_ms = max(int(item.get("reference_end_ms") or (start_ms + 2200)), start_ms + 500)
        normalized_items.append(
            {
                "text_en": text_en,
                "text_pt": text_pt,
                "phonetic_hint": _normalize_spaces(item.get("phonetic_hint") or "")[:255],
                "track_title": _normalize_spaces(item.get("track_title") or "")[:255],
                "artist_name": _normalize_spaces(item.get("artist_name") or "")[:255],
                "segment_index": max(int(item.get("segment_index") or 0), 0),
                "reference_start_ms": start_ms,
                "reference_end_ms": end_ms,
            }
        )

    if normalized_items:
        return normalized_items

    return [
        {
            "text_en": expected_phrase_en,
            "text_pt": expected_phrase_pt,
            "phonetic_hint": "",
            "track_title": "",
            "artist_name": "",
            "segment_index": 0,
            "reference_start_ms": 0,
            "reference_end_ms": 2200,
        }
    ]


def normalize_generated_items(raw_payload: dict, profile: StudentProfile, target_count: int) -> list[dict]:
    allowed_content_types = {choice for choice, _ in Lesson.ContentType.choices}
    allowed_difficulties = {choice for choice, _ in Lesson.Difficulty.choices}
    items = raw_payload.get("items")
    if not isinstance(items, list):
        raise PersonalizationError("LLM payload does not contain an items list.")

    normalized_items: list[dict] = []
    seen_keys: set[str] = set()
    default_difficulty = _guess_difficulty(profile)
    for item in items:
        if not isinstance(item, dict):
            continue

        title = _normalize_spaces(item.get("title") or "")[:255]
        source_url = str(item.get("source_url") or "").strip()
        expected_phrase_en = _normalize_spaces(item.get("expected_phrase_en") or "")[:255]
        expected_phrase_pt = _normalize_spaces(item.get("expected_phrase_pt") or "")[:255]
        instruction_text = _normalize_spaces(item.get("instruction_text") or "Repeat each line with confidence.")[:500]
        if not title or not source_url or not expected_phrase_en or not _is_http_url(source_url):
            continue

        source_title = _normalize_spaces(item.get("source_title") or title)[:255]
        normalized_key = f"{title.lower()}::{source_url.rstrip('/')}"
        if normalized_key in seen_keys:
            continue
        seen_keys.add(normalized_key)

        content_type = str(item.get("content_type") or Lesson.ContentType.CHARGE)
        if content_type not in allowed_content_types:
            content_type = Lesson.ContentType.CHARGE

        difficulty = str(item.get("difficulty") or default_difficulty)
        if difficulty not in allowed_difficulties:
            difficulty = default_difficulty

        cover_image_url = str(item.get("cover_image_url") or "").strip()
        if not _is_http_url(cover_image_url):
            cover_image_url = ""

        line_items = _normalize_line_items(item.get("line_items") or [], expected_phrase_en, expected_phrase_pt)
        normalized_items.append(
            {
                "title": title,
                "description": _normalize_spaces(item.get("description") or source_title)[:500],
                "content_type": content_type,
                "difficulty": difficulty,
                "tags": _clean_tags(item.get("tags") or []),
                "media_url": source_url,
                "source_url": source_url,
                "source_title": source_title,
                "cover_image_url": cover_image_url,
                "match_reason": _normalize_spaces(item.get("match_reason") or "Based on your onboarding answers")[:255],
                "instruction_text": instruction_text,
                "expected_phrase_en": expected_phrase_en,
                "expected_phrase_pt": expected_phrase_pt,
                "line_items": line_items,
                "media_manifest": item.get("media_manifest") or {},
            }
        )
        if len(normalized_items) >= target_count:
            break

    if not normalized_items:
        raise PersonalizationError("No valid lessons were produced by the model.")
    return normalized_items


def _generate_generic_lesson_payloads(profile: StudentProfile, target_count: int) -> list[dict]:
    try:
        sources = collect_source_documents(profile, target_count)
    except WebSearchError as exc:
        raise PersonalizationError(f"Web search failed: {exc}") from exc
    if not sources:
        raise PersonalizationError("No web sources were collected for personalization.")

    ollama_client = OllamaClient()
    try:
        raw_payload = ollama_client.generate_json(
            system_prompt=_build_system_prompt(),
            user_prompt=_build_user_prompt(profile, sources, target_count),
        )
    except OllamaError as exc:
        raise PersonalizationError(f"Ollama failed: {exc}") from exc
    return normalize_generated_items(raw_payload, profile, target_count)


def generate_lesson_payloads(profile: StudentProfile, target_count: int) -> list[dict]:
    item_count = max(int(target_count), 1)
    payloads: list[dict] = []

    try:
        payloads.extend(generate_music_payloads(profile, item_count))
    except Exception as exc:
        logger.warning("music payload generation skipped", extra={"error": str(exc)})

    remaining_count = item_count - len(payloads)
    if remaining_count <= 0:
        return payloads[:item_count]

    try:
        payloads.extend(_generate_generic_lesson_payloads(profile, remaining_count))
    except PersonalizationError:
        if payloads:
            return payloads[:item_count]
        raise

    return payloads[:item_count]


def get_or_create_ai_curator():
    user_model = get_user_model()
    email = settings.AI_CURATOR_EMAIL.strip().lower()
    if not email:
        raise PersonalizationError("AI_CURATOR_EMAIL is not configured.")

    teacher = user_model.objects.filter(email__iexact=email).first()
    if teacher is None:
        teacher = user_model.objects.create_user(
            email=email,
            password=None,
            first_name="AI",
            last_name="Curator",
            role=user_model.Role.TEACHER,
        )
    elif teacher.role not in {user_model.Role.TEACHER, user_model.Role.ADMIN}:
        teacher.role = user_model.Role.TEACHER
        teacher.save(update_fields=["role", "updated_at"])

    return teacher


def _create_exercise_lines(exercise: Exercise, line_items: list[dict]) -> None:
    ExerciseLine.objects.bulk_create(
        [
            ExerciseLine(
                exercise=exercise,
                order=index,
                text_en=line_item["text_en"],
                text_pt=line_item["text_pt"],
                phonetic_hint=line_item["phonetic_hint"],
                track_title=line_item.get("track_title", ""),
                artist_name=line_item.get("artist_name", ""),
                segment_index=max(int(line_item.get("segment_index", 0)), 0),
                reference_start_ms=max(int(line_item["reference_start_ms"]), 0),
                reference_end_ms=max(int(line_item["reference_end_ms"]), 0),
            )
            for index, line_item in enumerate(line_items, start=1)
        ]
    )


def replace_personalized_lessons(student, payloads: list[dict]) -> int:
    teacher = get_or_create_ai_curator()
    published_at = timezone.now()

    with transaction.atomic():
        Lesson.objects.filter(
            student=student,
            visibility=Lesson.Visibility.PRIVATE,
            generated_by_ai=True,
        ).delete()

        for payload in payloads:
            lesson = Lesson.objects.create(
                teacher=teacher,
                student=student,
                title=payload["title"],
                description=payload["description"],
                content_type=payload["content_type"],
                source_type=Lesson.SourceType.EXTERNAL_LINK,
                difficulty=payload["difficulty"],
                tags=payload["tags"],
                media_url=payload["media_url"],
                media_manifest=payload.get("media_manifest") or {},
                cover_image_url=payload["cover_image_url"],
                source_url=payload["source_url"],
                source_title=payload["source_title"],
                source_domain=urlparse(payload["source_url"]).netloc[:255],
                match_reason_hint=payload["match_reason"],
                generated_by_ai=True,
                visibility=Lesson.Visibility.PRIVATE,
                status=Lesson.Status.PUBLISHED,
                published_at=published_at,
            )
            exercise = Exercise.objects.create(
                lesson=lesson,
                instruction_text=payload["instruction_text"],
                expected_phrase_en=payload["expected_phrase_en"],
                expected_phrase_pt=payload["expected_phrase_pt"],
                max_score=100,
            )
            _create_exercise_lines(exercise, payload["line_items"])

    return len(payloads)


def generate_and_store_personalized_lessons(student, profile: StudentProfile, target_count: int | None = None) -> int:
    item_count = target_count or settings.PERSONALIZED_FEED_TARGET_ITEMS
    payloads = generate_lesson_payloads(profile, item_count)
    return replace_personalized_lessons(student, payloads)
