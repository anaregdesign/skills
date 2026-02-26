#!/usr/bin/env python3
"""Lint a PPTX for slide density and visual coverage."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from pptx import Presentation
from pptx.enum.shapes import MSO_SHAPE_TYPE


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="Input PPTX file")
    parser.add_argument(
        "--max-chars",
        type=int,
        default=220,
        help="Maximum body text characters per slide",
    )
    parser.add_argument(
        "--max-bullets",
        type=int,
        default=5,
        help="Maximum number of body bullet lines per slide",
    )
    parser.add_argument(
        "--max-line-chars",
        type=int,
        default=80,
        help="Maximum characters for a single body line",
    )
    parser.add_argument(
        "--min-visual-ratio",
        type=float,
        default=0.50,
        help="Minimum ratio of slides that contain visuals",
    )
    parser.add_argument(
        "--max-consecutive-text-only",
        type=int,
        default=1,
        help="Maximum consecutive slides with no visual",
    )
    parser.add_argument(
        "--min-structured-ratio",
        type=float,
        default=0.90,
        help="Minimum ratio of content slides using bullets/table/visual",
    )
    parser.add_argument(
        "--max-unstructured-content-slides",
        type=int,
        default=0,
        help="Maximum count of content slides with no bullets/table/visual",
    )
    parser.add_argument(
        "--json-output",
        help="Optional path to write a JSON report",
    )
    parser.add_argument(
        "--fail-on-warning",
        action="store_true",
        help="Exit with code 1 when warnings are detected",
    )
    return parser.parse_args()


def shape_has_visual(shape: Any) -> bool:
    if shape.shape_type == MSO_SHAPE_TYPE.PICTURE:
        return True
    try:
        if getattr(shape, "has_chart", False) and shape.has_chart:
            return True
    except Exception:
        pass
    return False


def shape_has_table(shape: Any) -> bool:
    if shape.shape_type == MSO_SHAPE_TYPE.TABLE:
        return True
    return False


def collect_slide_metrics(slide: Any, index: int) -> dict[str, Any]:
    title_shape = slide.shapes.title
    has_title = False
    body_chars = 0
    body_lines = 0
    longest_line = 0
    has_visual = False
    has_table = False

    if title_shape is not None and getattr(title_shape, "has_text_frame", False):
        has_title = bool(title_shape.text.strip())

    for shape in slide.shapes:
        if shape_has_visual(shape):
            has_visual = True
        if shape_has_table(shape):
            has_table = True
        if not getattr(shape, "has_text_frame", False):
            continue

        is_title_shape = title_shape is not None and shape == title_shape
        for paragraph in shape.text_frame.paragraphs:
            text = paragraph.text.strip()
            if not text:
                continue
            if is_title_shape:
                continue
            body_lines += 1
            body_chars += len(text)
            longest_line = max(longest_line, len(text))

    has_bullets = body_lines > 0
    has_structured = has_bullets or has_table or has_visual
    is_cover_like = has_title and body_lines <= 1 and not has_table and not has_visual

    return {
        "slide": index,
        "has_title": has_title,
        "body_chars": body_chars,
        "body_lines": body_lines,
        "longest_line": longest_line,
        "has_bullets": has_bullets,
        "has_table": has_table,
        "has_visual": has_visual,
        "has_structured": has_structured,
        "is_cover_like": is_cover_like,
        "warnings": [],
    }


def lint(args: argparse.Namespace) -> dict[str, Any]:
    input_path = Path(args.input).expanduser().resolve()
    if not input_path.exists():
        raise FileNotFoundError(f"PPTX not found: {input_path}")

    prs = Presentation(str(input_path))
    slides = list(prs.slides)
    if not slides:
        raise ValueError("Deck has zero slides.")

    results = [collect_slide_metrics(slide, idx) for idx, slide in enumerate(slides, start=1)]

    for item in results:
        if not item["has_title"]:
            item["warnings"].append("missing title text")
        if item["body_chars"] > args.max_chars:
            item["warnings"].append(
                f"body chars {item['body_chars']} > max {args.max_chars}"
            )
        if item["body_lines"] > args.max_bullets:
            item["warnings"].append(
                f"body lines {item['body_lines']} > max {args.max_bullets}"
            )
        if item["longest_line"] > args.max_line_chars:
            item["warnings"].append(
                f"line chars {item['longest_line']} > max {args.max_line_chars}"
            )
        if not item["has_structured"] and not item["is_cover_like"]:
            item["warnings"].append(
                "unstructured content; add bullets, table, or visual"
            )

    content_slides = [item for item in results if not item["is_cover_like"]]
    content_slide_count = len(content_slides)

    streak = 0
    for item in results:
        if item["is_cover_like"]:
            streak = 0
            continue
        if item["has_visual"] or item["has_table"]:
            streak = 0
            continue
        streak += 1
        if streak > args.max_consecutive_text_only:
            item["warnings"].append(
                "too many consecutive text-only slides; add chart/diagram/table/image"
            )

    total_slides = len(results)
    visual_slides = sum(1 for item in results if item["has_visual"])
    table_slides = sum(1 for item in results if item["has_table"])
    structured_slides = sum(1 for item in results if item["has_structured"])
    visual_content_slides = sum(1 for item in content_slides if item["has_visual"])
    unstructured_content_slides = sum(1 for item in content_slides if not item["has_structured"])
    visual_ratio = (
        1.0 if content_slide_count == 0 else visual_content_slides / content_slide_count
    )
    structured_ratio = (
        1.0
        if content_slide_count == 0
        else (content_slide_count - unstructured_content_slides) / content_slide_count
    )

    deck_warnings: list[str] = []
    if visual_ratio < args.min_visual_ratio:
        deck_warnings.append(
            f"visual ratio {visual_ratio:.2f} < min {args.min_visual_ratio:.2f}"
        )
    if structured_ratio < args.min_structured_ratio:
        deck_warnings.append(
            f"structured ratio {structured_ratio:.2f} < min {args.min_structured_ratio:.2f}"
        )
    if unstructured_content_slides > args.max_unstructured_content_slides:
        deck_warnings.append(
            "unstructured content slides "
            f"{unstructured_content_slides} > max {args.max_unstructured_content_slides}"
        )

    warning_count = len(deck_warnings) + sum(len(item["warnings"]) for item in results)
    report = {
        "input": str(input_path),
        "summary": {
            "slides": total_slides,
            "visual_slides": visual_slides,
            "visual_content_slides": visual_content_slides,
            "table_slides": table_slides,
            "structured_slides": structured_slides,
            "visual_ratio": round(visual_ratio, 4),
            "structured_ratio": round(structured_ratio, 4),
            "content_slides": content_slide_count,
            "unstructured_content_slides": unstructured_content_slides,
            "warning_count": warning_count,
        },
        "deck_warnings": deck_warnings,
        "slides": results,
    }
    return report


def print_report(report: dict[str, Any]) -> None:
    summary = report["summary"]
    print(f"Deck: {report['input']}")
    print(
        "Summary: slides={slides}, visual_slides={visual_slides}, table_slides={table_slides}, structured_slides={structured_slides}, visual_ratio={visual_ratio:.2f}, structured_ratio={structured_ratio:.2f}, warnings={warning_count}".format(
            **summary
        )
    )

    for warning in report["deck_warnings"]:
        print(f"Deck warning: {warning}")

    for item in report["slides"]:
        visual = "yes" if item["has_visual"] else "no"
        table = "yes" if item["has_table"] else "no"
        bullets = "yes" if item["has_bullets"] else "no"
        status = "WARN" if item["warnings"] else "OK"
        print(
            f"Slide {item['slide']:02d}: status={status}, body_chars={item['body_chars']}, body_lines={item['body_lines']}, longest_line={item['longest_line']}, bullets={bullets}, table={table}, visual={visual}"
        )
        for warning in item["warnings"]:
            print(f"  - {warning}")


def write_json_report(path: str, report: dict[str, Any]) -> None:
    output_path = Path(path).expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"[OK] Wrote JSON report: {output_path}")


def main() -> int:
    args = parse_args()
    try:
        report = lint(args)
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    print_report(report)

    if args.json_output:
        write_json_report(args.json_output, report)

    has_warnings = bool(report["deck_warnings"]) or any(
        item["warnings"] for item in report["slides"]
    )
    if args.fail_on_warning and has_warnings:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
