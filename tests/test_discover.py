#!/usr/bin/env python3
"""
Unit tests for discover.py - codebase analysis engine.
Tests stack detection, feature discovery, architecture mapping.
"""
import json
import sys
from pathlib import Path

import pytest

# Add tools directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "tools"))

from discover import (
    detect_stack,
    detect_entry_points,
    detect_architecture,
    read_readme,
    detect_test_patterns,
    discover_features,
    generate_report,
    count_source_files,
)


# === Stack Detection Tests ===

class TestDetectStack:
    def test_nodejs_project(self, tmp_path):
        """Detect Node.js project from package.json."""
        (tmp_path / "package.json").write_text(json.dumps({
            "name": "test-app",
            "dependencies": {"express": "^4.18.0"},
            "devDependencies": {"jest": "^29.0.0"},
        }))
        (tmp_path / "package-lock.json").write_text("{}")
        (tmp_path / "src").mkdir()
        (tmp_path / "src" / "index.js").write_text("// app")

        stack = detect_stack(tmp_path)
        assert stack["language"] == "JavaScript/TypeScript"
        assert stack["framework"] == "Express"
        assert stack["package_manager"] == "npm"
        assert stack["test_framework"] == "jest"
        assert stack["confidence"]["language"] == "high"

    def test_typescript_project(self, tmp_path):
        """Detect TypeScript project from tsconfig.json."""
        (tmp_path / "tsconfig.json").write_text("{}")
        (tmp_path / "package.json").write_text(json.dumps({
            "dependencies": {"next": "^14.0.0", "react": "^18.0.0"},
            "devDependencies": {"vitest": "^1.0.0"},
        }))
        (tmp_path / "yarn.lock").write_text("")

        stack = detect_stack(tmp_path)
        assert stack["language"] == "TypeScript"
        assert stack["framework"] == "Next.js"
        assert stack["package_manager"] == "yarn"
        assert stack["test_framework"] == "vitest"

    def test_python_project(self, tmp_path):
        """Detect Python project from pyproject.toml."""
        (tmp_path / "pyproject.toml").write_text("""
[project]
name = "myapp"
dependencies = ["fastapi>=0.100.0", "uvicorn"]

[tool.pytest.ini_options]
testpaths = ["tests"]
""")
        (tmp_path / "uv.lock").write_text("")
        (tmp_path / ".python-version").write_text("3.12.1")

        stack = detect_stack(tmp_path)
        assert stack["language"] == "Python"
        assert stack["framework"] == "FastAPI"
        assert stack["package_manager"] == "uv"
        assert stack["test_framework"] == "pytest"
        assert stack["runtime"] == "Python 3.12.1"

    def test_python_requirements_txt(self, tmp_path):
        """Detect Python project from requirements.txt."""
        (tmp_path / "requirements.txt").write_text("django==4.2\ncelery>=5.0\n")
        (tmp_path / "tests").mkdir()
        (tmp_path / "tests" / "test_app.py").write_text("# test")

        stack = detect_stack(tmp_path)
        assert stack["language"] == "Python"
        assert stack["framework"] == "Django"
        assert stack["test_framework"] == "pytest"

    def test_go_project(self, tmp_path):
        """Detect Go project from go.mod."""
        (tmp_path / "go.mod").write_text("""module github.com/user/myapp

go 1.22

require github.com/gin-gonic/gin v1.9.0
""")
        (tmp_path / "go.sum").write_text("")
        (tmp_path / "main.go").write_text("package main")

        stack = detect_stack(tmp_path)
        assert stack["language"] == "Go"
        assert stack["framework"] == "Gin"
        assert stack["package_manager"] == "go"
        assert stack["test_framework"] == "go test"
        assert "1.22" in stack["runtime"]

    def test_rust_project(self, tmp_path):
        """Detect Rust project from Cargo.toml."""
        (tmp_path / "Cargo.toml").write_text("""
[package]
name = "myapp"

[dependencies]
axum = "0.7"
tokio = { version = "1", features = ["full"] }
""")
        (tmp_path / "Cargo.lock").write_text("")

        stack = detect_stack(tmp_path)
        assert stack["language"] == "Rust"
        assert stack["framework"] == "Axum"
        assert stack["package_manager"] == "cargo"
        assert stack["test_framework"] == "cargo test"

    def test_language_from_source_files(self, tmp_path):
        """Fall back to source file counting when no config file."""
        (tmp_path / "src").mkdir()
        for i in range(5):
            (tmp_path / "src" / f"mod{i}.py").write_text("# python")

        stack = detect_stack(tmp_path)
        assert stack["language"] == "Python"
        assert stack["confidence"]["language"] == "medium"

    def test_empty_project(self, tmp_path):
        """Handle empty project gracefully."""
        stack = detect_stack(tmp_path)
        assert stack["language"] is None
        assert stack["framework"] is None


# === Entry Point Detection Tests ===

class TestDetectEntryPoints:
    def test_python_entry_points(self, tmp_path):
        """Detect Python entry points."""
        (tmp_path / "main.py").write_text("# main")
        (tmp_path / "app.py").write_text("# app")

        entries = detect_entry_points(tmp_path)
        paths = [e["path"] for e in entries]
        assert "main.py" in paths
        assert "app.py" in paths

    def test_nodejs_entry_points(self, tmp_path):
        """Detect Node.js entry and scripts."""
        (tmp_path / "package.json").write_text(json.dumps({
            "main": "dist/index.js",
            "scripts": {"start": "node dist/index.js", "dev": "ts-node src/index.ts"},
        }))
        (tmp_path / "src").mkdir()
        (tmp_path / "src" / "index.ts").write_text("// entry")

        entries = detect_entry_points(tmp_path)
        paths = [e["path"] for e in entries]
        assert "src/index.ts" in paths
        assert "dist/index.js" in paths

    def test_go_cmd_pattern(self, tmp_path):
        """Detect Go cmd/ directories."""
        (tmp_path / "cmd").mkdir()
        (tmp_path / "cmd" / "server").mkdir()
        (tmp_path / "cmd" / "server" / "main.go").write_text("package main")
        (tmp_path / "cmd" / "cli").mkdir()
        (tmp_path / "cmd" / "cli" / "main.go").write_text("package main")

        entries = detect_entry_points(tmp_path)
        paths = [e["path"] for e in entries]
        assert "cmd/cli/" in paths
        assert "cmd/server/" in paths


# === Architecture Detection Tests ===

class TestDetectArchitecture:
    def test_monorepo_detection(self, tmp_path):
        """Detect monorepo with packages/ directory."""
        (tmp_path / "packages").mkdir()
        (tmp_path / "packages" / "web").mkdir()
        (tmp_path / "packages" / "web" / "index.ts").write_text("// web")
        (tmp_path / "packages" / "api").mkdir()
        (tmp_path / "packages" / "api" / "index.ts").write_text("// api")

        arch = detect_architecture(tmp_path)
        assert arch["is_monorepo"] is True
        pkg_names = [p["name"] for p in arch["monorepo_packages"]]
        assert "web" in pkg_names
        assert "api" in pkg_names

    def test_component_detection(self, tmp_path):
        """Detect standard component directories."""
        (tmp_path / "src").mkdir()
        (tmp_path / "src" / "components").mkdir()
        (tmp_path / "src" / "components" / "Button.tsx").write_text("// btn")
        (tmp_path / "src" / "api").mkdir()
        (tmp_path / "src" / "api" / "routes.ts").write_text("// routes")

        arch = detect_architecture(tmp_path)
        labels = [c["label"] for c in arch["components"]]
        assert "UI Components" in labels
        assert "API Layer" in labels

    def test_top_level_dirs(self, tmp_path):
        """Track top-level directories."""
        (tmp_path / "src").mkdir()
        (tmp_path / "src" / "app.ts").write_text("// app")
        (tmp_path / "tests").mkdir()
        (tmp_path / "tests" / "test_app.py").write_text("# test")

        arch = detect_architecture(tmp_path)
        dir_names = [d["name"] for d in arch["top_level_dirs"]]
        assert "src" in dir_names
        assert "tests" in dir_names


# === README Parsing Tests ===

class TestReadReadme:
    def test_basic_readme(self, tmp_path):
        """Extract description from README.md."""
        (tmp_path / "README.md").write_text("""# My Project

A web application for managing tasks efficiently.

## Installation

Run npm install...
""")
        desc = read_readme(tmp_path)
        assert desc is not None
        assert "web application" in desc
        assert "Installation" not in desc

    def test_readme_with_badges(self, tmp_path):
        """Skip badges at top of README."""
        (tmp_path / "README.md").write_text("""# MyLib

[![Build Status](https://img.shields.io/badge)
![Coverage](https://img.shields.io/coverage)

A library for data processing.

## Usage
""")
        desc = read_readme(tmp_path)
        assert desc is not None
        assert "library" in desc.lower()

    def test_no_readme(self, tmp_path):
        """Handle missing README gracefully."""
        desc = read_readme(tmp_path)
        assert desc is None

    def test_empty_readme(self, tmp_path):
        """Handle empty README."""
        (tmp_path / "README.md").write_text("# Project\n")
        desc = read_readme(tmp_path)
        # May return None or empty string
        assert desc is None or desc == ""


# === Test Patterns Tests ===

class TestDetectTestPatterns:
    def test_detect_test_dir(self, tmp_path):
        """Detect tests/ directory."""
        (tmp_path / "tests").mkdir()
        (tmp_path / "tests" / "test_app.py").write_text("# test")

        patterns = detect_test_patterns(tmp_path)
        assert len(patterns["test_dirs"]) == 1
        assert patterns["test_dirs"][0]["path"] == "tests"

    def test_detect_npm_test(self, tmp_path):
        """Detect test command from package.json."""
        (tmp_path / "package.json").write_text(json.dumps({
            "scripts": {"test": "vitest run"},
        }))

        patterns = detect_test_patterns(tmp_path)
        assert patterns["test_command"] is not None
        assert "vitest" in patterns["test_command"]

    def test_skip_default_npm_test(self, tmp_path):
        """Skip default npm test error command."""
        (tmp_path / "package.json").write_text(json.dumps({
            "scripts": {"test": 'echo "Error: no test specified" && exit 1'},
        }))

        patterns = detect_test_patterns(tmp_path)
        assert patterns["test_command"] is None


# === Feature Discovery Tests ===

class TestDiscoverFeatures:
    def test_monorepo_features(self, tmp_path):
        """Discover features from monorepo packages."""
        (tmp_path / "packages").mkdir()
        for pkg in ["auth", "billing", "notifications"]:
            pkg_dir = tmp_path / "packages" / pkg
            pkg_dir.mkdir()
            (pkg_dir / "index.ts").write_text(f"// {pkg}")

        arch = detect_architecture(tmp_path)
        features = discover_features(tmp_path, {"language": "TypeScript"}, arch)
        names = [f["name"].lower() for f in features]
        assert "auth" in names
        assert "billing" in names

    def test_route_features(self, tmp_path):
        """Discover features from page/route files."""
        pages_dir = tmp_path / "src" / "pages"
        pages_dir.mkdir(parents=True)
        (pages_dir / "dashboard.tsx").write_text("// dashboard")
        (pages_dir / "settings.tsx").write_text("// settings")
        (pages_dir / "_app.tsx").write_text("// app wrapper")  # Should be excluded

        arch = detect_architecture(tmp_path)
        features = discover_features(tmp_path, {"language": "TypeScript"}, arch)
        names = [f["name"].lower() for f in features]
        assert "dashboard" in names
        assert "settings" in names
        # _app.tsx should be excluded (starts with _)
        assert "_app" not in " ".join(names)

    def test_exclusion_list(self, tmp_path):
        """Verify non-feature dirs are excluded."""
        (tmp_path / "src").mkdir()
        for d in ["utils", "helpers", "config", "auth", "payments"]:
            dir_path = tmp_path / "src" / d
            dir_path.mkdir()
            (dir_path / "index.ts").write_text(f"// {d}")

        arch = detect_architecture(tmp_path)
        features = discover_features(tmp_path, {"language": "TypeScript"}, arch)
        names = [f["name"].lower() for f in features]
        assert "utils" not in names
        assert "helpers" not in names
        assert "config" not in names
        assert "auth" in names
        assert "payments" in names

    def test_empty_project_no_features(self, tmp_path):
        """Empty project produces no features."""
        arch = detect_architecture(tmp_path)
        features = discover_features(tmp_path, {}, arch)
        assert features == []

    def test_go_cmd_features(self, tmp_path):
        """Discover features from Go cmd/ directories."""
        (tmp_path / "go.mod").write_text("module test\ngo 1.22\n")
        (tmp_path / "cmd").mkdir()
        for cmd in ["server", "migrate"]:
            cmd_dir = tmp_path / "cmd" / cmd
            cmd_dir.mkdir()
            (cmd_dir / "main.go").write_text("package main")

        arch = detect_architecture(tmp_path)
        features = discover_features(tmp_path, {"language": "Go"}, arch)
        names = [f["name"].lower() for f in features]
        assert "server" in names
        assert "migrate" in names

    def test_max_features_cap(self, tmp_path):
        """Verify feature count is capped."""
        (tmp_path / "src").mkdir()
        for i in range(60):
            d = tmp_path / "src" / f"feature_{i}"
            d.mkdir()
            (d / "mod.py").write_text(f"# feature {i}")

        arch = detect_architecture(tmp_path)
        features = discover_features(tmp_path, {"language": "Python"}, arch)
        assert len(features) <= 50


# === Full Report Tests ===

class TestGenerateReport:
    def test_full_report_structure(self, tmp_path):
        """Verify report has all expected fields."""
        (tmp_path / "package.json").write_text(json.dumps({
            "name": "test",
            "dependencies": {"react": "^18.0.0"},
        }))
        (tmp_path / "README.md").write_text("# Test\n\nA test project.\n")

        report = generate_report(tmp_path, "core")
        assert "version" in report
        assert "generated" in report
        assert "stack" in report
        assert "entry_points" in report
        assert "architecture" in report
        assert "readme_description" in report
        assert "test_patterns" in report
        assert report["features"] == []  # Core profile: no features

    def test_core_pm_includes_features(self, tmp_path):
        """Core+PM profile includes feature discovery."""
        (tmp_path / "package.json").write_text(json.dumps({
            "name": "test",
            "dependencies": {"next": "^14.0.0"},
        }))
        pages = tmp_path / "src" / "pages"
        pages.mkdir(parents=True)
        (pages / "home.tsx").write_text("// home")

        report = generate_report(tmp_path, "core+product")
        assert len(report["features"]) > 0


# === Source File Counting ===

class TestCountSourceFiles:
    def test_counts_by_extension(self, tmp_path):
        """Count source files by extension."""
        (tmp_path / "app.py").write_text("# py")
        (tmp_path / "lib.py").write_text("# py")
        (tmp_path / "main.ts").write_text("// ts")

        counts = count_source_files(tmp_path)
        assert counts.get(".py", 0) == 2
        assert counts.get(".ts", 0) == 1

    def test_excludes_node_modules(self, tmp_path):
        """Exclude node_modules from counting."""
        (tmp_path / "node_modules").mkdir()
        (tmp_path / "node_modules" / "pkg.js").write_text("// excluded")
        (tmp_path / "app.js").write_text("// included")

        counts = count_source_files(tmp_path)
        assert counts.get(".js", 0) == 1
