# Convert font exported by https://snowb.org to my atlas format for the pangea ports.
# INSTRUCTIONS:
# - Go to https://snowb.org and create a font
# - Click "Export" and set "Export Type" to "BMFont (XML)"
# - python3 rawdata/bmfont2atlas.py font.xml

from dataclasses import dataclass
from PIL import Image
import argparse, imagehash, os, rectpack, xmltodict, unicodedata

ATLAS_W = 1024
ATLAS_H = 1024
PADDING = 1
HASH_DIFF_BITS_THRESHOLD = 5

@dataclass
class Glyph:
    codepoint: int
    x: int
    y: int
    width: int
    height: int
    xoffset: int
    yoffset: int
    xadvance: int
    yadvance: int
    slice_image: Image
    slice_hash: int
    alias_of: int

    def __str__(self):
        comment = unicodedata.name(chr(self.codepoint))
        return f"{self.codepoint}\t{self.x}\t{self.y}\t{self.width}\t{self.height}\t{self.xoffset}\t{self.yoffset}\t{self.xadvance} {self.yadvance} {comment}"

parser = argparse.ArgumentParser(description="Convert font exported by https://snowb.org for Nanosaur2")
parser.add_argument('xmlpath', type=str, help="path to font.xml")
parser.add_argument('pngpath', type=str, help="path to font.png")
parser.add_argument('-o', metavar='OUTFILE', help="output path")
args = parser.parse_args()

atlas_image = Image.open(args.pngpath)

with open(args.xmlpath, "rt") as f:
    d = xmltodict.parse(f.read())

font_name = d['font']['info']['@face']
line_height = int(d['font']['common']['@lineHeight'])
xml_chars = d['font']['chars']['char']
num_chars = len(xml_chars)
xml_kernpairs = d['font']['kernings']['kerning']
num_kernpairs = len(xml_kernpairs)

glyphs = {}

for c in xml_chars:
    codepoint = int(c['@id'])
    x = int(c['@x'])
    y = int(c['@y'])
    width = int(c['@width'])
    height = int(c['@height'])
    xoffset = int(c['@xoffset'])
    yoffset = int(c['@yoffset'])
    xadvance = int(c['@xadvance'])
    yadvance = int(d['font']['common']['@lineHeight'])
    slice_image = atlas_image.crop((x, y, x+width, y+height))
    slice_hash = imagehash.phash(slice_image)
    alias_of = -1

    # Detect alias (if any)
    if codepoint > 255:
        best_diff = HASH_DIFF_BITS_THRESHOLD * 1000  # set to threshold * 1000
        alias_of = -1
        for cp, g in glyphs.items():
            if g.alias_of >= 0:
                continue
            w_diff = abs(g.width - width)
            h_diff = abs(g.height - height)
            if w_diff > 1 or h_diff > 1:
                continue
            hash_diff = (g.slice_hash - slice_hash) * 1000 + w_diff + h_diff
            if hash_diff <= best_diff:
                best_diff = hash_diff
                alias_of = cp
        if alias_of >= 0:
            print(f"Codepoint {codepoint:4} aliases {alias_of:4}  {chr(codepoint)}{chr(alias_of)}")
            x = glyphs[alias_of].x
            y = glyphs[alias_of].y
            width = glyphs[alias_of].width
            height = glyphs[alias_of].height

    glyphs[codepoint] = Glyph(codepoint=codepoint, x=x, y=y, width=width, height=height,
                              xoffset=xoffset, yoffset=yoffset, xadvance=xadvance, yadvance=yadvance,
                              slice_image=slice_image, slice_hash=slice_hash, alias_of=alias_of)

# Parse kernpairs
tuple_kernpairs = []
for c in xml_kernpairs:
    codepoint1 = int(c['@first'])
    codepoint2 = int(c['@second'])
    kernvalue = float(c['@amount'])
    tuple_kernpairs.append((codepoint1, codepoint2, kernvalue))

# ---------------------------------------
# Pack the glyphs

# Prep the packer
packer = rectpack.newPacker(rotation=False, pack_algo=rectpack.MaxRectsBl)
packer.add_bin(ATLAS_W, ATLAS_H)

for codepoint in glyphs:
    glyph = glyphs[codepoint]
    if glyph.alias_of < 0:  # only add rects for glyphs that are don't alias any other glyph (or are the master alias)
        padded_width = glyph.slice_image.width + PADDING*2
        padded_height = glyph.slice_image.height + PADDING*2
        packer.add_rect(padded_width, padded_height, codepoint)

# Pack the rects
packer.pack()
all_rects = packer.rect_list()

num_master_glyphs = sum(1 if g.alias_of < 0 else 0 for g in glyphs.values())
assert len(all_rects) == num_master_glyphs, "Not all glyphs accounted for, try increasing atlas dimensions"

# ---------------------------------------
# Recreate atlas

atlas = Image.new("RGBA", (ATLAS_W, ATLAS_H))

for rect in all_rects:
    bin_no, x, y, w, h, codepoint = rect
    assert bin_no == 0, "Not enough bins!!"

    glyph = glyphs[codepoint]

    if w != 0 and h != 0:
        x += PADDING
        y += PADDING
        w -= 2*PADDING
        h -= 2*PADDING
        atlas.paste(glyph.slice_image, (x, y))

    glyph.x = x
    glyph.y = y
    glyph.width = w
    glyph.height = h

    for g in glyphs.values():
        if g.alias_of == codepoint:
            g.x = x
            g.y = y
            g.width = w
            g.height = h

atlas_text = f"{num_chars} {line_height} {font_name}\n"
for glyph in glyphs.values():
    atlas_text += str(glyph) + "\n"
atlas_text += f"{num_kernpairs}\n"
for c in sorted(tuple_kernpairs):
    atlas_text += f"{c[0]} {c[1]} {c[2]}\n"

atlas.save(f"{args.o}.png")
open(f"{args.o}.txt", "wt").write(atlas_text)
