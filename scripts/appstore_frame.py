#!/usr/bin/env python3
"""App Store frames for Duly: navy background, headline with one green word,
grey subtitle, and the raw simulator screenshot in a device frame.

Matches the v1.0 sets (1320x2868 iPhone 6.9", 2064x2752 iPad 13";
the 6.3" set is the iPhone frame resized to 1206x2622).

  python3 scripts/appstore_frame.py iphone shot.png out.png "Job Photos" "Show the finished work on every invoice" --green Photos
"""
import argparse

from PIL import Image, ImageDraw, ImageFilter, ImageFont

BG = (10, 37, 64)
GREEN = (159, 232, 112)
WHITE = (255, 255, 255)
GREY = (199, 206, 214)
RING = (60, 72, 88)
FONTS = "/usr/share/fonts/opentype/inter/"

# canvas, title size, title cap-top, subtitle size, subtitle cap-top,
# frame box (x0, y0, x1, y1), bezel width, outer radius, screen radius
LAYOUT = {
    "iphone": dict(size=(1320, 2868), title=124, title_top=198, sub=52, sub_top=342,
                   frame=(119, 470, 1201, 2760), bezel=26, r_out=170, r_in=146),
    "ipad": dict(size=(2064, 2752), title=180, title_top=310, sub=84, sub_top=531,
                 frame=(269, 732, 1795, 2740), bezel=40, r_out=110, r_in=74),
}


def font(name, size):
    return ImageFont.truetype(FONTS + name, size)


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return m


def draw_line(draw, width, top, words, fnt, default):
    """words: [(text, colour)] drawn centred, cap top at `top`."""
    space = fnt.getlength(" ")
    total = sum(fnt.getlength(t) for t, _ in words) + space * (len(words) - 1)
    cap = fnt.getbbox("H")[1]  # offset from the 'la' anchor to the cap top
    x = (width - total) / 2
    for text, colour in words:
        draw.text((x, top - cap), text, font=fnt, fill=colour or default, anchor="la")
        x += fnt.getlength(text) + space


def frame(kind, shot_path, out_path, title, subtitle, green):
    L = LAYOUT[kind]
    W, H = L["size"]
    canvas = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(canvas)

    tf = font("InterDisplay-Bold.otf", L["title"])
    while sum(tf.getlength(w) for w in title.split()) + tf.getlength(" ") * (len(title.split()) - 1) > W * 0.9:
        tf = font("InterDisplay-Bold.otf", tf.size - 4)
    draw_line(d, W, L["title_top"], [(w, GREEN if w in green else WHITE) for w in title.split()], tf, WHITE)
    sf = font("Inter-Medium.otf", L["sub"])
    while sf.getlength(subtitle) > W * 0.9:
        sf = font("Inter-Medium.otf", sf.size - 2)
    draw_line(d, W, L["sub_top"], [(subtitle, GREY)], sf, GREY)

    x0, y0, x1, y1 = L["frame"]
    fw, fh = x1 - x0, y1 - y0
    # soft shadow
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((x0, y0 + 30, x1, y1 + 30), radius=L["r_out"], fill=120)
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    canvas.paste((4, 18, 34), (0, 0), shadow)
    # body: black, thin grey ring, black bezel
    body = Image.new("RGB", (fw, fh), (0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle((2, 2, fw - 3, fh - 3), radius=L["r_out"] - 2, outline=RING, width=3)
    canvas.paste(body, (x0, y0), rounded_mask((fw, fh), L["r_out"]))
    # screen
    b = L["bezel"]
    sw, sh = fw - 2 * b, fh - 2 * b
    shot = Image.open(shot_path).convert("RGB")
    scale = sw / shot.width
    shot = shot.resize((sw, round(shot.height * scale)), Image.LANCZOS)
    visible = min(sh, H - (y0 + b))  # the iPad frame runs off the bottom edge
    shot = shot.crop((0, 0, sw, min(shot.height, sh)))
    canvas.paste(shot, (x0 + b, y0 + b), rounded_mask(shot.size, L["r_in"]))
    canvas.save(out_path, optimize=True)
    return visible


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("kind", choices=LAYOUT)
    p.add_argument("shot")
    p.add_argument("out")
    p.add_argument("title")
    p.add_argument("subtitle")
    p.add_argument("--green", nargs="*", default=[])
    p.add_argument("--small", help="also write the 6.3-inch 1206x2622 copy here (iPhone only)")
    a = p.parse_args()
    frame(a.kind, a.shot, a.out, a.title, a.subtitle, set(a.green))
    if a.small:
        Image.open(a.out).resize((1206, 2622), Image.LANCZOS).save(a.small, optimize=True)
