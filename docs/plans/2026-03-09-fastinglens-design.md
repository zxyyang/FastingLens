# FastingLens Design

## Summary

`FastingLens` is a `local-first` fasting and meal logging app built as an `iPhone primary app` plus a `dependent Apple Watch app`.

The product goal is simple:

- Track `16+8` fasting cycles
- Let the user photograph meals on iPhone
- Send the image directly to a user-configured AI provider
- Receive structured meal recognition results
- Save confirmed data locally
- Surface fasting countdown and quick actions on Apple Watch

## Product Principles

- `AI by configuration`: the app must not hard-code one AI vendor
- `Local-first`: meal records, fasting sessions, reminders, and settings live locally
- `Lightweight on-device footprint`: no large embedded image-recognition engine in MVP
- `Reviewable AI output`: recognition results should be visible and editable before final save
- `Watch for speed`: Watch focuses on glanceable state and quick actions, not heavy input

## Platform Scope

- `iPhone`: primary experience, camera capture, AI setup, history, fasting plan
- `Apple Watch`: dependent watch app for reminders, current fasting state, quick logging
- `WidgetKit`: watch complication showing fasting countdown or progress
- `iCloud`: optional later phase using `CloudKit`; requires Apple Developer Program capability

## User Stories

- As a user, I can define a `16+8` fasting schedule and see whether I am in fasting or eating mode.
- As a user, I can take a photo of a meal and have AI return food type, estimated portion, and calories.
- As a user, I can paste a JSON config to switch AI providers without changing app code.
- As a user, I can review and fix AI results before saving them.
- As a user, I can use Apple Watch to check remaining fasting time and log quick events.
- As a user, I can optionally sync my local data through `iCloud` later.

## Functional Scope

### iPhone

- Dashboard
- Meal photo capture and import
- AI recognition review flow
- Meal history and editing
- Fasting plan setup
- Reminder setup
- AI provider management
- Export and backup settings

### Apple Watch

- Current fasting phase
- Countdown to phase change
- Quick actions:
  - Start fasting
  - End fasting
  - Log meal event
  - Skip reminder
- Daily summary snapshot

### Complication

- Remaining fasting time
- Remaining eating-window time
- Circular or corner progress visualization
- Fallback stale-state display when sync is outdated

## Information Architecture

### iPhone Tabs

1. `Home`
2. `Capture`
3. `History`
4. `Plan`
5. `AI`

### Watch Screens

1. `Status`
2. `Quick Log`
3. `Today`

## Core Flows

### Meal Recognition

1. User captures or selects a meal image on iPhone.
2. App loads the active AI provider JSON.
3. App transforms the image according to config rules.
4. App sends the request to the configured endpoint.
5. App parses the result into the unified meal schema.
6. User reviews the result and adjusts fields if needed.
7. App saves the meal locally.
8. App refreshes watch snapshot and complication timeline.

### Fasting Lifecycle

1. User starts a fasting session on iPhone or Watch.
2. App creates a `FastingSession`.
3. App calculates eating and fasting boundaries.
4. App schedules local notifications.
5. App syncs a watch snapshot.
6. Complication updates countdown/progress.

## AI Configuration Contract

The app should treat AI configuration as user data, not developer code.

Required behavior:

- Support multiple providers
- Allow raw JSON import and manual editing
- Allow one active provider at a time
- Support request templating and response-path extraction
- Validate the provider config before activation
- Preserve request and response logs if the user opts in

Expected normalized response:

```json
{
  "meal_type": "lunch",
  "food_items": [
    {
      "name": "grilled chicken breast",
      "portion": "150g",
      "estimated_calories": 250
    }
  ],
  "estimated_total_calories": 250,
  "confidence": 0.84,
  "notes": "Portion size is approximate."
}
```

## Data Model

- `UserProfile`
- `FastingPlan`
- `FastingSession`
- `MealRecord`
- `MealItem`
- `MealPhoto`
- `AIProviderConfig`
- `RecognitionJob`
- `ReminderRule`
- `WatchSnapshot`

## Storage Strategy

### MVP

- Use `SwiftData` as the primary local store
- Save photos in app-managed local storage
- Save AI configs as structured data plus raw JSON
- Store watch-facing state as a compact snapshot

### Later

- Add optional `CloudKit` sync behind a feature flag
- Keep the iPhone database as the primary authority
- Keep the watch database as a cache, not the source of truth

## Sync Strategy

- Use `WatchConnectivity` to push state updates from iPhone to Watch
- Sync only lightweight state:
  - active fasting session
  - today summary
  - recent meal summaries
  - reminder toggles
- Treat watch data as disposable cache

## Notifications

- Eating window starts
- Eating window ends soon
- Long time without a meal log
- Reminder tap should deep-link into the relevant iPhone or Watch action

## MVP Decisions

Included:

- `16+8` fasting timer
- AI provider JSON setup
- Meal photo recognition
- Manual confirmation before save
- Local meal history
- Watch reminders and quick logging
- Watch complication countdown

Excluded:

- Built-in large vision model
- Macro tracking beyond calories
- Social features
- Shared family plans
- Exercise calorie adjustments
- Multi-model routing

## Risks

- AI provider responses may be inconsistent unless schema validation is strict.
- Calorie estimates are inherently approximate and must be editable.
- Watch complication freshness depends on timely iPhone sync.
- `iCloud` sync introduces account, entitlement, and conflict-resolution work.

## Recommended Build Order

1. Shared domain models and provider config parser
2. iPhone AI settings screen
3. iPhone meal capture and review flow
4. Fasting plan and timer engine
5. Watch snapshot sync
6. Watch quick actions
7. Complication
8. Optional `CloudKit` sync

## Current Assumptions To Validate

- All AI recognition requests go through user-managed provider JSON.
- AI results always require manual confirmation in MVP.
- Photos are saved locally by default, with a future option to store only derived data.
- `iCloud` is phase 2, not phase 1.
