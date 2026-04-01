#!/usr/bin/env bash
# commands/help.sh — Help display for ag command
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

show_help() {
    local ft
    ft=$(get_setting "feature_tracking" "no")
    if [ "$ft" = "no" ]; then
        cat << 'EOF'
ag - Agentic Framework Gateway

USAGE:
    ag <command> [options]

COMMANDS:
    start               Session start checks + context summary
    init                Run project initialization interview
    work "description"  Start WIP tracking for a task
    todo <args>         Quick-capture ideas/tasks to TODO.md inbox
    commit              Run all pre-commit gates
    done                Task complete validation
    flush [opts]        Commit state files to main (no PR). --dry-run, --check, --features
    dogfood [--brief]   Detect root vs template instruction file drift (framework-dev)
    docs [F-XXXX]       Draft docs from registry (STACK.md ## Docs)
    set [key] [value]   View/change settings (--show, --validate, --migrate)
    hooks <sub>         Manage git hooks (install|status|disable)
    approve-onboarding  Review/approve auto-discovered proposals
    trace [options]     Spec-code traceability (drift + coverage)
    test llm [options]  Run LLM behavioral tests
    analyze-session <path> [--json]  Detect workflow violations in Claude JSONL logs
    agents <sub>        Project agent management (generate|list|clean)
    tools               List all available tools by category
    backlog <sub>       Ordered work queue (add|list|done|move|remove|clear)
    auto <sub>           Autonomous workflow (init|epic|status|pause|resume|stop|feedback)
    coord <sub>          Coordination server (start|stop|status)
    transition F-XXXX <state>  Manage feature state transitions (--status, --next, --dry-run, --unblocked)
    review [F-XXXX] [state]    Review checkpoint management (--approve, --reject, --reason)
    kickoff <sub>       Vision-to-backlog pipeline (prompt|--review|--approve|--discard|--status)
    decompose F-XXXX    Break epic into child features by component
    qa [--check|--json] QA Registry: feature-to-test map and gap analysis
    audit [options]     Spec verification & QA audit (--full, --status, --propagate, --metrics)
    nfr [sub]           NFR management (list, discover, coverage)
    worktree <sub>      Manage git worktrees (create|list|remove|path|status)
    intent [sub]        Manage intent journal (list|clear F-XXXX)
    formalize [T-XXXX...]  Promote TODO items to formal features + AC stubs
    git-init            Activate git version control (safe: .gitignore first, scaffold commit)
    gitignore           Generate/update stack-aware .gitignore
    sync [--check|--quiet] Detect drift across all artifacts, auto-fix safe errors
    export <tool|all>   Generate instruction files for AI tools (claude|cursor|copilot|codex)
    publish <sub>        App store publishing (init|preflight|ios|android|screenshots|metadata|status)
    verify [--full]     Run doctor verification
    run                 Show how to run this project
    status              Show current project status
    help                Show this help

EXAMPLES:
    ag start                    # Begin a new session
    ag init                     # Initialize project (if not done)
    ag run                      # Show how to run this project
    ag backlog add --task "X"   # Add task to work queue
    ag backlog list             # Show ordered queue
    ag work "Add login form"    # Start working on a task
    ag todo "Try new library"   # Capture idea to TODO.md
    ag todo list                # Show inbox items
    ag todo done T-0001 "done"  # Resolve item
    ag flush                    # Commit state files to main (PR if protected)
    ag flush --dry-run          # Preview what would be flushed
    ag docs                     # Draft docs for current work
    ag docs --list              # Show doc registry
    ag docs generate            # Generate all deferred docs
    ag auto init                # Set up auto mode settings
    ag auto status              # Check engine state
    ag auto pause               # Pause running engine
    ag intent list              # Show pending/orphaned intents
    ag intent clear F-0042      # Cancel a stuck intent
    ag sync                     # Full sync: detect + auto-fix
    ag sync --check             # Dry run: detect only
    ag commit                   # Verify ready to commit
    ag done                     # Check task completion
    ag approve-onboarding       # List unapproved proposals
    ag approve-onboarding --all # Approve all proposals
    ag trace                    # Full drift + coverage report
    ag trace --gaps             # Show only gaps
    ag test llm                 # Run all LLM behavioral tests
    ag test llm --critical      # Run critical tests only
    ag tools                    # Discover available tools
    ag agents generate          # Generate project-specific agents from stack
    ag agents generate --dry-run # Preview what would be generated
    ag agents list              # List current project agents

No formal feature tracking. Use STATUS.md for focus.
EOF
    else
        cat << 'EOF'
ag - Agentic Framework Gateway (Feature Tracking)

USAGE:
    ag <command> [options]

COMMANDS:
    start               Session start checks + context summary
    init                Run project initialization interview
    plan F-XXXX         Create plan with review loop (before implementing)
    implement F-XXXX    Verify acceptance exists, start WIP tracking
    spec [F-XXXX]       Write/check spec for a feature (single feature workflow)
    specs               Systematic brownfield spec generation by domain
    todo <args>         Quick-capture ideas/tasks to TODO.md inbox
    commit              Run all pre-commit gates
    done [F-XXXX]       Feature complete validation
    flush [opts]        Commit state files to main (no PR). --dry-run, --check, --features
    dogfood [--brief]   Detect root vs template instruction file drift (framework-dev)
    docs [F-XXXX]       Draft docs from registry (STACK.md ## Docs)
    set [key] [value]   View/change settings (--show, --validate, --migrate)
    hooks <sub>         Manage git hooks (install|status|disable)
    approve-onboarding  Review/approve auto-discovered proposals
    trace [options]     Spec-code traceability (drift + coverage)
    test llm [options]  Run LLM behavioral tests
    analyze-session <path> [--json]  Detect workflow violations in Claude JSONL logs
    agents <sub>        Project agent management (generate|list|clean)
    tools               List all available tools by category
    backlog <sub>       Ordered work queue (add|list|done|move|remove|clear)
    auto <sub>           Autonomous workflow (init|epic|status|pause|resume|stop|feedback)
    coord <sub>          Coordination server (start|stop|status)
    transition F-XXXX <state>  Manage feature state transitions (--status, --next, --dry-run, --unblocked)
    review [F-XXXX] [state]    Review checkpoint management (--approve, --reject, --reason)
    kickoff <sub>       Vision-to-backlog pipeline (prompt|--review|--approve|--discard|--status)
    phase <sub>          Multi-session plan phase tracking (list|done|active|drop|sync)
    decompose F-XXXX    Break epic into child features by component
    qa [--check|--json] QA Registry: feature-to-test map and gap analysis
    audit [options]     Spec verification & QA audit (--full, --status, --propagate, --metrics)
    nfr [sub]           NFR management (list, discover, coverage)
    worktree <sub>      Manage git worktrees (create|list|remove|path|status)
    intent [sub]        Manage intent journal (list|clear F-XXXX)
    formalize [T-XXXX...]  Promote TODO items to formal features + AC stubs
    publish <sub>        App store publishing (init|preflight|ios|android|screenshots|metadata|status)
    migrate-specs [opts]   Convert markdown ACs to YAML contracts (--dry-run, --archive)
    git-init            Activate git version control (safe: .gitignore first, scaffold commit)
    gitignore           Generate/update stack-aware .gitignore
    sync [--check|--quiet] Detect drift across all artifacts, auto-fix safe errors
    export <tool|all>   Generate instruction files for AI tools (claude|cursor|copilot|codex)
    verify [--full]     Run doctor verification
    run                 Show how to run this project
    status              Show current project status
    help                Show this help

EXAMPLES:
    ag start                    # Begin a new session
    ag init                     # Initialize project (if not done)
    ag run                      # Show how to run this project
    ag backlog add F-0042       # Add feature to work queue
    ag backlog add F-0042 -p 0  # Make it current work
    ag backlog list             # Show full queue
    ag backlog done             # Mark current done, advance
    ag plan F-0042              # Create plan with iterative review
    ag plan F-0042 --no-review  # Create plan without review loop
    ag implement F-0042         # Start working on feature F-0042
    ag phase list F-0042        # Show plan phases and progress
    ag phase done F-0042 2      # Mark phase 2 complete
    ag spec                     # Print spec-writing checklist for new feature
    ag spec F-0042              # Show spec status for F-0042
    ag spec --check             # Run spec health check on all features
    ag specs                    # Start/resume brownfield spec generation
    ag specs --status           # Show domain progress
    ag migrate-specs --dry-run  # Preview markdown AC to YAML migration
    ag migrate-specs --archive  # Migrate and archive old files
    ag todo "Try new library"   # Capture idea to TODO.md
    ag todo list                # Show inbox items
    ag todo done T-0001 "done"  # Resolve item
    ag flush                    # Commit state files to main (PR if protected)
    ag flush --dry-run          # Preview what would be flushed
    ag flush --features         # Include FEATURES.md status changes
    ag commit                   # Verify ready to commit
    ag done F-0042              # Check feature completion
    ag decompose F-0042         # Break epic into child features
    ag auto init                # Set up auto mode (generates settings.json)
    ag auto init --tier 1       # Set up for Docker sandbox
    ag auto status              # Check engine state
    ag auto pause               # Pause running engine
    ag auto resume              # Resume paused engine
    ag auto stop                # Stop running engine
    ag auto epic F-0042         # Autonomously execute epic's children
    ag auto feedback AC-003 "use existing auth"
    ag approve-onboarding       # List unapproved proposals
    ag approve-onboarding --all # Approve all proposals
    ag trace                    # Full drift + coverage report
    ag trace F-0042             # What files implement F-0042?
    ag trace src/auth.py        # What features does auth.py implement?
    ag trace --gaps             # Show only gaps (missing implementations)
    ag trace --json             # Machine-readable combined output
    ag test llm                 # Run all LLM behavioral tests
    ag test llm --critical      # Run critical tests only
    ag tools                    # Discover available tools
    ag agents generate          # Generate project-specific agents from stack
    ag agents generate --dry-run # Preview what would be generated
    ag agents list              # List current project agents
    ag docs F-0042              # Draft docs for feature F-0042
    ag docs --list              # Show doc registry from STACK.md
    ag docs --pr                # Draft PR-trigger docs only
    ag docs --check             # Dry run: what would be drafted
    ag docs generate            # Generate all deferred docs
    ag docs generate F-0042     # Generate deferred docs for one feature
    ag intent list              # Show pending/orphaned intents
    ag intent clear F-0042      # Cancel a stuck intent
    ag sync                     # Full sync: detect + auto-fix
    ag sync --check             # Dry run: detect only
    ag verify --full            # Full verification

Feature tracking with YAML contracts. Migrate from markdown: ag migrate-specs
EOF
    fi
}
