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
Layout is auto-selected from existing masters, so explicit layout mapping is not required.
When required profiles are missing, the build step clones and adds master layouts automatically.

## Authoring Order Rule (Per Slide)

1. Decide what to write on the page first (title/subtitle, bullets, table/visual).
2. Then select layout automatically from existing slide-master layouts.

Keep this order strict: `decide content -> select layout`.

## Minimal shape

```json
{
  "language": "ja",
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

- `title_slide` (optional): Adds a title slide section (position depends on `auto_slide_order`).
- `slides` (required): Non-empty list of slide objects.
- `language` (recommended): Deck language (`ja` or `en`) matching prompt language.
- `auto_slide_order` (optional): Section order tokens from `agenda`, `title`, `content`, `summary`.

Slide object fields:

- `title` (required): Slide title text.
- `subtitle` (optional): Subtitle text.
- `layout` (optional metadata): Ignored by renderer because layout is auto-detected.
- `layout_name` (optional metadata): Ignored by renderer because layout is auto-detected.
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
- Keep all slide text in `language` unless bilingual output is explicitly requested.
- Keep every content slide structured with bullets, a table, or a visual.
- Prefer one message per slide.
- Keep body bullets concise so `lint_pptx.py` can pass.
