"""
visual.py -- AI-powered visual review of screenshots (F-0168).

Uses the Anthropic API directly (multimodal messages) to review screenshots
for visual issues. Gracefully degrades if the SDK or API key is unavailable.

Usage:
    from auto.visual import visual_review
    result = visual_review(["path/to/screenshot.png"])
"""
from __future__ import annotations

import base64
import os
import re
from pathlib import Path

# Import VisualReviewResult from verify to avoid circular dependency at module level.
# We use a late import pattern instead.

_MAX_IMAGES_PER_REVIEW = 10

_REVIEW_PROMPT = """\
You are reviewing screenshots from an application's E2E test run.

Analyze each screenshot for:
1. Layout issues (overlapping elements, broken alignment, overflow)
2. Visual bugs (missing images, broken icons, rendering artifacts)
3. Text issues (truncated text, overlapping labels, wrong encoding)
4. Responsive issues (elements off-screen, scrollbars where unexpected)
5. Missing elements (empty states that should have content, missing buttons)

Respond with exactly this format:

SUMMARY: <1-2 sentence overview of what you see>

CONCERNS:
- <concern 1>
- <concern 2>
(or "None" if everything looks fine)
"""

_EXT_TO_MEDIA_TYPE = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
}


def _encode_image(path: str) -> tuple[str, str]:
    """Base64-encode an image file. Returns (base64_data, media_type)."""
    p = Path(path)
    media_type = _EXT_TO_MEDIA_TYPE.get(p.suffix.lower(), "image/png")
    with open(path, "rb") as f:
        data = base64.standard_b64encode(f.read()).decode("ascii")
    return data, media_type


def _parse_summary(text: str) -> str:
    """Extract SUMMARY: line from response."""
    match = re.search(r"SUMMARY:\s*(.+?)(?:\n|$)", text)
    return match.group(1).strip() if match else ""


def _parse_concerns(text: str) -> list[str]:
    """Extract CONCERNS: list from response."""
    match = re.search(r"CONCERNS:\s*\n((?:\s*-\s*.+\n?)+)", text)
    if not match:
        return []
    lines = match.group(1).strip().split("\n")
    concerns = []
    for line in lines:
        line = line.strip().lstrip("- ").strip()
        if line and line.lower() != "none":
            concerns.append(line)
    return concerns


def visual_review(
    screenshot_paths: list[str],
    context: str = "",
    model: str = "claude-sonnet-4-20250514",
) -> "VisualReviewResult":
    """Run AI visual review on screenshots.

    Args:
        screenshot_paths: Paths to screenshot image files.
        context: Optional context about what the screenshots show.
        model: Anthropic model to use.

    Returns:
        VisualReviewResult (never raises).
    """
    from auto.verify import VisualReviewResult

    if not screenshot_paths:
        return VisualReviewResult(
            performed=False,
            error="No screenshots provided",
        )

    # Check for anthropic SDK
    try:
        import anthropic  # noqa: F811
    except ImportError:
        return VisualReviewResult(
            performed=False,
            error="anthropic SDK not installed (pip install anthropic)",
        )

    # Check for API key
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        return VisualReviewResult(
            performed=False,
            error="ANTHROPIC_API_KEY environment variable not set",
        )

    # Cap images
    paths = screenshot_paths[:_MAX_IMAGES_PER_REVIEW]

    # Build multimodal content
    content: list[dict] = []
    for path in paths:
        try:
            data, media_type = _encode_image(path)
            content.append({
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": media_type,
                    "data": data,
                },
            })
        except (OSError, IOError):
            continue

    if not content:
        return VisualReviewResult(
            performed=False,
            error="Could not read any screenshot files",
        )

    prompt_text = _REVIEW_PROMPT
    if context:
        prompt_text += f"\n\nContext: {context}"

    content.append({"type": "text", "text": prompt_text})

    try:
        client = anthropic.Anthropic(api_key=api_key)
        response = client.messages.create(
            model=model,
            max_tokens=1024,
            messages=[{"role": "user", "content": content}],
        )
        text = response.content[0].text if response.content else ""

        return VisualReviewResult(
            performed=True,
            screenshots_reviewed=len(content) - 1,  # minus the text block
            summary=_parse_summary(text),
            concerns=_parse_concerns(text),
        )
    except Exception as e:
        return VisualReviewResult(
            performed=False,
            error=f"API error: {e}",
        )
