---
name: theme-template-ppt
description: Create PowerPoint decks from assets/template.pptx by first inspecting template slide-master layouts, then automatically selecting the best existing master layout per slide content. Use when asked to research a topic, draft slide headers, expand headers into slide-ready content, generate chart/table visuals, run build/lint scripts, and return final .pptx outputs. Do not use for Python environment provisioning (use python-venv).
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
- In LocalPlayground `skill_run_script`, set `path` to files under this skill's `scripts/` only.
- Never pass executables like `python3`, `bash`, or `uv` as `skill_run_script.path`.
- Do not use `skill_read_asset` for files under `scripts/` or `references/`.
- Do not read `assets/template.pptx` as base64 or plain text.
- Do not run `skill_list_resources` just to inspect template internals.
- Use only layouts that already exist in template slide masters.
- Determine layout automatically from slide content type (title/subtitle/bullets/table/visual).
- Do not rely on plan `layout` or `layout_name`; these are treated as optional metadata.
- Always include agenda and summary slides.
- Control section order via `plan.auto_slide_order` (`agenda,title,content,summary` by default).
- The runtime template can be replaced for each use; always inspect and validate masters every run.
- If required layout profiles are missing, create and add them to the slide master before appending slides.
- Never pass non-JSON files to:
  - `scripts/make_chart.py --spec`
  - `scripts/build_pptx.py --plan`
- Keep output language aligned with user prompt language across:
  - slide titles/body text,
  - chart titles/labels/legends,
  - table headers/cells and captions.
- Set `plan.language` (`ja` or `en`) and pass matching `language` in chart specs.
- Always run `scripts/ensure_workdir_key.bash` once before build/lint/chart steps.
- If required runtime dependencies are missing, stop and ask for environment provisioning handoff.

## Input Contract

- Collect: theme, target audience, objective, preferred slide count, and deadline.
- Collect: optional `slide_title` for output filename.
- Use `assets/template.pptx` as the canonical template.
- Place reusable visuals (logo/icons/brand images) in `assets/`.
- Ask focused follow-up questions only when required inputs are missing.

## Work Directory and Output Policy

- Use this fixed root: `~/.foundry_local_playground/outputs/pptx/`.
- Use this fixed working/output directory pattern: `~/.foundry_local_playground/outputs/pptx/<work_key>/`.
- Work key priority:
  - `--thread-key`
  - `THEME_TEMPLATE_PPT_WORK_KEY`
  - fallback envs (`PPTX_WORKDIR_KEY`, `CODEX_THREAD_ID`)
  - auto-generated unique key
- In LocalPlayground, persist `THEME_TEMPLATE_PPT_WORK_KEY` across turns via `scripts/ensure_workdir_key.bash`.
- Stage template in that directory before building slides.
- Insert slides in order into the staged template.
- Save final `.pptx` in the same directory.

## Python Dependencies

- Do not install dependencies in this skill.
- Hand off dependency setup to `python-venv` skill before running this skill.
- Packages:
  - `python-pptx`
  - `Pillow`
  - `matplotlib`
  - `japanize-matplotlib`

## Font Policy (Matplotlib Japanese Safety)

- For Japanese charts, ensure one of the following exists:
  - `japanize-matplotlib` is installed,
  - `font_path` is specified in chart spec,
  - Japanese font files are available under `assets/fonts/`.
- Prefer explicit `font_path` for deterministic rendering in CI/runtime.
- Keep chart font family consistent with template tone (for example Noto Sans JP).

## Script Input Contract (Critical)

- `scripts/make_chart.py --spec` accepts:
  - JSON file path only.
- `scripts/make_chart.py` also supports inline quick args when `--spec` is omitted:
  - `--type`, `--labels`, `--values`, optional `--title`.
- `scripts/build_pptx.py --plan` accepts:
  - JSON file path only.
- `scripts/add_slide.py --spec` accepts:
  - JSON file path only.
- Never pass Markdown, text requirements, or PPT/PPTX files as `--spec` or `--plan`.
- Always write machine-readable JSON to files before running build/lint steps.
- Always pass absolute JSON file paths to scripts.
- Required before build:
  - `<work_dir>/deck_plan.json` (required)
- Optional JSON files:
  - `<work_dir>/chart_spec_*.json` (when generating charts)
  - `<work_dir>/slide_spec_*.json` (when appending slides manually)
- Run JSON preflight before script execution:
  - `scripts/validate_json.py <chart_spec.json>`
  - `scripts/validate_json.py <deck_plan.json>`

## Workflow

### 1. Ensure Workdir Key and Reuse It

- Before planning content, fix work key in thread environment:

```bash
scripts/ensure_workdir_key.bash
```

- Use the same `THEME_TEMPLATE_PPT_WORK_KEY` on later turns in the same thread.

### 2. Emit Required JSON Files Before Build

- Resolve the working directory once and keep it in this thread:

```bash
WORK_DIR="$HOME/.foundry_local_playground/outputs/pptx/$THEME_TEMPLATE_PPT_WORK_KEY"
mkdir -p "$WORK_DIR"
```

- Write deck plan JSON to the required file path:

```bash
cat > "$WORK_DIR/deck_plan.json" <<'JSON'
{
  "language": "ja",
  "slides": [
    {
      "title": "イントロダクション",
      "bullets": [
        "要点1",
        "要点2"
      ]
    }
  ]
}
JSON
```

- Validate JSON before build:

```bash
scripts/validate_json.py "$WORK_DIR/deck_plan.json"
```

- If charts are needed, write chart spec JSON under the same work directory (for example `"$WORK_DIR/chart_spec_001.json"`), then validate it with `scripts/validate_json.py`.
- Do not call `build_pptx.py` until `"$WORK_DIR/deck_plan.json"` exists and passes validation.

### 3. Inspect Template Slide Masters First

- Before planning content, inspect layout catalog from template:

```bash
scripts/build_pptx.py --list-layouts
```

- Optional: save catalog JSON for plan authoring:

```bash
scripts/build_pptx.py --list-layouts --layout-report ./layout-catalog.json
```

- Use this catalog to understand which layout patterns exist in the template.
- The script auto-selects one of these existing master layouts for each slide.
- If required profiles are missing (title/content/visual/table), the script clones and adds missing layouts.

### 4. Decide Slide Content First, Then Select Layout

- For each page, decide content first:
  - title/subtitle,
  - bullets,
  - table and/or visual.
- After content is fixed, select layout automatically from slide masters.
- Keep this order strict: `decide content -> select layout`.

### 5. Fix Output Language from Prompt

- Detect user prompt language first (`ja` or `en`).
- Set `plan.language` to that value.
- Keep all slide/chart/table text in that language unless user explicitly asks bilingual output.
- Add `language` to every chart spec and keep it aligned with `plan.language`.

### 6. Research Theme on the Web

- Search the web based on the theme.
- Prefer primary or official sources.
- Cross-check key claims with at least two sources.
- Record source URLs and retrieval dates.

### 7. Draft Slide Headers as Bullets

- Produce a bullet list of slide headers before writing slide bodies.
- Keep at least five headers unless the user specifies a different count.
- Attach one line of intent per header.

### 8. Deep-Dive Each Header and Build Slide Plan

- Expand each header into one slide message.
- Keep each slide to 2-5 concise bullet points.
- Choose at least one structured format per content slide:
  - bullets,
  - table,
  - diagram/chart image.
- Attach source links to factual claims.
- Build the plan JSON using `references/deck-plan-schema.md`.
- Ensure plan input passed to `build_pptx.py` is a valid JSON file path.

### 9. Plan Visuals Early and Aggressively

- Convert dense text into visuals whenever possible.
- Target at least one visual slide in every two slides.
- Use tables for comparisons, KPI snapshots, and option matrices.
- Generate charts/figures with `scripts/make_chart.py` when needed.
- Build chart JSON from `references/chart-spec-schema.md`.
- Save generated images to a predictable folder (for example `assets/generated/`).
- Ensure chart input passed to `make_chart.py` is a valid JSON file path (or use inline quick args without JSON).

### 10. Build Deck from Template

- Use `scripts/build_pptx.py` to stage template and initialize output `.pptx`.
- Use `scripts/add_slide.py` to append one slide at a time from slide JSON specs.
- Keep `--template` omitted by default so the script uses `assets/template.pptx`.
- Keep master-layout auto detection enabled.
- The build flow always inserts agenda (`目次`/`Agenda`) and summary (`まとめ`/`Summary`) sections.
- Section order is configurable with `plan.auto_slide_order`.
- The build flow creates one output `.pptx` first, then appends slides sequentially.
- If generation fails mid-run, keep the partial `.pptx` and resume from the current plan state.
- Example:

```bash
WORK_DIR="$HOME/.foundry_local_playground/outputs/pptx/$THEME_TEMPLATE_PPT_WORK_KEY"
scripts/build_pptx.py \
  --slide-title "market-outlook-2026" \
  --plan "$WORK_DIR/deck_plan.json" \
  --output final-deck.pptx
```

- Optional direct append example:

```bash
WORK_DIR="$HOME/.foundry_local_playground/outputs/pptx/$THEME_TEMPLATE_PPT_WORK_KEY"
scripts/add_slide.py \
  --deck "$WORK_DIR/final-deck.pptx" \
  --kind content \
  --spec "$WORK_DIR/slide_spec_001.json" \
  --language ja
```

### 11. Validate Density and Visual Coverage

- Run `scripts/lint_pptx.py` after generation.
- Example:

```bash
WORK_DIR="$HOME/.foundry_local_playground/outputs/pptx/$THEME_TEMPLATE_PPT_WORK_KEY"
scripts/lint_pptx.py \
  --input "$WORK_DIR/final-deck.pptx" \
  --fail-on-warning
```

- If warnings exist, fix by:
  - splitting crowded slides,
  - reducing bullet count,
  - replacing text blocks with charts/diagrams/tables.
- Re-run lint until the deck passes quality gates from `references/quality-gates.md`.

### 12. Enforce Language Consistency

- Confirm `plan.language` matches prompt language.
- Confirm all slide text and chart labels match `plan.language`.
- For Japanese charts, confirm selected font can render all labels (no tofu boxes).

### 13. Perform Final Consistency Pass

- Check logical consistency across all slides.
- Check terminology and numeric consistency.
- Check that visual usage is sufficient and text density is controlled.

### 14. Save and Report

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
- `scripts/ensure_workdir_key.bash`: Create/reuse `THEME_TEMPLATE_PPT_WORK_KEY` in environment.
- `scripts/validate_json.py`: Validate JSON input files before build/chart runs.

## References

- `references/deck-plan-schema.md`: Plan schema for `build_pptx.py`.
- `references/chart-spec-schema.md`: Chart schema for `make_chart.py`.
- `references/quality-gates.md`: Slide density and visual-usage thresholds.
