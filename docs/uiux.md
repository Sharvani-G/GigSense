# GiGly — UI/UX Specification (Playful Geometric, applied)

This document takes the "Playful Geometric" design system (attached separately as your source-of-truth token/component reference) and applies it screen-by-screen, decision-by-decision to GiGly specifically. Nothing here contradicts the base design system — it specifies exactly *how* GiGly's actual content (fairness badges, coaching insights, chat) should express that system, so the result reads as a deliberate, considered app rather than a generic template with the design system's tokens dropped in.

---

## 1. The Core Design Idea for GiGly

**"Someone's got your back."** Not a banking dashboard, not a corporate compliance tool. The Memphis-inflected, sticker-book energy of Playful Geometric is a genuinely good fit for this brief specifically: gig work is precarious and often faceless, and this app's entire pitch is warmth and support. Every screen should feel like it's smiling *with* the worker, never *at* them — this rules out anything that reads as judgmental (harsh reds for underpayment, alarm-style iconography) in favor of the design system's existing pink/amber/mint palette, which already leans supportive rather than punitive.

## 2. Signature Element

**The Fairness Badge** is this app's one unmistakable, memorable visual moment (per the design system's "spend your boldness in one place" principle). Everything else in the app should be comparatively calm so this one element lands with full force each time it appears.

**Fair Pay badge**: pill shape, `quaternary` mint (#34D399) fill, white bold "Outfit" text "✅ Fair Pay", 2px dark border (#1E293B), hard 4px offset shadow, slight -2deg rotation for the sticker feel.

**Possibly Underpaid badge**: same pill shape, `secondary` hot pink (#F472B6) fill, white bold text "⚠️ Possibly Underpaid", same border/shadow/rotation treatment. Pink rather than a harsh red is a deliberate choice from the base palette — it reads as "pay attention," not "you did something wrong," which matters given the worker didn't cause the underpayment, the platform did.

**Entrance animation**: scale 0 → 1.1 → 1.0 with the design system's overshoot easing (`cubic-bezier(0.34, 1.56, 0.64, 1)`), roughly 500ms total. This is the one moment in the whole app that gets the full bounce treatment — no other element should compete with it for attention on the Fairness Result screen.

---

## 3. Screen-by-Screen Visual Spec

### 3.1 Home / Dashboard

- Background: `#FFFDF5` throughout, with a very faint dot-grid texture in the header area only (low opacity, ~4% — texture should be felt, not seen)
- Header greeting: "Outfit" ExtraBold, ~28px, foreground `#1E293B`
- **Weekly Insight card**: full-width, `tertiary` amber tint background (a soft ~15% tint of #FBBF24 over white, not full saturation — body text must stay easily legible), rounded-xl (16px), 2px dark border, hard shadow. Small "AI INSIGHT" pill badge top-right corner, violet fill, white text, tiny. Faint confetti-shape pattern (small triangles/circles, ~5% opacity) scattered behind the text block. Body text in Plus Jakarta Sans Medium, foreground color. This card gets a secondary, slightly gentler bounce entrance than the Fairness Badge (scale 0.9 → 1.0, less overshoot) — present but not competing with the app's main signature moment.
- **Stat cards** (Sticker Card spec exactly): white bg, 2px dark border, rounded-xl, 8px hard offset shadow in `#E2E8F0` for Earnings and Hours cards, and specifically `#F472B6` (pink) hard shadow for the Flagged Jobs card — this color-codes the one card that needs the worker's attention before they've even read the number. Each card has a floating icon-circle (32px, colored fill, white 2.5px-stroke Lucide icon inside, positioned half-overlapping the card's top border): coin/rupee icon for Earnings (violet circle), clock icon for Hours (mint circle), alert-triangle icon for Flagged (pink circle). Big stat number in Outfit Bold, ~32px. Small uppercase label beneath in Plus Jakarta Sans, tracking-wide, muted foreground color.
- **Chart**: `fl_chart` bar chart, bars in `accent` violet, rounded bar tops (matches the radius language elsewhere), simple gridlines in `border` gray, no chart-junk (no 3D, no gradient fills — keep it as clean and legible as the rest of the system is playful).
- **Platform pills**: small rounded-full tags, background rotates through violet/pink/amber/mint per platform in the order they first appear (the "confetti" rotational usage rule from the base system), white or dark text depending on contrast against that fill, showing "Zomato · ₹1,240 · 6 jobs" style content.
- **Empty state illustration**: a simple SVG built from the system's own primitive shapes — a circle (representing a coin) with a dashed squiggle "road" leading to it, in muted outline strokes, not filled/colorful (empty states should be calm, not competing visually with the app's populated, energetic state).

### 3.2 Log Job — Toggle & Manual Entry

- Toggle: two pill tabs side by side, ~50/50 width, active tab filled `accent` violet with white bold text, inactive tab outlined only (2px dark border, transparent fill, foreground text) — per the Secondary Button hover spec, inactive tab fills `tertiary` amber briefly on tap before switching (a small moment of tactile feedback).
- Platform dropdown: styled per the Input spec — white bg, 2px `#CBD5E1` border, rounded-lg (16px... actually per token use radius-md 16px for inputs), on focus/open border turns `accent` violet with a hard violet 4px shadow.
- Fare/Distance/Duration inputs: same Input spec, numeric keyboards, labels above each field in bold uppercase small tracking-wide text exactly as: "FARE (₹)", "DISTANCE (KM)", "DURATION (MIN)".
- "Log Job" button: full-width Candy Button — pill radius, `accent` violet fill, white bold text, 2px dark border, 4px hard shadow, hover lifts (-2px translate, shadow grows to 6px), press compresses (+2px translate, shadow shrinks to 2px). Small circular white icon-background with an ArrowRight icon inside, right-aligned within the button, per the Candy Button spec.

### 3.3 Log Job — Scan Screenshot

- "Choose from Gallery" / "Take Photo" as two Secondary Buttons side by side (outlined, fill `tertiary` amber on hover/press)
- Loading state while OCR processes: a simple centered spinner or a skeleton silhouette of the form fields — keep this calm and brief, no bounce here, this isn't the app's emotional moment
- Post-extraction form: identical styling to Manual Entry's inputs, but each pre-filled field gets a subtle one-time highlight flash (a soft violet outline pulse, ~600ms, once) when it first populates, so the worker's eye is drawn to what to review, without being alarming
- Confidence note (if any field failed): small text, muted foreground color, calm tone, positioned directly under the relevant blank field — never a red/alarming banner for this, it's expected normal behavior

### 3.4 Fairness Result

- This screen is intentionally the calmest in structure (centered, minimal chrome) so the Fairness Badge (§2) is the only thing competing for attention
- Below the badge: a simple two-column comparison — "Expected" and "Actual" fare, each in Outfit Bold numerals, muted labels beneath, separated by a thin dashed vertical divider (a literal application of the base system's "squiggle/dashed line as divider" texture rule)
- One-line explanation text, Plus Jakarta Sans Medium, centered, calm
- Two buttons at the bottom: "Log Another Job" (Secondary/outlined) and "Ask About This" (Primary/Candy Button, since this is the more likely/valuable next action)

### 3.5 Chat

- Background: same warm cream, with the faint dot-grid texture allowed to show through more here than elsewhere (chat screens tend to be visually sparse, so a bit more texture keeps it from feeling flat)
- User bubbles: `accent` violet fill, white text, right-aligned, asymmetric "speech bubble" radius per the base system's Special Blob Radius spec (`rounded-tl-2xl rounded-tr-2xl rounded-br-2xl rounded-bl-none`)
- Gemma bubbles: white/cream fill, 2px dark border, foreground text, left-aligned, mirrored radius (`rounded-tl-2xl rounded-tr-2xl rounded-bl-2xl rounded-br-none`), small circular avatar (28px, violet fill, a simple shield-outline icon in white, 2.5px stroke) positioned to the left of the bubble
- Quick-reply chips: small pill buttons, Secondary Button styling, arranged in a horizontal scroll row above the input if they don't fit on one line
- Typing indicator: three small dots inside a Gemma-styled bubble shape, each dot bouncing in sequence (staggered by ~150ms), respecting `prefers-reduced-motion` by falling back to a static "..." if motion is disabled
- Input row: rounded-full text field (matches pill language), circular send button (violet fill, white ArrowUp or Send icon) to its right, circular mic button (if voice bonus built) to the input's left, both icon-in-circle per the base system's iconography rule
- Disclaimer text under the input: tiny, muted foreground, "General guidance, not legal advice."

---

## 4. Motion Summary (restraint budget)

| Element | Motion | Intensity |
|---|---|---|
| Fairness Badge | Pop-in bounce, overshoot easing | **Full** — the app's one big moment |
| Weekly Insight card | Gentle pop-in on Home load | Medium |
| Stat cards | -1deg rotate + 1.02 scale on tap | Small, tactile |
| Pre-filled OCR fields | One-time highlight pulse | Small |
| Chat typing indicator | Staggered bounce dots | Small, continuous while waiting |
| Screen transitions (nav) | Simple 200–250ms fade/slide | Minimal — deliberately calm |
| `prefers-reduced-motion` | All bounce/wiggle/rotate effects disabled, replaced with instant or simple opacity transitions | N/A |

Deliberately **not** animated: navigation bar icons, dashboard chart load (should just render, no dramatic bar-grow animation — that reads as filler motion rather than meaningful feedback), button icons at rest.

---

## 5. Accessibility Notes Specific to GiGly

- Fairness state must **never** be communicated by color alone — the badge always includes both an icon (✅/⚠️) and explicit text ("Fair Pay" / "Possibly Underpaid"), per the base system's color-accessibility rule, and this matters more than usual here since correctly understanding this one signal is the app's entire value proposition.
- All tap targets minimum 48px height, especially on the Log Job form and chat input, since this app is designed to be used one-handed, often outdoors, often between deliveries.
- Focus states on all inputs/buttons: thick colored border + hard shadow per the base system spec — keep this even on mobile, don't strip it for "cleanliness."
- Chat and dashboard text must maintain the base system's stated AAA contrast (foreground `#1E293B` on background/white) — do not reduce opacity on body text for stylistic effect anywhere numbers or fairness information is shown.
