---
name: theme-template-ppt
description: Create PowerPoint decks from assets/template.pptx by first inspecting template slide-master layouts, then filling each slide with a matching layout_name in deck-plan JSON. Use when asked to research a topic, draft slide headers, expand headers into slide-ready content, generate chart/table visuals, run build/lint scripts, and return final .pptx outputs. Do not use for Python environment provisioning (use python-venv).
---

# Theme Template PPT

Create a PowerPoint deck from a theme and an assets template while keeping each slide visually clear and non-busy.

## Skill Boundary

- This skill handles:
  - research and draft slide content,
  - create deck/chart JSON inputs,
  - inspect template master layouts,
  - run `make_chart.py`, `build_pptx.py`, and `lint_pptx.py`,
  - return output paths and source list.
- This skill does not provision Python environments.
- Run this workflow only after the environment is prepared (for example by `python-venv`).

## Hard Rules

- Keep responsibility separation:
  - `python-venv`: environment creation/switch/dependency install only.
  - `theme-template-ppt`: research/planning/build/lint/output only.
- Do not call `python-venv` scripts from this skill.
- Do not read `assets/template.pptx` as base64 or plain text.
- Do not run `skill_list_resources` just to inspect template internals.
- Never pass non-JSON files to:
  - `scripts/make_chart.py --spec`
  - `scripts/build_pptx.py --plan`
- If required runtime dependencies are missing, stop and ask for environment provisioning handoff.

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
- Never pass Markdown, text requirements, or PPT/PPTX files as `--spec` or `--plan`.
- Always prepare machine-readable JSON before running build/lint steps.
- Run JSON preflight before script execution:
  - `python3 -m json.tool <chart_spec.json>`
  - `python3 -m json.tool <deck_plan.json>`

## Workflow

### 1. Inspect Template Slide Masters First

- Before planning content, inspect layout catalog from template:

```bash
python3 scripts/build_pptx.py --list-layouts
```

- Optional: save catalog JSON for plan authoring:

```bash
python3 scripts/build_pptx.py --list-layouts --layout-report ./layout-catalog.json
```

- Use this catalog as the source of truth for `layout_name`.
- Assign `layout_name` for title slide and every content slide in plan JSON.
- Prefer explicit `layout_name` over numeric `layout`.

### 2. Research Theme on the Web

- Search the web based on the theme.
- Prefer primary or official sources.
- Cross-check key claims with at least two sources.
- Record source URLs and retrieval dates.

### 3. Draft Slide Headers as Bullets

- Produce a bullet list of slide headers before writing slide bodies.
- Keep at least five headers unless the user specifies a different count.
- Attach one line of intent per header.

### 4. Deep-Dive Each Header and Build Slide Plan

- Expand each header into one slide message.
- Keep each slide to 2-5 concise bullet points.
- Choose at least one structured format per content slide:
  - bullets,
  - table,
  - diagram/chart image.
- Attach source links to factual claims.
- Build the plan JSON using `references/deck-plan-schema.md`.
- Add `layout_name` in every slide spec using names from Step 1.
- Ensure plan input passed to `build_pptx.py` is valid JSON (file/stdin/inline JSON).

### 5. Plan Visuals Early and Aggressively

- Convert dense text into visuals whenever possible.
- Target at least one visual slide in every two slides.
- Use tables for comparisons, KPI snapshots, and option matrices.
- Generate charts/figures with `scripts/make_chart.py` when needed.
- Build chart JSON from `references/chart-spec-schema.md`.
- Save generated images to a predictable folder (for example `assets/generated/`).
- Ensure chart input passed to `make_chart.py` is valid JSON (file/stdin/inline JSON) or inline quick args.

### 6. Build Deck from Template

- Use `scripts/build_pptx.py` to stage template and initialize output `.pptx`.
- Use `scripts/add_slide.py` to append one slide at a time from slide JSON specs.
- Keep `--template` omitted by default so the script uses `assets/template.pptx`.
- Keep auto selection enabled, but provide `layout_name` explicitly from Step 1.
- The build flow creates one output `.pptx` first, then appends slides sequentially.
- If generation fails mid-run, keep the partial `.pptx` and resume from the current plan state.
- Example:

```bash
python3 scripts/build_pptx.py \
  --slide-title "market-outlook-2026" \
  --plan /absolute/path/deck_plan.json \
  --output final-deck.pptx
```

- Optional direct append example:

```bash
python3 scripts/add_slide.py \
  --deck ~/.foundry_local_playground/output/market-outlook-2026/final-deck.pptx \
  --kind content \
  --spec /absolute/path/slide_spec_001.json
```

### 7. Validate Density and Visual Coverage

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

### 8. Perform Final Consistency Pass

- Check logical consistency across all slides.
- Check terminology and numeric consistency.
- Check that visual usage is sufficient and text density is controlled.

### 9. Save and Report

- Save final deck and return absolute path.
- Return:
  - work directory absolute path,
  - output `.pptx` absolute path,
  - staged template absolute path,
  - source URL list,
  - summary of major revisions made in quality pass.

## Script Quick Reference

- `scripts/build_pptx.py`: Initialize output `.pptx` and orchestrate sequential append.
- `scripts/add_slide.py`: Append one title/content slide to an existing `.pptx`.
- `scripts/lint_pptx.py`: Detect crowded and unstructured slides (bullets/table/visual checks).
- `scripts/make_chart.py`: Generate chart PNG files from simple JSON specs.

## References

- `references/deck-plan-schema.md`: Plan schema for `build_pptx.py`.
- `references/chart-spec-schema.md`: Chart schema for `make_chart.py`.
- `references/quality-gates.md`: Slide density and visual-usage thresholds.
