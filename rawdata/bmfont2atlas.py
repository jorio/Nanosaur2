# Convert font exported by https://snowb.org to my atlas format for the pangea ports.
# INSTRUCTIONS:
# - Go to https://snowb.org and create a font
# - Click "Export" and set "Export Type" to "BMFont (XML)"
# - python3 rawdata/bmfont2atlas.py font.xml

import os, sys, xmltodict, unicodedata

path = sys.argv[1]

with open(path, "rt") as f:
    d = xmltodict.parse(f.read())

font_name = d['font']['info']['@face']
line_height = int(d['font']['common']['@lineHeight'])
xml_chars = d['font']['chars']['char']
num_chars = len(xml_chars)
xml_kernpairs = d['font']['kernings']['kerning']
num_kernpairs = len(xml_kernpairs)

print(f"{num_chars} {line_height} {font_name}")

for c in xml_chars:
    codepoint = int(c['@id'])
    x = c['@x']
    y = c['@y']
    width = c['@width']
    height = c['@height']
    xoffset = c['@xoffset']
    yoffset = c['@yoffset']
    xadvance = c['@xadvance']
    yadvance = d['font']['common']['@lineHeight']
    comment = unicodedata.name(chr(codepoint))
    print(f"{codepoint}\t{x}\t{y}\t{width}\t{height}\t{xoffset}\t{yoffset}\t{xadvance} {yadvance} {comment}")

print(f"{num_kernpairs}")

tuple_kernpairs = []
for c in xml_kernpairs:
    codepoint1 = int(c['@first'])
    codepoint2 = int(c['@second'])
    kernvalue = float(c['@amount'])
    tuple_kernpairs.append((codepoint1, codepoint2, kernvalue))

for c in sorted(tuple_kernpairs):
    print(f"{c[0]} {c[1]} {c[2]}")
