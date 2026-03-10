# FastingLens UI Direction

## Visual Thesis

The product should feel like a `metabolic field notebook`, not a sterile medical dashboard.

The visual language mixes three cues:

- `Editorial health journal`: bold headings, spacious composition, strong hierarchy
- `Warm analog tracker`: paper-like surfaces, stamped labels, humane color temperature
- `Precision instrument`: crisp progress rings, countdown emphasis, confidence badges

The UI should be memorable for one thing: `time feels physical`.

Fasting is not shown as a generic timer. It is shown as a tangible window with mass, depth, and momentum. Cards should feel like clipped schedule boards. AI results should feel like inspected evidence, not black-box magic.

## Color System

- `Ink`: deep graphite for primary text and timer emphasis
- `Paper`: warm ivory background for the app shell
- `Tomato`: urgent accents for eating-window warnings
- `Sage`: stable state for fasting and confirmation
- `Citron`: high-energy highlight for AI actions and primary CTAs
- `Fog`: muted panels and secondary strokes

## Typography

- Headline style: large, condensed, serif-leaning presentation through `.fontDesign(.serif)`
- Utility labels: compact rounded style for pills and data chips
- Numeric emphasis: heavy rounded digits for countdowns and calorie totals

## Component Direction

- `Dashboard cards`: oversized corners, layered shadows, thin inset strokes
- `Phase ring`: thick circular progress with phase-specific tint
- `AI result sheet`: stacked evidence blocks with confidence chips and editable food rows
- `Watch status`: stripped down, high-contrast, no clutter, one dominant metric per screen

## Motion

- Gentle card rise on first load
- Progress ring sweep on phase transition
- AI result rows stagger in after parsing
- No busy looping animation; motion should signal state change, not decorate idly

## Accessibility

- High contrast by default
- Every color state must also have text and icon support
- Countdown and phase must remain readable with Dynamic Type
- Quick actions on watch must be reachable in one or two taps
