# Quality Gates

Use these gates during the final quality pass and while running `scripts/lint_pptx.py`.

## Ordered Design Checklist

1. Fix communication brief: audience, objective, and required decision/action.
2. Keep one message per slide and enforce story order (`agenda -> title -> content -> summary` by default).
3. Inspect slide masters, then map each page to an explicit intent (`title_cover`, `text_dense`, `text_brief`, `visual_split`, `visual_focus`, `table_comparison`, `table_focus`, `hybrid_data`).
4. Keep typography hierarchy stable (title > subtitle > body).
5. Keep font families and size scale limited and consistent across deck.
6. Keep color usage consistent (base/accent/warning) and readable contrast.
7. Keep margins, guides, and alignment consistent on all pages.
8. Keep density under control (line count, character count, line length).
9. Keep each content slide structured with bullets, table, or visual.
10. Keep image/diagram/chart style consistent (aspect ratio, caption style, icon style).
11. Keep terminology, units, dates, and language consistent.
12. Keep source notation consistent in speaker notes (`Sources:` section format).

## Lintable Gates (Automated)

- Keep body text within `220` characters per slide (`--max-chars`).
- Keep body bullet lines at `5` or fewer (`--max-bullets`).
- Keep single bullet line length within `80` characters (`--max-line-chars`).
- Keep visual ratio at `0.50` or higher (`--min-visual-ratio`).
- Avoid more than `1` consecutive text-only slide (`--max-consecutive-text-only`).
- Keep structured ratio at `0.90` or higher (`--min-structured-ratio`).
- Keep unstructured content slides at `0` (`--max-unstructured-content-slides`).
- Keep distinct font families at `2` or fewer (`--max-font-families`).
- Keep distinct font sizes at `6` or fewer (`--max-font-sizes`).
- Keep title/body median size ratio at `1.15` or higher (`--min-title-body-size-ratio`).
- Keep most-used content layout share at `0.65` or lower (`--max-layout-share`).
- Keep per-slide left guides at `4` or fewer (`--max-left-guides`).
- Keep minimum content margin at `0.30in` or higher (`--min-content-margin-inch`).
- Keep image aspect-ratio span controlled (`--max-image-aspect-ratio-span`).
- Enforce language consistency where required (`--language ja|en`).
- Enforce source-note format where required (`--require-sources-notes --sources-prefix "Sources:"`).

## Manual Review Gates (Non-automated)

- Check chart simplicity (avoid chartjunk, excessive legends, and unnecessary gridlines).
- Check icon/line/shadow style uniformity.
- Check image quality and tone consistency.
- Check business logic consistency across slides (numbers, claims, timeline).
- Check that each decision slide clearly states the required action.

## Required final checks

1. Re-run source spot-checks for critical claims.
2. Run:
   - `scripts/lint_pptx.py --input <deck.pptx> --language <ja|en> --fail-on-warning`
3. For research-heavy decks, run:
   - `scripts/lint_pptx.py --input <deck.pptx> --language <ja|en> --require-sources-notes --fail-on-warning`
4. Fix and re-run until no warnings remain.
5. Return final output path and source list to the user.
