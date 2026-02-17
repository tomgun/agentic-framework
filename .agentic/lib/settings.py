"""
settings.py — Shared settings resolution for the Agentic Framework (Python).

Provides get_setting() with three-level resolution:
  1. Explicit override in STACK.md ## Settings section
  2. Profile preset from .agentic/presets/profiles.conf
  3. Fallback default passed by caller

Usage:
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from settings import get_setting

    val = get_setting(root, "feature_tracking", "no")
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Optional

# Simple module-level cache to avoid re-parsing files within the same process
_cache: dict[str, object] = {}

# ---------------------------------------------------------------------------
# Internal: parse the ## Settings section from STACK.md
# ---------------------------------------------------------------------------

_SETTING_LINE_RE = re.compile(
    r"^\s*-\s*(?P<key>[a-z_][a-z0-9_]*):\s*(?P<value>[^#\n<]+)", re.IGNORECASE
)


def _extract_settings_section(stack_path: Path) -> dict[str, str]:
    """Extract key-value pairs from the ## Settings section of STACK.md."""
    cache_key = f"settings:{stack_path}"
    if cache_key in _cache:
        return _cache[cache_key]  # type: ignore[return-value]

    if not stack_path.exists():
        return {}

    try:
        text = stack_path.read_text(encoding="utf-8")
    except Exception:
        return {}

    settings: dict[str, str] = {}
    in_section = False

    for line in text.splitlines():
        if not in_section:
            if re.match(r"^##\s+Settings", line):
                in_section = True
            continue

        # Stop at next H2 heading (## Something) but NOT ### subsections
        if re.match(r"^##\s+[^#]", line):
            break

        m = _SETTING_LINE_RE.match(line)
        if m:
            key = m.group("key").strip()
            val = m.group("value").strip()
            # Strip inline comments
            val = re.sub(r"\s*#.*$", "", val)
            val = re.sub(r"<!--.*?-->", "", val).strip()
            if val:
                settings[key] = val

    _cache[cache_key] = settings
    return settings


def _search_whole_file(stack_path: Path, key: str) -> str | None:
    """Backward compat: search entire STACK.md for a key."""
    if not stack_path.exists():
        return None

    try:
        text = stack_path.read_text(encoding="utf-8")
    except Exception:
        return None

    # Match "- key: value" or "key: value" (case-insensitive key match)
    pattern = re.compile(
        rf"^\s*-?\s*{re.escape(key)}:\s*(?P<value>[^#\n<]+)",
        re.IGNORECASE | re.MULTILINE,
    )
    m = pattern.search(text)
    if m:
        val = m.group("value").strip()
        val = re.sub(r"\s*#.*$", "", val)
        val = re.sub(r"<!--.*?-->", "", val).strip()
        return val if val else None
    return None


# ---------------------------------------------------------------------------
# Internal: parse profiles.conf
# ---------------------------------------------------------------------------

def _load_profile_presets(presets_path: Path) -> dict[str, dict[str, str]]:
    """Load profile presets from profiles.conf.

    Returns: {"discovery": {"feature_tracking": "no", ...}, "formal": {...}}
    """
    cache_key = f"presets:{presets_path}"
    if cache_key in _cache:
        return _cache[cache_key]  # type: ignore[return-value]

    if not presets_path.exists():
        return {}

    profiles: dict[str, dict[str, str]] = {}
    try:
        for line in presets_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            # Format: profile.setting=value
            if "=" not in line or "." not in line.split("=")[0]:
                continue
            lhs, rhs = line.split("=", 1)
            parts = lhs.split(".", 1)
            if len(parts) != 2:
                continue
            profile_name, setting_key = parts[0].strip(), parts[1].strip()
            profiles.setdefault(profile_name, {})[setting_key] = rhs.strip()
    except Exception:
        pass

    _cache[cache_key] = profiles
    return profiles


# ---------------------------------------------------------------------------
# Internal: resolve profile
# ---------------------------------------------------------------------------

def _resolve_profile(root: Path) -> str:
    """Determine profile from STACK.md or infer from structure."""
    stack = root / "STACK.md"

    # Try ## Settings section first
    settings = _extract_settings_section(stack)
    raw = settings.get("profile", "")
    if raw.lower() in ("discovery", "formal"):
        return raw.lower()

    # Try whole-file search (backward compat)
    raw = _search_whole_file(stack, "Profile") or ""
    if raw.lower() in ("discovery", "formal"):
        return raw.lower()

    # Infer from directory structure
    if (root / "spec").is_dir():
        return "formal"
    return "discovery"


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def get_setting(root: Path, key: str, default: str = "") -> str:
    """Resolve a setting with three-level fallback.

    Resolution order:
      1. Explicit value in STACK.md ## Settings section
      2. Profile preset from .agentic/presets/profiles.conf
      3. Fallback default

    If no ## Settings section exists, falls back to whole-file search
    for backward compatibility.
    """
    if key == "profile":
        return _resolve_profile(root)

    stack = root / "STACK.md"
    presets_path = root / ".agentic" / "presets" / "profiles.conf"

    # 1. Check ## Settings section
    settings = _extract_settings_section(stack)
    if key in settings:
        return settings[key]

    # 2. If no ## Settings section, try whole-file (backward compat)
    if not settings:
        val = _search_whole_file(stack, key)
        if val is not None:
            return val

    # 3. Check profile preset
    profile = _resolve_profile(root)
    presets = _load_profile_presets(presets_path)
    profile_defaults = presets.get(profile, {})
    if key in profile_defaults:
        return profile_defaults[key]

    # 4. Return fallback default
    return default


def get_setting_source(root: Path, key: str) -> str:
    """Return the source of a setting value: 'explicit', 'preset', 'default', or 'inferred'."""
    if key == "profile":
        stack = root / "STACK.md"
        settings = _extract_settings_section(stack)
        if "profile" in settings:
            return "explicit"
        if _search_whole_file(stack, "Profile"):
            return "explicit"
        return "inferred"

    stack = root / "STACK.md"
    presets_path = root / ".agentic" / "presets" / "profiles.conf"

    settings = _extract_settings_section(stack)
    if key in settings:
        return "explicit"

    if not settings:
        val = _search_whole_file(stack, key)
        if val is not None:
            return "explicit"

    profile = _resolve_profile(root)
    presets = _load_profile_presets(presets_path)
    if key in presets.get(profile, {}):
        return "preset"

    return "default"


def validate_constraints(root: Path) -> list[str]:
    """Check constraint rules. Returns list of violation messages."""
    constraints_path = root / ".agentic" / "presets" / "constraints.conf"
    if not constraints_path.exists():
        return []

    violations: list[str] = []
    try:
        for line in constraints_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if " -> " not in line:
                continue

            ante_part, cons_part = line.split(" -> ", 1)
            ante_key, ante_val = ante_part.split("=", 1)
            cons_key, cons_allowed_str = cons_part.split("=", 1)

            ante_key = ante_key.strip()
            ante_val = ante_val.strip()
            cons_key = cons_key.strip()
            allowed = [v.strip() for v in cons_allowed_str.split("|")]

            current_ante = get_setting(root, ante_key)
            if current_ante != ante_val:
                continue  # Rule doesn't apply

            current_cons = get_setting(root, cons_key)
            if current_cons not in allowed:
                violations.append(
                    f"{ante_key}={ante_val} requires {cons_key}={'|'.join(allowed)}, "
                    f"but got '{current_cons}'"
                )
    except Exception:
        pass

    return violations
