#!/usr/bin/env python3
"""Render the Signet Play Store feature graphic.

Play spec: exactly 1024 x 500 px, PNG, opaque (no alpha). The image appears
as a marketing banner atop the store listing.

Design register: "security tool, not consumer app" — HUD-influenced, sharp
corners, mono type, subtle gold accents. Palette sourced from
`lib/core/theme/signet_theme.dart` `SignetTokens`.

Layout:
  - Left third: SIGNET wordmark (Liberation Sans Bold, tight tracking) +
    "VERIFY WHO'S CALLING" tagline in mono.
  - Right two-thirds: stylized A -> B verify flow. Two HUD panels labeled
    "YOU" and "MOM" flanking an abstract rotating-code display with four
    BIP-39 words. Monospace throughout on the right half for operator feel.

Regenerate with:
    python distribution/play-store/tools/render_feature_graphic.py
"""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


# --- Paths ---------------------------------------------------------------

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "distribution" / "play-store" / "feature-graphic.png"
ICON_SRC = ROOT / "assets" / "icon" / "signet-source-1024.png"

# --- Colors (from SignetTokens) -----------------------------------------

VOID_BG = (0x0A, 0x0C, 0x10)          # voidBg
NAVY = (0x08, 0x20, 0x36)              # icon panel navy
INK = (0xE4, 0xE6, 0xEA)               # ink
MUTED = (0x8A, 0x8D, 0x93)             # muted
GOLD = (0xC9, 0xA2, 0x4B)              # almond / vesica gold
MINT = (0x14, 0xB8, 0x86)              # verified mint
BORDER = (0x2A, 0x2D, 0x34)            # border
BORDER_STRONG = (0x3A, 0x3D, 0x44)     # borderStrong

# --- Dimensions ----------------------------------------------------------

W, H = 1024, 500

# --- Fonts ---------------------------------------------------------------

SANS_BOLD_CANDIDATES = [
    "/usr/share/fonts/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
]
SANS_REG_CANDIDATES = [
    "/usr/share/fonts/liberation/LiberationSans-Regular.ttf",
    "/usr/share/fonts/TTF/DejaVuSans.ttf",
]
MONO_BOLD_CANDIDATES = [
    "/usr/share/fonts/liberation/LiberationMono-Bold.ttf",
    "/usr/share/fonts/TTF/DejaVuSansMono-Bold.ttf",
    "/usr/share/fonts/TTF/Hack-Bold.ttf",
]
MONO_REG_CANDIDATES = [
    "/usr/share/fonts/liberation/LiberationMono-Regular.ttf",
    "/usr/share/fonts/TTF/DejaVuSansMono.ttf",
    "/usr/share/fonts/TTF/Hack-Regular.ttf",
]


def pick_font(candidates: list[str], size: int) -> ImageFont.FreeTypeFont:
    """Return the first candidate font that loads, else PIL default."""
    for p in candidates:
        if os.path.isfile(p):
            try:
                return ImageFont.truetype(p, size=size)
            except Exception:
                continue
    return ImageFont.load_default()


# --- Helpers -------------------------------------------------------------


def draw_tracked_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    font: ImageFont.FreeTypeFont,
    tracking_px: int,
    fill: tuple[int, int, int],
) -> int:
    """Render `text` with fixed pixel tracking between glyphs. Returns final x."""
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        bbox = font.getbbox(ch)
        adv = bbox[2] - bbox[0]
        x += adv + tracking_px
    return x


def measure_tracked(text: str, font: ImageFont.FreeTypeFont, tracking_px: int) -> int:
    total = 0
    for ch in text:
        bbox = font.getbbox(ch)
        total += (bbox[2] - bbox[0]) + tracking_px
    return max(0, total - tracking_px)


def draw_icon(img: Image.Image, cx: int, cy: int, size: int) -> None:
    """Draw the Signet mark: navy rounded square with two overlapping rings,
    gold vesica piscis between them, and a gold center dot. If the source
    icon PNG exists, prefer pasting it (flattened onto navy) for fidelity.
    """
    if ICON_SRC.is_file():
        try:
            src = Image.open(ICON_SRC).convert("RGBA")
            src = src.resize((size, size), Image.LANCZOS)
            # Flatten onto opaque canvas so the resulting feature graphic can
            # save as RGB without worrying about alpha bleed.
            canvas = Image.new("RGB", (size, size), VOID_BG)
            canvas.paste(src, (0, 0), src)
            img.paste(canvas, (cx - size // 2, cy - size // 2))
            return
        except Exception:
            pass
    # Fallback: draw a simplified glyph.
    d = ImageDraw.Draw(img)
    half = size // 2
    box = (cx - half, cy - half, cx + half, cy + half)
    d.rectangle(box, fill=NAVY)
    r = int(size * 0.30)
    off = int(size * 0.13)
    ring_w = max(2, int(size * 0.035))
    d.ellipse((cx - off - r, cy - r, cx - off + r, cy + r), outline=INK, width=ring_w)
    d.ellipse((cx + off - r, cy - r, cx + off + r, cy + r), outline=INK, width=ring_w)
    dot = max(3, int(size * 0.035))
    d.ellipse((cx - dot, cy - dot, cx + dot, cy + dot), fill=GOLD)


# --- Main render ---------------------------------------------------------


def render() -> Image.Image:
    img = Image.new("RGB", (W, H), VOID_BG)
    draw = ImageDraw.Draw(img)

    # ----- Subtle HUD grid on the void background -----
    grid_step = 32
    grid_color = (0x12, 0x14, 0x18)  # just a hair lighter than void
    for x in range(0, W, grid_step):
        draw.line([(x, 0), (x, H)], fill=grid_color, width=1)
    for y in range(0, H, grid_step):
        draw.line([(0, y), (W, y)], fill=grid_color, width=1)

    # ----- Left third: wordmark + tagline -----
    left_pad = 48
    wordmark_font = pick_font(SANS_BOLD_CANDIDATES, 84)
    tagline_font = pick_font(MONO_REG_CANDIDATES, 18)
    micro_font = pick_font(MONO_REG_CANDIDATES, 12)

    # SIGNET — tight tracking, uppercase, ink on void. Size tuned so the
    # mark fits inside the left third without colliding with the right-side
    # HUD panels.
    wordmark_tracking = 4  # px between glyphs; ~12-15 "tracking" in type terms
    wordmark_text = "SIGNET"
    wordmark_w = measure_tracked(wordmark_text, wordmark_font, wordmark_tracking)
    wordmark_x = left_pad
    wordmark_y = 200
    draw_tracked_text(
        draw,
        (wordmark_x, wordmark_y),
        wordmark_text,
        wordmark_font,
        wordmark_tracking,
        INK,
    )

    # Small gold tick under the M of wordmark — vesica-echo accent.
    tick_y = wordmark_y + 98
    draw.line(
        [(wordmark_x, tick_y), (wordmark_x + 34, tick_y)],
        fill=GOLD,
        width=3,
    )

    # Tagline in mono, uppercase, muted-with-ink.
    tagline = "VERIFY WHO'S CALLING"
    tag_tracking = 3
    draw_tracked_text(
        draw,
        (wordmark_x, tick_y + 18),
        tagline,
        tagline_font,
        tag_tracking,
        INK,
    )

    # Micro meta above wordmark — operator-console vibe.
    meta = "v0.2 ALPHA  //  OFFLINE  //  PEER-TO-PEER"
    draw_tracked_text(draw, (wordmark_x, wordmark_y - 30), meta, micro_font, 1, MUTED)

    # ----- Right two-thirds: A -> B verify flow -----
    right_x0 = 440  # column start — keeps clear of wordmark
    right_x1 = W - 40

    # Center: icon mark.
    icon_size = 150
    icon_cx = (right_x0 + right_x1) // 2
    icon_cy = H // 2 - 20  # lifted to leave room for the code strip
    draw_icon(img, icon_cx, icon_cy, icon_size)

    # Two HUD panels (sharp corners) labeled YOU and MOM.
    panel_w = 160
    panel_h = 210
    panel_y = icon_cy - panel_h // 2
    left_panel = (
        right_x0,
        panel_y,
        right_x0 + panel_w,
        panel_y + panel_h,
    )
    right_panel = (
        right_x1 - panel_w,
        panel_y,
        right_x1,
        panel_y + panel_h,
    )

    for box, label, role_color in (
        (left_panel, "YOU", MINT),
        (right_panel, "MOM", GOLD),
    ):
        # Panel fill + 1px border, HUD corner tags.
        draw.rectangle(box, fill=(0x0F, 0x11, 0x14), outline=BORDER_STRONG, width=1)
        # Corner tick marks.
        x0, y0, x1, y1 = box
        tick = 10
        for (cx_, cy_, dx1, dy1, dx2, dy2) in (
            (x0, y0, tick, 0, 0, tick),
            (x1, y0, -tick, 0, 0, tick),
            (x0, y1, tick, 0, 0, -tick),
            (x1, y1, -tick, 0, 0, -tick),
        ):
            draw.line([(cx_, cy_), (cx_ + dx1, cy_ + dy1)], fill=GOLD, width=2)
            draw.line([(cx_, cy_), (cx_ + dx2, cy_ + dy2)], fill=GOLD, width=2)

        # Role label.
        role_font = pick_font(MONO_BOLD_CANDIDATES, 14)
        label_tracking = 3
        label_w = measure_tracked(label, role_font, label_tracking)
        draw_tracked_text(
            draw,
            (x0 + (panel_w - label_w) // 2, y0 + 16),
            label,
            role_font,
            label_tracking,
            role_color,
        )

        # Divider line under label.
        draw.line([(x0 + 16, y0 + 40), (x1 - 16, y0 + 40)], fill=BORDER, width=1)

        # Status line.
        status_font = pick_font(MONO_REG_CANDIDATES, 12)
        status = "PAIRED" if label == "YOU" else "VERIFY"
        status_w = measure_tracked(status, status_font, 2)
        draw_tracked_text(
            draw,
            (x0 + (panel_w - status_w) // 2, y0 + 52),
            status,
            status_font,
            2,
            MUTED,
        )

    # Arrow from YOU -> icon -> MOM (mint hairline with chevrons).
    arrow_y = icon_cy
    arrow_start_x = left_panel[2] + 12
    arrow_end_x = right_panel[0] - 12
    icon_left = icon_cx - icon_size // 2 - 6
    icon_right = icon_cx + icon_size // 2 + 6
    draw.line([(arrow_start_x, arrow_y), (icon_left, arrow_y)], fill=MINT, width=2)
    draw.line([(icon_right, arrow_y), (arrow_end_x, arrow_y)], fill=MINT, width=2)
    # End chevron.
    draw.line(
        [(arrow_end_x, arrow_y), (arrow_end_x - 10, arrow_y - 6)],
        fill=MINT,
        width=2,
    )
    draw.line(
        [(arrow_end_x, arrow_y), (arrow_end_x - 10, arrow_y + 6)],
        fill=MINT,
        width=2,
    )

    # ----- BIP39 code row along the bottom, centered on the right column -----
    # Four real BIP-39 words — picked for voice-transcription clarity and
    # thematic resonance (material, place, flow, finality).
    words = ["orange", "river", "stone", "flint"]
    word_font = pick_font(MONO_BOLD_CANDIDATES, 20)
    sep_font = pick_font(MONO_REG_CANDIDATES, 20)
    sep = "  \u00b7  "  # middle dot with surrounding spaces

    # Measure to center under the icon cluster.
    total_text = sep.join(words)
    bbox = word_font.getbbox(total_text)
    code_w = bbox[2] - bbox[0]
    code_x = icon_cx - code_w // 2
    code_y = panel_y + panel_h + 36
    # Background strip for legibility.
    strip_pad_x = 18
    strip_pad_y = 8
    strip_box = (
        code_x - strip_pad_x,
        code_y - strip_pad_y,
        code_x + code_w + strip_pad_x,
        code_y + (bbox[3] - bbox[1]) + strip_pad_y + 4,
    )
    draw.rectangle(strip_box, fill=(0x0F, 0x1C, 0x18), outline=MINT, width=1)

    # Draw words with mint highlight, separators muted.
    cx = code_x
    for i, w in enumerate(words):
        draw.text((cx, code_y), w, font=word_font, fill=INK)
        cx += word_font.getbbox(w)[2] - word_font.getbbox(w)[0]
        if i < len(words) - 1:
            draw.text((cx, code_y), sep, font=sep_font, fill=GOLD)
            cx += sep_font.getbbox(sep)[2] - sep_font.getbbox(sep)[0]

    # Label above the strip.
    label_font = pick_font(MONO_REG_CANDIDATES, 11)
    code_label = "ROTATING CODE  //  30s WINDOW"
    draw_tracked_text(
        draw,
        (strip_box[0], strip_box[1] - 18),
        code_label,
        label_font,
        2,
        MUTED,
    )

    # ----- Thin outer frame (HUD chrome, not rounded) -----
    frame = 4
    draw.rectangle(
        (frame, frame, W - frame - 1, H - frame - 1),
        outline=BORDER,
        width=1,
    )

    return img


def main() -> None:
    img = render()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    # Ensure opaque (no alpha) on save.
    img = img.convert("RGB")
    img.save(OUT, "PNG")

    # Validation ----------------------------------------------------------
    reopened = Image.open(OUT)
    assert reopened.size == (W, H), f"bad size: {reopened.size}"
    assert reopened.mode == "RGB", f"bad mode: {reopened.mode}"
    px = list(reopened.convert("RGB").getdata())[:8]
    print(f"wrote: {OUT}")
    print(f"size:  {reopened.size}")
    print(f"mode:  {reopened.mode}")
    print(f"first 8 px RGB: {px}")


if __name__ == "__main__":
    main()
