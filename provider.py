#!/usr/bin/env python3
"""
Provider Cascade — cloud-first model routing with local fallback.

Manages an interleaved list of (provider, model) combinations,
health tracking with exponential backoff, and preference overrides.
"""

import os
import time
from datetime import datetime

PREFERENCE_FILE = "my-core/preferred-provider.txt"
BASE_COOLDOWN = 1800       # 30 minutes
MAX_COOLDOWN = 7200        # 2 hours
DEFAULT_PREFERENCE_LOOPS = 7


class ProviderCascade:

    def __init__(self, providers_config, local_fallback_config):
        self._providers = providers_config or []
        self._local = local_fallback_config or {}
        self._combos = self._build_interleaved()
        self._health = {}  # (provider, model) -> {"failed_until": float, "backoff": int}

    def _build_interleaved(self):
        """Flatten provider+model pairs into an interleaved list that never
        calls the same provider twice in a row."""
        queues = []
        for p in self._providers:
            name = p["name"]
            for m in p.get("models", []):
                queues.append((name, m))

        if not queues:
            return []

        by_provider = {}
        for name, model in queues:
            by_provider.setdefault(name, []).append(model)

        provider_order = list(by_provider.keys())
        iterators = {p: iter(models) for p, models in by_provider.items()}

        result = []
        while iterators:
            exhausted = []
            for p in provider_order:
                if p not in iterators:
                    continue
                try:
                    model = next(iterators[p])
                    result.append((p, model))
                except StopIteration:
                    exhausted.append(p)
            for p in exhausted:
                del iterators[p]

        return result

    def _get_provider_config(self, provider_name):
        for p in self._providers:
            if p["name"] == provider_name:
                return p
        return None

    def _make_client(self, api_base, api_key):
        from openai import OpenAI
        base = api_base.rstrip("/")
        if not base.endswith("/v1"):
            base += "/v1"
        return OpenAI(base_url=base, api_key=api_key)

    def _make_local_client(self):
        if not self._local:
            return None
        from openai import OpenAI
        base = self._local.get("api_base", "http://localhost:11434").rstrip("/")
        if not base.endswith("/v1"):
            base += "/v1"
        return OpenAI(base_url=base, api_key="ollama")

    def _is_healthy(self, provider_name, model_name):
        key = (provider_name, model_name)
        info = self._health.get(key)
        if info is None:
            return True
        return time.time() >= info["failed_until"]

    def _load_preference(self, loop_count):
        """Read preference file. Returns (provider, model) or None if expired/missing."""
        try:
            with open(PREFERENCE_FILE) as f:
                lines = f.read().strip().splitlines()
            if len(lines) < 3:
                return None
            provider = lines[0].strip()
            model = lines[1].strip()
            expires_at_loop = int(lines[2].strip())
            if loop_count > expires_at_loop:
                os.remove(PREFERENCE_FILE)
                return None
            return (provider, model)
        except (FileNotFoundError, ValueError, OSError):
            return None

    def get_client(self, loop_count):
        """Return (client, provider_name, model_name, mode).
        mode is 'cloud' or 'degraded'."""

        pref = self._load_preference(loop_count)
        if pref:
            prov_name, model_name = pref
            cfg = self._get_provider_config(prov_name)
            if cfg and self._is_healthy(prov_name, model_name):
                try:
                    client = self._make_client(cfg["api_base"], cfg["api_key"])
                    return (client, prov_name, model_name, "cloud")
                except Exception:
                    pass

        if not self._combos:
            return self._fallback_local()

        total = len(self._combos)
        start_idx = loop_count % total

        for offset in range(total):
            idx = (start_idx + offset) % total
            prov_name, model_name = self._combos[idx]

            if not self._is_healthy(prov_name, model_name):
                continue

            cfg = self._get_provider_config(prov_name)
            if cfg is None:
                continue

            try:
                client = self._make_client(cfg["api_base"], cfg["api_key"])
                return (client, prov_name, model_name, "cloud")
            except Exception:
                self.report_failure(prov_name, model_name)
                continue

        return self._fallback_local()

    def _fallback_local(self):
        """Return local Ollama client or None."""
        client = self._make_local_client()
        if client:
            model = self._local.get("model", "qwen3:8b")
            return (client, "local", model, "degraded")
        return (None, None, None, "degraded")

    def report_success(self, provider_name, model_name):
        key = (provider_name, model_name)
        self._health.pop(key, None)

    def report_failure(self, provider_name, model_name):
        key = (provider_name, model_name)
        info = self._health.get(key)
        if info is None:
            backoff = BASE_COOLDOWN
        else:
            backoff = min(info["backoff"] * 2, MAX_COOLDOWN)
        self._health[key] = {
            "failed_until": time.time() + backoff,
            "backoff": backoff,
        }

    def set_preference(self, provider_name, model_name, loops=DEFAULT_PREFERENCE_LOOPS, current_loop=0):
        """Write preference override that auto-expires after N loops."""
        expires_at = current_loop + loops
        try:
            os.makedirs(os.path.dirname(PREFERENCE_FILE) or ".", exist_ok=True)
            with open(PREFERENCE_FILE, "w") as f:
                f.write(f"{provider_name}\n{model_name}\n{expires_at}\n")
        except OSError:
            pass

    def clear_preference(self):
        try:
            os.remove(PREFERENCE_FILE)
        except FileNotFoundError:
            pass

    def get_status(self):
        """Return health status dict for display or agent tool output."""
        now = time.time()
        status = {"combos": [], "local_fallback": bool(self._local)}
        for prov, model in self._combos:
            key = (prov, model)
            info = self._health.get(key)
            if info is None or now >= info["failed_until"]:
                health = "healthy"
                cooldown_remaining = 0
            else:
                health = "cooling_down"
                cooldown_remaining = int(info["failed_until"] - now)
            status["combos"].append({
                "provider": prov,
                "model": model,
                "health": health,
                "cooldown_remaining_s": cooldown_remaining,
            })

        pref_info = None
        try:
            with open(PREFERENCE_FILE) as f:
                lines = f.read().strip().splitlines()
            if len(lines) >= 3:
                pref_info = {
                    "provider": lines[0].strip(),
                    "model": lines[1].strip(),
                    "expires_at_loop": int(lines[2].strip()),
                }
        except (FileNotFoundError, ValueError, OSError):
            pass
        status["preference"] = pref_info
        return status
