#!/usr/bin/env python3
"""Generate chart images from a JSON spec."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager


SUPPORTED_TYPES = {"bar", "line", "pie"}
JAPANESE_CHAR_RE = re.compile(r"[ぁ-ゖァ-ヺー一-龯々〆〤]")
ASCII_LETTER_RE = re.compile(r"[A-Za-z]")
LANGUAGE_ALIASES = {
    "ja": "ja",
    "jp": "ja",
    "japanese": "ja",
    "en": "en",
    "english": "en",
}
JA_FONT_CANDIDATES = [
    "IPAexGothic",
    "IPAGothic",
    "Noto Sans CJK JP",
    "Noto Sans JP",
    "Hiragino Sans",
    "Yu Gothic",
    "YuGothic",
    "Meiryo",
    "TakaoGothic",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--spec",
        help=(
            "Chart spec source: JSON file path, @<path>, '-' (stdin), "
            "or inline JSON object string"
        ),
    )
    parser.add_argument(
        "--output",
        help="Output PNG path (overrides spec.output when provided)",
    )
    parser.add_argument(
        "--type",
        dest="inline_type",
        choices=sorted(SUPPORTED_TYPES),
        help="Inline mode chart type (used when --spec is omitted).",
    )
    parser.add_argument(
        "--title",
        dest="inline_title",
        help="Inline mode chart title (used when --spec is omitted).",
    )
    parser.add_argument(
        "--labels",
        dest="inline_labels",
        help="Inline mode comma-separated labels (used when --spec is omitted).",
    )
    parser.add_argument(
        "--values",
        dest="inline_values",
        help="Inline mode comma-separated numeric values (used when --spec is omitted).",
    )
    parser.add_argument(
        "--x-label",
        dest="inline_x_label",
        help="Inline mode x-axis label (used when --spec is omitted).",
    )
    parser.add_argument(
        "--y-label",
        dest="inline_y_label",
        help="Inline mode y-axis label (used when --spec is omitted).",
    )
    parser.add_argument(
        "--color",
        dest="inline_color",
        help="Inline mode series color (used when --spec is omitted).",
    )
    parser.add_argument(
        "--ymax",
        dest="inline_ymax",
        type=float,
        help="Inline mode y-axis max (used when --spec is omitted).",
    )
    return parser.parse_args()


def normalize_language(raw: Any) -> str | None:
    if raw is None:
        return None
    value = str(raw).strip().lower()
    if not value:
        return None
    return LANGUAGE_ALIASES.get(value)


def contains_japanese(text: str) -> bool:
    return bool(JAPANESE_CHAR_RE.search(text))


def contains_ascii_letters(text: str) -> bool:
    return bool(ASCII_LETTER_RE.search(text))


def resolve_skill_dir() -> Path:
    current = Path(__file__).resolve().parent
    for candidate in [current, *current.parents]:
        if (candidate / "SKILL.md").exists():
            return candidate
    raise RuntimeError(f"Unable to resolve skill directory from script path: {__file__}")


def collect_chart_texts(spec: dict[str, Any]) -> list[str]:
    values: list[str] = []
    for key in ("title", "x_label", "y_label"):
        raw = spec.get(key)
        if raw is not None:
            text = str(raw).strip()
            if text:
                values.append(text)

    labels = spec.get("labels", [])
    if isinstance(labels, list):
        for label in labels:
            text = str(label).strip()
            if text:
                values.append(text)

    series = spec.get("series", [])
    if isinstance(series, list):
        for item in series:
            if not isinstance(item, dict):
                continue
            text = str(item.get("name", "")).strip()
            if text:
                values.append(text)
    return values


def infer_language_from_text(spec: dict[str, Any]) -> str:
    texts = collect_chart_texts(spec)
    ja_count = sum(1 for text in texts if contains_japanese(text))
    en_count = sum(
        1
        for text in texts
        if contains_ascii_letters(text) and not contains_japanese(text)
    )
    if ja_count > 0:
        return "ja"
    if en_count > 0:
        return "en"
    return "en"


def resolve_chart_language(spec: dict[str, Any]) -> str:
    explicit = normalize_language(spec.get("language"))
    if explicit:
        return explicit
    return infer_language_from_text(spec)


def validate_language_consistency(spec: dict[str, Any], language: str) -> None:
    if bool(spec.get("allow_mixed_language")):
        return

    texts = collect_chart_texts(spec)
    if not texts:
        return

    ja_count = sum(1 for text in texts if contains_japanese(text))
    en_count = sum(
        1
        for text in texts
        if contains_ascii_letters(text) and not contains_japanese(text)
    )

    if language == "ja" and ja_count == 0 and en_count > 0:
        raise ValueError(
            "Chart language is set to 'ja' but chart labels/titles look non-Japanese. "
            "Use Japanese labels or set language to 'en'."
        )
    if language == "en" and ja_count > 0:
        raise ValueError(
            "Chart language is set to 'en' but chart labels/titles include Japanese text. "
            "Set language to 'ja' or update labels."
        )


def parse_font_family(raw: Any) -> list[str]:
    if raw is None:
        return []
    if isinstance(raw, str):
        parts = [item.strip() for item in raw.split(",")]
        return [item for item in parts if item]
    if isinstance(raw, list):
        values = [str(item).strip() for item in raw]
        return [item for item in values if item]
    raise ValueError("Field 'font_family' must be a string or a list of strings.")


def resolve_font_path(spec: dict[str, Any], spec_base_dir: Path) -> Path | None:
    raw = spec.get("font_path")
    if raw is None:
        return None
    path = Path(str(raw).strip())
    if not str(path):
        return None
    if path.is_absolute():
        return path
    return (spec_base_dir / path).resolve()


def register_font_file(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(f"Font file not found: {path}")
    font_manager.fontManager.addfont(str(path))
    return font_manager.FontProperties(fname=str(path)).get_name()


def discover_asset_fonts() -> list[Path]:
    fonts_dir = resolve_skill_dir() / "assets" / "fonts"
    if not fonts_dir.exists():
        return []
    matches: list[Path] = []
    for pattern in ("*.ttf", "*.otf", "*.ttc"):
        matches.extend(sorted(fonts_dir.glob(pattern)))
    return matches


def configure_font(spec: dict[str, Any], spec_base_dir: Path, language: str) -> str:
    selected_families: list[str] = parse_font_family(spec.get("font_family"))
    explicit_font_path = resolve_font_path(spec, spec_base_dir)
    if explicit_font_path is not None:
        selected_families.insert(0, register_font_file(explicit_font_path))

    if language == "ja" and explicit_font_path is None:
        for font_file in discover_asset_fonts():
            try:
                selected_families.insert(0, register_font_file(font_file))
                break
            except Exception:
                continue

    installed_names = {entry.name for entry in font_manager.fontManager.ttflist}
    available_ja = [name for name in JA_FONT_CANDIDATES if name in installed_names]

    if language == "ja":
        try:
            import japanize_matplotlib  # type: ignore # noqa: F401
        except Exception:
            pass

        if not selected_families and not available_ja and "IPAexGothic" not in installed_names:
            raise ValueError(
                "Japanese chart rendering requires a Japanese font. "
                "Install 'japanize-matplotlib' or set spec.font_path / assets/fonts."
            )
        font_order = selected_families + available_ja + ["IPAexGothic", "DejaVu Sans"]
    else:
        font_order = selected_families + ["DejaVu Sans"]

    # Keep deterministic order while removing duplicates.
    deduped: list[str] = []
    seen: set[str] = set()
    for item in font_order:
        if item in seen:
            continue
        seen.add(item)
        deduped.append(item)

    matplotlib.rcParams["font.family"] = ["sans-serif"]
    matplotlib.rcParams["font.sans-serif"] = deduped
    matplotlib.rcParams["axes.unicode_minus"] = False
    return deduped[0]


def load_json_object(raw: str, source_label: str) -> dict[str, Any]:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {source_label}: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError(f"Chart spec from {source_label} must be a JSON object.")
    return data


def load_spec_from_path(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(
            f"Spec not found: {path}. Provide an existing JSON file path or inline JSON via --spec."
        )
    if path.suffix.lower() in {".md", ".ppt", ".pptx"}:
        raise ValueError(
            f"Unsupported spec file type: {path.suffix}. --spec expects chart JSON, not {path.name}."
        )
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError(
            f"Spec file is not UTF-8 text: {path}. --spec expects a UTF-8 JSON file."
        ) from exc
    return load_json_object(text, str(path))


def looks_like_json_object(raw: str) -> bool:
    stripped = raw.lstrip()
    return stripped.startswith("{")


def split_csv(raw: str, field_name: str) -> list[str]:
    items = [item.strip() for item in raw.split(",")]
    values = [item for item in items if item]
    if not values:
        raise ValueError(f"Inline field '{field_name}' must contain at least one value.")
    return values


def build_spec_from_inline_args(args: argparse.Namespace) -> dict[str, Any]:
    if not args.inline_labels or not args.inline_values:
        raise ValueError(
            "When --spec is omitted, both --labels and --values are required "
            "(or provide --spec with JSON)."
        )
    labels = split_csv(args.inline_labels, "labels")
    values = split_csv(args.inline_values, "values")
    if len(labels) != len(values):
        raise ValueError("Inline --labels and --values must have the same number of entries.")

    spec: dict[str, Any] = {
        "chart_type": args.inline_type or "bar",
        "labels": labels,
        "values": values,
    }
    if args.inline_title:
        spec["title"] = args.inline_title
    if args.inline_x_label:
        spec["x_label"] = args.inline_x_label
    if args.inline_y_label:
        spec["y_label"] = args.inline_y_label
    if args.inline_color:
        spec["color"] = args.inline_color
    if args.inline_ymax is not None:
        spec["ymax"] = args.inline_ymax
    return spec


def resolve_spec(args: argparse.Namespace) -> tuple[dict[str, Any], Path]:
    if args.spec:
        raw = args.spec.strip()
        if raw == "-":
            spec = load_json_object(sys.stdin.read(), "stdin")
            return spec, Path.cwd().resolve()

        if raw.startswith("@"):
            spec_path = Path(raw[1:]).expanduser().resolve()
            return load_spec_from_path(spec_path), spec_path.parent

        if looks_like_json_object(raw):
            return load_json_object(raw, "inline --spec JSON"), Path.cwd().resolve()

        spec_path = Path(raw).expanduser().resolve()
        return load_spec_from_path(spec_path), spec_path.parent

    return build_spec_from_inline_args(args), Path.cwd().resolve()


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
            raise ValueError(
                f"Field '{field_name}' contains non-numeric value: {item!r}"
            ) from exc
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


def load_series(
    raw_series: Any,
    *,
    labels_len: int,
    default_color: str,
    palette: list[str],
) -> list[dict[str, Any]]:
    if raw_series is None:
        return []
    if not isinstance(raw_series, list) or not raw_series:
        raise ValueError("Field 'series' must be a non-empty list when provided.")

    series: list[dict[str, Any]] = []
    for idx, item in enumerate(raw_series):
        if not isinstance(item, dict):
            raise ValueError(f"Field 'series[{idx}]' must be an object.")
        name = str(item.get("name", f"Series {idx + 1}")).strip() or f"Series {idx + 1}"
        values = require_list_of_values(item.get("values"), f"series[{idx}].values")
        if len(values) != labels_len:
            raise ValueError(
                f"Field 'series[{idx}].values' must have {labels_len} values "
                "to match 'labels'."
            )
        color = str(
            item.get("color")
            or (palette[idx] if idx < len(palette) else default_color)
        ).strip()
        series.append({"name": name, "values": values, "color": color})
    return series


def render_chart(spec: dict[str, Any], output_path: Path, spec_base_dir: Path) -> str:
    chart_type = str(spec.get("chart_type") or spec.get("type") or "bar").strip().lower()
    if chart_type not in SUPPORTED_TYPES:
        allowed = ", ".join(sorted(SUPPORTED_TYPES))
        raise ValueError(f"Unsupported chart_type '{chart_type}'. Allowed: {allowed}")

    style = str(spec.get("style", "seaborn-v0_8-whitegrid")).strip()
    if style:
        try:
            plt.style.use(style)
        except OSError as exc:
            raise ValueError(f"Unknown matplotlib style: {style}") from exc

    language = resolve_chart_language(spec)
    validate_language_consistency(spec, language)
    active_font = configure_font(spec, spec_base_dir, language)

    labels = require_list_of_labels(spec.get("labels"), "labels")
    single_values = require_list_of_values(spec.get("values"), "values") if "values" in spec else []

    color = str(spec.get("color", "#2F5597")).strip() or "#2F5597"
    colors_raw = spec.get("colors", [])
    palette = [str(item).strip() for item in colors_raw] if isinstance(colors_raw, list) else []
    figsize = get_figsize(spec.get("figsize"))
    title = str(spec.get("title", "")).strip()
    x_label = str(spec.get("x_label", "")).strip()
    y_label = str(spec.get("y_label", "")).strip()
    dpi = int(spec.get("dpi", 200))
    show_grid = bool(spec.get("grid", True))
    y_max_raw = spec.get("ymax", spec.get("y_max"))

    series = load_series(
        spec.get("series"),
        labels_len=len(labels),
        default_color=color,
        palette=palette,
    )
    if not series and not single_values:
        raise ValueError(
            "Provide either field 'values' or field 'series' in chart spec."
        )
    if single_values and len(labels) != len(single_values):
        raise ValueError("Fields 'labels' and 'values' must have the same length.")
    if chart_type == "pie" and series:
        raise ValueError("Pie chart does not support multi-series input.")

    fig, ax = plt.subplots(figsize=figsize)

    if chart_type == "bar":
        if series:
            x_positions = list(range(len(labels)))
            group_width = 0.8
            bar_width = group_width / len(series)
            start = -group_width / 2 + bar_width / 2
            for idx, item in enumerate(series):
                offset = start + idx * bar_width
                ax.bar(
                    [value + offset for value in x_positions],
                    item["values"],
                    width=bar_width,
                    color=item["color"],
                    label=item["name"],
                )
            ax.set_xticks(x_positions)
            ax.set_xticklabels(labels)
            ax.legend()
        else:
            ax.bar(labels, single_values, color=color)
    elif chart_type == "line":
        if series:
            for item in series:
                ax.plot(
                    labels,
                    item["values"],
                    label=item["name"],
                    color=item["color"],
                    marker="o",
                    linewidth=2.0,
                )
            ax.legend()
        else:
            ax.plot(labels, single_values, color=color, marker="o", linewidth=2.0)
    elif chart_type == "pie":
        ax.pie(single_values, labels=labels, autopct="%1.0f%%", startangle=90)
        ax.axis("equal")

    if title:
        ax.set_title(title)
    if chart_type != "pie":
        if x_label:
            ax.set_xlabel(x_label)
        if y_label:
            ax.set_ylabel(y_label)
        if y_max_raw is not None:
            y_max = float(y_max_raw)
            if y_max <= 0:
                raise ValueError("Field 'ymax' must be positive when provided.")
            ax.set_ylim(top=y_max)
        if show_grid:
            ax.grid(axis="y", linestyle="--", alpha=0.35)

    fig.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(str(output_path), dpi=dpi)
    plt.close(fig)
    return active_font


def resolve_output(spec_base_dir: Path, spec: dict[str, Any], cli_output: str | None) -> Path:
    if cli_output:
        return Path(cli_output).expanduser().resolve()
    spec_output = spec.get("output")
    if not spec_output:
        raise ValueError("Provide output via --output or spec.output.")
    output_path = Path(str(spec_output))
    if output_path.is_absolute():
        return output_path
    return (spec_base_dir / output_path).resolve()


def main() -> int:
    args = parse_args()

    try:
        spec, spec_base_dir = resolve_spec(args)
        output_path = resolve_output(spec_base_dir, spec, args.output)
        active_font = render_chart(spec, output_path, spec_base_dir)
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    print(f"[OK] Chart image generated: {output_path}")
    print(f"[OK] Language: {resolve_chart_language(spec)}")
    print(f"[OK] Font: {active_font}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
