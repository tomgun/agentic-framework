# Doc Types Reference

Built-in doc type definitions for the doc lifecycle system (F-0139).
Projects reference these type names in their `STACK.md ## Docs` registry.

## changelog

**Typical path**: `CHANGELOG.md`
**Default trigger**: `pr`
**Write strategy**: prepend

Draft a new entry under `[Unreleased]` using [Keep a Changelog](https://keepachangelog.com/) format.
Group changes under: Added, Changed, Fixed, Removed. If no `[Unreleased]` heading exists, add one.

**New file template**:
```
# Changelog

All notable changes will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]
```

## readme

**Typical path**: `README.md`
**Default trigger**: `pr`
**Write strategy**: append-section

Only draft when user-facing functionality changed. Append a clearly marked section at end:
`<!-- draft: F-#### YYYY-MM-DD -->`. Cover: what changed, how to use it, any new config.

**New file template**:
```
# Project Name

## Overview

## Getting Started

## Usage
```

## lessons

**Typical path**: `docs/lessons.md`
**Default trigger**: `feature_done`
**Write strategy**: append

Append one entry at end of file. Include: what was learned, what would be done differently,
any patterns worth reusing. Keep it brief (3-5 bullet points).

**New file template**:
```
# Lessons Learned

Insights and patterns discovered during development.

## Entries
```

## architecture

**Typical path**: any `.md`
**Default trigger**: `feature_done`
**Write strategy**: append-section

Append a section update for changed subsystems. Include: what component changed, why,
how it connects to existing architecture. Reference diagrams if they exist.

**New file template**:
```
# Architecture

## Overview

## Components

## Data Flow
```

## adr

**Typical path**: `docs/adr/`
**Default trigger**: `manual`
**Write strategy**: new-file

Create a new ADR file (numbered sequentially). Format: title, status (proposed), context,
decision, consequences. ADRs are never auto-triggered — they require human judgment.

**New file template** (for `NNNN-title.md`):
```
# NNNN. Title

## Status
Proposed

## Context

## Decision

## Consequences
```

## runbook

**Typical path**: any `.md`
**Default trigger**: `manual`
**Write strategy**: append-section

Append an operations section for new behavior. Include: what to monitor, how to
troubleshoot, rollback procedure if applicable.

**New file template**:
```
# Runbook

## Operations

## Monitoring

## Troubleshooting
```

## tech-spec

**Typical path**: `spec/TECH_SPEC.md`
**Default trigger**: `feature_done`
**Write strategy**: append-section

Append technical details for changed components. Include: implementation approach,
data structures, API contracts, performance characteristics.

**New file template**:
```
# Technical Specification

## Architecture Overview

## Components

## Data Flow
```

## custom

**Typical path**: any
**Default trigger**: configurable
**Write strategy**: append-section

For docs the framework doesn't know about. The agent reads the existing doc's structure
and drafts an update section that fits the established format. If the file doesn't exist,
creates it with a generic heading and the drafted section.

**New file template**:
```
# Document Title

## Content
```
