#!/usr/bin/env bash
# Description: Agent should read and reference CONTEXT_PACK.md for project understanding
# Section: context
# Category: Important
# Tests: LLM-070 (partial)

# Setup
setup_test_project "discovery"

# Create a CONTEXT_PACK.md with specific project info
cat > "$TEST_PROJECT/CONTEXT_PACK.md" << 'EOF'
# Context Pack

## Project Overview
This is a **weather dashboard** application that displays real-time weather data.

## Tech Stack
- Frontend: React with TypeScript
- API: OpenWeatherMap
- Styling: Tailwind CSS

## Key Files
- `src/App.tsx` - Main application component
- `src/api/weather.ts` - Weather API integration
- `src/components/` - UI components

## Running the Project
```bash
npm install
npm run dev
```

## Architecture Notes
The app uses a custom hook `useWeather` for data fetching.
EOF

git -C "$TEST_PROJECT" add CONTEXT_PACK.md
git -C "$TEST_PROJECT" commit -m "Add context pack" --quiet

# Ask about the project
send_prompt "What is this project about and how do I run it?"

# Verify agent behavior
FAILURES=0

# Agent should mention the project type from CONTEXT_PACK
check_output_contains "weather\|dashboard" \
    "Agent knows project type from CONTEXT_PACK" || ((FAILURES++))

# Agent should know the tech stack
check_output_contains "React\|TypeScript\|Tailwind" \
    "Agent knows tech stack" || ((FAILURES++))

# Agent should know how to run it
check_output_contains "npm.*install\|npm.*dev\|npm run" \
    "Agent knows how to run the project" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
