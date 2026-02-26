#!/usr/bin/env python3
"""Generate chart images from a JSON spec."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


SUPPORTED_TYPES = {"bar", "line", "pie"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True, help="Path to chart JSON spec")
    parser.add_argument(
        "--output",
        help="Output PNG path (overrides spec.output when provided)",
    )
    return parser.parse_args()


def load_spec(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError("Chart spec must be a JSON object.")
    return data


def require_list_of_labels(value: Any, field_name: str) -> list[str]:
    if not isinstance(value, list) or not value:
        raise ValueError(f"Field '{field_name}' must be a non-empty list.")
    labels = [str(item).strip() for item in value]
    if any(not item for item in labels):
        raise ValueError(f"Field '{field_name}' cannot contain empty labels.")
    return labels


def require_list_of_values(value: Any, field_name: str) -> list[float]:
    if not isinstance(value, list) or not value:
        raise ValueError(f"Field '{field_name}' must be a non-empty list.")
    numbers: list[float] = []
    for item in value:
        try:
            numbers.append(float(item))
        except Exception as exc:
            raise ValueError(f"Field '{field_name}' contains non-numeric value: {item!r}") from exc
    return numbers


def get_figsize(raw: Any) -> tuple[float, float]:
    if raw is None:
        return (10.0, 5.6)
    if not isinstance(raw, list) or len(raw) != 2:
        raise ValueError("Field 'figsize' must be [width, height].")
    width = float(raw[0])
    height = float(raw[1])
    if width <= 0 or height <= 0:
        raise ValueError("Field 'figsize' values must be positive.")
    return (width, height)


def render_chart(spec: dict[str, Any], output_path: Path) -> None:
    chart_type = str(spec.get("chart_type", "bar")).strip().lower()
    if chart_type not in SUPPORTED_TYPES:
        allowed = ", ".join(sorted(SUPPORTED_TYPES))
        raise ValueError(f"Unsupported chart_type '{chart_type}'. Allowed: {allowed}")

    labels = require_list_of_labels(spec.get("labels"), "labels")
    values = require_list_of_values(spec.get("values"), "values")
    if len(labels) != len(values):
        raise ValueError("Fields 'labels' and 'values' must have the same length.")

    color = str(spec.get("color", "#2F5597"))
    figsize = get_figsize(spec.get("figsize"))
    title = str(spec.get("title", "")).strip()
    x_label = str(spec.get("x_label", "")).strip()
    y_label = str(spec.get("y_label", "")).strip()
    dpi = int(spec.get("dpi", 200))
    show_grid = bool(spec.get("grid", True))

    fig, ax = plt.subplots(figsize=figsize)

    if chart_type == "bar":
        ax.bar(labels, values, color=color)
    elif chart_type == "line":
        ax.plot(labels, values, color=color, marker="o", linewidth=2.0)
    elif chart_type == "pie":
        ax.pie(values, labels=labels, autopct="%1.0f%%", startangle=90)
        ax.axis("equal")

    if title:
        ax.set_title(title)
    if chart_type != "pie":
        if x_label:
            ax.set_xlabel(x_label)
        if y_label:
            ax.set_ylabel(y_label)
        if show_grid:
            ax.grid(axis="y", linestyle="--", alpha=0.35)

    fig.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(str(output_path), dpi=dpi)
    plt.close(fig)


def resolve_output(spec_path: Path, spec: dict[str, Any], cli_output: str | None) -> Path:
    if cli_output:
        return Path(cli_output).expanduser().resolve()
    spec_output = spec.get("output")
    if not spec_output:
        raise ValueError("Provide output via --output or spec.output.")
    output_path = Path(str(spec_output))
    if output_path.is_absolute():
        return output_path
    return (spec_path.parent / output_path).resolve()


def main() -> int:
    args = parse_args()
    spec_path = Path(args.spec).expanduser().resolve()
    if not spec_path.exists():
        print(f"[ERROR] Spec not found: {spec_path}", file=sys.stderr)
        return 1

    try:
        spec = load_spec(spec_path)
        output_path = resolve_output(spec_path, spec, args.output)
        render_chart(spec, output_path)
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    print(f"[OK] Chart image generated: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
