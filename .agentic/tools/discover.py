#!/usr/bin/env python3
"""
discover.py - Codebase analysis engine for brownfield onboarding.

Analyzes an existing project to detect tech stack, architecture,
entry points, test patterns, and features. Outputs a JSON discovery report.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# Import shared settings library
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "lib"))
from settings import get_setting

# Directories to always exclude from scanning
EXCLUDE_DIRS = {
    ".agentic", ".agentic-journal", ".agentic-state",
    "node_modules", ".git", "__pycache__", "build", "dist",
    ".next", ".nuxt", "target", "vendor", ".venv", "venv",
    "env", ".env", ".tox", ".mypy_cache", ".pytest_cache",
    "coverage", ".coverage", "htmlcov", ".eggs", "*.egg-info",
    ".gradle", ".idea", ".vscode", "bin", "obj",
}

# Directories that are NOT features (utility/infra)
NON_FEATURE_DIRS = {
    "utils", "util", "lib", "libs", "helpers", "helper",
    "common", "shared", "config", "configs", "configuration",
    "scripts", "script", "tools", "tool", "build", "dist",
    "node_modules", "__pycache__", ".git", ".agentic",
    "assets", "static", "public", "resources", "res",
    "fixtures", "mocks", "stubs", "testdata", "test_data",
    "types", "interfaces", "models", "schemas", "migrations",
    "docs", "doc", "documentation", "examples", "example",
    "vendor", "third_party", "external", "generated", "gen",
    "internal", "pkg", "cmd",  # Go conventions (cmd handled separately)
}

# Source file extensions
SOURCE_EXTENSIONS = {
    ".py", ".ts", ".js", ".tsx", ".jsx", ".go", ".rs", ".java",
    ".rb", ".gd", ".cs", ".cpp", ".c", ".swift", ".kt", ".scala",
    ".php", ".ex", ".exs", ".hs", ".ml", ".clj",
}

# Max limits for performance
MAX_FILES_SCAN = 10000
MAX_DEPTH = 5
MAX_FEATURES = 50


def should_exclude(path: Path) -> bool:
    """Check if a path should be excluded from scanning."""
    parts = path.parts
    return any(part in EXCLUDE_DIRS or part.startswith(".") for part in parts)


def count_source_files(root: Path) -> dict[str, int]:
    """Count source files by extension."""
    counts: dict[str, int] = {}
    total = 0
    for dirpath, dirnames, filenames in os.walk(root):
        rel = Path(dirpath).relative_to(root)
        if should_exclude(rel) or len(rel.parts) > MAX_DEPTH:
            dirnames.clear()
            continue
        # Prune excluded dirs
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS and not d.startswith(".")]
        for f in filenames:
            ext = Path(f).suffix.lower()
            if ext in SOURCE_EXTENSIONS:
                counts[ext] = counts.get(ext, 0) + 1
                total += 1
                if total >= MAX_FILES_SCAN:
                    return counts
    return counts


def detect_stack(root: Path) -> dict:
    """Detect tech stack from config files and source analysis."""
    stack: dict = {
        "language": None,
        "framework": None,
        "runtime": None,
        "package_manager": None,
        "test_framework": None,
        "build_tool": None,
        "confidence": {},
    }

    # --- Language detection from config files (high confidence) ---
    config_signals: list[tuple[str, str, str, str]] = [
        # (file, language, field, confidence)
        # tsconfig before package.json so TypeScript takes priority
        ("tsconfig.json", "TypeScript", "language", "high"),
        ("package.json", "JavaScript/TypeScript", "language", "high"),
        ("pyproject.toml", "Python", "language", "high"),
        ("requirements.txt", "Python", "language", "high"),
        ("setup.py", "Python", "language", "high"),
        ("Pipfile", "Python", "language", "high"),
        ("Cargo.toml", "Rust", "language", "high"),
        ("go.mod", "Go", "language", "high"),
        ("Gemfile", "Ruby", "language", "high"),
        ("build.gradle", "Java/Kotlin", "language", "high"),
        ("build.gradle.kts", "Kotlin", "language", "high"),
        ("pom.xml", "Java", "language", "high"),
        ("composer.json", "PHP", "language", "high"),
        ("mix.exs", "Elixir", "language", "high"),
        ("Makefile", None, "build_tool", "medium"),
        ("CMakeLists.txt", "C/C++", "language", "high"),
        ("project.godot", "GDScript", "language", "high"),
    ]

    for filename, lang, field, confidence in config_signals:
        if (root / filename).exists():
            if lang and not stack["language"]:
                stack["language"] = lang
                stack["confidence"]["language"] = confidence
            elif field == "build_tool" and not stack["build_tool"]:
                stack["build_tool"] = filename.split(".")[0]

    # Refine language from source file counts
    if not stack["language"]:
        counts = count_source_files(root)
        if counts:
            primary_ext = max(counts, key=counts.get)
            ext_to_lang = {
                ".py": "Python", ".ts": "TypeScript", ".tsx": "TypeScript",
                ".js": "JavaScript", ".jsx": "JavaScript",
                ".go": "Go", ".rs": "Rust", ".java": "Java",
                ".rb": "Ruby", ".gd": "GDScript", ".cs": "C#",
                ".cpp": "C++", ".c": "C", ".swift": "Swift",
                ".kt": "Kotlin", ".scala": "Scala", ".php": "PHP",
            }
            stack["language"] = ext_to_lang.get(primary_ext, primary_ext)
            stack["confidence"]["language"] = "medium"

    # --- Framework detection ---
    framework_signals = _detect_framework(root, stack.get("language"))
    if "framework" in framework_signals:
        stack["framework"] = framework_signals["framework"]
    if "confidence" in framework_signals:
        stack["confidence"].update(framework_signals["confidence"])

    # --- Package manager ---
    pm_signals = [
        ("pnpm-lock.yaml", "pnpm"),
        ("yarn.lock", "yarn"),
        ("package-lock.json", "npm"),
        ("bun.lockb", "bun"),
        ("uv.lock", "uv"),
        ("Pipfile.lock", "pipenv"),
        ("poetry.lock", "poetry"),
        ("Cargo.lock", "cargo"),
        ("go.sum", "go"),
        ("Gemfile.lock", "bundler"),
    ]
    for filename, pm in pm_signals:
        if (root / filename).exists():
            stack["package_manager"] = pm
            stack["confidence"]["package_manager"] = "high"
            break

    # --- Runtime ---
    if not stack["runtime"]:
        if (root / ".python-version").exists():
            try:
                stack["runtime"] = f"Python {(root / '.python-version').read_text().strip()}"
                stack["confidence"]["runtime"] = "high"
            except Exception:
                pass
        elif (root / ".node-version").exists():
            try:
                stack["runtime"] = f"Node {(root / '.node-version').read_text().strip()}"
                stack["confidence"]["runtime"] = "high"
            except Exception:
                pass
        elif (root / ".nvmrc").exists():
            try:
                stack["runtime"] = f"Node {(root / '.nvmrc').read_text().strip()}"
                stack["confidence"]["runtime"] = "high"
            except Exception:
                pass
        elif (root / "go.mod").exists():
            try:
                content = (root / "go.mod").read_text()
                m = re.search(r"^go\s+(\S+)", content, re.MULTILINE)
                if m:
                    stack["runtime"] = f"Go {m.group(1)}"
                    stack["confidence"]["runtime"] = "high"
            except Exception:
                pass

    # --- Test framework ---
    stack["test_framework"] = _detect_test_framework(root, stack.get("language"))

    return stack


def _detect_framework(root: Path, language: str | None) -> dict:
    """Detect application framework."""
    result: dict = {}

    # Check package.json for JS/TS frameworks
    pkg_json = root / "package.json"
    if pkg_json.exists():
        try:
            pkg = json.loads(pkg_json.read_text())
            deps = {}
            deps.update(pkg.get("dependencies", {}))
            deps.update(pkg.get("devDependencies", {}))

            js_frameworks = [
                ("next", "Next.js"), ("nuxt", "Nuxt"), ("@angular/core", "Angular"),
                ("svelte", "SvelteKit"), ("vue", "Vue"), ("react", "React"),
                ("express", "Express"), ("fastify", "Fastify"), ("koa", "Koa"),
                ("hono", "Hono"), ("astro", "Astro"), ("gatsby", "Gatsby"),
                ("remix", "Remix"), ("electron", "Electron"),
            ]
            for pkg_name, fw_name in js_frameworks:
                if pkg_name in deps:
                    result["framework"] = fw_name
                    result.setdefault("confidence", {})["framework"] = "high"
                    break
        except Exception:
            pass

    # Check pyproject.toml for Python frameworks
    pyproject = root / "pyproject.toml"
    if pyproject.exists() and (language or "").startswith("Python"):
        try:
            content = pyproject.read_text()
            py_frameworks = [
                ("fastapi", "FastAPI"), ("django", "Django"), ("flask", "Flask"),
                ("starlette", "Starlette"), ("tornado", "Tornado"),
                ("aiohttp", "aiohttp"), ("sanic", "Sanic"),
            ]
            content_lower = content.lower()
            for pkg_name, fw_name in py_frameworks:
                if pkg_name in content_lower:
                    result["framework"] = fw_name
                    result.setdefault("confidence", {})["framework"] = "high"
                    break
        except Exception:
            pass

    # Check requirements.txt as fallback
    if not result.get("framework"):
        req_txt = root / "requirements.txt"
        if req_txt.exists() and (language or "").startswith("Python"):
            try:
                content = req_txt.read_text().lower()
                for pkg_name, fw_name in [
                    ("fastapi", "FastAPI"), ("django", "Django"), ("flask", "Flask"),
                ]:
                    if pkg_name in content:
                        result["framework"] = fw_name
                        result.setdefault("confidence", {})["framework"] = "high"
                        break
            except Exception:
                pass

    # Check Cargo.toml for Rust frameworks
    cargo = root / "Cargo.toml"
    if cargo.exists() and language == "Rust":
        try:
            content = cargo.read_text().lower()
            rust_frameworks = [
                ("actix-web", "Actix Web"), ("axum", "Axum"), ("rocket", "Rocket"),
                ("warp", "Warp"), ("bevy", "Bevy"), ("tauri", "Tauri"),
            ]
            for pkg_name, fw_name in rust_frameworks:
                if pkg_name in content:
                    result["framework"] = fw_name
                    result.setdefault("confidence", {})["framework"] = "high"
                    break
        except Exception:
            pass

    # Go framework detection
    gomod = root / "go.mod"
    if gomod.exists() and language == "Go":
        try:
            content = gomod.read_text().lower()
            go_frameworks = [
                ("gin-gonic/gin", "Gin"), ("labstack/echo", "Echo"),
                ("gofiber/fiber", "Fiber"), ("go-chi/chi", "Chi"),
                ("gorilla/mux", "Gorilla Mux"),
            ]
            for pkg_name, fw_name in go_frameworks:
                if pkg_name in content:
                    result["framework"] = fw_name
                    result.setdefault("confidence", {})["framework"] = "high"
                    break
        except Exception:
            pass

    return result


def _detect_test_framework(root: Path, language: str | None) -> str | None:
    """Detect test framework from config and directory structure."""
    lang = (language or "").lower()

    # Python
    if "python" in lang:
        if (root / "pytest.ini").exists() or (root / "conftest.py").exists():
            return "pytest"
        if (root / "pyproject.toml").exists():
            try:
                if "pytest" in (root / "pyproject.toml").read_text().lower():
                    return "pytest"
            except Exception:
                pass
        if (root / "setup.cfg").exists():
            try:
                if "pytest" in (root / "setup.cfg").read_text().lower():
                    return "pytest"
            except Exception:
                pass
        # Check for unittest pattern
        for d in ["tests", "test"]:
            test_dir = root / d
            if test_dir.is_dir():
                return "pytest"  # default assumption for Python

    # JavaScript/TypeScript
    if "script" in lang or "typescript" in lang:
        pkg_json = root / "package.json"
        if pkg_json.exists():
            try:
                pkg = json.loads(pkg_json.read_text())
                deps = {}
                deps.update(pkg.get("dependencies", {}))
                deps.update(pkg.get("devDependencies", {}))
                if "vitest" in deps:
                    return "vitest"
                if "jest" in deps:
                    return "jest"
                if "@testing-library/react" in deps:
                    return "jest/testing-library"
                if "mocha" in deps:
                    return "mocha"
            except Exception:
                pass

    # Go
    if "go" in lang:
        return "go test"

    # Rust
    if "rust" in lang:
        return "cargo test"

    # Ruby
    if "ruby" in lang:
        if (root / "spec").is_dir():
            return "rspec"
        return "minitest"

    return None


def detect_entry_points(root: Path) -> list[dict]:
    """Detect main entry points of the project."""
    entries = []

    entry_patterns = [
        ("main.py", "Python main module"),
        ("app.py", "Python app entry"),
        ("manage.py", "Django management"),
        ("wsgi.py", "WSGI entry"),
        ("asgi.py", "ASGI entry"),
        ("index.ts", "TypeScript entry"),
        ("index.js", "JavaScript entry"),
        ("main.ts", "TypeScript main"),
        ("main.js", "JavaScript main"),
        ("main.go", "Go main"),
        ("main.rs", "Rust main"),
        ("Main.java", "Java main"),
        ("Program.cs", "C# main"),
        ("main.swift", "Swift main"),
        ("project.godot", "Godot project"),
    ]

    # Check root and common source dirs
    search_dirs = [root]
    for d in ["src", "app", "cmd", "lib", "server", "api"]:
        p = root / d
        if p.is_dir():
            search_dirs.append(p)

    for search_dir in search_dirs:
        for filename, description in entry_patterns:
            target = search_dir / filename
            if target.exists():
                rel = str(target.relative_to(root))
                entries.append({
                    "path": rel,
                    "description": description,
                    "confidence": "high",
                })

    # Check package.json for scripts
    pkg_json = root / "package.json"
    if pkg_json.exists():
        try:
            pkg = json.loads(pkg_json.read_text())
            main_field = pkg.get("main") or pkg.get("module")
            if main_field:
                entries.append({
                    "path": main_field,
                    "description": "package.json main",
                    "confidence": "high",
                })
            scripts = pkg.get("scripts", {})
            if "start" in scripts:
                entries.append({
                    "path": f"npm start → {scripts['start']}",
                    "description": "Start script",
                    "confidence": "high",
                })
            if "dev" in scripts:
                entries.append({
                    "path": f"npm run dev → {scripts['dev']}",
                    "description": "Dev script",
                    "confidence": "high",
                })
        except Exception:
            pass

    # Check for Go cmd/ pattern
    cmd_dir = root / "cmd"
    if cmd_dir.is_dir():
        for child in sorted(cmd_dir.iterdir()):
            if child.is_dir() and not child.name.startswith("."):
                entries.append({
                    "path": f"cmd/{child.name}/",
                    "description": f"Go command: {child.name}",
                    "confidence": "high",
                })

    return entries


def detect_architecture(root: Path) -> dict:
    """Map directory structure and identify components."""
    architecture: dict = {
        "top_level_dirs": [],
        "components": [],
        "is_monorepo": False,
        "monorepo_packages": [],
    }

    # Scan top-level directories
    for child in sorted(root.iterdir()):
        if not child.is_dir():
            continue
        if child.name.startswith(".") or child.name in EXCLUDE_DIRS:
            continue
        # Count files inside
        file_count = sum(1 for _ in child.rglob("*") if _.is_file()
                         and not should_exclude(_.relative_to(root)))
        if file_count > 0:
            architecture["top_level_dirs"].append({
                "name": child.name,
                "file_count": min(file_count, 9999),
            })

    # Monorepo detection
    monorepo_markers = ["packages", "apps", "services", "libs", "modules"]
    for marker in monorepo_markers:
        marker_dir = root / marker
        if marker_dir.is_dir():
            architecture["is_monorepo"] = True
            for pkg in sorted(marker_dir.iterdir()):
                if pkg.is_dir() and not pkg.name.startswith("."):
                    architecture["monorepo_packages"].append({
                        "name": pkg.name,
                        "path": f"{marker}/{pkg.name}",
                    })

    # Identify likely components from standard dir names
    component_dirs = [
        ("src/components", "UI Components"),
        ("src/pages", "Pages/Routes"),
        ("src/routes", "Routes"),
        ("src/api", "API Layer"),
        ("src/services", "Services"),
        ("src/models", "Data Models"),
        ("src/controllers", "Controllers"),
        ("src/middleware", "Middleware"),
        ("src/hooks", "React Hooks"),
        ("src/stores", "State Stores"),
        ("app/api", "API Routes"),
        ("app/models", "Models"),
        ("api", "API"),
        ("server", "Server"),
        ("client", "Client"),
        ("frontend", "Frontend"),
        ("backend", "Backend"),
        ("core", "Core Logic"),
    ]
    for dir_path, label in component_dirs:
        if (root / dir_path).is_dir():
            architecture["components"].append({
                "path": dir_path,
                "label": label,
                "confidence": "high",
            })

    return architecture


def read_readme(root: Path) -> str | None:
    """Extract project description from README."""
    for name in ["README.md", "README", "README.rst", "README.txt", "readme.md"]:
        readme = root / name
        if readme.exists():
            try:
                content = readme.read_text(encoding="utf-8", errors="replace")
                # Take first meaningful section (skip badges, title)
                lines = content.splitlines()
                desc_lines = []
                in_content = False
                for line in lines[:60]:  # Only look at first 60 lines
                    stripped = line.strip()
                    # Skip badge lines, empty, and pure headers
                    if stripped.startswith("[![") or stripped.startswith("!["):
                        continue
                    if stripped.startswith("# ") and not in_content:
                        in_content = True
                        continue
                    if in_content and stripped:
                        if stripped.startswith("## "):
                            break  # Stop at next section
                        desc_lines.append(stripped)
                    if len(desc_lines) >= 5:
                        break
                return " ".join(desc_lines).strip() if desc_lines else None
            except Exception:
                pass
    return None


def detect_test_patterns(root: Path) -> dict:
    """Detect test directory and patterns."""
    patterns: dict = {
        "test_dirs": [],
        "test_command": None,
    }

    for d in ["tests", "test", "spec", "__tests__", "test_suite"]:
        test_dir = root / d
        if test_dir.is_dir():
            file_count = sum(1 for f in test_dir.rglob("*")
                             if f.is_file() and f.suffix in SOURCE_EXTENSIONS)
            if file_count > 0:
                patterns["test_dirs"].append({
                    "path": d,
                    "file_count": file_count,
                })

    # Detect test command from package.json
    pkg_json = root / "package.json"
    if pkg_json.exists():
        try:
            pkg = json.loads(pkg_json.read_text())
            test_cmd = pkg.get("scripts", {}).get("test")
            if test_cmd and test_cmd != 'echo "Error: no test specified" && exit 1':
                patterns["test_command"] = f"npm test → {test_cmd}"
        except Exception:
            pass

    # Detect from Makefile
    makefile = root / "Makefile"
    if makefile.exists() and not patterns["test_command"]:
        try:
            content = makefile.read_text()
            if re.search(r"^test:", content, re.MULTILINE):
                patterns["test_command"] = "make test"
        except Exception:
            pass

    return patterns


def discover_features(root: Path, stack: dict, architecture: dict,
                      sub_projects: list[dict] | None = None) -> list[dict]:
    """Discover existing features/modules from code structure (feature_tracking=yes only)."""
    features: list[dict] = []
    seen_names: set[str] = set()

    def add_feature(name: str, description: str, confidence: str, evidence: str):
        if name.lower() in seen_names or len(features) >= MAX_FEATURES:
            return
        seen_names.add(name.lower())
        features.append({
            "name": name,
            "description": description,
            "confidence": confidence,
            "evidence": evidence,
        })

    # Monorepo packages as features
    if architecture.get("is_monorepo"):
        for pkg in architecture.get("monorepo_packages", []):
            add_feature(
                name=pkg["name"].replace("-", " ").replace("_", " ").title(),
                description=f"Package: {pkg['path']}",
                confidence="medium",
                evidence=f"monorepo package at {pkg['path']}",
            )

    # Go cmd/ directories as features
    cmd_dir = root / "cmd"
    if cmd_dir.is_dir():
        for child in sorted(cmd_dir.iterdir()):
            if child.is_dir() and not child.name.startswith("."):
                add_feature(
                    name=child.name.replace("-", " ").replace("_", " ").title(),
                    description=f"CLI command: {child.name}",
                    confidence="high",
                    evidence=f"cmd/{child.name}/",
                )

    # Scan top-level source directories for modules
    lang = (stack.get("language") or "").lower()

    # Route-based feature discovery (web apps)
    _discover_route_features(root, features, seen_names, sub_projects)

    # Module-based feature discovery
    _discover_module_features(root, lang, features, seen_names)

    return features[:MAX_FEATURES]


def _discover_route_features(root: Path, features: list[dict], seen_names: set[str],
                             sub_projects: list[dict] | None = None):
    """Discover features from route/page files."""
    route_dirs = [
        root / "src" / "pages",
        root / "src" / "routes",
        root / "app",      # Next.js app router
        root / "pages",    # Next.js pages router
    ]

    # Also scan sub-project route dirs
    for sp in (sub_projects or []):
        sp_root = root / sp["name"]
        for d in ["src/pages", "src/routes"]:
            route_dirs.append(sp_root / Path(d))

    for route_dir in route_dirs:
        if not route_dir.is_dir():
            continue
        for child in sorted(route_dir.iterdir()):
            if child.name.startswith(("_", ".", "[")) or child.name in ("api", "layout", "error"):
                continue
            if child.is_dir() or child.suffix in {".tsx", ".jsx", ".ts", ".js", ".vue", ".svelte"}:
                name = child.stem if child.is_file() else child.name
                if name.lower() in NON_FEATURE_DIRS or name.lower() in seen_names:
                    continue
                if len(features) >= MAX_FEATURES:
                    return
                seen_names.add(name.lower())
                features.append({
                    "name": name.replace("-", " ").replace("_", " ").title(),
                    "description": f"Route/page: {child.relative_to(child.parent.parent) if child.parent != child.parent.parent else child.name}",
                    "confidence": "medium",
                    "evidence": f"route at {child.relative_to(child.parent.parent)}",
                })


def _discover_module_features(root: Path, lang: str, features: list[dict], seen_names: set[str]):
    """Discover features from top-level modules/packages."""
    # Determine where to look for modules
    src_dirs = []
    for d in ["src", "lib", "app", "server", "api", "core"]:
        p = root / d
        if p.is_dir():
            src_dirs.append(p)

    # If no src dirs, look at root (for Python projects, etc.)
    if not src_dirs and "python" in lang:
        # Look for Python packages at root (dirs with __init__.py)
        for child in sorted(root.iterdir()):
            if child.is_dir() and (child / "__init__.py").exists():
                if child.name not in EXCLUDE_DIRS and child.name not in NON_FEATURE_DIRS:
                    src_dirs.append(child)

    for src_dir in src_dirs:
        for child in sorted(src_dir.iterdir()):
            if not child.is_dir() or child.name.startswith(("_", ".")):
                continue
            if child.name.lower() in NON_FEATURE_DIRS or child.name.lower() in seen_names:
                continue
            if len(features) >= MAX_FEATURES:
                return
            # Count substantive files
            file_count = sum(1 for f in child.rglob("*")
                             if f.is_file() and f.suffix in SOURCE_EXTENSIONS
                             and not should_exclude(f.relative_to(root)))
            if file_count < 1:
                continue

            seen_names.add(child.name.lower())
            features.append({
                "name": child.name.replace("-", " ").replace("_", " ").title(),
                "description": f"Module: {child.relative_to(root)}",
                "confidence": "low",
                "evidence": f"directory {child.relative_to(root)} ({file_count} source files)",
            })


# --- Sub-project detection ---

_PROJECT_MARKERS = [
    ("package.json", "TypeScript"),  # refined below if no tsconfig
    ("pyproject.toml", "Python"),
    ("go.mod", "Go"),
    ("Cargo.toml", "Rust"),
    ("requirements.txt", "Python"),
]


def detect_sub_projects(root: Path) -> list[dict]:
    """Detect sub-projects in immediate subdirectories."""
    sub_projects = []
    for child in sorted(root.iterdir()):
        if not child.is_dir() or child.name.startswith(".") or child.name in EXCLUDE_DIRS:
            continue
        for marker_file, lang in _PROJECT_MARKERS:
            if (child / marker_file).exists():
                # Refine language: JS vs TS
                if marker_file == "package.json" and not (child / "tsconfig.json").exists():
                    lang = "JavaScript"
                # Detect framework
                framework = _detect_sub_project_framework(child, marker_file)
                # Azure Functions host.json overrides framework
                if (child / "host.json").exists():
                    framework = "Azure Functions"
                has_tests = _sub_project_has_tests(child)
                sub_projects.append({
                    "name": child.name,
                    "path": f"{child.name}/",
                    "language": lang,
                    "framework": framework,
                    "has_tests": has_tests,
                })
                break  # first marker wins per directory
    return sub_projects


def _detect_sub_project_framework(sp_root: Path, marker: str) -> str | None:
    """Detect framework for a sub-project from its config."""
    if marker == "package.json":
        try:
            pkg = json.loads((sp_root / "package.json").read_text())
            deps = {}
            deps.update(pkg.get("dependencies", {}))
            deps.update(pkg.get("devDependencies", {}))
            js_frameworks = [
                ("next", "Next.js"), ("nuxt", "Nuxt"), ("@angular/core", "Angular"),
                ("svelte", "SvelteKit"), ("vue", "Vue"), ("react-native", "React Native"),
                ("react", "React"), ("express", "Express"), ("fastify", "Fastify"),
            ]
            for pkg_name, fw_name in js_frameworks:
                if pkg_name in deps:
                    return fw_name
        except Exception:
            pass
    elif marker in ("pyproject.toml", "requirements.txt"):
        try:
            content = (sp_root / marker).read_text().lower()
            for pkg_name, fw_name in [
                ("fastapi", "FastAPI"), ("django", "Django"), ("flask", "Flask"),
            ]:
                if pkg_name in content:
                    return fw_name
        except Exception:
            pass
    return None


def _sub_project_has_tests(sp_root: Path) -> bool:
    """Check if a sub-project has test files."""
    for d in ["tests", "test", "__tests__", "spec"]:
        if (sp_root / d).is_dir():
            return True
    # Check for *.test.* or *.spec.* files in src/
    src = sp_root / "src"
    if src.is_dir():
        for f in src.rglob("*"):
            if f.is_file() and (".test." in f.name or ".spec." in f.name):
                return True
    return False


# --- Serverless function detection ---

def _serverless_type_hint(name: str) -> str:
    """Infer type hint from function name prefix."""
    lower = name.lower()
    if lower.startswith("admin"):
        return "admin"
    if lower.startswith("mobile"):
        return "mobile"
    if lower.startswith(("internal", "system", "cron", "scheduled")):
        return "infrastructure"
    return "user-facing"


def detect_serverless_functions(root: Path) -> list[dict]:
    """Detect serverless functions (Azure Functions, AWS Lambda, Vercel)."""
    functions = []

    # Azure Functions: */function.json
    for fj in root.rglob("function.json"):
        rel = fj.relative_to(root)
        if should_exclude(rel):
            continue
        try:
            config = json.loads(fj.read_text())
            bindings = config.get("bindings", [])
            trigger = None
            route = None
            methods = []
            for b in bindings:
                btype = b.get("type", "")
                if b.get("direction") == "in" and btype.endswith("Trigger"):
                    trigger = btype.replace("Trigger", "").lower()
                    route = b.get("route")
                    methods = b.get("methods", [])
            name = fj.parent.name
            functions.append({
                "name": name,
                "trigger": trigger or "unknown",
                "route": route,
                "methods": [m.upper() for m in methods] if methods else [],
                "type_hint": _serverless_type_hint(name),
                "path": str(fj.parent.relative_to(root)),
            })
        except Exception:
            continue

    # AWS Lambda: serverless.yml / template.yaml (SAM)
    for cfg in ["serverless.yml", "serverless.yaml", "template.yaml", "template.yml"]:
        if (root / cfg).exists():
            functions.append({
                "name": "_aws_lambda_config",
                "trigger": "config_file",
                "route": None,
                "methods": [],
                "type_hint": "infrastructure",
                "path": cfg,
            })
            break

    # Vercel: api/ directory with source files
    api_dir = root / "api"
    if api_dir.is_dir():
        for f in sorted(api_dir.rglob("*")):
            if f.is_file() and f.suffix in SOURCE_EXTENSIONS and not should_exclude(f.relative_to(root)):
                name = f.stem
                functions.append({
                    "name": name,
                    "trigger": "http",
                    "route": str(f.relative_to(api_dir)).rsplit(".", 1)[0],
                    "methods": [],
                    "type_hint": _serverless_type_hint(name),
                    "path": str(f.relative_to(root)),
                })

    return functions


# --- UI component grouping ---

def detect_ui_components(root: Path, sub_projects: list[dict]) -> list[dict]:
    """Detect UI component groupings from standard directories."""
    components = []
    scan_dirs = []

    # Standard root-level dirs
    for pattern in ["src/components", "src/pages", "src/screens"]:
        d = root / pattern
        if d.is_dir():
            scan_dirs.append(d)

    # Sub-project dirs
    for sp in sub_projects:
        sp_root = root / sp["name"]
        for pattern in ["src/components", "src/pages", "src/screens"]:
            d = sp_root / pattern
            if d.is_dir():
                scan_dirs.append(d)

    for scan_dir in scan_dirs:
        for child in sorted(scan_dir.iterdir()):
            if not child.is_dir() or child.name.startswith(("_", ".")):
                continue
            if child.name.lower() in NON_FEATURE_DIRS:
                continue
            file_count = sum(1 for f in child.rglob("*")
                             if f.is_file() and f.suffix in SOURCE_EXTENSIONS)
            if file_count >= 2:
                components.append({
                    "name": child.name,
                    "path": str(child.relative_to(root)),
                    "file_count": file_count,
                })

    return components


# --- Feature clustering ---

def _camel_case_split(name: str) -> list[str]:
    """Split camelCase/PascalCase into lowercase tokens."""
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", name)
    s = re.sub(r"[^a-zA-Z0-9]", " ", s)
    return [t.lower() for t in s.split() if t]


def _normalize_name(name: str) -> str:
    """Normalize a name to joined lowercase tokens for prefix matching."""
    return "".join(_camel_case_split(name))


def _common_prefix_len(a: str, b: str) -> int:
    """Return the length of the common prefix of two strings."""
    n = min(len(a), len(b))
    for i in range(n):
        if a[i] != b[i]:
            return i
    return n


def cluster_features(ui_components: list[dict], serverless_functions: list[dict],
                     features: list[dict]) -> list[dict]:
    """Group related frontend/backend/mobile items into feature clusters."""
    # Collect (normalized_name, tier, path, type_hint)
    items: list[tuple[str, str, str, str]] = []

    for comp in ui_components:
        norm = _normalize_name(comp["name"])
        path = comp.get("path", "")
        tier = "mobile" if "/screens/" in path else "frontend"
        items.append((norm, tier, path + "/", "user-facing"))

    for func in serverless_functions:
        if func["name"].startswith("_"):
            continue
        norm = _normalize_name(func["name"])
        items.append((norm, "backend", func.get("path", ""),
                      func.get("type_hint", "user-facing")))

    if not items:
        return []

    # Sort for prefix grouping
    items.sort(key=lambda x: x[0])

    # Greedy prefix grouping: merge items sharing >= 4 char prefix
    clusters_map: dict[str, dict] = {}

    for norm, tier, path, type_hint in items:
        best_key = None
        best_plen = 0
        for key in list(clusters_map.keys()):
            plen = _common_prefix_len(norm, key)
            if plen >= 4 and plen > best_plen:
                best_key = key
                best_plen = plen

        if best_key is not None:
            common = norm[:best_plen]
            if common != best_key:
                clusters_map[common] = clusters_map.pop(best_key)
            clusters_map[common].setdefault(tier, []).append(path)
            if type_hint not in ("user-facing",):
                clusters_map[common]["type_hint"] = type_hint
        else:
            clusters_map[norm] = {tier: [path], "type_hint": type_hint}

    # Build output list
    clusters = []
    for key, data in sorted(clusters_map.items()):
        frontend = data.get("frontend", [])
        backend = data.get("backend", [])
        mobile = data.get("mobile", [])
        tier_count = sum(1 for t in [frontend, backend, mobile] if t)
        confidence = "high" if tier_count >= 3 else ("medium" if tier_count >= 2 else "low")
        clusters.append({
            "name": key,
            "frontend": frontend,
            "backend": backend,
            "mobile": mobile,
            "has_tests": False,
            "type_hint": data.get("type_hint", "user-facing"),
            "confidence": confidence,
        })
    return clusters


# --- Infrastructure pattern detection ---

def detect_infra_patterns(root: Path) -> list[dict]:
    """Detect infrastructure patterns (CI/CD, IaC, containers, deployment)."""
    patterns = []

    # CI/CD
    ci_cd_checks = [
        (".github/workflows", "GitHub Actions"),
        (".gitlab-ci.yml", "GitLab CI"),
        ("azure-pipelines.yml", "Azure Pipelines"),
        ("Jenkinsfile", "Jenkins"),
        (".circleci", "CircleCI"),
        ("bitbucket-pipelines.yml", "Bitbucket Pipelines"),
        (".travis.yml", "Travis CI"),
    ]
    for path_str, detail in ci_cd_checks:
        p = root / path_str
        if p.exists():
            # For directories, count files inside
            if p.is_dir():
                files = [f for f in p.rglob("*") if f.is_file()]
                if files:
                    patterns.append({"type": "ci_cd", "path": path_str, "detail": f"{detail} ({len(files)} files)"})
            else:
                patterns.append({"type": "ci_cd", "path": path_str, "detail": detail})

    # IaC
    iac_checks = [
        ("terraform", "Terraform"),
        ("pulumi", "Pulumi"),
        ("cloudformation", "CloudFormation"),
        ("bicep", "Bicep"),
        ("cdk", "AWS CDK"),
    ]
    for path_str, detail in iac_checks:
        p = root / path_str
        if p.is_dir():
            tf_files = list(p.rglob("*.tf")) if detail == "Terraform" else list(p.rglob("*"))
            if tf_files or detail != "Terraform":
                patterns.append({"type": "iac", "path": path_str, "detail": detail})

    # Containers
    dockerfiles = list(root.glob("Dockerfile*"))
    if dockerfiles:
        patterns.append({"type": "container", "path": "Dockerfile", "detail": f"Docker ({len(dockerfiles)} Dockerfile(s))"})
    if (root / "docker-compose.yml").exists() or (root / "docker-compose.yaml").exists():
        compose_name = "docker-compose.yml" if (root / "docker-compose.yml").exists() else "docker-compose.yaml"
        patterns.append({"type": "container", "path": compose_name, "detail": "Docker Compose"})
    for k8s_dir in ["k8s", "kubernetes", "helm"]:
        if (root / k8s_dir).is_dir():
            patterns.append({"type": "container", "path": k8s_dir, "detail": f"Kubernetes ({k8s_dir}/)"})
            break

    # Deployment
    deploy_checks = [
        ("deploy", "Deploy scripts"),
        ("scripts/deploy", "Deploy scripts"),
        ("infrastructure", "Infrastructure"),
    ]
    for path_str, detail in deploy_checks:
        if (root / path_str).is_dir():
            patterns.append({"type": "deployment", "path": path_str, "detail": detail})

    # Makefile with deploy target
    makefile = root / "Makefile"
    if makefile.exists():
        try:
            content = makefile.read_text()
            if re.search(r"^deploy:", content, re.MULTILINE):
                patterns.append({"type": "deployment", "path": "Makefile", "detail": "Makefile deploy target"})
        except Exception:
            pass

    return patterns


# --- Domain detection ---

# Framework-to-domain-type mapping
_FRAMEWORK_DOMAIN_TYPE = {
    "React": "frontend", "Vue": "frontend", "Angular": "frontend",
    "Next.js": "frontend", "Nuxt": "frontend", "SvelteKit": "frontend",
    "Svelte": "frontend", "Astro": "frontend", "Gatsby": "frontend",
    "Remix": "frontend", "Electron": "frontend",
    "React Native": "mobile", "Flutter": "mobile",
    "Express": "backend", "FastAPI": "backend", "Django": "backend",
    "Flask": "backend", "Fastify": "backend", "Koa": "backend",
    "Hono": "backend", "Gin": "backend", "Echo": "backend",
    "Fiber": "backend", "Chi": "backend", "Gorilla Mux": "backend",
    "Actix Web": "backend", "Axum": "backend", "Rocket": "backend",
    "Warp": "backend", "Azure Functions": "backend",
    "Bevy": "frontend", "Tauri": "frontend",
}


def detect_domains(root: Path, sub_projects: list[dict],
                   feature_clusters: list[dict],
                   architecture: dict,
                   infra_patterns: list[dict]) -> list[dict]:
    """Group sub-projects, clusters, and infra into domains."""
    domains: list[dict] = []
    cluster_assigned: set[str] = set()

    # 1. Each sub-project with a recognized framework → a domain
    for sp in sub_projects:
        fw = sp.get("framework") or ""
        domain_type = _FRAMEWORK_DOMAIN_TYPE.get(fw, "shared")
        domain_name = sp["name"]

        # Find clusters matching this sub-project by path prefix
        matched_clusters = []
        for cluster in feature_clusters:
            cluster_paths = (cluster.get("frontend", []) +
                             cluster.get("backend", []) +
                             cluster.get("mobile", []))
            for p in cluster_paths:
                if p.startswith(sp["name"] + "/") or p.startswith(sp.get("path", "")):
                    if cluster["name"] not in cluster_assigned:
                        matched_clusters.append(cluster["name"])
                        cluster_assigned.add(cluster["name"])
                    break

        # Estimate features from clusters or a default
        estimated = len(matched_clusters) if matched_clusters else max(1, sp.get("file_count", 3) // 3)

        domains.append({
            "name": domain_name,
            "type": domain_type,
            "sub_projects": [sp["name"]],
            "clusters": matched_clusters,
            "infra_paths": [],
            "estimated_features": estimated,
        })

    # 2. Infrastructure domain (≥3 infra patterns or dedicated IaC directory)
    iac_dirs = [p for p in infra_patterns if p["type"] == "iac"]
    if len(infra_patterns) >= 3 or iac_dirs:
        domains.append({
            "name": "infrastructure",
            "type": "infrastructure",
            "sub_projects": [],
            "clusters": [],
            "infra_paths": [p["path"] for p in infra_patterns],
            "estimated_features": max(1, len(infra_patterns)),
        })

    # 3. Assign orphan clusters to existing domains or create uncategorized
    orphan_clusters = [c for c in feature_clusters if c["name"] not in cluster_assigned]
    if orphan_clusters and domains:
        # Try to assign by tier (frontend/backend/mobile)
        for cluster in orphan_clusters:
            assigned = False
            if cluster.get("frontend"):
                for d in domains:
                    if d["type"] == "frontend":
                        d["clusters"].append(cluster["name"])
                        d["estimated_features"] += 1
                        assigned = True
                        break
            if not assigned and cluster.get("backend"):
                for d in domains:
                    if d["type"] == "backend":
                        d["clusters"].append(cluster["name"])
                        d["estimated_features"] += 1
                        assigned = True
                        break
            if not assigned and cluster.get("mobile"):
                for d in domains:
                    if d["type"] == "mobile":
                        d["clusters"].append(cluster["name"])
                        d["estimated_features"] += 1
                        assigned = True
                        break
            if not assigned:
                cluster_assigned.add(cluster["name"])
                # Collect for uncategorized domain

    # Remaining truly orphan clusters → uncategorized
    still_orphan = [c["name"] for c in feature_clusters
                    if c["name"] not in cluster_assigned
                    and not any(c["name"] in d["clusters"] for d in domains)]
    if still_orphan:
        domains.append({
            "name": "uncategorized",
            "type": "uncategorized",
            "sub_projects": [],
            "clusters": still_orphan,
            "infra_paths": [],
            "estimated_features": len(still_orphan),
        })

    # 4. Single-project repos (no sub-projects): 1 domain from root
    if not sub_projects and not domains:
        # Derive name from root directory or package name
        domain_name = root.name
        pkg_json = root / "package.json"
        if pkg_json.exists():
            try:
                pkg = json.loads(pkg_json.read_text())
                if pkg.get("name"):
                    domain_name = pkg["name"].split("/")[-1]  # strip @scope/
            except Exception:
                pass

        # Detect type from root framework
        fw = None
        for sp_marker, _ in _PROJECT_MARKERS:
            if (root / sp_marker).exists():
                fw = _detect_sub_project_framework(root, sp_marker)
                if (root / "host.json").exists():
                    fw = "Azure Functions"
                break
        if not fw:
            # Try the main stack detect
            stack = detect_stack(root)
            fw = stack.get("framework")

        domain_type = _FRAMEWORK_DOMAIN_TYPE.get(fw or "", "shared")

        all_cluster_names = [c["name"] for c in feature_clusters]
        domains.append({
            "name": domain_name,
            "type": domain_type,
            "sub_projects": [],
            "clusters": all_cluster_names,
            "infra_paths": [p["path"] for p in infra_patterns] if infra_patterns else [],
            "estimated_features": max(len(all_cluster_names), len(feature_clusters)),
        })

    return domains


# --- API spec detection ---

def detect_api_specs(root: Path, sub_projects: list[dict]) -> str | None:
    """Check for OpenAPI/Swagger spec files."""
    search_dirs = [root] + [root / sp["name"] for sp in sub_projects]

    for d in search_dirs:
        if not d.is_dir():
            continue
        for child in d.rglob("*"):
            if not child.is_file():
                continue
            if should_exclude(child.relative_to(root)):
                continue
            name_lower = child.name.lower()
            if ("openapi" in name_lower or "swagger" in name_lower) and \
               child.suffix in (".json", ".yaml", ".yml"):
                return str(child.relative_to(root))
    return None


def generate_report(root: Path, profile: str, feature_tracking: bool = False) -> dict:
    """Orchestrate all discovery and generate the JSON report."""
    root = root.resolve()

    stack = detect_stack(root)
    entry_points = detect_entry_points(root)
    architecture = detect_architecture(root)
    readme_desc = read_readme(root)
    test_patterns = detect_test_patterns(root)

    # Always detect sub-projects
    sub_projects = detect_sub_projects(root)

    # Backfill root stack from sub-projects when root has no config
    if not stack["language"] and sub_projects:
        langs = list({sp["language"] for sp in sub_projects if sp["language"]})
        if len(langs) == 1:
            stack["language"] = langs[0]
            stack["confidence"]["language"] = "medium"
        elif langs:
            stack["language"] = langs[0]
            stack["confidence"]["language"] = "low"

    if not stack["framework"] and sub_projects:
        frameworks = [sp["framework"] for sp in sub_projects if sp["framework"]]
        if len(frameworks) == 1:
            stack["framework"] = frameworks[0]
            stack["confidence"]["framework"] = "medium"
        elif len(frameworks) > 1:
            stack["framework"] = f"Multi ({', '.join(frameworks)})"
            stack["confidence"]["framework"] = "medium"

    if not stack["package_manager"] and sub_projects:
        for sp in sub_projects:
            sp_root = root / sp["name"]
            for lockfile, pm in [
                ("pnpm-lock.yaml", "pnpm"), ("yarn.lock", "yarn"),
                ("package-lock.json", "npm"), ("bun.lockb", "bun"),
            ]:
                if (sp_root / lockfile).exists():
                    stack["package_manager"] = pm
                    stack["confidence"]["package_manager"] = "medium"
                    break
            if stack["package_manager"]:
                break

    # Always detect infra patterns (useful for CONTEXT_PACK.md even in core)
    infra_patterns = detect_infra_patterns(root)

    features = []
    serverless_functions = []
    ui_components = []
    feature_clusters = []
    api_spec_path = None
    domains = []

    if feature_tracking:
        features = discover_features(root, stack, architecture, sub_projects)
        serverless_functions = detect_serverless_functions(root)
        ui_components = detect_ui_components(root, sub_projects)
        feature_clusters = cluster_features(ui_components, serverless_functions, features)
        api_spec_path = detect_api_specs(root, sub_projects)
        domains = detect_domains(root, sub_projects, feature_clusters,
                                 architecture, infra_patterns)
    else:
        # Non-feature-tracking projects still get domains for context
        domains = detect_domains(root, sub_projects, [],
                                 architecture, infra_patterns)

    report = {
        "version": "2.0.0",
        "generated": datetime.now(timezone.utc).isoformat(),
        "profile": profile,
        "project_root": str(root),
        "stack": stack,
        "entry_points": entry_points,
        "architecture": architecture,
        "readme_description": readme_desc,
        "test_patterns": test_patterns,
        "features": features,
        "sub_projects": sub_projects,
        "infra_patterns": infra_patterns,
        "domains": domains,
    }

    if feature_tracking:
        report["serverless_functions"] = serverless_functions
        report["ui_components"] = ui_components
        report["feature_clusters"] = feature_clusters
        report["api_spec_path"] = api_spec_path

    return report


def main():
    parser = argparse.ArgumentParser(description="Analyze existing codebase for onboarding")
    parser.add_argument("--root", type=str, default=".", help="Project root directory")
    parser.add_argument("--output", type=str, required=True, help="Output JSON report path")
    parser.add_argument("--profile", type=str, default="discovery",
                        choices=["discovery", "formal"],
                        help="Agentic Framework profile")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"ERROR: {root} is not a directory")
        raise SystemExit(1)

    profile = args.profile

    # Resolve feature_tracking from settings (profile preset handles formal→yes)
    feature_tracking = get_setting(root, "feature_tracking", "no") == "yes"

    report = generate_report(root, profile, feature_tracking=feature_tracking)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2))

    # Print summary
    stack = report["stack"]
    print(f"Language: {stack.get('language', 'unknown')}")
    if stack.get("framework"):
        print(f"Framework: {stack['framework']}")
    if stack.get("package_manager"):
        print(f"Package manager: {stack['package_manager']}")
    if stack.get("test_framework"):
        print(f"Test framework: {stack['test_framework']}")
    print(f"Entry points: {len(report['entry_points'])}")
    print(f"Components: {len(report['architecture'].get('components', []))}")
    if report.get("sub_projects"):
        print(f"Sub-projects: {len(report['sub_projects'])}")
    if report["features"]:
        print(f"Features discovered: {len(report['features'])}")
    if report.get("serverless_functions"):
        print(f"Serverless functions: {len(report['serverless_functions'])}")
    if report.get("ui_components"):
        print(f"UI components: {len(report['ui_components'])}")
    if report.get("feature_clusters"):
        print(f"Feature clusters: {len(report['feature_clusters'])}")
    if report.get("api_spec_path"):
        print(f"API spec: {report['api_spec_path']}")
    if report.get("infra_patterns"):
        print(f"Infrastructure patterns: {len(report['infra_patterns'])}")
    if report.get("domains"):
        domain_summary = ", ".join(f"{d['name']}({d['type']})" for d in report["domains"])
        print(f"Domains: {len(report['domains'])} [{domain_summary}]")


if __name__ == "__main__":
    main()
