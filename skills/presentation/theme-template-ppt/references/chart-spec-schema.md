# Chart Spec Schema

Use this schema for `scripts/make_chart.py --spec`.

## Minimal shape

```json
{
  "chart_type": "bar",
  "language": "en",
  "title": "Comparison",
  "labels": ["Option A", "Option B", "Option C"],
  "values": [72, 64, 81],
  "output": "assets/generated/chart-01.png",
  "style": "seaborn-v0_8-whitegrid"
}
```

## Multi-series shape

```json
{
  "chart_type": "bar",
  "language": "ja",
  "title": "Metric comparison",
  "labels": ["Price", "Ease", "Nutrition"],
  "series": [
    { "name": "A", "values": [4.0, 4.5, 4.2] },
    { "name": "B", "values": [3.5, 3.8, 4.7] }
  ],
  "output": "assets/generated/chart-02.png",
  "ymax": 5,
  "font_path": "assets/fonts/NotoSansJP-Regular.ttf"
}
```

## Notes

- `chart_type` supports: `bar`, `line`, `pie`.
- `type` is accepted as an alias of `chart_type`.
- `language` supports: `ja`, `en`. Set this to the user prompt language.
- Provide either:
  - `values` for single-series charts, or
  - `series` for multi-series bar/line charts.
- If `output` is relative, it is resolved from the spec file directory.
- If `font_path` is relative, it is resolved from the spec file directory.
- `font_family` supports string or list and is applied before fallback font search.
- For Japanese charts, provide one of:
  - `font_path` in spec,
  - font files under `assets/fonts/`,
  - `japanize-matplotlib` installation.
- Set `allow_mixed_language: true` only when deliberate bilingual labels are required.
- `style` applies matplotlib style presets (for example `seaborn-v0_8-whitegrid`).
- CLI `--output` overrides spec `output`.
