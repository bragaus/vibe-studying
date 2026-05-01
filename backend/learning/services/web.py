"""Busca web e extracao leve de paginas para bootstrap do feed."""

from __future__ import annotations

from dataclasses import dataclass
from html import unescape
from html.parser import HTMLParser
import json
import logging
import re
from urllib.parse import parse_qs, quote_plus, urlencode, urlparse
from urllib.request import Request, urlopen

from django.conf import settings


logger = logging.getLogger(__name__)


class WebSearchError(RuntimeError):
    """Erro operacional ao consultar a busca ou extrair uma pagina."""


@dataclass(slots=True)
class WebSearchResult:
    title: str
    url: str
    snippet: str
    thumbnail_url: str = ""


@dataclass(slots=True)
class ExtractedSource:
    query: str
    match_reason: str
    content_type: str
    title: str
    url: str
    snippet: str
    source_title: str
    source_domain: str
    cover_image_url: str
    text_excerpt: str


def _normalize_spaces(value: str) -> str:
    return " ".join(unescape(value).split())


def _is_http_url(value: str) -> bool:
    parsed = urlparse(value)
    return parsed.scheme in {"http", "https"} and bool(parsed.netloc)


def _read_url(request: Request, *, timeout: int) -> tuple[bytes, object]:
    try:
        with urlopen(request, timeout=timeout) as response:
            return response.read(), response.headers
    except Exception as exc:
        raise WebSearchError(str(exc)) from exc


class SearxngSearchClient:
    def __init__(self, base_url: str | None = None, timeout: int | None = None):
        self.base_url = (base_url or settings.SEARXNG_BASE_URL).rstrip("/")
        self.timeout = timeout or settings.PERSONALIZED_FEED_SEARCH_TIMEOUT_SECONDS

    def search(self, query: str, limit: int = 5) -> list[WebSearchResult]:
        if not self.base_url:
            raise WebSearchError("SEARXNG_BASE_URL is not configured.")

        params = urlencode(
            {
                "q": query,
                "format": "json",
                "language": settings.PERSONALIZED_FEED_SEARCH_LANGUAGE,
                "categories": "general",
                "safesearch": 0,
            }
        )
        request = Request(
            f"{self.base_url}/search?{params}",
            headers={"Accept": "application/json", "User-Agent": settings.PERSONALIZED_FEED_HTTP_USER_AGENT},
        )

        try:
            raw_payload, _ = _read_url(request, timeout=self.timeout)
            payload = json.loads(raw_payload.decode("utf-8"))
        except Exception as exc:
            raise WebSearchError(f"Failed to query SearXNG: {exc}") from exc

        raw_results = payload.get("results") or []
        parsed_results: list[WebSearchResult] = []
        for item in raw_results:
            url = str(item.get("url") or "").strip()
            if not _is_http_url(url):
                continue

            parsed_results.append(
                WebSearchResult(
                    title=_normalize_spaces(str(item.get("title") or "Untitled source")),
                    url=url,
                    snippet=_normalize_spaces(str(item.get("content") or "")),
                    thumbnail_url=str(item.get("img_src") or item.get("thumbnail") or "").strip(),
                )
            )
            if len(parsed_results) >= limit:
                break

        return parsed_results


class _DuckDuckGoHTMLResultsParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self._capture_title = False
        self._capture_snippet = False
        self._title_buffer: list[str] = []
        self._snippet_buffer: list[str] = []
        self._current_url = ""
        self._pending_titles: list[tuple[str, str]] = []
        self.snippets: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]):
        attrs_dict = {key.lower(): value or "" for key, value in attrs}
        class_names = attrs_dict.get("class", "")
        if tag == "a" and "result__a" in class_names:
            self._capture_title = True
            self._title_buffer = []
            self._current_url = attrs_dict.get("href", "")
        elif tag in {"a", "div"} and "result__snippet" in class_names:
            self._capture_snippet = True
            self._snippet_buffer = []

    def handle_data(self, data: str):
        if self._capture_title:
            self._title_buffer.append(data)
        if self._capture_snippet:
            self._snippet_buffer.append(data)

    def handle_endtag(self, tag: str):
        if tag == "a" and self._capture_title:
            title = _normalize_spaces("".join(self._title_buffer))
            if title:
                self._pending_titles.append((title, self._current_url))
            self._capture_title = False
            self._title_buffer = []
            self._current_url = ""
            return

        if tag in {"a", "div"} and self._capture_snippet:
            snippet = _normalize_spaces("".join(self._snippet_buffer))
            if snippet:
                self.snippets.append(snippet)
            self._capture_snippet = False
            self._snippet_buffer = []

    def build_results(self, limit: int) -> list[WebSearchResult]:
        results: list[WebSearchResult] = []
        for index, (title, raw_url) in enumerate(self._pending_titles):
            url = normalize_duckduckgo_result_url(raw_url)
            if not _is_http_url(url):
                continue
            results.append(
                WebSearchResult(
                    title=title,
                    url=url,
                    snippet=self.snippets[index] if index < len(self.snippets) else "",
                )
            )
            if len(results) >= limit:
                break
        return results


def normalize_duckduckgo_result_url(raw_url: str) -> str:
    cleaned_url = unescape(raw_url).strip()
    if cleaned_url.startswith("//"):
        cleaned_url = f"https:{cleaned_url}"
    if cleaned_url.startswith("/"):
        cleaned_url = f"https://duckduckgo.com{cleaned_url}"

    parsed = urlparse(cleaned_url)
    if parsed.netloc.endswith("duckduckgo.com") and parsed.path.startswith("/l/"):
        encoded_targets = parse_qs(parsed.query).get("uddg") or []
        if encoded_targets:
            return encoded_targets[0]
    return cleaned_url


class DuckDuckGoSearchClient:
    base_url = "https://html.duckduckgo.com/html/"

    def __init__(self, timeout: int | None = None):
        self.timeout = timeout or settings.PERSONALIZED_FEED_SEARCH_TIMEOUT_SECONDS

    def search(self, query: str, limit: int = 5) -> list[WebSearchResult]:
        request = Request(
            f"{self.base_url}?q={quote_plus(query)}",
            headers={
                "Accept": "text/html,application/xhtml+xml",
                "User-Agent": settings.PERSONALIZED_FEED_HTTP_USER_AGENT,
            },
        )
        try:
            raw_html, _ = _read_url(request, timeout=self.timeout)
        except WebSearchError as exc:
            raise WebSearchError(f"Failed to query DuckDuckGo: {exc}") from exc

        parser = _DuckDuckGoHTMLResultsParser()
        parser.feed(raw_html.decode("utf-8", errors="replace"))
        parser.close()
        return parser.build_results(limit)


class WikipediaSearchClient:
    api_url = "https://en.wikipedia.org/w/api.php"

    def __init__(self, timeout: int | None = None):
        self.timeout = timeout or settings.PERSONALIZED_FEED_SEARCH_TIMEOUT_SECONDS

    def search(self, query: str, limit: int = 5) -> list[WebSearchResult]:
        params = urlencode(
            {
                "action": "query",
                "list": "search",
                "format": "json",
                "utf8": 1,
                "srsearch": query,
                "srlimit": limit,
            }
        )
        request = Request(
            f"{self.api_url}?{params}",
            headers={"Accept": "application/json", "User-Agent": settings.PERSONALIZED_FEED_HTTP_USER_AGENT},
        )
        try:
            raw_payload, _ = _read_url(request, timeout=self.timeout)
            payload = json.loads(raw_payload.decode("utf-8"))
        except Exception as exc:
            raise WebSearchError(f"Failed to query Wikipedia: {exc}") from exc

        results: list[WebSearchResult] = []
        for item in payload.get("query", {}).get("search", []):
            title = _normalize_spaces(str(item.get("title") or ""))
            if not title:
                continue
            page_title = title.replace(" ", "_")
            snippet = _normalize_spaces(re.sub(r"<[^>]+>", " ", str(item.get("snippet") or "")))
            results.append(
                WebSearchResult(
                    title=title,
                    url=f"https://en.wikipedia.org/wiki/{page_title}",
                    snippet=snippet,
                )
            )
            if len(results) >= limit:
                break
        return results


class MultiSearchClient:
    def __init__(self, providers: list | None = None):
        self.providers = providers or self._build_default_providers()

    def _build_default_providers(self) -> list:
        # SearXNG saiu do caminho padrao para simplificar o bootstrap local.
        # Hoje o fluxo usa apenas internet publica + Ollama local.
        return [WikipediaSearchClient(), DuckDuckGoSearchClient()]

    def search(self, query: str, limit: int = 5) -> list[WebSearchResult]:
        results: list[WebSearchResult] = []
        seen_urls: set[str] = set()
        errors: list[str] = []

        for provider in self.providers:
            provider_name = provider.__class__.__name__
            try:
                provider_results = provider.search(query, limit=limit)
            except WebSearchError as exc:
                errors.append(f"{provider_name}: {exc}")
                logger.warning("search provider failed", extra={"provider": provider_name, "query": query, "error": str(exc)})
                continue

            for item in provider_results:
                normalized_url = item.url.rstrip("/")
                if normalized_url in seen_urls:
                    continue
                seen_urls.add(normalized_url)
                results.append(item)
                if len(results) >= limit:
                    return results

        if results:
            return results
        if errors:
            raise WebSearchError("All search providers failed: " + " | ".join(errors))
        return []


class _SimpleHTMLExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self._active_tag: str | None = None
        self._buffer: list[str] = []
        self.title = ""
        self.description = ""
        self.og_title = ""
        self.og_image = ""
        self.text_chunks: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]):
        attrs_dict = {key.lower(): value or "" for key, value in attrs}
        if tag == "meta":
            property_name = attrs_dict.get("property", "").lower()
            name = attrs_dict.get("name", "").lower()
            content = _normalize_spaces(attrs_dict.get("content", ""))
            if property_name == "og:title" and content:
                self.og_title = content
            elif property_name == "og:image" and content:
                self.og_image = content
            elif name == "description" and content:
                self.description = content

        if tag in {"title", "p", "h1", "h2", "h3", "li"}:
            self._active_tag = tag
            self._buffer = []

    def handle_data(self, data: str):
        if self._active_tag is not None:
            self._buffer.append(data)

    def handle_endtag(self, tag: str):
        if self._active_tag != tag:
            return

        text = _normalize_spaces("".join(self._buffer))
        if not text:
            self._active_tag = None
            self._buffer = []
            return

        if tag == "title":
            self.title = text
        elif len(self.text_chunks) < settings.PERSONALIZED_FEED_MAX_SOURCE_SEGMENTS:
            self.text_chunks.append(text)

        self._active_tag = None
        self._buffer = []


def extract_source_document(
    url: str,
    *,
    query: str,
    match_reason: str,
    content_type: str,
    fallback_title: str = "",
    fallback_snippet: str = "",
    fallback_image_url: str = "",
) -> ExtractedSource:
    if not _is_http_url(url):
        raise WebSearchError(f"Invalid source URL: {url}")

    request = Request(
        url,
        headers={
            "Accept": "text/html,application/xhtml+xml",
            "User-Agent": settings.PERSONALIZED_FEED_HTTP_USER_AGENT,
        },
    )
    try:
        with urlopen(request, timeout=settings.PERSONALIZED_FEED_FETCH_TIMEOUT_SECONDS) as response:
            content_type_header = response.headers.get("Content-Type", "")
            if "html" not in content_type_header:
                raise WebSearchError(f"Unsupported content type for {url}: {content_type_header}")

            raw_html = response.read(settings.PERSONALIZED_FEED_MAX_SOURCE_BYTES)
            charset = response.headers.get_content_charset() or "utf-8"
    except Exception as exc:
        raise WebSearchError(f"Failed to fetch source {url}: {exc}") from exc

    html = raw_html.decode(charset, errors="replace")
    html = re.sub(r"<script\b[^>]*>.*?</script>", " ", html, flags=re.IGNORECASE | re.DOTALL)
    html = re.sub(r"<style\b[^>]*>.*?</style>", " ", html, flags=re.IGNORECASE | re.DOTALL)

    parser = _SimpleHTMLExtractor()
    parser.feed(html)
    parser.close()

    text_excerpt = " ".join(parser.text_chunks[: settings.PERSONALIZED_FEED_MAX_SOURCE_SEGMENTS])
    if not text_excerpt:
        text_excerpt = _normalize_spaces(re.sub(r"<[^>]+>", " ", html))
    text_excerpt = text_excerpt[: settings.PERSONALIZED_FEED_MAX_EXTRACTED_CHARS]

    parsed_url = urlparse(url)
    source_title = parser.og_title or parser.title or fallback_title or parsed_url.netloc
    cover_image_url = parser.og_image or fallback_image_url
    if not _is_http_url(cover_image_url):
        cover_image_url = ""

    return ExtractedSource(
        query=query,
        match_reason=match_reason,
        content_type=content_type,
        title=fallback_title or source_title,
        url=url,
        snippet=fallback_snippet or parser.description,
        source_title=source_title[:255],
        source_domain=parsed_url.netloc[:255],
        cover_image_url=cover_image_url,
        text_excerpt=text_excerpt,
    )
