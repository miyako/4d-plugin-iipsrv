#!/bin/bash
# Builds the static libraries the Xcode project links from a/, as universal
# (arm64 + x86_64) archives, from pinned official source releases:
#   libjpeg 9c       -> libjpeg.a     (= include/jpeglib.h, JPEG_LIB_VERSION 90 / 9.3)
#   libtiff 4.0.9    -> libtiff.a     (= include/tiffvers.h; JPEG off, ZIP on, as in include/tiffconf.h)
#   openjpeg 2.3.0   -> libopenjp2.a  (= include/openjpeg.h, include/opj_config.h)
#   libjson 7.6.1    -> libjson.a     (compiled with the committed include/libjson headers
#                                      and JSONOptions.h, so the options match the plugin)
# zlib comes from the SDK (libz.tbd), so it is not built here.
#
# The committed headers in include/ are shared with the Windows build and are
# not modified; they differ from upstream only by small local edits
# (jmorecfg.h INT32 typedef, tiff.h MSVC uint64, libjson deprecated decl).
#
# usage: scripts/build-macos-deps.sh [output-dir]   (default: a/)
# WORK (default build/deps) holds downloads and per-arch builds; a rerun reuses them.
# Needs: Xcode command line tools, curl, cmake.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/a}"
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT" ;; esac
WORK="${WORK:-$ROOT/build/deps}"
MIN="${MACOSX_DEPLOYMENT_TARGET:-11.5}"
JOBS="$(sysctl -n hw.ncpu)"
ARCHS="arm64 x86_64"

JPEG_URL=https://www.ijg.org/files/jpegsrc.v9c.tar.gz
JPEG_SHA=682aee469c3ca857c4c38c37a6edadbfca4b04d42e56613b11590ec6aa4a278d
TIFF_URL=https://download.osgeo.org/libtiff/tiff-4.0.9.tar.gz
TIFF_SHA=6e7bdeec2c310734e734d19aae3a71ebe37a4d842e0e23dbb1b8921c0026cfcd
OPJ_URL=https://github.com/uclouvain/openjpeg/archive/refs/tags/v2.3.0.tar.gz
OPJ_SHA=3dc787c1bb6023ba846c2a0d9b1f6e179f1cd255172bde9eb75b01f1e6c7d71a
JSON_URL=https://downloads.sourceforge.net/project/libjson/libjson_7.6.1.zip
JSON_SHA=07267a3951038ee2e02d26cc41bf8e275668c38f751240d3e78dc979182e7376

# keep Homebrew headers and libraries out of the build
unset CPATH LIBRARY_PATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH PKG_CONFIG_PATH || true
export PKG_CONFIG_LIBDIR=/nonexistent
export MACOSX_DEPLOYMENT_TARGET="$MIN"

mkdir -p "$WORK/dl" "$OUT"

# fetch <url> <sha256> <file>: download with retries, verify the checksum
fetch() {
  local f="$WORK/dl/$3" i
  if [ -f "$f" ] && echo "$2  $f" | shasum -a 256 -c - >/dev/null 2>&1; then
    return 0
  fi
  for i in 1 2 3; do
    curl -fsSL --retry 3 -o "$f.tmp" "$1" && break
    [ "$i" = 3 ] && { echo "::error::download failed: $1"; return 1; }
    echo "download $1 failed, retrying"; sleep 10
  done
  echo "$2  $f.tmp" | shasum -a 256 -c - || { echo "::error::checksum mismatch: $1"; rm -f "$f.tmp"; return 1; }
  mv "$f.tmp" "$f"
}

# unpack <archive> <dest dir>: fresh extraction into dest
unpack() {
  rm -rf "${2:?}"; mkdir -p "$2"
  case "$1" in
    *.zip) (cd "$2" && unzip -q "$WORK/dl/$1") ;;
    *) tar -xzf "$WORK/dl/$1" -C "$2" --strip-components 1 ;;
  esac
}

host_for() { case "$1" in arm64) echo aarch64-apple-darwin ;; x86_64) echo x86_64-apple-darwin ;; esac; }

fetch "$JPEG_URL" "$JPEG_SHA" jpegsrc.v9c.tar.gz
fetch "$TIFF_URL" "$TIFF_SHA" tiff-4.0.9.tar.gz
fetch "$OPJ_URL"  "$OPJ_SHA"  openjpeg-2.3.0.tar.gz
fetch "$JSON_URL" "$JSON_SHA" libjson_7.6.1.zip

# autotools projects: one build per arch, then lipo (ar can't archive fat objects)
for A in $ARCHS; do
  P="$WORK/$A/prefix"
  FLAGS="-arch $A -mmacosx-version-min=$MIN -O2"

  if [ ! -f "$P/lib/libjpeg.a" ]; then
    echo "::group::libjpeg $A"
    S="$WORK/$A/jpeg"; unpack jpegsrc.v9c.tar.gz "$S"
    (cd "$S" && ./configure --prefix="$P" --host="$(host_for "$A")" \
        --enable-static --disable-shared \
        CC=clang CFLAGS="$FLAGS" LDFLAGS="-arch $A -mmacosx-version-min=$MIN" \
      && make -j"$JOBS" && make install)
    echo "::endgroup::"
  fi

  if [ ! -f "$P/lib/libtiff.a" ]; then
    echo "::group::libtiff $A"
    S="$WORK/$A/tiff"; unpack tiff-4.0.9.tar.gz "$S"
    # tiff 4.0.9's config.sub predates aarch64-apple-darwin; jpeg 9c ships a newer pair
    J="$WORK/$A/jpeg-cfg"; unpack jpegsrc.v9c.tar.gz "$J"
    cp "$J/config.sub" "$J/config.guess" "$S/config/"
    # same codec set as the committed include/tiffconf.h: no JPEG/OJPEG/JBIG/LZMA,
    # ZIP + PixarLog through the SDK's zlib
    # configure only knows x86 as LSB-first; arm64 is little-endian too, and the
    # committed tiffconf.h says LSB2MSB, so pin HOST_FILLORDER after configure
    (cd "$S" && ./configure --prefix="$P" --host="$(host_for "$A")" \
        --enable-static --disable-shared --disable-cxx \
        --disable-jpeg --disable-old-jpeg --disable-jbig --disable-lzma \
        --enable-zlib --enable-pixarlog --without-x \
        CC=clang CFLAGS="$FLAGS" LDFLAGS="-arch $A -mmacosx-version-min=$MIN" \
      && sed -i "" -e "s/^#define HOST_FILLORDER FILLORDER_MSB2LSB/#define HOST_FILLORDER FILLORDER_LSB2MSB/" libtiff/tiffconf.h libtiff/tif_config.h \
      && make -C port -j"$JOBS" && make -C libtiff -j"$JOBS" && make -C libtiff install)
    echo "::endgroup::"
  fi
done

lipo -create "$WORK"/arm64/prefix/lib/libjpeg.a "$WORK"/x86_64/prefix/lib/libjpeg.a -output "$OUT/libjpeg.a"
lipo -create "$WORK"/arm64/prefix/lib/libtiff.a "$WORK"/x86_64/prefix/lib/libtiff.a -output "$OUT/libtiff.a"

# openjpeg: CMake builds both archs in one pass. 2.3.0 fails to generate with
# BUILD_SHARED_LIBS=OFF (install(EXPORT) of an unknown target), so build the
# openjp2_static target that the shared+static configuration adds.
if [ ! -f "$WORK/openjpeg-build/bin/libopenjp2.a" ]; then
  echo "::group::openjpeg"
  unpack openjpeg-2.3.0.tar.gz "$WORK/openjpeg"
  rm -rf "$WORK/openjpeg-build"
  cmake -S "$WORK/openjpeg" -B "$WORK/openjpeg-build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=ON \
    -DBUILD_CODEC=OFF -DBUILD_TESTING=OFF -DBUILD_DOC=OFF \
    -DBUILD_JPIP=OFF -DBUILD_JPWL=OFF -DBUILD_MJ2=OFF
  cmake --build "$WORK/openjpeg-build" -j "$JOBS" --target openjp2_static
  echo "::endgroup::"
fi
cp "$WORK/openjpeg-build/bin/libopenjp2.a" "$OUT/libopenjp2.a"

# libjson: upstream sources, with the committed headers and JSONOptions.h laid on top
if [ ! -f "$WORK/libjson-build/libjson.a" ]; then
  echo "::group::libjson"
  unpack libjson_7.6.1.zip "$WORK/libjson-src"
  J="$WORK/libjson-src/libjson"
  cp -R "$ROOT/include/libjson/." "$J/"
  # JSON_MAP spells the key "const x"; with x = void * that is "const void *", not the
  # map's "void * const", which current libc++ rejects. "x const" is the intended type.
  sed -i "" -e 's/std::pair<const x, y>/std::pair<x const, y>/' "$J/_internal/Source/JSONDefs.h"
  grep -q 'std::pair<x const, y>' "$J/_internal/Source/JSONDefs.h"
  rm -rf "$WORK/libjson-build"; mkdir -p "$WORK/libjson-build"
  for f in "$J"/_internal/Source/*.cpp; do
    clang++ -arch arm64 -arch x86_64 -mmacosx-version-min="$MIN" -O2 -DNDEBUG -fPIC \
      -I"$J" -c "$f" -o "$WORK/libjson-build/$(basename "${f%.cpp}").o"
  done
  # Apple's libtool archives fat objects directly
  libtool -static -o "$WORK/libjson-build/libjson.a" "$WORK"/libjson-build/*.o
  echo "::endgroup::"
fi
cp "$WORK/libjson-build/libjson.a" "$OUT/libjson.a"

# every output must carry both slices
for L in libjpeg libtiff libopenjp2 libjson; do
  for A in $ARCHS; do
    lipo "$OUT/$L.a" -verify_arch "$A" || { echo "::error::$L.a lacks $A"; exit 1; }
  done
  echo "$L.a: $(lipo -archs "$OUT/$L.a")"
done
