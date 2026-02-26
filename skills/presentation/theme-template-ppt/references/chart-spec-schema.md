# Chart Spec Schema

Use this schema for `scripts/make_chart.py --spec`.

## Minimal shape

```json
{
  "chart_type": "bar",
  "title": "Comparison",
  "labels": ["Option A", "Option B", "Option C"],
  "values": [72, 64, 81],
  "output": "assets/generated/chart-01.png"
}
```

## Multi-series shape

```json
{
  "chart_type": "bar",
  "title": "Metric comparison",
  "labels": ["Price", "Ease", "Nutrition"],
  "series": [
    { "name": "A", "values": [4.0, 4.5, 4.2] },
    { "name": "B", "values": [3.5, 3.8, 4.7] }
  ],
  "output": "assets/generated/chart-02.png",
  "ymax": 5
}
```

## Notes

- `chart_type` supports: `bar`, `line`, `pie`.
- `type` is accepted as an alias of `chart_type`.
- Provide either:
  - `values` for single-series charts, or
  - `series` for multi-series bar/line charts.
- If `output` is relative, it is resolved from the spec file directory.
- CLI `--output` overrides spec `output`.
