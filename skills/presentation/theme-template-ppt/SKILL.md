---
name: theme-template-ppt
description: Create PowerPoint decks from a provided theme and the template at assets/template.pptx. Use when asked to research a topic on the web, draft slide headers, expand each header into slide-ready content, aggressively structure slides with bullets, tables, and chart/diagram visuals, and actively apply template slide-master layouts while preventing text-heavy pages, validating consistency and density, and saving a final .pptx with its output path.
---

# Theme Template PPT

Create a PowerPoint deck from a theme and an assets template while keeping each slide visually clear and non-busy.

## Skill Boundary

- This skill handles:
  - research and draft slide content,
  - create deck/chart JSON inputs,
  - run `make_chart.py`, `build_pptx.py`, and `lint_pptx.py`,
  - return output paths and source list.
- Run this workflow in an already prepared Python environment.

## Input Contract

- Collect: theme, target audience, objective, preferred slide count, and deadline.
- Collect: `slide_title` for work directory naming.
- Use `assets/template.pptx` as the canonical template.
- Place reusable visuals (logo/icons/brand images) in `assets/`.
- Ask focused follow-up questions only when required inputs are missing.

## Work Directory and Output Policy

- Use this fixed root: `~/.foundry_local_playground/output/`.
- Use this fixed working/output directory: `~/.foundry_local_playground/output/<slide_title>/`.
- Stage template in that directory before building slides.
- Insert slides in order into the staged template.
- Save final `.pptx` in the same directory.

## Python Dependencies

- Install: `python3 -m pip install -r scripts/requirements.txt`
- Optional isolated environment:
  1. `python3 -m venv .venv`
  2. `source .venv/bin/activate`
  3. `python3 -m pip install -r scripts/requirements.txt`
- Packages:
  - `python-pptx`
  - `Pillow`
  - `matplotlib`

## Script Input Contract (Critical)

- `scripts/make_chart.py --spec` accepts:
  - JSON file path,
  - `@<path>`,
  - `-` (read JSON from stdin),
  - inline JSON object string.
- `scripts/make_chart.py` also supports inline quick args when `--spec` is omitted:
  - `--type`, `--labels`, `--values`, optional `--title`.
- `scripts/build_pptx.py --plan` accepts:
  - JSON file path,
  - `@<path>`,
  - `-` (read JSON from stdin),
  - inline JSON object string.
- Never pass Markdown (`.md`) or PPT/PPTX files as `--spec` or `--plan`.
- Always prepare machine-readable JSON before running build/lint steps.

## Workflow

### 1. Research Theme on the Web

- Search the web based on the theme.
- Prefer primary or official sources.
- Cross-check key claims with at least two sources.
- Record source URLs and retrieval dates.

### 2. Draft Slide Headers as Bullets

- Produce a bullet list of slide headers before writing slide bodies.
- Keep at least five headers unless the user specifies a different count.
- Attach one line of intent per header.

### 3. Deep-Dive Each Header and Build Slide Plan

- Expand each header into one slide message.
- Keep each slide to 2-5 concise bullet points.
- Choose at least one structured format per content slide:
  - bullets,
  - table,
  - diagram/chart image.
- Attach source links to factual claims.
- Build the plan JSON using `references/deck-plan-schema.md`.
- Add `layout_name` in slide specs when you need strict master layout control.
- Ensure plan input passed to `build_pptx.py` is valid JSON (file/stdin/inline JSON).

### 4. Plan Visuals Early and Aggressively

- Convert dense text into visuals whenever possible.
- Target at least one visual slide in every two slides.
- Use tables for comparisons, KPI snapshots, and option matrices.
- Generate charts/figures with `scripts/make_chart.py` when needed.
- Build chart JSON from `references/chart-spec-schema.md`.
- Save generated images to a predictable folder (for example `assets/generated/`).
- Ensure chart input passed to `make_chart.py` is valid JSON (file/stdin/inline JSON) or inline quick args.

### 5. Build Deck from Template

- Use `scripts/build_pptx.py` to stage template and populate slides from the plan JSON.
- Keep `--template` omitted by default so the script uses `assets/template.pptx`.
- Let the script auto-select the best slide-master layout for each slide type (title/visual/table/content).
- Example:

```bash
python3 scripts/build_pptx.py \
  --slide-title "market-outlook-2026" \
  --plan /absolute/path/deck_plan.json \
  --output final-deck.pptx
```

### 6. Validate Density and Visual Coverage

- Run `scripts/lint_pptx.py` after generation.
- Example:

```bash
python3 scripts/lint_pptx.py \
  --input ~/.foundry_local_playground/output/market-outlook-2026/final-deck.pptx \
  --fail-on-warning
```

- If warnings exist, fix by:
  - splitting crowded slides,
  - reducing bullet count,
  - replacing text blocks with charts/diagrams/tables.
- Re-run lint until the deck passes quality gates from `references/quality-gates.md`.

### 7. Perform Final Consistency Pass

- Check logical consistency across all slides.
- Check terminology and numeric consistency.
- Check that visual usage is sufficient and text density is controlled.

### 8. Save and Report

- Save final deck and return absolute path.
- Return:
  - work directory absolute path,
  - output `.pptx` absolute path,
  - staged template absolute path,
  - source URL list,
  - summary of major revisions made in quality pass.

## Script Quick Reference

- `scripts/build_pptx.py`: Build final `.pptx` from template and JSON plan.
- `scripts/lint_pptx.py`: Detect crowded and unstructured slides (bullets/table/visual checks).
- `scripts/make_chart.py`: Generate chart PNG files from simple JSON specs.

## References

- `references/deck-plan-schema.md`: Plan schema for `build_pptx.py`.
- `references/chart-spec-schema.md`: Chart schema for `make_chart.py`.
- `references/quality-gates.md`: Slide density and visual-usage thresholds.
