#!/bin/sh

V=1.9.0
git clone http://anongit.freedesktop.org/git/dbus/dbus.git/

cd dbus
git reset --hard
git clean -fdx 
git checkout dbus-$V

for f in ../../common-api-dbus-runtime/src/dbus-patches/*.patch ; do 
  patch -p1 <$f
done

./autogen.sh
./configure --prefix=$PWD/libdbus_patched
make -j8 -C dbus

# Optional installation
#sudo make -C dbus install
#sudo make install-pkgconfigDATA

# If not installed, then this is true:
echo Libs are in $PWD/dbus/.libs

exit

Libraries have been installed in:
   /tmp/dbus-with-patch/dbus/libdbus_patched/lib

If you ever happen to want to link against installed libraries
in a given directory, LIBDIR, you must either use libtool, and
specify the full pathname of the library, or use the `-LLIBDIR'
flag during linking and do at least one of the following:
   - add LIBDIR to the `LD_LIBRARY_PATH' environment variable
     during execution
   - add LIBDIR to the `LD_RUN_PATH' environment variable
     during linking
   - use the `-Wl,-rpath -Wl,LIBDIR' linker flag
   - have your system administrator add LIBDIR to `/etc/ld.so.conf'

See any operating system documentation about shared libraries for
more information, such as the ld(1) and ld.so(8) manual pages.
