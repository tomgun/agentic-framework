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
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "tools"))

from discover import (
    detect_stack,
    detect_entry_points,
    detect_architecture,
    read_readme,
    detect_test_patterns,
    discover_features,
    generate_report,
    count_source_files,
    detect_sub_projects,
    detect_serverless_functions,
    detect_ui_components,
    cluster_features,
    detect_api_specs,
    detect_infra_patterns,
    detect_domains,
    _normalize_name,
    _camel_case_split,
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
        for pkg in ["auth", "orders", "notifications"]:
            pkg_dir = tmp_path / "packages" / pkg
            pkg_dir.mkdir()
            (pkg_dir / "index.ts").write_text(f"// {pkg}")

        arch = detect_architecture(tmp_path)
        features = discover_features(tmp_path, {"language": "TypeScript"}, arch)
        names = [f["name"].lower() for f in features]
        assert "auth" in names
        assert "orders" in names

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

        report = generate_report(tmp_path, "discovery")
        assert report["version"] == "2.0.0"
        assert "generated" in report
        assert "stack" in report
        assert "entry_points" in report
        assert "architecture" in report
        assert "readme_description" in report
        assert "test_patterns" in report
        assert "sub_projects" in report
        assert report["features"] == []  # Discovery profile: no features

    def test_formal_includes_features(self, tmp_path):
        """Formal profile includes feature discovery."""
        (tmp_path / "package.json").write_text(json.dumps({
            "name": "test",
            "dependencies": {"next": "^14.0.0"},
        }))
        pages = tmp_path / "src" / "pages"
        pages.mkdir(parents=True)
        (pages / "home.tsx").write_text("// home")

        report = generate_report(tmp_path, "formal")
        assert len(report["features"]) > 0
        assert "serverless_functions" in report
        assert "ui_components" in report
        assert "feature_clusters" in report
        assert "api_spec_path" in report


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


# === Sub-project Detection Tests ===

class TestDetectSubProjects:
    def test_nested_package_json(self, tmp_path):
        """Detect sub-projects with package.json."""
        frontend = tmp_path / "frontend"
        frontend.mkdir()
        (frontend / "package.json").write_text(json.dumps({
            "dependencies": {"react": "^18.0.0"},
        }))
        (frontend / "tsconfig.json").write_text("{}")

        backend = tmp_path / "backend"
        backend.mkdir()
        (backend / "package.json").write_text(json.dumps({
            "dependencies": {"express": "^4.0.0"},
        }))

        sps = detect_sub_projects(tmp_path)
        assert len(sps) == 2
        names = {sp["name"] for sp in sps}
        assert names == {"backend", "frontend"}

        # Frontend has tsconfig → TypeScript
        fe = next(sp for sp in sps if sp["name"] == "frontend")
        assert fe["language"] == "TypeScript"
        assert fe["framework"] == "React"

        # Backend has no tsconfig → JavaScript
        be = next(sp for sp in sps if sp["name"] == "backend")
        assert be["language"] == "JavaScript"
        assert be["framework"] == "Express"

    def test_no_false_positives_node_modules(self, tmp_path):
        """node_modules should not be detected as a sub-project."""
        nm = tmp_path / "node_modules"
        nm.mkdir()
        (nm / "package.json").write_text("{}")
        (tmp_path / "src").mkdir()
        (tmp_path / "src" / "app.ts").write_text("// app")

        sps = detect_sub_projects(tmp_path)
        assert len(sps) == 0

    def test_azure_functions_host_json(self, tmp_path):
        """Sub-project with host.json detected as Azure Functions."""
        funcs = tmp_path / "functions"
        funcs.mkdir()
        (funcs / "package.json").write_text(json.dumps({"name": "functions"}))
        (funcs / "host.json").write_text("{}")

        sps = detect_sub_projects(tmp_path)
        assert len(sps) == 1
        assert sps[0]["framework"] == "Azure Functions"

    def test_python_sub_project(self, tmp_path):
        """Detect Python sub-project."""
        api = tmp_path / "api"
        api.mkdir()
        (api / "pyproject.toml").write_text('[project]\nname="api"\ndependencies=["fastapi"]\n')

        sps = detect_sub_projects(tmp_path)
        assert len(sps) == 1
        assert sps[0]["language"] == "Python"
        assert sps[0]["framework"] == "FastAPI"

    def test_sub_project_with_tests(self, tmp_path):
        """Detect has_tests for sub-projects."""
        fe = tmp_path / "frontend"
        fe.mkdir()
        (fe / "package.json").write_text("{}")
        (fe / "__tests__").mkdir()

        be = tmp_path / "backend"
        be.mkdir()
        (be / "package.json").write_text("{}")

        sps = detect_sub_projects(tmp_path)
        fe_sp = next(sp for sp in sps if sp["name"] == "frontend")
        be_sp = next(sp for sp in sps if sp["name"] == "backend")
        assert fe_sp["has_tests"] is True
        assert be_sp["has_tests"] is False


# === Serverless Function Detection Tests ===

class TestDetectServerlessFunctions:
    def test_azure_functions(self, tmp_path):
        """Parse Azure Functions function.json."""
        func_dir = tmp_path / "inventory"
        func_dir.mkdir()
        (func_dir / "function.json").write_text(json.dumps({
            "bindings": [
                {
                    "type": "httpTrigger",
                    "direction": "in",
                    "route": "inventory",
                    "methods": ["get"],
                    "authLevel": "anonymous",
                },
                {"type": "http", "direction": "out"},
            ]
        }))
        (func_dir / "index.ts").write_text("// handler")

        funcs = detect_serverless_functions(tmp_path)
        assert len(funcs) == 1
        assert funcs[0]["name"] == "inventory"
        assert funcs[0]["trigger"] == "http"
        assert funcs[0]["route"] == "inventory"
        assert funcs[0]["methods"] == ["GET"]
        assert funcs[0]["type_hint"] == "user-facing"

    def test_azure_admin_functions(self, tmp_path):
        """Admin prefix gets correct type hint."""
        func_dir = tmp_path / "adminUsers"
        func_dir.mkdir()
        (func_dir / "function.json").write_text(json.dumps({
            "bindings": [
                {"type": "httpTrigger", "direction": "in", "route": "admin/users", "methods": ["get", "post"]},
            ]
        }))

        funcs = detect_serverless_functions(tmp_path)
        assert len(funcs) == 1
        assert funcs[0]["type_hint"] == "admin"

    def test_aws_lambda_config(self, tmp_path):
        """Detect AWS Lambda serverless.yml."""
        (tmp_path / "serverless.yml").write_text("service: my-service\n")

        funcs = detect_serverless_functions(tmp_path)
        assert len(funcs) == 1
        assert funcs[0]["name"] == "_aws_lambda_config"
        assert funcs[0]["trigger"] == "config_file"

    def test_vercel_api(self, tmp_path):
        """Detect Vercel api/ functions."""
        api = tmp_path / "api"
        api.mkdir()
        (api / "hello.ts").write_text("// handler")
        (api / "users.ts").write_text("// handler")

        funcs = detect_serverless_functions(tmp_path)
        assert len(funcs) == 2
        names = {f["name"] for f in funcs}
        assert names == {"hello", "users"}
        assert all(f["trigger"] == "http" for f in funcs)

    def test_no_serverless(self, tmp_path):
        """Non-serverless project returns empty list."""
        (tmp_path / "src").mkdir()
        (tmp_path / "src" / "app.ts").write_text("// app")

        funcs = detect_serverless_functions(tmp_path)
        assert funcs == []

    def test_timer_trigger(self, tmp_path):
        """Detect timer trigger Azure Function."""
        func_dir = tmp_path / "cronCleanup"
        func_dir.mkdir()
        (func_dir / "function.json").write_text(json.dumps({
            "bindings": [
                {"type": "timerTrigger", "direction": "in", "schedule": "0 0 * * *"},
            ]
        }))

        funcs = detect_serverless_functions(tmp_path)
        assert len(funcs) == 1
        assert funcs[0]["trigger"] == "timer"


# === UI Component Detection Tests ===

class TestDetectUIComponents:
    def test_component_directory_grouping(self, tmp_path):
        """Detect component directories with 2+ source files."""
        comp_dir = tmp_path / "src" / "components" / "Orders"
        comp_dir.mkdir(parents=True)
        (comp_dir / "Orders.tsx").write_text("// orders")
        (comp_dir / "OrdersList.tsx").write_text("// list")
        (comp_dir / "OrdersDetail.tsx").write_text("// detail")

        small_dir = tmp_path / "src" / "components" / "Tiny"
        small_dir.mkdir()
        (small_dir / "Tiny.tsx").write_text("// only one file")

        comps = detect_ui_components(tmp_path, [])
        assert len(comps) == 1
        assert comps[0]["name"] == "Orders"
        assert comps[0]["file_count"] == 3

    def test_sub_project_components(self, tmp_path):
        """Detect components inside sub-projects."""
        fe = tmp_path / "frontend" / "src" / "components" / "Dashboard"
        fe.mkdir(parents=True)
        (fe / "Dashboard.tsx").write_text("// dash")
        (fe / "DashboardChart.tsx").write_text("// chart")

        sub_projects = [{"name": "frontend", "path": "frontend/", "language": "TypeScript",
                         "framework": "React", "has_tests": False}]
        comps = detect_ui_components(tmp_path, sub_projects)
        assert len(comps) == 1
        assert comps[0]["name"] == "Dashboard"
        assert comps[0]["path"] == "frontend/src/components/Dashboard"

    def test_excludes_utility_dirs(self, tmp_path):
        """Exclude utility directories from component detection."""
        for name in ["utils", "helpers", "Dashboard"]:
            d = tmp_path / "src" / "components" / name
            d.mkdir(parents=True)
            (d / "index.tsx").write_text("// code")
            (d / "helpers.tsx").write_text("// more code")

        comps = detect_ui_components(tmp_path, [])
        names = [c["name"] for c in comps]
        assert "Dashboard" in names
        assert "utils" not in names
        assert "helpers" not in names

    def test_screens_detected_as_mobile(self, tmp_path):
        """screens/ directories are detected."""
        screen_dir = tmp_path / "src" / "screens" / "Home"
        screen_dir.mkdir(parents=True)
        (screen_dir / "Home.tsx").write_text("// home")
        (screen_dir / "HomeStyles.ts").write_text("// styles")

        comps = detect_ui_components(tmp_path, [])
        assert len(comps) == 1
        assert comps[0]["name"] == "Home"


# === Feature Clustering Tests ===

class TestClusterFeatures:
    def test_prefix_matching(self, tmp_path):
        """Items with common prefix >= 4 chars are clustered."""
        ui = [
            {"name": "Inventory", "path": "frontend/src/components/Inventory", "file_count": 5},
        ]
        funcs = [
            {"name": "inventory", "trigger": "http", "route": "inventory",
             "methods": ["GET"], "type_hint": "user-facing", "path": "functions/inventory"},
            {"name": "inventoryDetail", "trigger": "http", "route": "inventory/average",
             "methods": ["GET"], "type_hint": "user-facing", "path": "functions/inventoryDetail"},
        ]

        clusters = cluster_features(ui, funcs, [])
        # All should be in one cluster (common prefix "inventory")
        assert len(clusters) == 1
        assert clusters[0]["name"] == "inventory"
        assert len(clusters[0]["frontend"]) == 1
        assert len(clusters[0]["backend"]) == 2
        assert clusters[0]["confidence"] == "medium"  # frontend + backend

    def test_confidence_levels(self, tmp_path):
        """Verify confidence based on tier count."""
        ui = [
            {"name": "Orders", "path": "frontend/src/components/Orders", "file_count": 3},
            {"name": "Orders", "path": "mobile/src/screens/Orders", "file_count": 2},
        ]
        funcs = [
            {"name": "orders", "trigger": "http", "route": "orders",
             "methods": ["GET"], "type_hint": "user-facing", "path": "functions/orders"},
        ]

        clusters = cluster_features(ui, funcs, [])
        orders = next(c for c in clusters if c["name"] == "orders")
        assert orders["confidence"] == "high"  # all 3 tiers

    def test_type_hint_tagging(self, tmp_path):
        """Admin functions get admin type hint on cluster."""
        funcs = [
            {"name": "adminUsers", "trigger": "http", "route": "admin/users",
             "methods": ["GET"], "type_hint": "admin", "path": "functions/adminUsers"},
            {"name": "adminRoles", "trigger": "http", "route": "admin/roles",
             "methods": ["GET"], "type_hint": "admin", "path": "functions/adminRoles"},
        ]

        clusters = cluster_features([], funcs, [])
        assert len(clusters) == 1
        assert clusters[0]["type_hint"] == "admin"

    def test_no_merge_short_prefix(self, tmp_path):
        """Items with < 4 char common prefix stay separate."""
        ui = [
            {"name": "Auth", "path": "src/components/Auth", "file_count": 3},
            {"name": "API", "path": "src/components/API", "file_count": 3},
        ]

        clusters = cluster_features(ui, [], [])
        assert len(clusters) == 2

    def test_empty_input(self):
        """Empty inputs produce no clusters."""
        clusters = cluster_features([], [], [])
        assert clusters == []

    def test_separate_unrelated(self):
        """Unrelated items stay in separate clusters."""
        ui = [
            {"name": "Orders", "path": "fe/src/components/Orders", "file_count": 3},
            {"name": "Inventory", "path": "fe/src/components/Inventory", "file_count": 5},
        ]

        clusters = cluster_features(ui, [], [])
        assert len(clusters) == 2
        names = {c["name"] for c in clusters}
        assert "orders" in names
        assert "inventory" in names


# === Name Normalization Tests ===

class TestNameNormalization:
    def test_camel_case_split(self):
        """camelCase splitting works correctly."""
        assert _camel_case_split("userProfileEdit") == ["user", "profile", "edit"]
        assert _camel_case_split("InventoryDetail") == ["inventory", "detail"]
        assert _camel_case_split("adminUsers") == ["admin", "users"]
        assert _camel_case_split("simple") == ["simple"]

    def test_normalize_name(self):
        """Normalize produces joined lowercase tokens."""
        assert _normalize_name("userProfileEdit") == "userprofileedit"
        assert _normalize_name("Inventory") == "inventory"
        assert _normalize_name("admin-users") == "adminusers"
        assert _normalize_name("my_component") == "mycomponent"


# === Stack Backfill from Sub-projects ===

class TestSubProjectStackBackfill:
    def test_language_from_sub_projects(self, tmp_path):
        """Root with no config gets language from unanimous sub-projects."""
        for name in ["frontend", "mobile"]:
            d = tmp_path / name
            d.mkdir()
            (d / "package.json").write_text("{}")
            (d / "tsconfig.json").write_text("{}")

        report = generate_report(tmp_path, "discovery")
        assert report["stack"]["language"] == "TypeScript"
        assert report["stack"]["confidence"]["language"] == "medium"

    def test_framework_multi(self, tmp_path):
        """Multiple sub-project frameworks produce Multi(...) framework."""
        fe = tmp_path / "frontend"
        fe.mkdir()
        (fe / "package.json").write_text(json.dumps({"dependencies": {"react": "^18"}}))
        (fe / "tsconfig.json").write_text("{}")

        funcs = tmp_path / "functions"
        funcs.mkdir()
        (funcs / "package.json").write_text("{}")
        (funcs / "host.json").write_text("{}")

        report = generate_report(tmp_path, "discovery")
        assert "Multi" in report["stack"]["framework"]
        assert "React" in report["stack"]["framework"]
        assert "Azure Functions" in report["stack"]["framework"]

    def test_package_manager_from_sub_project(self, tmp_path):
        """Root with no lockfile gets package manager from sub-project."""
        fe = tmp_path / "frontend"
        fe.mkdir()
        (fe / "package.json").write_text("{}")
        (fe / "yarn.lock").write_text("")

        report = generate_report(tmp_path, "discovery")
        assert report["stack"]["package_manager"] == "yarn"

    def test_no_backfill_when_root_has_config(self, tmp_path):
        """Root config takes priority over sub-projects."""
        (tmp_path / "package.json").write_text(json.dumps({
            "dependencies": {"next": "^14.0.0"},
        }))
        (tmp_path / "tsconfig.json").write_text("{}")
        (tmp_path / "package-lock.json").write_text("{}")

        fe = tmp_path / "frontend"
        fe.mkdir()
        (fe / "package.json").write_text(json.dumps({"dependencies": {"vue": "^3"}}))
        (fe / "yarn.lock").write_text("")

        report = generate_report(tmp_path, "discovery")
        # Root config wins
        assert report["stack"]["framework"] == "Next.js"
        assert report["stack"]["package_manager"] == "npm"


# === Integration: Multi-Sub-Project Structure ===

class TestMultiSubProjectIntegration:
    def test_multi_sub_project_repo(self, tmp_path):
        """Full integration test: multi-sub-project with serverless functions."""
        # web sub-project (React frontend)
        web = tmp_path / "web"
        (web / "src" / "components" / "Checkout").mkdir(parents=True)
        (web / "src" / "components" / "Checkout" / "Checkout.tsx").write_text("// checkout")
        (web / "src" / "components" / "Checkout" / "CheckoutForm.tsx").write_text("// form")
        (web / "src" / "components" / "Catalog").mkdir(parents=True)
        (web / "src" / "components" / "Catalog" / "Catalog.tsx").write_text("// catalog")
        (web / "src" / "components" / "Catalog" / "CatalogGrid.tsx").write_text("// grid")
        (web / "package.json").write_text(json.dumps({"dependencies": {"react": "^18"}}))
        (web / "tsconfig.json").write_text("{}")
        (web / "yarn.lock").write_text("")

        # api sub-project (Azure Functions)
        api = tmp_path / "api"
        api.mkdir()
        (api / "package.json").write_text("{}")
        (api / "host.json").write_text("{}")
        for fn_name in ["checkout", "checkoutConfirm", "catalog"]:
            fn_dir = api / fn_name
            fn_dir.mkdir()
            (fn_dir / "function.json").write_text(json.dumps({
                "bindings": [
                    {"type": "httpTrigger", "direction": "in",
                     "route": fn_name, "methods": ["get"]},
                ]
            }))
            (fn_dir / "index.ts").write_text(f"// {fn_name}")

        # mobile sub-project
        mobile = tmp_path / "mobile"
        (mobile / "src" / "screens" / "Checkout").mkdir(parents=True)
        (mobile / "src" / "screens" / "Checkout" / "CheckoutScreen.tsx").write_text("// screen")
        (mobile / "src" / "screens" / "Checkout" / "CheckoutStyles.ts").write_text("// styles")
        (mobile / "package.json").write_text(json.dumps({"dependencies": {"react-native": "^0.72"}}))
        (mobile / "tsconfig.json").write_text("{}")

        report = generate_report(tmp_path, "formal")

        # Sub-projects detected
        sp_names = {sp["name"] for sp in report["sub_projects"]}
        assert sp_names == {"web", "api", "mobile"}

        # Stack backfilled
        assert report["stack"]["language"] == "TypeScript"
        assert "Multi" in report["stack"]["framework"]
        assert report["stack"]["package_manager"] == "yarn"

        # Serverless functions detected
        sf_names = {f["name"] for f in report["serverless_functions"]}
        assert "checkout" in sf_names
        assert "checkoutConfirm" in sf_names
        assert "catalog" in sf_names

        # UI components detected
        comp_names = {c["name"] for c in report["ui_components"]}
        assert "Checkout" in comp_names
        assert "Catalog" in comp_names

        # Feature clusters created
        assert len(report["feature_clusters"]) > 0
        cluster_names = {c["name"] for c in report["feature_clusters"]}
        assert "checkout" in cluster_names
        assert "catalog" in cluster_names

        # Checkout cluster has frontend + backend + mobile = high confidence
        checkout = next(c for c in report["feature_clusters"] if c["name"] == "checkout")
        assert len(checkout["frontend"]) >= 1
        assert len(checkout["backend"]) >= 1
        assert len(checkout["mobile"]) >= 1
        assert checkout["confidence"] == "high"

        # Domains detected (3+ domains: web, api, mobile)
        assert "domains" in report
        assert len(report["domains"]) >= 3
        domain_names = {d["name"] for d in report["domains"]}
        assert "web" in domain_names
        assert "api" in domain_names
        assert "mobile" in domain_names

        # Domain types correct
        web_domain = next(d for d in report["domains"] if d["name"] == "web")
        assert web_domain["type"] == "frontend"
        mobile_domain = next(d for d in report["domains"] if d["name"] == "mobile")
        assert mobile_domain["type"] == "mobile"
        api_domain = next(d for d in report["domains"] if d["name"] == "api")
        assert api_domain["type"] == "backend"

        # Infra patterns always present (may be empty for this test)
        assert "infra_patterns" in report


# === Infrastructure Pattern Detection Tests ===

class TestDetectInfraPatterns:
    def test_github_actions(self, tmp_path):
        """Detect GitHub Actions workflows."""
        wf = tmp_path / ".github" / "workflows"
        wf.mkdir(parents=True)
        (wf / "ci.yml").write_text("name: CI\n")
        (wf / "deploy.yml").write_text("name: Deploy\n")

        patterns = detect_infra_patterns(tmp_path)
        assert len(patterns) >= 1
        ci_cd = [p for p in patterns if p["type"] == "ci_cd"]
        assert len(ci_cd) == 1
        assert "GitHub Actions" in ci_cd[0]["detail"]

    def test_terraform(self, tmp_path):
        """Detect Terraform IaC."""
        tf = tmp_path / "terraform"
        tf.mkdir()
        (tf / "main.tf").write_text('resource "aws_s3_bucket" "b" {}\n')

        patterns = detect_infra_patterns(tmp_path)
        iac = [p for p in patterns if p["type"] == "iac"]
        assert len(iac) == 1
        assert "Terraform" in iac[0]["detail"]

    def test_docker(self, tmp_path):
        """Detect Docker containers."""
        (tmp_path / "Dockerfile").write_text("FROM node:18\n")
        (tmp_path / "docker-compose.yml").write_text("version: '3'\n")

        patterns = detect_infra_patterns(tmp_path)
        containers = [p for p in patterns if p["type"] == "container"]
        assert len(containers) == 2  # Dockerfile + docker-compose

    def test_kubernetes(self, tmp_path):
        """Detect Kubernetes config."""
        (tmp_path / "k8s").mkdir()
        (tmp_path / "k8s" / "deployment.yaml").write_text("kind: Deployment\n")

        patterns = detect_infra_patterns(tmp_path)
        k8s = [p for p in patterns if p["type"] == "container" and "Kubernetes" in p["detail"]]
        assert len(k8s) == 1

    def test_empty_repo(self, tmp_path):
        """Non-infra repo returns empty list."""
        (tmp_path / "src").mkdir()
        (tmp_path / "src" / "app.py").write_text("# app")

        patterns = detect_infra_patterns(tmp_path)
        assert patterns == []

    def test_deploy_makefile(self, tmp_path):
        """Detect Makefile with deploy target."""
        (tmp_path / "Makefile").write_text("build:\n\tgo build\n\ndeploy:\n\tkubectl apply\n")

        patterns = detect_infra_patterns(tmp_path)
        deploy = [p for p in patterns if p["type"] == "deployment"]
        assert len(deploy) == 1
        assert "Makefile" in deploy[0]["detail"]

    def test_multiple_ci_cd(self, tmp_path):
        """Detect multiple CI/CD systems."""
        wf = tmp_path / ".github" / "workflows"
        wf.mkdir(parents=True)
        (wf / "ci.yml").write_text("name: CI\n")
        (tmp_path / "Jenkinsfile").write_text("pipeline {}\n")

        patterns = detect_infra_patterns(tmp_path)
        ci_cd = [p for p in patterns if p["type"] == "ci_cd"]
        assert len(ci_cd) == 2


# === Domain Detection Tests ===

class TestDetectDomains:
    def test_sub_projects_grouped_by_framework(self, tmp_path):
        """Sub-projects with recognized frameworks produce typed domains."""
        sub_projects = [
            {"name": "frontend", "path": "frontend/", "language": "TypeScript",
             "framework": "React", "has_tests": True},
            {"name": "api", "path": "api/", "language": "Python",
             "framework": "FastAPI", "has_tests": True},
        ]

        domains = detect_domains(tmp_path, sub_projects, [], {}, [])
        assert len(domains) == 2
        fe = next(d for d in domains if d["name"] == "frontend")
        assert fe["type"] == "frontend"
        api = next(d for d in domains if d["name"] == "api")
        assert api["type"] == "backend"

    def test_infra_domain_threshold(self, tmp_path):
        """Infrastructure domain created when >= 3 infra patterns."""
        infra = [
            {"type": "ci_cd", "path": ".github/workflows", "detail": "GitHub Actions"},
            {"type": "container", "path": "Dockerfile", "detail": "Docker"},
            {"type": "container", "path": "docker-compose.yml", "detail": "Docker Compose"},
        ]

        domains = detect_domains(tmp_path, [], [], {}, infra)
        infra_domains = [d for d in domains if d["type"] == "infrastructure"]
        assert len(infra_domains) == 1
        assert infra_domains[0]["name"] == "infrastructure"

    def test_infra_domain_from_iac_dir(self, tmp_path):
        """Infrastructure domain created when IaC directory exists (even < 3 total)."""
        infra = [
            {"type": "iac", "path": "terraform", "detail": "Terraform"},
        ]

        domains = detect_domains(tmp_path, [], [], {}, infra)
        infra_domains = [d for d in domains if d["type"] == "infrastructure"]
        assert len(infra_domains) == 1

    def test_no_infra_domain_below_threshold(self, tmp_path):
        """No infrastructure domain when < 3 patterns and no IaC dir."""
        infra = [
            {"type": "ci_cd", "path": ".github/workflows", "detail": "GitHub Actions"},
            {"type": "container", "path": "Dockerfile", "detail": "Docker"},
        ]

        domains = detect_domains(tmp_path, [], [], {}, infra)
        infra_domains = [d for d in domains if d["type"] == "infrastructure"]
        assert len(infra_domains) == 0

    def test_clusters_assigned_to_domains(self, tmp_path):
        """Clusters are assigned to domains by path prefix."""
        sub_projects = [
            {"name": "frontend", "path": "frontend/", "language": "TypeScript",
             "framework": "React", "has_tests": False},
        ]
        clusters = [
            {"name": "orders", "frontend": ["frontend/src/components/Orders/"],
             "backend": [], "mobile": [], "confidence": "low"},
        ]

        domains = detect_domains(tmp_path, sub_projects, clusters, {}, [])
        fe = next(d for d in domains if d["name"] == "frontend")
        assert "orders" in fe["clusters"]

    def test_single_project_fallback(self, tmp_path):
        """Single-project repo produces 1 domain named from root directory."""
        (tmp_path / "package.json").write_text(json.dumps({
            "name": "my-app",
            "dependencies": {"react": "^18"},
        }))

        domains = detect_domains(tmp_path, [], [], {}, [])
        assert len(domains) == 1
        assert domains[0]["name"] == "my-app"
        assert domains[0]["type"] == "frontend"

    def test_single_project_no_package(self, tmp_path):
        """Single-project without package.json uses directory name."""
        domains = detect_domains(tmp_path, [], [], {}, [])
        assert len(domains) == 1
        assert domains[0]["name"] == tmp_path.name

    def test_mobile_domain_type(self, tmp_path):
        """React Native sub-project gets mobile type."""
        sub_projects = [
            {"name": "mobile", "path": "mobile/", "language": "TypeScript",
             "framework": "React Native", "has_tests": False},
        ]

        domains = detect_domains(tmp_path, sub_projects, [], {}, [])
        assert len(domains) == 1
        assert domains[0]["type"] == "mobile"

    def test_azure_functions_domain(self, tmp_path):
        """Azure Functions sub-project gets backend type."""
        sub_projects = [
            {"name": "functions", "path": "functions/", "language": "TypeScript",
             "framework": "Azure Functions", "has_tests": False},
        ]

        domains = detect_domains(tmp_path, sub_projects, [], {}, [])
        assert len(domains) == 1
        assert domains[0]["type"] == "backend"
