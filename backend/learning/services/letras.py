"""Resolver e extrair letras/traducoes do Letras.com/Letras.mus.br."""

from __future__ import annotations

from dataclasses import dataclass
from difflib import SequenceMatcher
from html import unescape
import json
import re
from urllib.parse import urlparse
from urllib.request import Request, urlopen

from django.conf import settings
from django.utils.text import slugify


class LetrasScrapeError(RuntimeError):
    """Falha ao resolver ou extrair uma letra do Letras."""


@dataclass(slots=True)
class LetrasSongData:
    track_title: str
    artist_name: str
    source_url: str
    translation_url: str
    cover_image_url: str
    listen_url: str
    youtube_url: str
    language_code: str
    line_pairs: list[dict[str, str]]


_JSON_LD_PATTERN = re.compile(
    r'<script type="application/ld\+json">(?P<payload>.*?)</script>',
    re.DOTALL,
)
_META_CONTENT_PATTERN = r'<meta[^>]+property="{property_name}"[^>]+content="(?P<value>[^"]+)"'
_LINK_HREF_PATTERN = r'<link[^>]+rel="{rel_name}"[^>]+href="(?P<value>[^"]+)"'
_SONG_LIST_ITEM_PATTERN = re.compile(
    r'<li class="songList-table-row --song[^"]*"[^>]*data-name="(?P<title>[^"]+)"[^>]*data-shareurl="(?P<url>https://www\.letras\.(?:com|mus\.br)/[^"]+/[^"]+/)"',
    re.DOTALL,
)
_VERSE_PAIR_PATTERN = re.compile(
    r'<span class="verse">\s*<span[^>]*>(?P<translated>.*?)</span>\s*<span class="romanization">(?P<original>.*?)</span>\s*</span>',
    re.DOTALL,
)
_ORIGINAL_CONTAINER_PATTERNS = [
    re.compile(r'<div class="lyric-original">(?P<body>.*?)</div>\s*<nav class="lyricMenu', re.DOTALL),
    re.compile(r'<div class="lyric-original">(?P<body>.*?)</div>\s*</div>\s*</article>', re.DOTALL),
]
_PARAGRAPH_PATTERN = re.compile(r'<p[^>]*>(?P<body>.*?)</p>', re.DOTALL)
_YOUTUBE_ID_PATTERN = re.compile(r'"YoutubeID":"(?P<video_id>[^"]+)"')


def _normalize_spaces(value: str) -> str:
    return " ".join(unescape(str(value)).split())


def _normalize_title_key(value: str) -> str:
    normalized = slugify(_normalize_spaces(value))
    return normalized.replace('-', ' ')


def _strip_tags(value: str) -> str:
    no_breaks = re.sub(r'<br\s*/?>', '\n', value, flags=re.IGNORECASE)
    no_tags = re.sub(r'<[^>]+>', '', no_breaks)
    return _normalize_spaces(no_tags.replace('\n', ' '))


def _read_html(url: str, *, timeout: int = 12) -> str:
    request = Request(
        url,
        headers={
            'Accept': 'text/html,application/xhtml+xml',
            'User-Agent': settings.PERSONALIZED_FEED_HTTP_USER_AGENT,
        },
    )
    try:
        with urlopen(request, timeout=timeout) as response:
            return response.read().decode('utf-8', errors='replace')
    except Exception as exc:
        raise LetrasScrapeError(str(exc)) from exc


def _extract_meta_value(html: str, *, property_name: str) -> str:
    pattern = re.compile(_META_CONTENT_PATTERN.format(property_name=re.escape(property_name)))
    match = pattern.search(html)
    return _normalize_spaces(match.group('value')) if match else ''


def _extract_link_href(html: str, *, rel_name: str) -> str:
    pattern = re.compile(_LINK_HREF_PATTERN.format(rel_name=re.escape(rel_name)))
    match = pattern.search(html)
    return _normalize_spaces(match.group('value')) if match else ''


def _extract_music_recording_json_ld(html: str) -> dict:
    for match in _JSON_LD_PATTERN.finditer(html):
        raw_payload = match.group('payload').strip()
        try:
            parsed = json.loads(raw_payload)
        except json.JSONDecodeError:
            continue
        if isinstance(parsed, dict) and parsed.get('@type') == 'MusicRecording':
            return parsed
    return {}


def _extract_song_links_from_artist_page(html: str) -> list[tuple[str, str]]:
    return [
        (_normalize_spaces(match.group('title')), match.group('url'))
        for match in _SONG_LIST_ITEM_PATTERN.finditer(html)
    ]


def _match_song_url(track_title: str, candidates: list[tuple[str, str]]) -> str:
    normalized_target = _normalize_title_key(track_title)
    if not normalized_target:
        return ''

    best_score = 0.0
    best_url = ''
    for candidate_title, candidate_url in candidates:
        normalized_candidate = _normalize_title_key(candidate_title)
        if normalized_candidate == normalized_target:
            return candidate_url
        score = SequenceMatcher(None, normalized_target, normalized_candidate).ratio()
        if normalized_target in normalized_candidate or normalized_candidate in normalized_target:
            score += 0.15
        if score > best_score:
            best_score = score
            best_url = candidate_url

    return best_url if best_score >= 0.55 else ''


def _build_artist_urls(artist_name: str) -> list[str]:
    artist_slug = slugify(artist_name)
    if not artist_slug:
        return []
    return [
        f'https://www.letras.com/{artist_slug}/',
        f'https://www.letras.mus.br/{artist_slug}/',
    ]


def resolve_letras_song_url(track_title: str, artist_name: str) -> str:
    last_error: LetrasScrapeError | None = None
    for artist_url in _build_artist_urls(artist_name):
        try:
            artist_html = _read_html(artist_url)
        except LetrasScrapeError as exc:
            last_error = exc
            continue

        song_url = _match_song_url(track_title, _extract_song_links_from_artist_page(artist_html))
        if song_url:
            return song_url

        artist_json_ld = _extract_music_recording_json_ld(artist_html)
        if artist_json_ld:
            candidate_url = _normalize_spaces(artist_json_ld.get('url') or '')
            if candidate_url:
                return candidate_url

    if last_error is not None:
        raise last_error

    artist_slug = slugify(artist_name)
    track_slug = slugify(track_title)
    if artist_slug and track_slug:
        return f'https://www.letras.com/{artist_slug}/{track_slug}/'
    raise LetrasScrapeError('Could not resolve Letras song URL.')


def _extract_original_lines(html: str) -> list[str]:
    for pattern in _ORIGINAL_CONTAINER_PATTERNS:
        match = pattern.search(html)
        if not match:
            continue
        container_html = match.group('body')
        lines: list[str] = []
        for paragraph_match in _PARAGRAPH_PATTERN.finditer(container_html):
            paragraph_html = re.sub(r'<br\s*/?>', '\n', paragraph_match.group('body'), flags=re.IGNORECASE)
            for raw_line in paragraph_html.split('\n'):
                cleaned = _strip_tags(raw_line)
                if cleaned:
                    lines.append(cleaned[:255])
        if lines:
            return lines
    return []


def _extract_translation_pairs(html: str) -> list[dict[str, str]]:
    pairs: list[dict[str, str]] = []
    for match in _VERSE_PAIR_PATTERN.finditer(html):
        translated = _strip_tags(match.group('translated'))[:255]
        original = _strip_tags(match.group('original'))[:255]
        if not translated or not original:
            continue
        pairs.append({'text_en': original, 'text_pt': translated})
    return pairs


def _build_translation_url(source_url: str) -> str:
    parsed = urlparse(source_url)
    host = 'www.letras.mus.br'
    path = parsed.path if parsed.path.endswith('/') else f'{parsed.path}/'
    return f'https://{host}{path}traducao.html'


def _extract_youtube_url(html: str) -> str:
    match = _YOUTUBE_ID_PATTERN.search(html)
    if not match:
        return ''
    return f'https://www.youtube.com/watch?v={match.group("video_id")}'


def fetch_letras_song_data(track_title: str, artist_name: str, *, song_url: str | None = None) -> LetrasSongData:
    resolved_url = song_url or resolve_letras_song_url(track_title, artist_name)
    source_html = _read_html(resolved_url)
    translation_url = _build_translation_url(resolved_url)
    try:
        translation_html = _read_html(translation_url)
    except LetrasScrapeError:
        translation_html = ''

    music_recording = _extract_music_recording_json_ld(source_html)
    resolved_track_title = _normalize_spaces(music_recording.get('name') or track_title)
    artist_payload = music_recording.get('byArtist') if isinstance(music_recording.get('byArtist'), dict) else {}
    resolved_artist_name = _normalize_spaces(artist_payload.get('name') or artist_name)
    cover_image_url = _normalize_spaces(music_recording.get('image') or _extract_meta_value(source_html, property_name='og:image'))
    listen_url = ''
    if isinstance(artist_payload.get('potentialAction'), dict):
        targets = artist_payload['potentialAction'].get('target') or []
        if isinstance(targets, list) and targets:
            listen_url = _normalize_spaces((targets[0] or {}).get('urlTemplate') or '')

    original_lines = _extract_original_lines(source_html)
    translation_pairs = _extract_translation_pairs(translation_html) if translation_html else []
    line_pairs = translation_pairs
    if not line_pairs and original_lines:
        line_pairs = [{'text_en': line, 'text_pt': ''} for line in original_lines]
    if not line_pairs:
        raise LetrasScrapeError('Could not extract lyric lines from Letras.')

    language_code = 'en' if any(re.search(r'[A-Za-z]', item['text_en']) for item in line_pairs) else ''

    return LetrasSongData(
        track_title=resolved_track_title,
        artist_name=resolved_artist_name,
        source_url=_extract_link_href(source_html, rel_name='canonical') or resolved_url,
        translation_url=_extract_link_href(translation_html, rel_name='canonical') if translation_html else translation_url,
        cover_image_url=cover_image_url,
        listen_url=listen_url,
        youtube_url=_extract_youtube_url(source_html),
        language_code=language_code,
        line_pairs=line_pairs,
    )
