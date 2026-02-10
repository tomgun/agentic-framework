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
from datetime import datetime, timezone
from pathlib import Path

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


def discover_features(root: Path, stack: dict, architecture: dict) -> list[dict]:
    """Discover existing features/modules from code structure (Core+PM only)."""
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
    _discover_route_features(root, features, seen_names)

    # Module-based feature discovery
    _discover_module_features(root, lang, features, seen_names)

    return features[:MAX_FEATURES]


def _discover_route_features(root: Path, features: list[dict], seen_names: set[str]):
    """Discover features from route/page files."""
    route_dirs = [
        root / "src" / "pages",
        root / "src" / "routes",
        root / "app",      # Next.js app router
        root / "pages",    # Next.js pages router
    ]

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


def generate_report(root: Path, profile: str) -> dict:
    """Orchestrate all discovery and generate the JSON report."""
    root = root.resolve()

    stack = detect_stack(root)
    entry_points = detect_entry_points(root)
    architecture = detect_architecture(root)
    readme_desc = read_readme(root)
    test_patterns = detect_test_patterns(root)

    features = []
    if profile == "core+product":
        features = discover_features(root, stack, architecture)

    report = {
        "version": "1.0.0",
        "generated": datetime.now(timezone.utc).isoformat(),
        "profile": profile,
        "project_root": str(root),
        "stack": stack,
        "entry_points": entry_points,
        "architecture": architecture,
        "readme_description": readme_desc,
        "test_patterns": test_patterns,
        "features": features,
    }

    return report


def main():
    parser = argparse.ArgumentParser(description="Analyze existing codebase for onboarding")
    parser.add_argument("--root", type=str, default=".", help="Project root directory")
    parser.add_argument("--output", type=str, required=True, help="Output JSON report path")
    parser.add_argument("--profile", type=str, default="core", choices=["core", "core+product"],
                        help="Agentic Framework profile")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"ERROR: {root} is not a directory")
        raise SystemExit(1)

    report = generate_report(root, args.profile)

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
    if report["features"]:
        print(f"Features discovered: {len(report['features'])}")


if __name__ == "__main__":
    main()
