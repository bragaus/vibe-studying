"""Cliente minimo para o Ollama local."""

from __future__ import annotations

import json
from typing import Any
from urllib.request import Request, urlopen

from django.conf import settings


class OllamaError(RuntimeError):
    """Erro ao consultar o modelo local."""


class OllamaClient:
    def __init__(self, base_url: str | None = None, model: str | None = None, timeout: int | None = None):
        self.base_url = (base_url or settings.OLLAMA_BASE_URL).rstrip("/")
        self.model = model or settings.OLLAMA_MODEL
        self.timeout = timeout or settings.OLLAMA_TIMEOUT_SECONDS

    def generate_json(self, *, system_prompt: str, user_prompt: str) -> dict:
        if not self.base_url:
            raise OllamaError("OLLAMA_BASE_URL is not configured.")
        if not self.model:
            raise OllamaError("OLLAMA_MODEL is not configured.")

        attempts = [
            ("generate", self._build_generate_payload(system_prompt=system_prompt, user_prompt=user_prompt, force_json=True)),
            ("chat", self._build_chat_payload(system_prompt=system_prompt, user_prompt=user_prompt, force_json=True)),
            ("generate", self._build_generate_payload(system_prompt=system_prompt, user_prompt=user_prompt, force_json=False)),
        ]

        errors: list[str] = []
        for endpoint, payload in attempts:
            try:
                parsed_response = self._request(endpoint, payload)
                return self._extract_json_payload(parsed_response)
            except OllamaError as exc:
                errors.append(f"{endpoint}: {exc}")

        raise OllamaError(" | ".join(errors) if errors else "Ollama returned an empty response.")

    def _build_options(self) -> dict[str, Any]:
        return {
            "temperature": settings.OLLAMA_TEMPERATURE,
            "num_predict": settings.OLLAMA_NUM_PREDICT,
        }

    def _build_generate_payload(self, *, system_prompt: str, user_prompt: str, force_json: bool) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "model": self.model,
            "stream": False,
            "system": system_prompt,
            "prompt": user_prompt,
            "options": self._build_options(),
        }
        if force_json:
            payload["format"] = "json"
        return payload

    def _build_chat_payload(self, *, system_prompt: str, user_prompt: str, force_json: bool) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "model": self.model,
            "stream": False,
            "options": self._build_options(),
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
        }
        if force_json:
            payload["format"] = "json"
        return payload

    def _request(self, endpoint: str, payload: dict[str, Any]) -> dict[str, Any]:
        request = Request(
            f"{self.base_url}/api/{endpoint}",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json", "Accept": "application/json"},
        )

        try:
            with urlopen(request, timeout=self.timeout) as response:
                return json.loads(response.read().decode("utf-8"))
        except Exception as exc:
            raise OllamaError(f"Failed to query Ollama: {exc}") from exc

    def _extract_json_payload(self, parsed_response: dict[str, Any]) -> dict[str, Any]:
        for candidate in self._candidate_payloads(parsed_response):
            if isinstance(candidate, dict):
                return candidate
            if not isinstance(candidate, str) or not candidate.strip():
                continue
            parsed_candidate = self._parse_json_text(candidate)
            if parsed_candidate is not None:
                return parsed_candidate

        raise OllamaError("Ollama returned an empty response.")

    def _candidate_payloads(self, parsed_response: dict[str, Any]) -> list[Any]:
        message = parsed_response.get("message") or {}
        return [
            parsed_response.get("response"),
            parsed_response.get("content"),
            message.get("content"),
            message.get("thinking"),
        ]

    def _parse_json_text(self, raw_value: str) -> dict[str, Any] | None:
        candidates = [raw_value.strip(), self._strip_code_fences(raw_value)]
        extracted_fragment = self._extract_json_fragment(raw_value)
        if extracted_fragment:
            candidates.append(extracted_fragment)

        seen: set[str] = set()
        for candidate in candidates:
            normalized = candidate.strip()
            if not normalized or normalized in seen:
                continue
            seen.add(normalized)
            try:
                parsed = json.loads(normalized)
            except json.JSONDecodeError:
                continue
            if isinstance(parsed, dict):
                return parsed
        return None

    def _strip_code_fences(self, raw_value: str) -> str:
        stripped = raw_value.strip()
        if stripped.startswith("```") and stripped.endswith("```"):
            stripped = stripped[3:-3].strip()
            if stripped.lower().startswith("json"):
                stripped = stripped[4:].strip()
        return stripped

    def _extract_json_fragment(self, raw_value: str) -> str | None:
        start_positions = [index for index, char in enumerate(raw_value) if char in "[{"]
        for start in start_positions:
            stack: list[str] = []
            in_string = False
            escaped = False
            for index in range(start, len(raw_value)):
                char = raw_value[index]
                if in_string:
                    if escaped:
                        escaped = False
                    elif char == "\\":
                        escaped = True
                    elif char == '"':
                        in_string = False
                    continue

                if char == '"':
                    in_string = True
                    continue
                if char in "[{":
                    stack.append(char)
                    continue
                if char in "]}":
                    if not stack:
                        break
                    opener = stack.pop()
                    if (opener == "{" and char != "}") or (opener == "[" and char != "]"):
                        break
                    if not stack:
                        return raw_value[start : index + 1]
            
        return None
