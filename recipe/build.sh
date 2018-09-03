#!/bin/bash

set -e

# Adopt a Unix-friendly path if we're on Windows (see bld.bat).
[ -n "$PATH_OVERRIDE" ] && export PATH="$PATH_OVERRIDE"

# On Windows we want $LIBRARY_PREFIX in both "mixed" (C:/Conda/...) and Unix
# (/c/Conda) forms, but Unix form is often "/" which can cause problems.
if [ -n "$LIBRARY_PREFIX_M" ] ; then
    mprefix="$LIBRARY_PREFIX_M"
    if [ "$LIBRARY_PREFIX_U" = / ] ; then
        uprefix=""
    else
        uprefix="$LIBRARY_PREFIX_U"
    fi
else
    mprefix="$PREFIX"
    uprefix="$PREFIX"
fi

# Cf. https://github.com/conda-forge/staged-recipes/issues/673, we're in the
# process of excising Libtool files from our packages. Existing ones can break
# the build while this happens. We have "/." at the end of $uprefix to be safe
# in case the variable is empty.
find $uprefix/ -name '*.la' -delete

sed -i.orig s:'@PREFIX@':"${uprefix}":g src/fccfg.c

# So that -Wl,--as-needed works (sorted to appear before before libs) and
# that we work at all on Windows.

autoreconf_args="-vfi"
if [ -n "$CYGWIN_PREFIX" ] ; then
    export ACLOCAL=aclocal-1.15 AUTOMAKE=automake-1.15
    autoreconf_args="$autoreconf_args -I $mprefix/share/aclocal -I $BUILD_PREFIX_M/Library/mingw-w64/share/aclocal"
    sed -i.orig "s/0.19.8/0.19.7/" configure.ac # hack (note: lazy about meaning of periods in regexes here)
    (cd / && mkdir -p mingw64/share/gettext && cp -r mingw-w64/share/gettext/* mingw64/share/gettext/)

    export FREETYPE_CFLAGS="-I$mprefix/include" FREETYPE_LIBS="-L$mprefix/bin -L$mprefix/lib -lfreetype"
    export LIBXML2_CFLAGS="-I$mprefix/include" LIBXML2_LIBS="-L$mprefix/bin -L$mprefix/lib -lxml2"
fi
autoreconf $autoreconf_args

configure_args=(
    --prefix="$mprefix"
    --enable-libxml2
    --enable-static
    --disable-docs
)

# See:
# https://github.com/Homebrew/homebrew-core/blob/master/Formula/fontconfig.rb
# https://bugs.freedesktop.org/show_bug.cgi?id=105366
if [[ ${target_platform} == osx-64 ]]; then
  export UUID_CFLAGS=" "
  export UUID_LIBS=" "
  sed -i -e 's|PKGCONFIG_REQUIRES_PRIVATELY=\"\$PKGCONFIG_REQUIRES_PRIVATELY uuid\"||g' configure
  configure_args+=(
      --with-add-fonts="$uprefix"/fonts,/System/Library/Fonts,/Library/Fonts,~/Library/Fonts,/System/Library/Assets/com_apple_MobileAsset_Font3,/System/Library/Assets/com_apple_MobileAsset_Font4
  )
elif [ -n "$CYGWIN_PREFIX" ] ; then
  export PKG_CONFIG_LIBDIR=$uprefix/lib/pkgconfig:$uprefix/share/pkgconfig
  configure_args+=(
      --disable-shared
  )
else
  configure_args+=(
      --with-add-fonts="$uprefix"/fonts
  )
fi


./configure "${configure_args[@]}"

make -j${CPU_COUNT} ${VERBOSE_AT}
make check ${VERBOSE_AT}
make install

# Remove any new Libtool files we may have installed. It is intended that
# conda-build will eventually do this automatically.
find $uprefix/. -name '*.la' -delete

# Remove computed cache with local fonts
rm -Rf "$uprefix"/var/cache/fontconfig

# Leave cache directory, in case it's needed
mkdir -p "$uprefix"/var/cache/fontconfig
touch "$uprefix"/var/cache/fontconfig/.leave

# We can remove this when we start using the new conda-build.
find $PREFIX -name '*.la' -delete
