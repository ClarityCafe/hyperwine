#!/bin/sh
# Build Script for hyperwine

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
EPREFIX="/mnt/hyperwine/dist" 
PREFIX="/mnt/hyperwine/dist"
CHROOT32_DIR="$BASE_DIR/.chroot/32"
CHROOT64_DIR="$BASE_DIR/.chroot/64"

if [ -z "$(command -v debootstrap)" ]; then
  echo "debootstrap not found! This script requires debootstrap" && exit 1
fi

if [ -z "$(command -v qemu-i386-static)" ]; then
  echo "QEMU not found! This script requires QEMU" && exit 1
fi

if [ -z "$(command -v proot)" ]; then
  echo "proot not found! This script requires proot" && exit 1
fi

# chroot_exec takes $1 as the rootfs path. the rest is taken as arguments for the shell.
chroot_exec() {
    proot --rootfs="$1" -0 -q "/bin/bash -c $*"
}

echo "Running Git submodule update. This shouldn't take long."
# call submodules if we haven't already.
git submodule add --update


echo "Setting up chroots, this may take a while."

sleep 3

mkdir "$CHROOT32_DIR"
mkdir "$CHROOT64_DIR"

debootstrap --arch i386 buster "$CHROOT32_DIR" http://deb.debian.org/debian/
debootstrap --arch amd64 buster "$CHROOT64_DIR" http://deb.debian.org/debian/

chroot_exec "$CHROOT32_DIR" apt-get install -y xserver-xorg-dev libfreetype6-dev && mkdir /mnt/hyperwine
chroot_exec "$CHROOT64_DIR" apt-get install -y xserver-xorg-dev libfreetype6-dev && mkdir /mnt/hyperwine

mount --bind "$BASE_DIR" "$CHROOT32_DIR/mnt/hyperwine"
mount --bind "$BASE_DIR" "$CHROOT64_DIR/mnt/hyperwine"

echo "Chroot done. Now building hyperwine:"
echo "Step [1/3] - Build WINE64"
sleep 2

#######################
# Build step: Wine64 ##
#######################
chroot_exec "$CHROOT64_DIR" cd /mnt/hyperwine && \
    cd wine64 && \
    ./configure --prefix="$PREFIX" --exec-prefix="$EPREFIX" --disable-win16 --enable-win64 --with-x --without-cups --disable-win16 --enable-win64 --without-curses --without-capi --without-glu --without-gphoto --without-gsm --without-hal --without-ldap --without-netapi && \
    make

echo "Now building hyperwine"
echo "Step [2/3] - Build WINE32"
sleep 2

#######################
# Build step: Wine32 ##
#######################
chroot_exec "$CHROOT32_DIR" cd /mnt/hyperwine && \
   cd wine32 && \
   ./configure --prefix="$PREFIX" --exec-prefix="$EPREFIX" --disable-win16 --with-wine64="/mnt/hyperwine/wine64" --with-x --without-cups --disable-win16 --enable-win64 --without-curses --without-capi --without-glu --without-gphoto --without-gsm --without-hal --without-ldap --without-netapi && \
   make && \
   make install

echo "Now building hyperwine"
echo "Step [3/3] - Get Winetricks and pack"
sleep 2

############################
# Build step: winetricks  ##
############################
cd winetricks || exit 1
make
make PREFIX="$BASE_DIR/dist" install


######################
# Build step: warp  ##
######################

cd "$BASE_DIR" || exit 1
cp -Rf hyperwine.sh dist/


# Read build-exclude, remove all the files listed in there.
# Comments are ommitted out of $line.

cat build-exclude || exit 1 | while read -r line; do
  [ -z "${line##*#*}" ] && continue
  echo "removing $BASE_DIR/dist/$line"
  rm -rf "$BASE_DIR/dist/$line"
done;


# Grab warp-packer
curl -Lo warp-packer https://github.com/dgiagio/warp/releases/download/v0.3.0/linux-x64.warp-packer
chmod +x warp-packer

./warp-packer --arch linux-x64 --input_dir dist --exec hyperwine.sh --output "$BASE_DIR/release/hyperwine"

echo "Build complete. check the resulting binary in $BASE_DIR/release/hyperwine"
echo "contents of $BASE_DIR/release/ :"
ls "$BASE_DIR/release/"

exit 0;