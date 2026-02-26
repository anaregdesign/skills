#!/usr/bin/env python3
"""Append one slide to an existing PowerPoint file from a JSON slide spec."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from pptx import Presentation

from build_pptx import (
    add_notes,
    add_table,
    add_visual,
    list_master_layouts,
    load_json,
    load_json_text,
    looks_like_json_object,
    normalize_slide_spec,
    pick_layout,
    set_bullets,
    set_subtitle,
    set_title,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--deck", required=True, help="Target PPTX path to append to")
    parser.add_argument(
        "--kind",
        choices=["title", "content"],
        default="content",
        help="Slide spec kind: title or content (default: content)",
    )
    parser.add_argument(
        "--spec",
        required=True,
        help="Slide spec source: JSON file path, @<path>, '-' (stdin), or inline JSON object string",
    )
    parser.add_argument(
        "--plan-base",
        help="Base directory for resolving relative paths when --spec is inline or stdin",
    )
    parser.add_argument(
        "--fallback-layout",
        type=int,
        default=1,
        help="Fallback layout index when layout/layout_name selection fails",
    )
    parser.add_argument(
        "--strict-images",
        action="store_true",
        help="Fail when a referenced visual image file is missing",
    )
    parser.add_argument(
        "--no-prefer-master-layouts",
        action="store_true",
        help="Disable automatic slide-master layout selection by content type",
    )
    return parser.parse_args()


def resolve_base_dir(raw_base: str | None) -> Path:
    if raw_base:
        return Path(raw_base).expanduser().resolve()
    return Path.cwd().resolve()


def resolve_spec_input(raw_spec: str, base_dir: Path) -> tuple[dict[str, Any], Path]:
    source = raw_spec.strip()
    if not source:
        raise ValueError("--spec is empty.")

    if source == "-":
        spec = load_json_text(sys.stdin.read(), "stdin")
        return spec, (base_dir / "stdin-slide-spec.json")

    if source.startswith("@"):
        source = source[1:].strip()
        if not source:
            raise ValueError("Invalid --spec value: @ requires a file path.")

    if looks_like_json_object(source):
        spec = load_json_text(source, "inline --spec JSON")
        return spec, (base_dir / "inline-slide-spec.json")

    spec_path = Path(source).expanduser().resolve()
    if not spec_path.exists():
        raise FileNotFoundError(
            f"Spec not found: {spec_path}. Provide an existing JSON file or inline JSON."
        )
    if spec_path.suffix.lower() in {".md", ".ppt", ".pptx"}:
        raise ValueError(
            f"Unsupported spec file type: {spec_path.suffix}. --spec expects slide JSON, not {spec_path.name}."
        )
    return load_json(spec_path), spec_path


def append_title_slide(
    prs: Presentation,
    layouts: list[dict[str, Any]],
    raw_spec: dict[str, Any],
    fallback_layout: int,
    prefer_master_layouts: bool,
) -> tuple[bool, bool, bool]:
    requested_layout_name = str(raw_spec.get("layout_name", "")).strip()
    layout, selection_mode = pick_layout(
        prs,
        layouts,
        raw_spec.get("layout"),
        requested_layout_name,
        fallback_layout,
        prefer_master_layouts=prefer_master_layouts,
        is_title_slide=True,
        has_bullets=False,
        has_table=False,
        has_visual=False,
        has_subtitle=bool(str(raw_spec.get("subtitle", "")).strip()),
    )

    slide = prs.slides.add_slide(layout)
    set_title(slide, str(raw_spec.get("title", "")).strip())
    set_subtitle(slide, str(raw_spec.get("subtitle", "")).strip())

    title_sources = raw_spec.get("sources", [])
    title_notes = raw_spec.get("speaker_notes", [])
    if not isinstance(title_sources, list):
        title_sources = []
    if not isinstance(title_notes, list):
        title_notes = []
    add_notes(slide, [str(item) for item in title_sources], [str(item) for item in title_notes])

    used_master_auto = selection_mode == "master_auto"
    return used_master_auto, False, False


def append_content_slide(
    prs: Presentation,
    layouts: list[dict[str, Any]],
    raw_spec: dict[str, Any],
    spec_reference_path: Path,
    fallback_layout: int,
    strict_images: bool,
    prefer_master_layouts: bool,
) -> tuple[bool, bool, bool]:
    spec = normalize_slide_spec(raw_spec, 1)
    layout, selection_mode = pick_layout(
        prs,
        layouts,
        spec["layout"],
        spec["layout_name"],
        fallback_layout,
        prefer_master_layouts=prefer_master_layouts,
        is_title_slide=False,
        has_bullets=bool(spec["bullets"]),
        has_table=bool(spec["table"]),
        has_visual=bool(spec["visual"].get("path")),
        has_subtitle=bool(spec["subtitle"]),
    )

    slide = prs.slides.add_slide(layout)
    set_title(slide, spec["title"])
    set_subtitle(slide, spec["subtitle"])
    set_bullets(slide, spec["bullets"])
    table_added = add_table(prs, slide, spec["table"])
    visual_added = add_visual(prs, slide, spec["visual"], spec_reference_path, strict_images)
    add_notes(slide, spec["sources"], spec["speaker_notes"])

    used_master_auto = selection_mode == "master_auto"
    return used_master_auto, table_added, visual_added


def run(args: argparse.Namespace) -> dict[str, Any]:
    deck_path = Path(args.deck).expanduser().resolve()
    if not deck_path.exists():
        raise FileNotFoundError(f"Deck not found: {deck_path}")

    base_dir = resolve_base_dir(args.plan_base)
    raw_spec, spec_reference_path = resolve_spec_input(args.spec, base_dir)
    if not isinstance(raw_spec, dict):
        raise ValueError("Slide spec must be a JSON object.")

    prs = Presentation(str(deck_path))
    layouts = list_master_layouts(prs)
    prefer_master_layouts = not args.no_prefer_master_layouts

    if args.kind == "title":
        used_master_auto, table_added, visual_added = append_title_slide(
            prs,
            layouts,
            raw_spec,
            args.fallback_layout,
            prefer_master_layouts,
        )
    else:
        used_master_auto, table_added, visual_added = append_content_slide(
            prs,
            layouts,
            raw_spec,
            spec_reference_path,
            args.fallback_layout,
            args.strict_images,
            prefer_master_layouts,
        )

    prs.save(str(deck_path))
    return {
        "deck_path": str(deck_path),
        "kind": args.kind,
        "used_master_auto": used_master_auto,
        "table_added": table_added,
        "visual_added": visual_added,
    }


def main() -> int:
    args = parse_args()
    try:
        result = run(args)
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
