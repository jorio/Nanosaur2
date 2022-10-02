#!/bin/bash
# Run this from nano2's root directory

set -e

SRCDIR=rawdata
OUTDIR=Data/Sprites
MKATLAS="python3 $SRCDIR/mkatlas.py"

$MKATLAS $SRCDIR/font           -o ${OUTDIR}/font           -a 512x512 --font --y-offset -6
