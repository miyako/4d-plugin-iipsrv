#!/bin/bash
# Builds the iipsrv synthetic-boundary ownership harness against a source tree
# with ASan/UBSan and runs every test in its own process (macOS only).
#
#   tests/ownership/run.sh <source-root> <fixed|baseline>
#
# <source-root> provides the plugin sources and the bundled 4D Plugin API.
# The harness itself always comes from this script's directory, so the SAME
# harness can be run against an immutable baseline (git archive of the base
# SHA) and against the fixed tree.
#
# In "fixed" mode every test must pass. In "baseline" mode the tests named
# in EXPECTED_BASELINE_FAILURES must fail and every other test (the
# controls) must pass; anything else is a harness or model error.
#
# The third-party static libraries (libtiff, libjpeg, openjpeg, libjson) are
# not in the repository; their C entry points are replaced by generated
# stubs that abort if called. No test decodes or encodes an image.
set -euo pipefail

SRC=$(cd "$1" && pwd)
MODE=$2
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

EXPECTED_BASELINE_FAILURES="
defect_picture_fromfile_ownership
defect_picture_setbytes_leak
defect_picture_createcopy_ownership
defect_picture_grayscale_owner_leak
defect_picture_getsize_owner_leak
defect_picture_thumbnail_owner_leak
"

SAN="-g -O1 -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=undefined"
API="$SRC/4D Plugin API"
# Same prefix header and search paths as the Xcode target.
INC=(-include "$SRC/4D Plugin_Prefix.pch" -I "$API" -I "$API/Classes" -I "$SRC" -I "$SRC/include"
     -I "$SRC/include/libjson" -I "$SRC/iipsrv"
     -DHAVE_SYS_TIME_H -DCHUNKED -DHAVE_ISFINITE -DOPJ_STATIC)
CXX=(-x objective-c++ -std=c++17 -fno-objc-arc)

objs=()
cc() { # <file>
    local o="$OUT/$(basename "$1").o"
    xcrun clang $SAN -w "${CXX[@]}" "${INC[@]}" -c "$1" -o "$o"
    objs+=("$o")
}

cc "$API/4DPluginAPI.c"
for f in "$API"/Classes/*.cpp; do cc "$f"; done
cc "$SRC/4DPlugin.cpp"
# iipsrv sources in the Xcode target's Sources phase.
for f in CVT DSOImage DeepZoom FIF ICC IIIF IIPImage IIPResponse JPEGCompressor JTL OBJ \
         OpenJPEGImage PFL SPECTRA TIL TPTImage Task TileManager Transforms View Watermark Zoomify; do
    cc "$SRC/iipsrv/$f.cc"
done
cc "$SRC/include/libjson_methods.cpp"
cc "$HERE/engine_harness.mm"

FW=(-framework Foundation -framework CoreFoundation -framework Carbon -framework Cocoa)
link() { xcrun clang++ $SAN "${objs[@]}" "$@" "${FW[@]}" -o "$OUT/harness"; }

# Generate aborting stubs for the unresolved third-party C symbols.
if ! link 2>"$OUT/link.log"; then
    syms=$(grep -oE '"_(_?TIFF|jpeg_|opj_|json_)[A-Za-z0-9_]*"' "$OUT/link.log" | tr -d '"' | sed 's/^_//' | sort -u)
    [ -n "$syms" ] || { cat "$OUT/link.log"; exit 1; }
    {
        echo '#include <cstdio>'; echo '#include <cstdlib>'
        for s in $syms; do
            echo "extern \"C\" void $s(void) { fprintf(stderr, \"THIRD-PARTY STUB CALLED: $s\\n\"); abort(); }"
        done
    } >"$OUT/thirdparty_stubs.cpp"
    xcrun clang++ -w -c "$OUT/thirdparty_stubs.cpp" -o "$OUT/thirdparty_stubs.o"
    objs+=("$OUT/thirdparty_stubs.o")
    link
fi

export ASAN_OPTIONS=abort_on_error=0:halt_on_error=1
export UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1

bad=0
for t in $("$OUT/harness" --list); do
    if "$OUT/harness" "$t" >"$OUT/$t.log" 2>&1; then got=pass; else got=fail; fi
    expect=pass
    if [ "$MODE" = baseline ] && grep -qx "$t" <<<"$EXPECTED_BASELINE_FAILURES"; then expect=fail; fi
    if [ "$got" = "$expect" ]; then status=OK; else status=UNEXPECTED; bad=1; fi
    printf '%-12s %-5s (expected %-4s) %s\n' "$status" "$got" "$expect" "$t"
    if [ "$got" = fail ]; then sed 's/^/    | /' "$OUT/$t.log" | head -40; fi
    # A sanitizer report, engine violation or third-party call is only
    # acceptable as a named baseline failure.
    if [ "$expect" = pass ] && grep -qE 'ERROR: AddressSanitizer|runtime error:|ENGINE VIOLATION|THIRD-PARTY STUB' "$OUT/$t.log"; then
        echo "UNEXPECTED   sanitizer/engine violation in $t"; bad=1
    fi
done

if [ $bad -ne 0 ]; then echo "RESULT ($MODE): FAILED"; exit 1; fi
echo "RESULT ($MODE): all outcomes as expected"
