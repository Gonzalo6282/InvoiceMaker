#!/usr/bin/env python3
"""Builds a full App Store set (screens 01-08) for one listing from the raw
screens on the ci-screenshots branch, in the v1.0 frame style.

  git fetch origin +ci-screenshots:refs/remotes/origin/ci-screenshots
  python3 scripts/appstore_full_set.py es OUT_DIR --photo02-iphone DE_02.png --photo02-ipad DE_02_IPAD.png

Screen 02 is the "on-site" photo with a small phone in the corner. The photo is
licensed and not in the repo, so the script takes an existing 02 from another
language (any of them: same photo, same phone position), repaints the caption
and puts this language's editor screen into the small phone.

Writes OUT_DIR/<listing>-iphone/NN.png (1320x2868), <listing>-iphone-63/NN-6.3.png
(1206x2622) and <listing>-ipad/NN.png (2064x2752).
"""
import argparse
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
from appstore_frame import BG, GREEN, GREY, LAYOUT, WHITE, draw_line, font, frame, rounded_mask  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

DEVICES = {"iphone": "iPhone-17-Pro-Max", "ipad": "iPad-Pro-13-inch-(M5)"}

# Which raw screen each App Store image uses (same order as the v1.0 sets).
SCREENS = {
    "01": "03-templates.png",
    "02": "02-editor.png",  # inside the small phone of the photo composite
    "03": "01-list.png",
    "04": "05-paid-pdf.png",
    "05": "08-quote-editor.png",
    "06": "04-paid-editor.png",
    "07": "12-invoice-look.png",
    "08": "13-photos-editor.png",
}

# listing: capture region and captions (title, green words, subtitle) per image.
SETS = {
    "es": ("MX", {
        "01": ("Crea facturas", {"facturas"}, "Factura a tus clientes en segundos"),
        "02": ("Factura en la obra", {"en", "la", "obra"}, "Para oficios y freelancers"),
        "03": ("Cada factura al día", {"Cada"}, "Pagadas, pendientes y vencidas"),
        "04": ("Cobra más rápido", {"rápido"}, "Tu CLABE y PayPal en cada factura"),
        "05": ("Cotizaciones", {"Cotizaciones"}, "Conviértelas en factura con un toque"),
        "06": ("Recibos", {"Recibos"}, "Marca pagado y envía un recibo"),
        "07": ("Tu diseño", {"diseño"}, "Personaliza con tu logo"),
        "08": ("Fotos de la obra", {"obra"}, "Muestra el trabajo terminado en cada factura"),
    }),
}

# The small phone's screen inside screen 02: (x0, y0, x1, y1, corner radius),
# measured on the existing 02 images (it is the whole raw screen, scaled).
PHONE02 = {"iphone": (789, 1735, 1264, 2767, 66), "ipad": (1234, 1643, 1977, 2634, 38)}
# The caption band at the top of screen 02 (repainted down to here; the photo starts lower).
CAPTION_BAND = {"iphone": 520, "ipad": 770}


def raw(region, device, name, tmp):
    path = os.path.join(tmp, f"{region}-{device}-{name}")
    with open(path, "wb") as f:
        subprocess.run(["git", "show", f"origin/ci-screenshots:{region}-{DEVICES[device]}/{name}"], stdout=f, check=True)
    return path


def photo02(device, base_path, shot_path, out_path, title, green, subtitle):
    L = LAYOUT[device]
    canvas = Image.open(base_path).convert("RGB")
    W, _ = canvas.size
    d = ImageDraw.Draw(canvas)
    d.rectangle((0, 0, W, CAPTION_BAND[device]), fill=BG)
    tf = font("InterDisplay-Bold.otf", L["title"])
    while sum(tf.getlength(w) for w in title.split()) + tf.getlength(" ") * (len(title.split()) - 1) > W * 0.9:
        tf = font("InterDisplay-Bold.otf", tf.size - 4)
    draw_line(d, W, L["title_top"], [(w, GREEN if w in green else WHITE) for w in title.split()], tf, WHITE)
    sf = font("Inter-Medium.otf", L["sub"])
    while sf.getlength(subtitle) > W * 0.9:
        sf = font("Inter-Medium.otf", sf.size - 2)
    draw_line(d, W, L["sub_top"], [(subtitle, GREY)], sf, GREY)
    x0, y0, x1, y1, r = PHONE02[device]
    shot = Image.open(shot_path).convert("RGB").resize((x1 - x0, y1 - y0), Image.LANCZOS)
    canvas.paste(shot, (x0, y0), rounded_mask(shot.size, r))
    canvas.save(out_path, optimize=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("listing", choices=SETS)
    p.add_argument("out")
    p.add_argument("--photo02-iphone", required=True)
    p.add_argument("--photo02-ipad", required=True)
    a = p.parse_args()
    region, captions = SETS[a.listing]
    bases = {"iphone": a.photo02_iphone, "ipad": a.photo02_ipad}
    with tempfile.TemporaryDirectory() as tmp:
        for device in DEVICES:
            folder = os.path.join(a.out, f"{a.listing}-{device}")
            os.makedirs(folder, exist_ok=True)
            for n, screen in SCREENS.items():
                title, green, subtitle = captions[n]
                shot = raw(region, device, screen, tmp)
                target = os.path.join(folder, f"{n}.png")
                if n == "02":
                    photo02(device, bases[device], shot, target, title, green, subtitle)
                else:
                    frame(device, shot, target, title, subtitle, green)
                if device == "iphone":
                    small = os.path.join(a.out, f"{a.listing}-iphone-63")
                    os.makedirs(small, exist_ok=True)
                    Image.open(target).resize((1206, 2622), Image.LANCZOS).save(os.path.join(small, f"{n}-6.3.png"), optimize=True)
                print("ok", a.listing, device, n)


if __name__ == "__main__":
    main()
