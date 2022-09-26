import sys, os, struct, io
from PIL import Image

def funpack(file, format):
    length = struct.calcsize(format)
    blob = file.read(length)
    return struct.unpack(format, blob)

COMBINE = True
inpath = sys.argv[1]
outpath = sys.argv[2]

filesize = os.path.getsize(inpath)
basename = os.path.splitext(os.path.basename(inpath))[0]
print(basename)

with open(inpath, 'rb') as file:
    numsprites = funpack(file, ">L")[0]
    assert numsprites <= 65535, ("This looks like a little-endian sprite file, probably from the iOS version. "
        "This script does not support sprite files from the iOS version.")

    for i in range(numsprites):
        width, height, aspect, hasalpha, datasize, jpegoffset = funpack(file, ">iifiii")

        print(F"sprite {i}:\tAR={aspect}\t{width}x{height} alpha={hasalpha} bytes={datasize}")
        assert aspect == height / width, "weird aspect ratio!"

        file.read(jpegoffset-4)
        jpegdata = file.read(datasize-jpegoffset)
        colorimage = Image.open(io.BytesIO(jpegdata))

        maskdata = None
        maskimage = None
        if hasalpha != 0:
            maskdata = file.read(width*height)
            maskimage = Image.frombytes('L', (width,height), maskdata)

        os.makedirs(outpath, exist_ok=True)
        if not COMBINE:
            open(os.path.join(outpath, F"{basename}{i:03}_color.jpg"), "wb").write(jpegdata)
            if maskimage:
                maskimage.save(os.path.join(outpath, F"{basename}{i:03}_mask.png"))
        else:
            if hasalpha:
                colorimage.putalpha(maskimage)
            colorimage = colorimage.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            colorimage.save(os.path.join(outpath, F"{basename}{i:03}.png"))
