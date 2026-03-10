# FastingLens Implementation Plan

## Delivery Strategy

Build the product vertically, not layer-by-layer. Each slice should leave behind something usable.

## Slice 1: Domain and AI config

- Shared fasting and meal models
- AI provider JSON model
- JSON decode validation tests

Status: `completed`

## Slice 2: UI foundations

- Theme tokens
- Dashboard card composition
- AI settings JSON editor
- Watch status summary view
- Sample preview data

Status: `in progress`

## Slice 3: App shell

- iPhone SwiftUI app target
- Watch app target
- Widget extension target
- Shared environment wiring

## Slice 4: Fasting engine

- Active session state
- Countdown math
- Reminder scheduling hooks
- Phase transitions

## Slice 5: AI capture flow

- Image picker/camera bridge
- Request assembly from provider config
- Response normalization
- Manual confirmation before save

## Slice 6: Watch sync

- Snapshot generator
- `WatchConnectivity` bridge
- Quick log actions
- Complication data provider

## Slice 7: Optional cloud sync

- `CloudKit` capability
- Conflict strategy
- iCloud migration path

## Testing Strategy

- Keep pure countdown and config-validation logic in packages with `swift test`
- Add parser tests before writing the network layer
- Add snapshot/sample-data previews before app shell integration
- Once Xcode targets exist, run simulator build checks for iPhone and Watch
