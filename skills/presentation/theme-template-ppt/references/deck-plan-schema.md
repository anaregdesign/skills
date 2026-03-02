# Deck Plan Schema

Use this JSON format as input to `scripts/build_pptx.py`.
Write plan JSON to a file and pass that file path to `--plan` (inline JSON is not supported).
Run `scripts/ensure_workdir_key.bash` first, then run `scripts/build_pptx.py` under
`~/.foundry_local_playground/outputs/pptx/<work_key>/`.
The same thread reuses the same `THEME_TEMPLATE_PPT_WORK_KEY` on later runs.
Each item in `slides[]` can also be passed directly to `scripts/add_slide.py --kind content --spec <slide_spec.json>`.

`build_pptx.py` always auto-inserts agenda (`目次`/`Agenda`) and summary (`まとめ`/`Summary`) sections.
By default they are placed at first/last positions.

You can override section order with `auto_slide_order`.
Default order is: `["agenda", "title", "content", "summary"]`.

## Layout-First Rule

Inspect template layouts before authoring the plan:

```bash
scripts/build_pptx.py --list-layouts --layout-report ./layout-catalog.json
```

Use this catalog to understand available title/content/table/visual-oriented layouts.
Then rank per-slide candidates from your skeleton plan:

```bash
scripts/build_pptx.py --plan ./deck_plan.json --suggest-layouts --candidate-limit 3 --suggestions-report ./layout-suggestions.json
```

Use `layout-suggestions.json` to decide one layout per slide before final copy writing.
Layout can still be auto-selected if `layout_name`/`layout` are omitted.
When required profiles are missing, the build step clones and adds master layouts automatically.

## Authoring Order Rule (Per Slide)

1. Organize one page claim/message first:
   - `message` (one-line core assertion)
   - `story_role` (optional narrative role)
   - one intent label:
   - `title_cover`
   - `text_dense`
   - `text_brief`
   - `visual_split`
   - `visual_focus`
   - `table_comparison`
   - `table_focus`
   - `hybrid_data`
2. Confirm layout candidates:
   - run `--suggest-layouts`,
   - compare candidates by placeholder profile and composition fit.
3. Decide assigned layout:
   - set `layout_name` (preferred) or `layout` (catalog index).
4. Write/finalize page content after layout decision, and map content into placeholders:
   - title/subtitle placeholder,
   - visual/table placeholder,
   - body placeholders (split bullets across suitable text slots, favoring larger content areas).

Keep this order strict: `claim -> candidate review -> layout decision -> content rewrite -> fill placeholders`.

## Minimal shape

```json
{
  "language": "ja",
  "brief": {
    "audience": "Exec leadership",
    "objective": "Explain options and recommend one",
    "required_decision": "Approve FY2026 migration budget"
  },
  "design_system": {
    "font_families": ["Noto Sans JP", "Noto Serif JP"],
    "size_scale_pt": {
      "title": 34,
      "subtitle": 22,
      "body": 18,
      "caption": 12
    },
    "color_roles": {
      "base": "#0F172A",
      "accent": "#0EA5E9",
      "warning": "#DC2626"
    }
  },
  "auto_slide_order": ["title", "agenda", "content", "summary"],
  "title_slide": {
      "title": "Theme title",
      "subtitle": "Audience and date",
      "sources": ["https://example.com"],
      "speaker_notes": ["Optional presenter note"]
  },
  "slides": [
    {
      "title": "Slide header",
      "message": "One-line core takeaway of this slide",
      "story_role": "context",
      "intent": "visual_split",
      "layout_name": "06_figure_and_description",
      "subtitle": "Optional subtitle",
      "bullets": [
        "Key point 1",
        "Key point 2",
        "Key point 3"
      ],
      "visual": {
        "path": "../assets/generated/chart-01.png",
        "caption": "Chart caption",
        "left": "56%",
        "top": "20%",
        "width": "38%"
      },
      "table": {
        "headers": ["Metric", "Current", "Target"],
        "rows": [
          ["Conversion", "2.1%", "3.0%"],
          ["CAC", "$120", "$95"]
        ],
        "left": "6%",
        "top": "35%",
        "width": "88%",
        "height": "50%"
      },
      "sources": [
        "https://source-a.example",
        "https://source-b.example"
      ],
      "speaker_notes": [
        "Presenter detail 1",
        "Presenter detail 2"
      ]
    }
  ]
}
```

## Field details

- `brief` (recommended): Communication brief.
  - `audience`: Target readers.
  - `objective`: What this deck should accomplish.
  - `required_decision`: Explicit decision/action expected after reading.
- `design_system` (recommended): Visual tokens for consistency.
  - `font_families`: Preferred families.
  - `size_scale_pt`: Title/subtitle/body/caption size scale.
  - `color_roles`: Base/accent/warning color roles.
- `title_slide` (optional): Adds a title slide section (position depends on `auto_slide_order`).
- `slides` (required): Non-empty list of slide objects.
- `language` (recommended): Deck language (`ja` or `en`) matching prompt language.
- `auto_slide_order` (optional): Section order tokens from `agenda`, `title`, `content`, `summary`.

Slide object fields:

- `title` (required): Slide title text.
- `message` (recommended): One-sentence key takeaway; enforce one slide/one message.
- `story_role` (recommended): Role in story flow (`context`, `problem`, `analysis`, `options`, `recommendation`, `next_action`).
- `intent` (strongly recommended): Layout intent label (`title_cover`, `text_dense`, `text_brief`, `visual_split`, `visual_focus`, `table_comparison`, `table_focus`, `hybrid_data`). The renderer selects layout from this first, then fills placeholders.
- `subtitle` (optional): Subtitle text.
- `layout_name` (optional but recommended after candidate review): Exact layout name lock (case-insensitive). Example: `"06_figure_and_description"`.
- `layout` (optional): Catalog index lock from `layout-catalog.json` / `--suggest-layouts` output. Used when `layout_name` is not set.
- `bullets` (optional): List of body bullet strings.
- `visual` (optional): Visual object.
- `table` (optional): Table object for structured comparison.
- `sources` (optional): URL list attached to speaker notes.
- `speaker_notes` (optional): Additional presenter notes.

Visual object fields:

- `path` (required when `visual` is used): Image file path.
- `caption` (optional): Caption text below image.
- `left`, `top`, `width`, `height` (optional):
  - Inches as number/string: `5` or `"5.0"`
  - Percentage string relative to slide size: `"38%"`

Table object fields:

- `headers` (required when `table` is used): Header row text list.
- `rows` (required when `table` is used): Data rows as list of string lists.
- `left`, `top`, `width`, `height` (optional):
  - Inches as number/string: `5` or `"5.0"`
  - Percentage string relative to slide size: `"38%"`

## Notes

- Resolve relative image paths from the plan JSON location.
- For `mcp-mermaid` diagrams, keep image files under the same work directory (recommended: `assets/generated/mermaid/` when `deck_plan.json` is in `"$WORK_DIR"`).
- Keep image aspect ratio choices intentional across deck (avoid random mix of portrait/landscape crops).
- Keep caption style and icon style consistent on every visual slide.
- Keep all slide text in `language` unless bilingual output is explicitly requested.
- Keep every content slide structured with bullets, a table, or a visual.
- Let scripts handle deterministic ranking/build/lint; let LLM rewrite semantic copy to fit selected layout blanks.
- Prefer one message per slide.
- Keep body bullets concise so `lint_pptx.py` can pass.
