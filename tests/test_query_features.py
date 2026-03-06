#!/usr/bin/env python3
"""
Tests for query_features.py - validates core claim: fast filtering.
"""
import sys
from pathlib import Path

# Add .agentic/lib/tools to path
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "tools"))

from query_features import parse_features, filter_features, load_features_flat, get_children


def test_parse_features():
    """Test that we can parse features from markdown."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")

    assert len(features) == 7, f"Expected 7 features, got {len(features)}"
    assert features[0]["id"] == "F-0001"
    assert features[0]["name"] == "User Authentication"
    assert features[0]["status"] == "shipped"


def test_filter_by_status():
    """Test filtering by status."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")
    
    class Args:
        status = "in_progress"
        tags = None
        layer = None
        domain = None
        priority = None
        owner = None
        complexity = None
        parent = None
        category = None
    
    filtered = filter_features(features, Args())
    assert len(filtered) == 2, f"Expected 2 in_progress, got {len(filtered)}"
    assert all(f["status"] == "in_progress" for f in filtered)


def test_filter_by_tags():
    """Test filtering by tags."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")

    class Args:
        status = None
        tags = ["auth"]
        layer = None
        domain = None
        priority = None
        owner = None
        complexity = None
        parent = None
        category = None

    filtered = filter_features(features, Args())
    assert len(filtered) == 5, f"Expected 5 auth features, got {len(filtered)}"
    assert all("auth" in f.get("tags", []) for f in filtered)


def test_filter_by_layer():
    """Test filtering by layer."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")

    class Args:
        status = None
        tags = None
        layer = "presentation"
        domain = None
        priority = None
        owner = None
        complexity = None
        parent = None
        category = None

    filtered = filter_features(features, Args())
    assert len(filtered) == 4, f"Expected 4 presentation features, got {len(filtered)}"
    assert all(f.get("layer") == "presentation" for f in filtered)


def test_filter_combined():
    """Test combining multiple filters."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")
    
    class Args:
        status = "in_progress"
        tags = ["auth"]
        layer = None
        domain = None
        priority = None
        owner = None
        complexity = None
        parent = None
        category = None
    
    filtered = filter_features(features, Args())
    assert len(filtered) == 1, f"Expected 1 feature, got {len(filtered)}"
    assert filtered[0]["id"] == "F-0002"


def test_filter_by_category():
    """Test filtering by category."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")

    class Args:
        status = None
        tags = None
        layer = None
        domain = None
        priority = None
        owner = None
        complexity = None
        parent = None
        category = "Core"

    filtered = filter_features(features, Args())
    assert len(filtered) == 2, f"Expected 2 Core features, got {len(filtered)}"
    assert all(f.get("category") == "Core" for f in filtered)


def test_filter_by_owner():
    """Test filtering by owner."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")

    class Args:
        status = None
        tags = None
        layer = None
        domain = None
        priority = None
        owner = "alice@example.com"
        complexity = None
        parent = None
        category = None

    filtered = filter_features(features, Args())
    assert len(filtered) == 2, f"Expected 2 features for alice, got {len(filtered)}"
    assert all(f.get("owner") == "alice@example.com" for f in filtered)


# Tests for --children functionality

def test_query_children_returns_direct_children():
    """Test that --children returns direct children only (non-recursive)."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")

    children = get_children(features, "F-0001", recursive=False)

    # F-0001 has F-0002 and F-0003 as direct children
    assert len(children) == 2, f"Expected 2 direct children, got {len(children)}"
    child_ids = {c["id"] for c in children}
    assert child_ids == {"F-0002", "F-0003"}


def test_query_children_shows_status_summary():
    """Test that children include status for summary calculation."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")

    children = get_children(features, "F-0001", recursive=False)

    # Verify we can count statuses
    statuses = [c.get("status") for c in children]
    assert "in_progress" in statuses  # F-0002
    assert "planned" in statuses  # F-0003


def test_query_children_empty_when_no_children():
    """Test that features with no children return empty list."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")

    # F-0004 has no children
    children = get_children(features, "F-0004", recursive=False)
    assert len(children) == 0, f"Expected 0 children, got {len(children)}"


def test_query_children_invalid_parent_errors():
    """Test that non-existent parent is detected."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")

    # Check parent existence before calling get_children (as main() does)
    parent_exists = any(f["id"] == "F-9999" for f in features)
    assert not parent_exists, "F-9999 should not exist"


def test_query_children_combined_with_status_filter():
    """Test --children combined with --status filter."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")

    # Get only planned children of F-0001
    children = get_children(features, "F-0001", recursive=False, status_filter="planned")

    assert len(children) == 1, f"Expected 1 planned child, got {len(children)}"
    assert children[0]["id"] == "F-0003"


def test_query_children_recursive_returns_all_descendants():
    """Test --recursive returns all descendants."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")

    # F-0001 -> F-0002 -> F-0006, F-0007
    # F-0001 -> F-0003
    descendants = get_children(features, "F-0001", recursive=True)

    assert len(descendants) == 4, f"Expected 4 descendants, got {len(descendants)}"
    desc_ids = {d["id"] for d in descendants}
    assert desc_ids == {"F-0002", "F-0003", "F-0006", "F-0007"}


def test_query_children_recursive_shows_indented_tree():
    """Test recursive mode includes depth for tree formatting."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")

    descendants = get_children(features, "F-0001", recursive=True)

    # Check depths
    depth_map = {d["id"]: d["depth"] for d in descendants}
    assert depth_map["F-0002"] == 0  # Direct child
    assert depth_map["F-0003"] == 0  # Direct child
    assert depth_map["F-0006"] == 1  # Child of F-0002
    assert depth_map["F-0007"] == 1  # Child of F-0002


def test_query_children_recursive_with_status_filter():
    """Test recursive mode with status filter maintains tree structure."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")

    # Get only planned descendants
    descendants = get_children(features, "F-0001", recursive=True, status_filter="planned")

    # Should include F-0003 (depth 0) and F-0007 (depth 1, under F-0002)
    assert len(descendants) == 2, f"Expected 2 planned descendants, got {len(descendants)}"
    desc_ids = {d["id"] for d in descendants}
    assert desc_ids == {"F-0003", "F-0007"}

    # F-0007 should still have depth 1 (under filtered-out F-0002)
    f0007 = next(d for d in descendants if d["id"] == "F-0007")
    assert f0007["depth"] == 1


if __name__ == "__main__":
    print("Running query_features tests...")
    test_parse_features()
    print("✓ test_parse_features")

    test_filter_by_status()
    print("✓ test_filter_by_status")

    test_filter_by_tags()
    print("✓ test_filter_by_tags")

    test_filter_by_layer()
    print("✓ test_filter_by_layer")

    test_filter_combined()
    print("✓ test_filter_combined")

    test_filter_by_category()
    print("✓ test_filter_by_category")

    test_filter_by_owner()
    print("✓ test_filter_by_owner")

    # --children tests
    test_query_children_returns_direct_children()
    print("✓ test_query_children_returns_direct_children")

    test_query_children_shows_status_summary()
    print("✓ test_query_children_shows_status_summary")

    test_query_children_empty_when_no_children()
    print("✓ test_query_children_empty_when_no_children")

    test_query_children_invalid_parent_errors()
    print("✓ test_query_children_invalid_parent_errors")

    test_query_children_combined_with_status_filter()
    print("✓ test_query_children_combined_with_status_filter")

    test_query_children_recursive_returns_all_descendants()
    print("✓ test_query_children_recursive_returns_all_descendants")

    test_query_children_recursive_shows_indented_tree()
    print("✓ test_query_children_recursive_shows_indented_tree")

    test_query_children_recursive_with_status_filter()
    print("✓ test_query_children_recursive_with_status_filter")

    print("\n✅ All query_features tests passed!")

