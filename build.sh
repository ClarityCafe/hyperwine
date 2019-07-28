#!/bin/sh
# Build Script for hyperwine

BASE_DIR="$(cd `dirname $0` && pwd)"
DATAROOTDIR="$BASE_DIR/dist" 
EPREFIX="$BASE_DIR/dist" 
PREFIX="$BASE_DIR/dist"


# call submodules if we haven't already.
git submodule add --update;

echo "This script assumes you have all of the build dependencies of Wine. If you don't"
echo "Please acquire them first."

# Warn if they don't have lib32 targeting

if [ ! -d /usr/lib32 ]  || [! -d /usr/lib32 ] && [! -d /usr/lib32/i386-linux-gnu ]; then
   echo "Warning: This script builds Wine with WoW64. Install 32-bit versions of the dependencies"
   echo "Or, do a chroot/LXD to build the 32-bit version manually."
fi

#######################
# Build step: Wine64 ##
#######################
cd wine64;
./configure --prefix="$PREFIX" --exec-prefix="$EPREFIX" --disable-win16 --enable-win64 --with-x --without-cups --disable-win16 --enable-win64 --without-curses --without-capi --without-glu --without-gphoto --without-gsm --without-hal --without-ldap --without-netapi
make
cd ..

#######################
# Build step: Wine32 ##
#######################
cd wine32;
./configure --prefix="$PREFIX" --exec-prefix="$EPREFIX" --disable-win16 --with-wine64="$BASE_DIR/wine64" --with-x --without-cups --disable-win16 --enable-win64 --without-curses --without-capi --without-glu --without-gphoto --without-gsm --without-hal --without-ldap --without-netapi
make
make install
cd ..

############################
# Build step: winetricks  ##
############################
cd winetricks
make
make PREFIX="$BASE_DIR/dist" install


######################
# Build step: warp  ##
######################

cd "$BASE_DIR"
cp -Rf hyperwine.sh dist/


# Grab warp-packer
curl -Lo warp-packer https://github.com/dgiagio/warp/releases/download/v0.3.0/linux-x64.warp-packer
chmod +x warp-packer

./warp-packer --arch linux-x64 --input_dir dist --exec hyperwine.sh --output "$BASE_DIR/release/hyperwine"

echo "Setup done. check the resulting binary in $BASE_DIR/release/hyperwine"