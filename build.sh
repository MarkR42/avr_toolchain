#!/bin/bash

# Build a working toolchain for the attiny??1? microcontrollers.
# Examples: attiny1614, attiny3217
# Might also work for attiny??0? microcontrollers,
# The cpu architecture is known to gcc as avrxmega3
#
# This is an attempt to automate the instructions here:
# https://github.com/vladbelous/tinyAVR_gcc_setup
#
# 

# Prerequsities:
# 1. native toolchain (Ubuntu: build-essential)
# 2. wget
# 3. svn # subversion
# 4. autoconf / automake
# 5. texinfo # package "texinfo"

PREFIX=/usr/local/avr # We assume write access.
DOWNLOAD_DIR=$(pwd)/download
UNPACK_DIR=$(pwd)/unpack

# Add our "bin" to path.
PATH=$PREFIX/bin:$PATH

mkdir -p $DOWNLOAD_DIR

function fetch_file {
    # Fetch a URL into $DOWNLOAD_DIR
    echo "Downloading $1"
    (
        cd $DOWNLOAD_DIR
        wget -q --timestamping  $1
    )
}

######### DOWNLOAD STUFF
#
# binutils

BINUTILS_URL=https://ftp.gnu.org/gnu/binutils/binutils-2.39.tar.xz
BINUTILS=$(basename $BINUTILS_URL)

echo $BINUTILS

GCC_URL=http://mirror.koddos.net/gcc/releases/gcc-9.2.0/gcc-9.2.0.tar.xz
GCC=$(basename $GCC_URL)

AVR_LIBC_URL=http://download.savannah.gnu.org/releases/avr-libc/avr-libc-2.0.0.tar.bz2
AVR_LIBC=$(basename $AVR_LIBC_URL)

set -e # Error on

fetch_file $BINUTILS_URL
fetch_file $GCC_URL
fetch_file $AVR_LIBC_URL

echo "Downloads complete"


############ BUILD
#
mkdir -p $PREFIX
mkdir -p $UNPACK_DIR
# binutils
set +e # error off
if avr-ar -V; then
    echo "Avr binutils already working ok"
else
    set -e # error on
    echo "Building and installing avr-binutils"
    (
        set -e
        set -x # debug
        cd $UNPACK_DIR
        tar -xf $DOWNLOAD_DIR/$BINUTILS
        cd binutils-2.39
        mkdir avr-obj
        cd avr-obj
        ../configure --prefix=$PREFIX --target=avr --disable-nls
        make
        make install
    )
    echo "Binutils complete"
fi

# gcc
if avr-gcc -v; then
    echo "avr-gcc already working ok"
else
    set -e
    echo "Building gcc"
    (
        set -e
        set -x
        cd $UNPACK_DIR
        rm -rf gcc-9.2.0
        tar -xf $DOWNLOAD_DIR/$GCC
        cd gcc-9.2.0
        ./contrib/download_prerequisites
        mkdir avr-obj
        cd avr-obj
        ../configure --prefix=$PREFIX --target=avr --enable-languages=c,c++ \
            --disable-nls --disable-libssp --with-dwarf2

        make
        make install    
    )
    echo "gcc complete"
fi

# THIS is what we would do if they ever add support for the
# avr attiny 1-series into a released version of avr-libc.
#avr-libc
#set -e
#if test -e $PREFIX/avr/lib/libc.a; then
#    echo "avr-libc already installed"
#else
#    echo "Building avr-libc"
#    (
#        set -e
#        cd $UNPACK_DIR
#        tar -xf $DOWNLOAD_DIR/$AVR_LIBC#
#        cd avr-libc-2.0.0
#        ./configure --prefix=$PREFIX --build=`./config.guess` --host=avr
#        make
#        make install
#    )
#fi

# GET a subversion avr-libc and patch with support for our chips.
## UMMMM
# 1. Get subversion avr-libc 
#   svn checkout 'http://svn.savannah.gnu.org/viewvc/avr-libc/trunk/avr-libc/'
# 2. Patch it with the patch here:
#   https://savannah.nongnu.org/patch/?9543#comment0
#   An attachment: https://savannah.nongnu.org/patch/download.php?file_id=48974
#  patch with -p0
#
# 3. Enter the directory, run ./bootstrap (requires autoconf)
# 4. Build as above.
#
# Then there is no need to install atpacks or any other hacky nonsense
# and we can compile source for any tinyavr chips
if test -e $PREFIX/avr/lib/avrxmega3/libc.a; then
    echo "Avr-libc already installed with support for avrxmega3, you lucky thing!"
else
    echo "Building patched avr-libc"
    set -e
    (
        set -e
        set -x
        cd $UNPACK_DIR
        rm -rf avr-libc
        svn checkout -r 2548 svn://svn.savannah.nongnu.org/avr-libc/trunk/avr-libc
        cd avr-libc
        xzcat ../../avrxmega3-v12.diff.xz | patch -p0
        ./bootstrap # requires autoconf
        ./configure --prefix=$PREFIX --build=`./config.guess` --host=avr
        make
        make install
    )
    echo "Avr libc done"
fi

echo "All done"
