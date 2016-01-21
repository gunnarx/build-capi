#!/bin/bash

# Stop script on first failure
set -e
# Fail on unset variables
set -u

e() {
  "$@"
  $DELAYCMD
}

# Input "sleep 1" or whatever you like as first argument
DELAYCMD="$1"

# Base directory
D=$(dirname "$0")
cd "$D"
MYDIR="$PWD"

set -x
git clone --recursive https://github.com/boostorg/boost.git
git clone http://git.projects.genivi.org/common-api/cpp-someip-runtime.git
git clone http://git.projects.genivi.org/ipc/common-api-runtime.git
git clone http://git.projects.genivi.org/vSomeIP.git
git clone http://git.projects.genivi.org/dlt-daemon.git
git clone https://github.com/doxygen/doxygen.git

e cd "$MYDIR"
e cd doxygen
e mkdir -p build
e cd build
e cmake -G "Unix Makefiles" -D CMAKE_INSTALL_PREFIX=$PWD/../P/ ..
e make -j8
# No need to install - we will make sure the binary is in $PATH

e cd "$MYDIR"
e cd dlt-daemon
e mkdir -p build
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

sed -i 's#${includedir}/dlt#${includedir}#' $PKG_CONFIG_PATH/automotive-dlt.pc

# and libdir also needs fixing.  In this native build libs seem to be installed
# under ${exec_prefix}/x86_64-linux-gnu/lib, not only ${exec_prefix}/lib ?

# Trying uname to get machine name prefix (x86_64), who knows if this make it
# more portable maybe:
correct_libdir="$\{exec_prefix\}/lib/$(uname -m)-linux-gnu"

# Patch definition of libdir in DLT pkg_ config file
sed -i "s#libdir=\${exec_prefix}/lib#libdir=$correct_libdir#" $PKG_CONFIG_PATH/automotive-dlt.pc

e cd "$MYDIR"
e cd common-api-runtime
e mkdir -p build
e export PKG_CONFIG_PATH=$PWD/../dlt-daemon/P/lib/$(uname -m)-linux-gnu/pkgconfig
e export PATH=$PATH:$PWD/../doxygen/P/bin/
e cd build
e grep cmake ../INSTALL | sed 's@^\$@@' | sh 
e make -j8
# No make install, we just pick the binaries directly from the build directory

e cd "$MYDIR"
e cd boost
e git checkout boost-1.58.0
e git submodule update
e ./bootstrap.sh --with-libraries=system,thread,log --prefix=$PWD/P/
e ./b2 -j8
e ./b2 headers
e ./b2 install

e cd "$MYDIR"
e cd vSomeIP
e mkdir -p build
e export BOOST_ROOT=$PWD/../boost/P/
e export PATH=$PATH:$PWD/../../doxygen/P/bin/
e cd build
e cmake ..
e make -j8
# No make install, we just pick the binaries directly from the build directory

e cd "$MYDIR"
e cd cpp-someip-runtime
e mkdir -p build
e export BOOST_ROOT=$PWD/../boost/P/
e export CommonAPI_DIR=$PWD/../common-api-runtime/build
e cd build
e grep cmake ../INSTALL | sed 's@^\$@@' | sh 
e make -j8
# No make install, we just pick the binaries directly from the build directory


