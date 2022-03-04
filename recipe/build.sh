#!/bin/bash

set -xeo pipefail

# For the Linux builds, get our prefix into the shared library
sed -i.orig s:'@PREFIX@':"$PREFIX":g src/fccfg.c

meson setup builddir \
    --default-library=both \
    --buildtype=release \
    --prefix=$PREFIX \
    -Dlibdir=lib \
    --wrap-mode=nofallback

ninja -v -C builddir -j ${CPU_COUNT}

if [[ "$CONDA_BUILD_CROSS_COMPILATION" != "1" ]]; then
    ninja -C builddir test -j ${CPU_COUNT}
fi

ninja -C builddir install -j ${CPU_COUNT}

# Clear out the local cache but make sure the directory is packaged.
rm -Rf "$PREFIX"/var/cache/fontconfig
mkdir -p "$PREFIX"/var/cache/fontconfig
touch "$PREFIX"/var/cache/fontconfig/.leave
