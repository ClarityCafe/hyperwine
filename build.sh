#!/bin/sh
# Build Script for hyperwine
set -eo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
EPREFIX="/mnt/hyperwine/dist" 
PREFIX="/mnt/hyperwine/dist"
CHROOT32_DIR="$BASE_DIR/chroot/32"
CHROOT64_DIR="$BASE_DIR/chroot/64"

if [ -z "$(command -v proot)" ]; then
   echo "proot not found! This script requires proot" && exit 1
fi

if [ -z "$(command -v qemu-i386-static)" ]; then
   echo "QEMU Static not found! This script requires QEMU Static" && exit 1
fi

if [ -z "$(command -v debootstrap)" ]; then
  echo "debootstrap not found! This script requires debootstrap" && exit 1
fi


# chroot_exec takes $1 as the rootfs path. the rest is taken as arguments for the shell.
chroot_exec() {
    if [ "$1" = "$CHROOT32_DIR" ]; then
      proot -S "$1" -0 /bin/sh -c "${*:2}" | while read -r line; do
        echo "[CHROOT-32] $line"
      done
    else
      proot -S "$1" -0 /bin/sh -c "${*:2}" | while read -r line; do
       echo "[CHROOT-64] $line"
      done
    fi
}

echo "Running Git submodule update. This shouldn't take long."
# call submodules if we haven't already.
git submodule update --init --recursive


echo "Setting up chroots, this may take a while."

sleep 3

if [ ! -d "$CHROOT32_DIR" ] && [ ! -d "$CHROOT64_DIR" ]; then

  mkdir -p "$CHROOT32_DIR"
  mkdir -p "$CHROOT64_DIR"

  sudo debootstrap --arch i386 buster "$CHROOT32_DIR" http://deb.debian.org/debian/ | while read -r line; do
    echo "[BOOTSTRAP-32] $line"
  done
  sudo debootstrap --arch amd64 buster "$CHROOT64_DIR" http://deb.debian.org/debian/ | while read -r line; do
    echo "[BOOTSTRAP-64] $line"
  done

  echo "Fixing permissiong for the chroots, please be patient."

  sudo chown -R "$(id -u)":"$(id -g)" "$CHROOT32_DIR"
  sudo chown -R "$(id -u)":"$(id -g)" "$CHROOT64_DIR"

  echo "Verifying that the chroot dirs are not empty..."

  if [ -z "$(ls "$CHROOT32_DIR")" ]; then 
    echo "FAIL: $CHROOT32_DIR is empty. debootstrap didn't work. Fix this." && exit 3;
  else
    echo "PASS: $CHROOT32_DIR has contents. printing contents."
    ls -al "$CHROOT32_DIR"
    sleep 2;
  fi


  if [ -z "$(ls "$CHROOT64_DIR")" ]; then 
    echo "FAIL: $CHROOT64_DIR is empty. debootstrap didn't work. Fix this." && exit 3;
  else
    echo "PASS: $CHROOT32_DIR has contents. printing contents."
    ls -al "$CHROOT32_DIR"
    sleep 2;
  fi

  echo "Copying QEMU binary to $CHROOT32_DIR. Please Authorize."
  sudo cp -Rf "$(command -v qemu-i386-static)" "$CHROOT32_DIR/bin"

  chroot_exec "$CHROOT32_DIR" apt-get install -y xserver-xorg-dev libfreetype6-dev && mkdir /mnt/hyperwine
  chroot_exec "$CHROOT64_DIR" apt-get install -y xserver-xorg-dev libfreetype6-dev && mkdir /mnt/hyperwine

  sudo mount --bind "$BASE_DIR" "$CHROOT32_DIR/mnt/hyperwine"
  sudo mount --bind "$BASE_DIR" "$CHROOT64_DIR/mnt/hyperwine"
else
  echo "Chroot already initialized. Running additional setup."

  chroot_exec "$CHROOT32_DIR" apt-get install -y xserver-xorg-dev libfreetype6-dev && mkdir /mnt/hyperwine
  chroot_exec "$CHROOT64_DIR" apt-get install -y xserver-xorg-dev libfreetype6-dev && mkdir /mnt/hyperwine

  sudo mount --bind "$BASE_DIR" "$CHROOT32_DIR/mnt/hyperwine"
  sudo mount --bind "$BASE_DIR" "$CHROOT64_DIR/mnt/hyperwine"
fi

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
  rm -rfv "$BASE_DIR/dist/$line"
done;


# Grab warp-packer
curl -Lo warp-packer https://github.com/dgiagio/warp/releases/download/v0.3.0/linux-x64.warp-packer
chmod +x warp-packer

./warp-packer --arch linux-x64 --input_dir dist --exec hyperwine.sh --output "$BASE_DIR/release/hyperwine"

echo "Build complete. check the resulting binary in $BASE_DIR/release/hyperwine"
echo "contents of $BASE_DIR/release/ :"
ls "$BASE_DIR/release/"

exit 0;