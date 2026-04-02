---
name: publishing-app
description: >
  App store publishing workflow for mobile apps (iOS, Android, React Native,
  Flutter). Guides users through `ag publish` commands: init, preflight,
  build, screenshots, metadata, submit, and status. Use when the user wants
  to publish an app, set up publishing, check store submission status, or
  generate screenshots — e.g. "publish to app store", "ag publish", "submit
  to play store", "generate screenshots", "check publish status".
  Do NOT use for: general build/deploy tasks unrelated to app stores,
  web deployment, CI/CD setup.
compatibility: "Requires mobile project (iOS/Android/React Native/Flutter)."
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent]
metadata:
  author: agentic-framework
  version: "0.77.0"
---
# App Store Publishing

This skill orchestrates mobile app publishing via the `ag publish` commands.

## Quick Reference

| Command | What it does |
|---------|-------------|
| `ag publish init` | Scaffold publishing config |
| `ag publish preflight` | Validate prerequisites |
| `ag publish ios [--dry-run]` | Full iOS publishing pipeline |
| `ag publish android [--dry-run]` | Full Android publishing pipeline |
| `ag publish screenshots` | Generate store screenshots |
| `ag publish metadata --validate` | Check metadata completeness |
| `ag publish status` | Show current progress |

## Workflow

1. **Init**: Run `ag publish init` to create `.agentic/publish.yaml` and add settings to STACK.md
2. **Configure**: Edit `publish.yaml` with bundle ID, team ID, signing details
3. **Credentials**: Set environment variables (never hardcode secrets)
4. **Preflight**: Run `ag publish preflight` to validate everything
5. **Publish**: Run `ag publish ios` or `ag publish android`
6. **Monitor**: Run `ag publish status` to track progress

## Providers

- **fastlane**: Wraps fastlane commands (deliver, supply, snapshot, screengrab)
- **custom**: Delegates to user-defined scripts in publish.yaml

Set provider in STACK.md: `publish_provider: fastlane` or `publish_provider: custom`

## Key Files

- `.agentic/publish.yaml` — Publishing configuration
- `.agentic/session/publish-state.json` — Current publish progress (session-scoped)
- `.agentic/lib/tools/publish/` — Publishing scripts
- `.agentic/lib/tools/publish/providers/` — Provider implementations
- `.agentic/lib/auto/publish.py` — Python orchestrator

## Credential Environment Variables

### iOS
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_PATH`
- `MATCH_PASSWORD`, `MATCH_GIT_URL` (for code signing via match)

### Android
- `GOOGLE_PLAY_JSON_KEY_PATH`
- `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`
