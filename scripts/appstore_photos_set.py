#!/usr/bin/env python3
"""Builds the v1.1 "Job photos" App Store image (screenshot 08) for every
listing from the raw screens on the ci-screenshots branch.

  git fetch origin ci-screenshots && python3 scripts/appstore_photos_set.py OUT_DIR

Writes OUT_DIR/<listing>-iphone/08.png (1320x2868), <listing>-iphone-63/08-6.3.png
(1206x2622) and <listing>-ipad/08.png (2064x2752).
"""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
from appstore_frame import frame  # noqa: E402
from PIL import Image  # noqa: E402

# listing: (capture region, title, green words, subtitle)
SETS = {
    "us": ("US", "Job Photos", {"Photos"}, "Show the finished work on every invoice"),
    "uk": ("UK", "Job Photos", {"Photos"}, "Show the finished work on every invoice"),
    "au": ("AU", "Job Photos", {"Photos"}, "Show the finished work on every invoice"),
    "ca": ("CA", "Job Photos", {"Photos"}, "Show the finished work on every invoice"),
    "es": ("US", "Fotos de la obra", {"obra"}, "Muestra el trabajo terminado en cada factura"),
    "fr": ("FR", "Photos du chantier", {"chantier"}, "Montrez le travail fini sur chaque facture"),
}
DEVICES = {"iphone": "iPhone-17-Pro-Max", "ipad": "iPad-Pro-13-inch-(M5)"}
SCREEN = "13-photos-editor.png"


def raw(region, device, tmp):
    path = os.path.join(tmp, f"{region}-{device}.png")
    with open(path, "wb") as f:
        subprocess.run(["git", "show", f"origin/ci-screenshots:{region}-{DEVICES[device]}/{SCREEN}"], stdout=f, check=True)
    return path


def main(out):
    with tempfile.TemporaryDirectory() as tmp:
        for listing, (region, title, green, subtitle) in SETS.items():
            for device in DEVICES:
                try:
                    shot = raw(region, device, tmp)
                except subprocess.CalledProcessError:
                    print(f"missing {region} {device}")
                    continue
                folder = os.path.join(out, f"{listing}-{device}")
                os.makedirs(folder, exist_ok=True)
                target = os.path.join(folder, "08.png")
                frame(device, shot, target, title, subtitle, green)
                if device == "iphone":
                    small = os.path.join(out, f"{listing}-iphone-63")
                    os.makedirs(small, exist_ok=True)
                    Image.open(target).resize((1206, 2622), Image.LANCZOS).save(os.path.join(small, "08-6.3.png"), optimize=True)
                print("ok", listing, device)


if __name__ == "__main__":
    main(sys.argv[1])
