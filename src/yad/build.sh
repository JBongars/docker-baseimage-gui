#!/bin/sh
#
# Helper script that builds yad as a static binary.
#
# NOTE: This script is expected to be run under Alpine Linux.
#

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

# Define software versions.
YAD_VERSION=0.42.42
PANGO_VERSION=1.49.3
GTK_VERSION=2.24.33
ATK_VERSION=2.36.0
GDKPIXBUF_VERSION=2.42.6

# Define software download URLs.
YAD_URL=https://github.com/step-/yad/archive/refs/tags/${YAD_VERSION}.tar.gz
PANGO_URL=https://download.gnome.org/sources/pango/${PANGO_VERSION%.*}/pango-${PANGO_VERSION}.tar.xz
GTK_URL=https://download.gnome.org/sources/gtk+/${GTK_VERSION%.*}/gtk%2B-${GTK_VERSION}.tar.xz
ATK_URL=https://download.gnome.org/sources/atk/${ATK_VERSION%.*}/atk-${ATK_VERSION}.tar.xz
GDKPIXBUF_URL=https://download.gnome.org/sources/gdk-pixbuf/${GDKPIXBUF_VERSION%.*}/gdk-pixbuf-${GDKPIXBUF_VERSION}.tar.xz

# Set same default compilation flags as abuild.
export CFLAGS="-Os -fomit-frame-pointer"
export CXXFLAGS="$CFLAGS"
export CPPFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--as-needed"

export CC=xx-clang
export CXX=xx-clang++

function log {
    echo ">>> $*"
}

log "Installing required Alpine packages..."
apk --no-cache add \
    curl \
    build-base \
    clang \
    meson \
    autoconf \
    automake \
    intltool \
    pkgconfig \
    glib-dev \
    gtk-update-icon-cache \

xx-apk --no-cache --no-scripts add \
    g++ \
    glib-dev \
    glib-static \
    util-linux-dev \
    brotli-static \
    gettext-static \
    pcre-dev \
    expat-static \
    libffi-dev \
    zlib-static \
    bzip2-static \
    graphite2-static \
    pixman-static \
    libpng-static \
    libx11-static \
    libxcb-static \
    libxdmcp-dev \
    libxau-dev \
    libxrender-dev \
    fribidi-dev \
    fribidi-static \
    harfbuzz-dev \
    harfbuzz-static \
    fontconfig-dev \
    fontconfig-static \
    freetype-static \
    cairo-dev \
    cairo-static \

echo "[binaries]
pkgconfig = '$(xx-info)-pkg-config'

[properties]
sys_root = '$(xx-info sysroot)'
pkg_config_libdir = '$(xx-info sysroot)/usr/lib/pkgconfig'

[host_machine]
system = 'linux'
cpu_family = '$(xx-info arch)'
cpu = '$(xx-info arch)'
endian = 'little'
" > /tmp/meson-cross.txt

#
# Build pango
# The static library is not provided by Alpine repository, so we need to build
# it ourself.
#
mkdir /tmp/pango
log "Downloading pango..."
curl -# -L ${PANGO_URL} | tar -xJ --strip 1 -C /tmp/pango
log "Configuring pango..."
(
    cd /tmp/pango && abuild-meson \
        -Ddefault_library=static \
        -Dintrospection=disabled \
        -Dgtk_doc=false \
        --cross-file /tmp/meson-cross.txt \
        build \
)
log "Compiling pango..."
meson compile -C /tmp/pango/build
log "Installing pango..."
DESTDIR=$(xx-info sysroot) meson install --no-rebuild -C /tmp/pango/build

#
# Build atk.
# The static library is not provided by Alpine repository, so we need to build
# it ourself.
#
mkdir /tmp/atk
log "Downloading atk..."
curl -# -L ${ATK_URL} | tar -xJ --strip 1 -C /tmp/atk
log "Configuring atk..."
(
    cd /tmp/atk && abuild-meson \
        -Ddefault_library=static \
        -Dintrospection=false \
        -Ddocs=false \
        --cross-file /tmp/meson-cross.txt \
        build \
)
log "Compiling atk..."
meson compile -C /tmp/atk/build
log "Installing atk..."
DESTDIR=$(xx-info sysroot) meson install --no-rebuild -C /tmp/atk/build

#
# Build GdkPixbuf.
# The static library is not provided by Alpine repository, so we need to build
# it ourself.
#
mkdir /tmp/gdkpixbuf
log "Downloading GdkPixbuf..."
curl -# -L ${GDKPIXBUF_URL} | tar -xJ --strip 1 -C /tmp/gdkpixbuf
log "Configuring GdkPixbuf..."
(
    cd /tmp/gdkpixbuf && abuild-meson \
        -Ddefault_library=static \
        -Dpng=true \
        -Dtiff=false \
        -Djpeg=false \
        -Dbuiltin_loaders=png \
        -Dgtk_doc=false \
        -Ddocs=false \
        -Dintrospection=disabled \
        -Dman=false \
        -Drelocatable=false \
        -Dnative_windows_loaders=false \
        -Dinstalled_tests=false \
        -Dgio_sniffing=false \
        --cross-file /tmp/meson-cross.txt \
        build \
)
log "Compiling GdkPixbuf..."
meson compile -C /tmp/gdkpixbuf/build
log "Installing GdkPixbuf..."
DESTDIR=$(xx-info sysroot) meson install --no-rebuild -C /tmp/gdkpixbuf/build

#
# Build GTK.
# The static library is not provided by Alpine repository, so we need to build
# it ourself.
#
mkdir /tmp/gtk
log "Downloading GTK..."
curl -# -L ${GTK_URL} | tar -xJ --strip 1 -C /tmp/gtk
log "Configuring GTK..."
(
    cd /tmp/gtk && ./configure \
        --build=$(TARGETPLATFORM= xx-clang --print-target-triple) \
        --host=$(xx-clang --print-target-triple) \
        --prefix=/usr \
        --enable-static \
        --disable-shared \
        --enable-debug=no \
        --disable-xinerama \
        --disable-glibtest \
        --disable-modules \
        --disable-cups \
        --disable-papi \
        --enable-introspection=no \
        --disable-gtk-doc \
        --disable-gtk-doc-html \
        --disable-gtk-doc-pdf \
        --disable-man \
        --with-gdktarget=x11 \
        --with-xinput=no \
)
log "Compiling GTK..."
sed 's/^SRC_SUBDIRS = gdk gtk modules demos tests perf/SRC_SUBDIRS = gdk gtk/' -i /tmp/gtk/Makefile
make -C /tmp/gtk -j$(nproc)
log "Installing GTK..."
make DESTDIR=$(xx-info sysroot) -C /tmp/gtk install

#
# Build YAD.
#
mkdir /tmp/yad
log "Downloading YAD..."
curl -# -L ${YAD_URL} | tar xz --strip 1 -C /tmp/yad
log "Configuring YAD..."
export LDFLAGS="$LDFLAGS --static -static -Wl,--strip-all" && \
(
    cd /tmp/yad && autoreconf -ivf && intltoolize && LIBS="-Wl,--start-group -lX11 -lxcb -lXdmcp -lXau -lpcre -lpixman-1 -lffi -lpng -lz -lbz2 -lgraphite2 -lexpat -lXrender -luuid -lbrotlidec -lbrotlicommon -lmount -lblkid -lfreetype -Wl,--end-group" ./configure \
        --build=$(TARGETPLATFORM= xx-clang --print-target-triple) \
        --host=$(xx-clang --print-target-triple) \
        --prefix=/usr \
	--disable-spell \
	--disable-sourceview \
        --disable-gio \
        --disable-icon-browser \
        --disable-html \
        --disable-pfd \
)
log "Compiling YAD..."
make -C /tmp/yad -j$(nproc)
log "Installing YAD..."
make DESTDIR=/tmp/yad-install -C /tmp/yad install