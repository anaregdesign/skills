#!/usr/bin/env python3
"""Build a PowerPoint file from a template and a deck-plan JSON."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

from pptx import Presentation
from pptx.enum.shapes import PP_PLACEHOLDER
from pptx.util import Inches, Pt


BODY_PLACEHOLDERS = {
    value
    for value in (
        getattr(PP_PLACEHOLDER, "BODY", None),
        getattr(PP_PLACEHOLDER, "OBJECT", None),
        getattr(PP_PLACEHOLDER, "TEXT", None),
        getattr(PP_PLACEHOLDER, "VERTICAL_BODY", None),
    )
    if value is not None
}

TITLE_PLACEHOLDERS = {
    value
    for value in (
        getattr(PP_PLACEHOLDER, "TITLE", None),
        getattr(PP_PLACEHOLDER, "CENTER_TITLE", None),
    )
    if value is not None
}

SUBTITLE_PLACEHOLDERS = {
    value
    for value in (
        getattr(PP_PLACEHOLDER, "SUBTITLE", None),
    )
    if value is not None
}

VISUAL_LAYOUT_KEYWORDS = (
    "picture",
    "photo",
    "image",
    "media",
    "chart",
    "diagram",
    "caption",
    "two content",
)

TABLE_LAYOUT_KEYWORDS = (
    "table",
    "matrix",
    "comparison",
)


def normalize_language(raw: Any) -> str | None:
    if raw is None:
        return None
    value = str(raw).strip().lower()
    if value in {"ja", "jp", "japanese"}:
        return "ja"
    if value in {"en", "english"}:
        return "en"
    return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--slide-title", help="Slide deck title used for workdir naming")
    parser.add_argument(
        "--template",
        help="Path to PPTX template (default: <skill-dir>/assets/template.pptx)",
    )
    parser.add_argument(
        "--plan",
        help="Deck plan source: JSON file path, @<path>, '-' (stdin), or inline JSON object string",
    )
    parser.add_argument(
        "--work-root",
        default="~/.foundry_local_playground/output",
        help="Base output root (default: ~/.foundry_local_playground/output)",
    )
    parser.add_argument(
        "--output",
        help="Optional output file name (.pptx). Saved inside workdir.",
    )
    parser.add_argument(
        "--fallback-layout",
        type=int,
        default=1,
        help="Layout index used when slide.layout is missing or invalid",
    )
    parser.add_argument(
        "--strict-images",
        action="store_true",
        help="Fail when a visual image path does not exist",
    )
    parser.add_argument(
        "--no-prefer-master-layouts",
        action="store_true",
        help="Disable automatic slide-master layout selection by content type",
    )
    parser.add_argument(
        "--list-layouts",
        action="store_true",
        help=(
            "Inspect template slide masters and print a JSON layout catalog. "
            "When used, --slide-title/--plan are not required."
        ),
    )
    parser.add_argument(
        "--layout-report",
        help="Optional JSON output file for --list-layouts mode",
    )

    args = parser.parse_args()
    if args.list_layouts:
        return args
    if not args.slide_title:
        parser.error("--slide-title is required unless --list-layouts is used.")
    if not args.plan:
        parser.error("--plan is required unless --list-layouts is used.")
    return args


def normalize_slide_title(raw: str) -> str:
    cleaned = raw.strip()
    if not cleaned:
        raise ValueError("slide-title is empty.")
    cleaned = re.sub(r"[\\/]+", "-", cleaned)
    cleaned = re.sub(r"\s+", "-", cleaned)
    cleaned = re.sub(r"-{2,}", "-", cleaned).strip("-")
    if not cleaned:
        raise ValueError("slide-title became empty after normalization.")
    return cleaned


def resolve_skill_dir() -> Path:
    current = Path(__file__).resolve().parent
    for candidate in [current, *current.parents]:
        if (candidate / "SKILL.md").exists():
            return candidate
    raise RuntimeError(f"Unable to resolve skill directory from script path: {__file__}")


def resolve_template_path(raw_template: str | None) -> Path:
    if raw_template:
        return Path(raw_template).expanduser().resolve()
    return (resolve_skill_dir() / "assets" / "template.pptx").resolve()


def prepare_work_paths(args: argparse.Namespace, template_path: Path) -> tuple[Path, Path, Path]:
    root = Path(args.work_root).expanduser().resolve()
    slide_dir_name = normalize_slide_title(args.slide_title)
    work_dir = root / slide_dir_name
    work_dir.mkdir(parents=True, exist_ok=True)

    staged_template = work_dir / template_path.name
    if template_path.resolve() != staged_template.resolve():
        shutil.copy2(template_path, staged_template)

    if args.output:
        output_name = Path(args.output).name
        if not output_name.lower().endswith(".pptx"):
            output_name = f"{output_name}.pptx"
    else:
        output_name = f"{slide_dir_name}.pptx"
    output_path = work_dir / output_name

    return work_dir, staged_template, output_path


def load_json(path: Path) -> dict[str, Any]:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError(
            f"Plan file is not UTF-8 text: {path}. --plan expects a UTF-8 JSON file."
        ) from exc
    return load_json_text(text, str(path))


def load_json_text(raw: str, source_label: str) -> dict[str, Any]:
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON: {source_label}: {exc}") from exc


def looks_like_json_object(raw: str) -> bool:
    return raw.lstrip().startswith("{")


def resolve_plan_input(raw_plan: str, work_dir: Path) -> tuple[dict[str, Any], Path, Path]:
    source = raw_plan.strip()
    if not source:
        raise ValueError("--plan is empty.")

    if source == "-":
        plan = load_json_text(sys.stdin.read(), "stdin")
        staged_plan = (work_dir / "deck_plan.stdin.json").resolve()
        staged_plan.write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
        return plan, staged_plan, staged_plan

    if source.startswith("@"):
        source = source[1:].strip()
        if not source:
            raise ValueError("Invalid --plan value: @ requires a file path.")

    if looks_like_json_object(source):
        plan = load_json_text(source, "inline --plan JSON")
        staged_plan = (work_dir / "deck_plan.inline.json").resolve()
        staged_plan.write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
        return plan, staged_plan, staged_plan

    plan_path = Path(source).expanduser().resolve()
    if not plan_path.exists():
        raise FileNotFoundError(
            f"Plan not found: {plan_path}. Provide an existing JSON file path or inline JSON via --plan."
        )
    if plan_path.suffix.lower() in {".md", ".ppt", ".pptx"}:
        raise ValueError(
            f"Unsupported plan file type: {plan_path.suffix}. --plan expects deck plan JSON, not {plan_path.name}."
        )

    plan = load_json(plan_path)
    staged_plan = (work_dir / plan_path.name).resolve()
    if plan_path.resolve() != staged_plan:
        shutil.copy2(plan_path, staged_plan)
    return plan, plan_path, staged_plan


def to_emu(value: Any, total: int, default_emu: int) -> int:
    if value is None:
        return default_emu
    if isinstance(value, (int, float)):
        return int(Inches(float(value)))
    if isinstance(value, str):
        raw = value.strip()
        if raw.endswith("%"):
            pct = float(raw[:-1])
            return int(total * pct / 100.0)
        return int(Inches(float(raw)))
    raise ValueError(f"Unsupported dimension value: {value!r}")


def resolve_path(raw: str, plan_path: Path) -> Path:
    path = Path(raw)
    if path.is_absolute():
        return path
    return (plan_path.parent / path).resolve()


def list_master_layouts(prs: Presentation) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    seen_layout_ids: set[int] = set()

    for master_index, master in enumerate(prs.slide_masters):
        for layout_index, layout in enumerate(master.slide_layouts):
            layout_id = id(layout)
            if layout_id in seen_layout_ids:
                continue
            seen_layout_ids.add(layout_id)

            name = str(getattr(layout, "name", "") or "").strip()
            name_lower = name.lower()
            placeholder_types: set[Any] = set()
            for placeholder in layout.placeholders:
                try:
                    placeholder_types.add(placeholder.placeholder_format.type)
                except Exception:
                    continue

            items.append(
                {
                    "layout": layout,
                    "name": name,
                    "name_lower": name_lower,
                    "master_index": master_index,
                    "layout_index": layout_index,
                    "has_title": bool(placeholder_types & TITLE_PLACEHOLDERS),
                    "has_subtitle": bool(placeholder_types & SUBTITLE_PLACEHOLDERS),
                    "has_body": bool(placeholder_types & BODY_PLACEHOLDERS),
                }
            )

    if not items:
        for layout_index, layout in enumerate(prs.slide_layouts):
            name = str(getattr(layout, "name", "") or "").strip()
            items.append(
                {
                    "layout": layout,
                    "name": name,
                    "name_lower": name.lower(),
                    "master_index": 0,
                    "layout_index": layout_index,
                    "has_title": False,
                    "has_subtitle": False,
                    "has_body": False,
                }
            )
    return items


def build_layout_catalog(layouts: list[dict[str, Any]]) -> list[dict[str, Any]]:
    catalog: list[dict[str, Any]] = []
    for item in layouts:
        catalog.append(
            {
                "master_index": item["master_index"],
                "layout_index": item["layout_index"],
                "layout_name": item["name"],
                "has_title": item["has_title"],
                "has_subtitle": item["has_subtitle"],
                "has_body": item["has_body"],
            }
        )
    return catalog


def inspect_template_layouts(args: argparse.Namespace) -> dict[str, Any]:
    template_path = resolve_template_path(args.template)
    if not template_path.exists():
        raise FileNotFoundError(f"Template not found: {template_path}")

    prs = Presentation(str(template_path))
    layouts = list_master_layouts(prs)
    report = {
        "template_path": str(template_path),
        "layout_count": len(layouts),
        "layouts": build_layout_catalog(layouts),
    }

    if args.layout_report:
        report_path = Path(args.layout_report).expanduser().resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    return report


def find_layout_by_name(layouts: list[dict[str, Any]], raw_name: str) -> dict[str, Any] | None:
    wanted = raw_name.strip().lower()
    if not wanted:
        return None

    for item in layouts:
        if item["name_lower"] == wanted:
            return item
    for item in layouts:
        if wanted in item["name_lower"]:
            return item
    return None


def score_layout_candidate(
    candidate: dict[str, Any],
    *,
    is_title_slide: bool,
    has_bullets: bool,
    has_table: bool,
    has_visual: bool,
    has_subtitle: bool,
) -> int:
    name = candidate["name_lower"]
    score = 0

    if "blank" in name:
        score -= 30

    if is_title_slide:
        if "title" in name or "cover" in name:
            score += 60
        if candidate["has_title"]:
            score += 20
        if candidate["has_subtitle"] or has_subtitle:
            score += 15
        if candidate["has_body"]:
            score -= 8
        return score

    if candidate["has_title"]:
        score += 14
    if has_subtitle and candidate["has_subtitle"]:
        score += 10
    if has_bullets and candidate["has_body"]:
        score += 18
    if "title and content" in name:
        score += 10

    if has_visual:
        if any(token in name for token in VISUAL_LAYOUT_KEYWORDS):
            score += 38
        if "content" in name:
            score += 8

    if has_table:
        if any(token in name for token in TABLE_LAYOUT_KEYWORDS):
            score += 40
        if "content" in name:
            score += 8

    if not has_visual and not has_table and has_bullets and "content" in name:
        score += 8

    return score


def resolve_fallback_layout(prs: Presentation, fallback: int) -> Any:
    layout_count = len(prs.slide_layouts)
    if layout_count == 0:
        raise ValueError("Template does not contain any slide layouts.")
    if 0 <= fallback < layout_count:
        return prs.slide_layouts[fallback]
    return prs.slide_layouts[0]


def pick_layout(
    prs: Presentation,
    layouts: list[dict[str, Any]],
    requested_index: Any,
    requested_name: str,
    fallback: int,
    *,
    prefer_master_layouts: bool,
    is_title_slide: bool,
    has_bullets: bool,
    has_table: bool,
    has_visual: bool,
    has_subtitle: bool,
) -> tuple[Any, str]:
    layout_count = len(prs.slide_layouts)
    if layout_count == 0:
        raise ValueError("Template does not contain any slide layouts.")

    if requested_name.strip():
        matched = find_layout_by_name(layouts, requested_name)
        if matched is not None:
            return matched["layout"], "requested_name"
        print(
            f"[WARN] Requested layout_name not found: {requested_name!r}; fallback selection is used.",
            file=sys.stderr,
        )

    if isinstance(requested_index, int) and 0 <= requested_index < layout_count:
        return prs.slide_layouts[requested_index], "requested_index"

    if prefer_master_layouts:
        scored: list[tuple[int, dict[str, Any]]] = []
        for candidate in layouts:
            score = score_layout_candidate(
                candidate,
                is_title_slide=is_title_slide,
                has_bullets=has_bullets,
                has_table=has_table,
                has_visual=has_visual,
                has_subtitle=has_subtitle,
            )
            scored.append((score, candidate))
        scored.sort(key=lambda item: item[0], reverse=True)
        if scored and scored[0][0] > 0:
            return scored[0][1]["layout"], "master_auto"

    return resolve_fallback_layout(prs, fallback), "fallback"


def find_body_shape(slide: Any) -> Any | None:
    title_shape = slide.shapes.title
    for shape in slide.shapes:
        if shape == title_shape:
            continue
        if not getattr(shape, "has_text_frame", False):
            continue
        if not getattr(shape, "is_placeholder", False):
            continue
        try:
            placeholder_type = shape.placeholder_format.type
        except Exception:
            continue
        if placeholder_type in BODY_PLACEHOLDERS:
            return shape

    for shape in slide.shapes:
        if shape == title_shape:
            continue
        if getattr(shape, "has_text_frame", False):
            return shape
    return None


def set_title(slide: Any, title_text: str) -> None:
    if not title_text:
        return
    if slide.shapes.title and slide.shapes.title.has_text_frame:
        text_frame = slide.shapes.title.text_frame
        text_frame.clear()
        text_frame.paragraphs[0].text = title_text
        return

    box = slide.shapes.add_textbox(Inches(0.75), Inches(0.3), Inches(11.5), Inches(0.9))
    paragraph = box.text_frame.paragraphs[0]
    paragraph.text = title_text
    paragraph.font.size = Pt(30)


def set_subtitle(slide: Any, subtitle_text: str) -> None:
    if not subtitle_text:
        return

    for shape in slide.placeholders:
        if not shape.has_text_frame:
            continue
        try:
            placeholder_type = shape.placeholder_format.type
        except Exception:
            continue
        if placeholder_type == PP_PLACEHOLDER.SUBTITLE:
            text_frame = shape.text_frame
            text_frame.clear()
            text_frame.paragraphs[0].text = subtitle_text
            return

    box = slide.shapes.add_textbox(Inches(0.75), Inches(1.4), Inches(11.5), Inches(0.9))
    paragraph = box.text_frame.paragraphs[0]
    paragraph.text = subtitle_text
    paragraph.font.size = Pt(20)


def set_bullets(slide: Any, bullets: list[str]) -> None:
    if not bullets:
        return
    body_shape = find_body_shape(slide)
    if body_shape is None:
        body_shape = slide.shapes.add_textbox(Inches(0.8), Inches(1.7), Inches(6.0), Inches(4.6))
    text_frame = body_shape.text_frame
    text_frame.clear()
    text_frame.word_wrap = True
    text_frame.paragraphs[0].text = bullets[0]
    text_frame.paragraphs[0].level = 0
    for item in bullets[1:]:
        paragraph = text_frame.add_paragraph()
        paragraph.text = item
        paragraph.level = 0


def add_table(prs: Presentation, slide: Any, table_spec: dict[str, Any]) -> bool:
    if not table_spec:
        return False

    headers = table_spec.get("headers", [])
    rows = table_spec.get("rows", [])
    if not headers or not rows:
        return False

    column_count = len(headers)
    if column_count == 0:
        return False
    for row in rows:
        if len(row) != column_count:
            raise ValueError("All table rows must match headers length.")

    default_left = int(prs.slide_width * 0.06)
    default_top = int(prs.slide_height * 0.34)
    default_width = int(prs.slide_width * 0.88)
    default_height = int(prs.slide_height * 0.50)

    left = to_emu(table_spec.get("left"), prs.slide_width, default_left)
    top = to_emu(table_spec.get("top"), prs.slide_height, default_top)
    width = to_emu(table_spec.get("width"), prs.slide_width, default_width)
    height = to_emu(table_spec.get("height"), prs.slide_height, default_height)

    shape = slide.shapes.add_table(
        rows=len(rows) + 1,
        cols=column_count,
        left=left,
        top=top,
        width=width,
        height=height,
    )
    table = shape.table

    for col_index, header in enumerate(headers):
        cell = table.cell(0, col_index)
        cell.text = str(header)
        first_paragraph = cell.text_frame.paragraphs[0]
        first_paragraph.font.bold = True

    for row_index, row in enumerate(rows, start=1):
        for col_index, value in enumerate(row):
            table.cell(row_index, col_index).text = str(value)

    return True


def add_visual(
    prs: Presentation,
    slide: Any,
    visual: dict[str, Any],
    plan_path: Path,
    strict_images: bool,
) -> bool:
    image_ref = visual.get("path")
    if not image_ref:
        return False

    image_path = resolve_path(str(image_ref), plan_path)
    if not image_path.exists():
        message = f"Image not found: {image_path}"
        if strict_images:
            raise FileNotFoundError(message)
        print(f"[WARN] {message}", file=sys.stderr)
        return False

    default_left = int(prs.slide_width * 0.56)
    default_top = int(prs.slide_height * 0.20)
    default_width = int(prs.slide_width * 0.38)

    left = to_emu(visual.get("left"), prs.slide_width, default_left)
    top = to_emu(visual.get("top"), prs.slide_height, default_top)
    width = to_emu(visual.get("width"), prs.slide_width, default_width)
    height_value = visual.get("height")
    height = None if height_value is None else to_emu(height_value, prs.slide_height, 0)

    if height is None:
        picture = slide.shapes.add_picture(str(image_path), left, top, width=width)
    else:
        picture = slide.shapes.add_picture(str(image_path), left, top, width=width, height=height)

    caption = str(visual.get("caption", "")).strip()
    if caption:
        caption_top = picture.top + picture.height + int(Inches(0.05))
        caption_height = int(Inches(0.45))
        box = slide.shapes.add_textbox(left, caption_top, picture.width, caption_height)
        paragraph = box.text_frame.paragraphs[0]
        paragraph.text = caption
        paragraph.font.size = Pt(12)

    return True


def add_notes(slide: Any, sources: list[str], speaker_notes: list[str]) -> None:
    clean_sources = [item.strip() for item in sources if item and item.strip()]
    clean_notes = [item.strip() for item in speaker_notes if item and item.strip()]
    if not clean_sources and not clean_notes:
        return

    lines: list[str] = []
    if clean_sources:
        lines.append("Sources:")
        lines.extend(f"- {item}" for item in clean_sources)
    if clean_notes:
        if lines:
            lines.append("")
        lines.append("Notes:")
        lines.extend(f"- {item}" for item in clean_notes)

    notes_frame = slide.notes_slide.notes_text_frame
    notes_frame.clear()
    notes_frame.paragraphs[0].text = "\n".join(lines)


def normalize_slide_spec(raw: Any, index: int) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise ValueError(f"Slide #{index} must be a JSON object.")

    title = str(raw.get("title", f"Slide {index}")).strip() or f"Slide {index}"
    bullets_raw = raw.get("bullets", [])
    if bullets_raw is None:
        bullets_raw = []
    if not isinstance(bullets_raw, list):
        raise ValueError(f"Slide #{index} field 'bullets' must be a list.")
    bullets = [str(item).strip() for item in bullets_raw if str(item).strip()]

    sources_raw = raw.get("sources", [])
    if sources_raw is None:
        sources_raw = []
    if not isinstance(sources_raw, list):
        raise ValueError(f"Slide #{index} field 'sources' must be a list.")
    sources = [str(item).strip() for item in sources_raw if str(item).strip()]

    notes_raw = raw.get("speaker_notes", [])
    if notes_raw is None:
        notes_raw = []
    if not isinstance(notes_raw, list):
        raise ValueError(f"Slide #{index} field 'speaker_notes' must be a list.")
    speaker_notes = [str(item).strip() for item in notes_raw if str(item).strip()]

    visual_raw = raw.get("visual")
    if visual_raw is None:
        visual = {}
    elif isinstance(visual_raw, dict):
        visual = visual_raw
    else:
        raise ValueError(f"Slide #{index} field 'visual' must be an object.")

    table_raw = raw.get("table")
    if table_raw is None:
        table = {}
    elif isinstance(table_raw, dict):
        headers_raw = table_raw.get("headers", [])
        rows_raw = table_raw.get("rows", [])
        if not isinstance(headers_raw, list):
            raise ValueError(f"Slide #{index} field 'table.headers' must be a list.")
        if not isinstance(rows_raw, list):
            raise ValueError(f"Slide #{index} field 'table.rows' must be a list.")

        headers = [str(item).strip() for item in headers_raw if str(item).strip()]
        rows: list[list[str]] = []
        for row_i, row_item in enumerate(rows_raw, start=1):
            if not isinstance(row_item, list):
                raise ValueError(
                    f"Slide #{index} field 'table.rows[{row_i}]' must be a list."
                )
            row_values = [str(value).strip() for value in row_item]
            if row_values:
                rows.append(row_values)

        if rows and headers:
            expected_cols = len(headers)
            for row_i, row_values in enumerate(rows, start=1):
                if len(row_values) != expected_cols:
                    raise ValueError(
                        f"Slide #{index} field 'table.rows[{row_i}]' must have {expected_cols} columns."
                    )

        table = {
            "headers": headers,
            "rows": rows,
            "left": table_raw.get("left"),
            "top": table_raw.get("top"),
            "width": table_raw.get("width"),
            "height": table_raw.get("height"),
        }
    else:
        raise ValueError(f"Slide #{index} field 'table' must be an object.")

    return {
        "layout": raw.get("layout"),
        "layout_name": str(raw.get("layout_name", "")).strip(),
        "title": title,
        "subtitle": str(raw.get("subtitle", "")).strip(),
        "bullets": bullets,
        "sources": sources,
        "speaker_notes": speaker_notes,
        "visual": visual,
        "table": table,
    }


def add_title_slide_if_requested(
    prs: Presentation,
    layouts: list[dict[str, Any]],
    plan: dict[str, Any],
    fallback_layout: int,
    prefer_master_layouts: bool,
) -> tuple[int, int]:
    title_spec = plan.get("title_slide")
    if not isinstance(title_spec, dict):
        return 0, 0

    requested_layout_name = str(title_spec.get("layout_name", "")).strip()
    layout, selection_mode = pick_layout(
        prs,
        layouts,
        title_spec.get("layout"),
        requested_layout_name,
        fallback_layout,
        prefer_master_layouts=prefer_master_layouts,
        is_title_slide=True,
        has_bullets=False,
        has_table=False,
        has_visual=False,
        has_subtitle=bool(str(title_spec.get("subtitle", "")).strip()),
    )
    slide = prs.slides.add_slide(layout)
    set_title(slide, str(title_spec.get("title", "")).strip())
    set_subtitle(slide, str(title_spec.get("subtitle", "")).strip())

    title_sources = title_spec.get("sources", [])
    title_notes = title_spec.get("speaker_notes", [])
    if not isinstance(title_sources, list):
        title_sources = []
    if not isinstance(title_notes, list):
        title_notes = []
    add_notes(slide, [str(item) for item in title_sources], [str(item) for item in title_notes])
    master_auto_count = 1 if selection_mode == "master_auto" else 0
    return 1, master_auto_count


def build_deck(args: argparse.Namespace) -> dict[str, Any]:
    template_path = resolve_template_path(args.template)
    prefer_master_layouts = not args.no_prefer_master_layouts

    if not template_path.exists():
        raise FileNotFoundError(f"Template not found: {template_path}")

    work_dir, staged_template, output_path = prepare_work_paths(args, template_path)
    plan, plan_reference_path, staged_plan_path = resolve_plan_input(args.plan, work_dir)

    if not isinstance(plan, dict):
        raise ValueError("Top-level plan JSON must be an object.")
    slides_raw = plan.get("slides")
    if not isinstance(slides_raw, list) or not slides_raw:
        raise ValueError("Plan must contain a non-empty 'slides' list.")
    expected_language = normalize_language(plan.get("language"))
    if plan.get("language") not in (None, "") and expected_language is None:
        raise ValueError("Unsupported plan.language. Use 'ja' or 'en'.")

    # Initialize one output PPTX file, then append slides to it one-by-one.
    if staged_template.resolve() != output_path.resolve() or not output_path.exists():
        shutil.copy2(staged_template, output_path)

    add_slide_script = (Path(__file__).resolve().parent / "add_slide.py").resolve()
    if not add_slide_script.exists():
        raise FileNotFoundError(f"Slide append script not found: {add_slide_script}")

    inserted_visuals = 0
    inserted_tables = 0
    master_auto_layout_count = 0
    added_slides = 0

    def append_one(spec_obj: dict[str, Any], *, kind: str, seq: int) -> dict[str, Any]:
        spec_path = (work_dir / f"slide_spec_{seq:03d}_{kind}.json").resolve()
        spec_path.write_text(json.dumps(spec_obj, ensure_ascii=False, indent=2), encoding="utf-8")

        command = [
            sys.executable,
            str(add_slide_script),
            "--deck",
            str(output_path),
            "--kind",
            kind,
            "--spec",
            str(spec_path),
            "--fallback-layout",
            str(args.fallback_layout),
            "--plan-base",
            str(plan_reference_path.parent),
        ]
        if args.strict_images:
            command.append("--strict-images")
        if args.no_prefer_master_layouts:
            command.append("--no-prefer-master-layouts")
        if expected_language:
            command.extend(["--language", expected_language])

        completed = subprocess.run(command, capture_output=True, text=True)
        if completed.returncode != 0:
            stderr_text = (completed.stderr or "").strip()
            stdout_text = (completed.stdout or "").strip()
            detail = stderr_text or stdout_text or "unknown error"
            raise RuntimeError(f"Failed to append {kind} slide #{seq}: {detail}")

        stdout_text = (completed.stdout or "").strip()
        if not stdout_text:
            raise RuntimeError(f"Slide append returned empty output for {kind} slide #{seq}.")
        try:
            return json.loads(stdout_text.splitlines()[-1])
        except json.JSONDecodeError as exc:
            raise RuntimeError(
                f"Slide append returned non-JSON output for {kind} slide #{seq}: {stdout_text}"
            ) from exc

    title_spec = plan.get("title_slide")
    if isinstance(title_spec, dict):
        title_result = append_one(title_spec, kind="title", seq=0)
        added_slides += 1
        if title_result.get("used_master_auto"):
            master_auto_layout_count += 1

    for index, raw_slide in enumerate(slides_raw, start=1):
        if not isinstance(raw_slide, dict):
            raise ValueError(f"Slide #{index} must be a JSON object.")
        slide_result = append_one(raw_slide, kind="content", seq=index)
        added_slides += 1
        if slide_result.get("used_master_auto"):
            master_auto_layout_count += 1
        if slide_result.get("table_added"):
            inserted_tables += 1
        if slide_result.get("visual_added"):
            inserted_visuals += 1

    return {
        "work_dir": work_dir,
        "plan_path": plan_reference_path,
        "staged_plan": staged_plan_path,
        "staged_template": staged_template,
        "output_path": output_path,
        "slide_count": added_slides,
        "visual_count": inserted_visuals,
        "table_count": inserted_tables,
        "master_auto_layout_count": master_auto_layout_count,
        "language": expected_language or "auto",
    }


def main() -> int:
    args = parse_args()
    try:
        if args.list_layouts:
            report = inspect_template_layouts(args)
            print(json.dumps(report, ensure_ascii=False, indent=2))
            return 0
        result = build_deck(args)
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    print(f"[OK] Created {result['output_path']}")
    print(f"[OK] Work directory: {result['work_dir']}")
    print(f"[OK] Plan source: {result['plan_path']}")
    print(f"[OK] Staged plan: {result['staged_plan']}")
    print(f"[OK] Staged template: {result['staged_template']}")
    print(f"[OK] Slides: {result['slide_count']}")
    print(f"[OK] Slides using auto-selected master layouts: {result['master_auto_layout_count']}")
    print(f"[OK] Slides with inserted tables: {result['table_count']}")
    print(f"[OK] Slides with inserted visuals: {result['visual_count']}")
    print(f"[OK] Language: {result['language']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
