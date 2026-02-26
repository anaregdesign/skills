# Deck Plan Schema

Use this JSON format as input to `scripts/build_pptx.py`.
Run `build_pptx.py` with `--slide-title` so output is created in `~/.foundry_local_playground/output/<slide_title>/`.

## Minimal shape

```json
{
  "title_slide": {
    "title": "Theme title",
    "subtitle": "Audience and date",
    "layout": 0,
    "layout_name": "Title Slide",
    "sources": ["https://example.com"],
    "speaker_notes": ["Optional presenter note"]
  },
  "slides": [
    {
      "title": "Slide header",
      "subtitle": "Optional subtitle",
      "layout": 1,
      "layout_name": "Title and Content",
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

- `title_slide` (optional): Adds a title slide before normal slides.
- `slides` (required): Non-empty list of slide objects.

Slide object fields:

- `title` (required): Slide title text.
- `subtitle` (optional): Subtitle text.
- `layout` (optional): Integer layout index from the template.
- `layout_name` (optional): Slide-master layout name (preferred over `layout`).
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
- Use `layout_name` when the template has specific master layouts to target.
- Keep every content slide structured with bullets, a table, or a visual.
- Prefer one message per slide.
- Keep body bullets concise so `lint_pptx.py` can pass.
