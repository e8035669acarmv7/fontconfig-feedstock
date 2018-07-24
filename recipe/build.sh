#!/bin/bash

sed -i.orig s:'@PREFIX@':"${PREFIX}":g src/fccfg.c

# Cf. https://github.com/conda-forge/staged-recipes/issues/673, we're in the
# process of excising Libtool files from our packages. Existing ones can break
# the build while this happens.
find $PREFIX -name '*.la' -delete

autoreconf -f -i

./configure --prefix "${PREFIX}" \
	    --enable-libxml2 \
	    --enable-static \
	    --disable-docs \
      --with-add-fonts=${PREFIX}/fonts

make -j${CPU_COUNT}
make check
make install

# Remove any new Libtool files we may have installed. It is intended that
# conda-build will eventually do this automatically.
find $PREFIX -name '*.la' -delete

# Remove computed cache with local fonts
rm -Rf "${PREFIX}/var/cache/fontconfig"

# Leave cache directory, in case it's needed
mkdir -p "${PREFIX}/var/cache/fontconfig"
touch "${PREFIX}/var/cache/fontconfig/.leave"
