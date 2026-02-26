# Quality Gates

Use these gates during the final quality pass and while running `scripts/lint_pptx.py`.

## Content density

- Keep body text within `220` characters per slide.
- Keep body bullet lines at `5` or fewer.
- Keep single bullet line length within `80` characters.
- Split slides when limits are exceeded.

## Visual usage

- Keep visual ratio at `0.50` or higher.
- Avoid more than `1` consecutive text-only slide.
- Replace dense paragraphs with charts, comparison tables, or process diagrams.

## Structured formatting

- Keep structured ratio at `0.90` or higher on content slides.
- Keep unstructured content slides at `0` (target and default gate).
- For each content slide, use at least one:
  - bullets,
  - table,
  - visual (chart/diagram/image).

## Consistency

- Keep terminology consistent across all headers and slides.
- Keep all numeric claims aligned with cited sources.
- Keep timeline statements consistent (no contradictory dates).
- Keep output language consistent with user prompt language (`ja` or `en`).
- Keep chart labels/titles/legends in the same language as slide text.
- For Japanese charts, ensure selected font renders all glyphs (no tofu boxes).

## Required final checks

1. Re-run source spot-checks for critical claims.
2. Run `scripts/lint_pptx.py --fail-on-warning`.
3. Fix and re-run until no warnings remain.
4. Return final output path and source list to the user.
