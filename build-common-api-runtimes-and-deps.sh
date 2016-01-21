#!/bin/bash
# (C) Gunnar Andersson 2016
# License: CC0

# TIP: Also refer to go.genivi.org for pipelines performing these builds

# Building Common API C++ runtimes and (some) dependencies from source.
# Not all deps are built from source - there are lower deps that need to be
# installed on the build machine.  In a Yocto environment you would make sure
# these deps are built anyhow.

# Input "sleep 1" or whatever you like as first argument
DELAYCMD="$1"

# Fail on unset variables
set -u

e() {
  "$@"
  $DELAYCMD  # Delay or wait between steps
}


# Base directory
D=$(dirname "$0")
cd "$D"
MYDIR="$PWD"

# Allowing failures here, the normal failure is it's already cloned
# Of course we could check for that but lazy.
set -x
git clone --recursive https://github.com/boostorg/boost.git
git clone http://git.projects.genivi.org/ipc/common-api-runtime.git
git clone http://git.projects.genivi.org/ipc/common-api-dbus-runtime.git
git clone http://git.projects.genivi.org/common-api/cpp-someip-runtime.git
git clone http://git.projects.genivi.org/vSomeIP.git
git clone http://git.projects.genivi.org/dlt-daemon.git
git clone https://github.com/doxygen/doxygen.git
git clone http://anongit.freedesktop.org/git/dbus/dbus.git

# Stop script on first failure
set -e

# --- DOXYGEN ---
# MISSING: dot (graphviz), asciidoc
# Dependencies:
# * NOTE: Need bison and flex installed (not built from source here)
e cd "$MYDIR"
e cd doxygen
e mkdir -p build
e cd build
e cmake -G "Unix Makefiles" -D CMAKE_INSTALL_PREFIX=$PWD/../P/ ..
e make -j8
e make install


# --- DLT DAEMON ---
# Dependencies: Not much that I know.  maybe zlib or something simple
e cd "$MYDIR"
e cd dlt-daemon
e mkdir -p build
e export DLT_PKG_CONFIG_PATH=$PWD/P/lib/$(uname -m)-linux-gnu/pkgconfig
e cd build
e cmake -D CMAKE_INSTALL_PREFIX=$PWD/../P/ .. 
e make -j8
e make install  # Need to install pkg-config files for later use

# Ugly-patch the dlt/dlt.h bug which occurs due to a buggy pkg-config file
# in combination with usage.

# Either the pkg-config should define the PREFIX only in include path, and the C
# programs should include <dlt/dlt.h> *OR* the pkg-config should make $PREFIX/dlt
# part of the include path and the C programes include simply <dlt.h>

# Currently it is the combination of both which does not work.
# C programs also prefix their include like this: #include <dlt/dlt.h>
# - the compiler can only try to match this to:
#  <PREFIX>/include/dlt/dlt/dlt.h which obviously does not exist.
#
# The reason this bug is not seen on a non-prefix install is that /usr/include
# is already in the include search path by default, thus when everything is
# installed there <dlt/dlt.h> resolves to /usr/include/dlt/dlt.h.   This
# however does not happen if a custom PREFIX is used for installation.

sed -i 's#${includedir}/dlt#${includedir}#' $DLT_PKG_CONFIG_PATH/automotive-dlt.pc

# and libdir also needs fixing.  In this native build libs seem to be installed
# under ${exec_prefix}/x86_64-linux-gnu/lib, not only ${exec_prefix}/lib !?

# Trying uname to get machine name prefix (x86_64), who knows if this make it
# more portable maybe:
correct_libdir="$\{exec_prefix\}/lib/$(uname -m)-linux-gnu"

# Patch definition of libdir in DLT pkg_ config file
sed -i "s#libdir=\${exec_prefix}/lib#libdir=$correct_libdir#" $DLT_PKG_CONFIG_PATH/automotive-dlt.pc

# --- Common API C++ Runtime ---
# Dependencies:
# - OPTIONAL: Doxygen needed for documentation (built from source above)
# - OPTIONAL: DLT (built from source above)
e cd "$MYDIR"
e cd common-api-runtime
e mkdir -p build
e export PKG_CONFIG_PATH=$DLT_PKG_CONFIG_PATH  # so cmake can find DLT
e export PATH=$PATH:$PWD/../doxygen/P/bin/
e cd build
e grep cmake ../INSTALL | sed 's@^\$@@' | sh 
e make -j8
# No make install, we use the binaries directly from the build directory

# --- libdbus with CommonAPI C++ patch ---
# Dependencies:
# - autoconf (not built from source here)
# - libtool  (not built from source here)
# - expat    (libexpat-dev, not built from source here)
# TODO
e cd "$MYDIR"
e cd dbus
e git checkout dbus-1.9.0
e git reset --hard  # <- reapply patches successfully if script is rerun
for f in ../common-api-dbus-runtime/src/dbus-patches/*.patch ; do
  patch -p1 -N <"$f"
done
e ./autogen.sh
e ./configure --prefix $PWD/P
e make -j8 -C dbus
e make install

# --- Common API C++ D-Bus Runtime ---
# Dependencies:
# - libdbus with special patch (built from source above)
# - Common API C++ (built from source above)
# - OPTIONAL: DLT (built from source above)
e cd "$MYDIR"
e cd common-api-dbus-runtime
e export CommonAPI_DIR=$PWD/../common-api-runtime/build
# Set $PATH to include doxygen -- done previously
e export PKG_CONFIG_PATH=$PWD/../dbus/P/lib/pkgconfig:$PWD/../dlt-daemon/P/lib/pkgconfig
e mkdir -p build
e cd build
e cmake -D USE_INSTALLED_COMMONAPI=ON ..
e make -j8
# No make install, the result is in build directory



# --- BOOST ---
# Dependencies: Not much.
e cd "$MYDIR"
e cd boost
e git checkout boost-1.58.0
e git submodule update
e ./bootstrap.sh --with-libraries=system,thread,log --prefix=$PWD/P/
e ./b2 -j8
e ./b2 headers
e ./b2 install

# --- vSomeIP ---
# Dependencies:
# - OPTIONAL: Doxygen needed for documentation (built from source above)
# - Boost (built from source above
# NOT DLT?  (Uses boost logging?)
e cd "$MYDIR"
e cd vSomeIP
e mkdir -p build
e export BOOST_ROOT=$PWD/../boost/P/
# Set $PATH to include doxygen -- done previously
e cd build
e cmake ..
e make -j8
# No make install, we use the binaries directly from the build directory

# --- Common API C++ Some-IP Runtime ---
# Dependencies:
# - vSomeIP (built from source above)
# - Boost (built from source above
# - Common API C++ (built from source above)
# NOT DLT?  (Uses boost logging?)
e cd "$MYDIR"
e cd cpp-someip-runtime
e mkdir -p build
e export BOOST_ROOT=$PWD/../boost/P/
e export CommonAPI_DIR=$PWD/../common-api-runtime/build
e cd build
e grep cmake ../INSTALL | sed 's@^\$@@' | sh 
e make -j8
# No make install, the result is in build directory


