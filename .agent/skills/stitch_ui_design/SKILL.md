---
name: stitch_ui_design
description: Guiding principles and instructions for using the Google Stitch MCP to generate Liquid Glass UI components.
---

# Stitch UI Design Skill for CHARU

When creating or updating User Interfaces for CHARU using Stitch Developer tools, observe these specific criteria:

## 1. Liquid Glass Aesthetics
- **Transparency** & **Blur**: Apply background blur (15-20px, 0.75 alpha) for the Bottom Navigation, News Cards backgrounds, and popup backgrounds.
- **Borders**: Thin white borders for cards (e.g. 1px solid rgba(255, 255, 255, 0.2)).

## 2. Text Readability (CRITICAL)
- **Opaque Backgrounds**: Any element containing Chinese text MUST have a solid opaque background. Never apply blur directly to text-containing cards, only behind them.
- **Typography**: Minimum 18sp for body text.

## 3. Stitch Prompt Example
When utilizing Stitch to generate UI, embed this system prompt constraint:
> "Build a mobile reading app with Liquid Glass style. Semi-transparent cards for navigation elements (blur 15-20px, alpha 0.75), thin white borders. Text content areas must have solid opaque backgrounds for maximum CJK character readability. Dark theme with soft red accent (#FF6B6B). Bottom navigation with blur effect. Chinese text should use large clear font (minimum 18sp for body text)."
