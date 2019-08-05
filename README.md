# Hyperwine

Hyperwine is a single-binary packaging of Wine for Flatpak applications. Originally designed for the 
[InVision Studio Flatpak](https://github.com/sr229/com.invisionapp.Studio), Hyperwine can also be reused
as a minimal Wine installation.

## What comes in the box?

- WoW64
- Winetricks
- Lutris patches (basically Proton and Lutris's own patches to work in games).

By default, we remove the HAL, LDAP, 16-bit Windows and stuff you don't need.

## Building


### The easy way

Just run this convinience script.

```
$ bash build.sh
```
Cross your fingers and wait.

**Note: Build Script requires QEMU Static, proot and debootstrap. Install them first if you haven't yet.**

### The (rather) hard way

If the script didn't work, there is a nother way to do it, which is doing bit by hand.

First, you'll need to enable multiarch for your distribution. It varies per Linux distribution so consult
your distribution's wiki to enable multiarch.

To build hyperwine, navigate to `wine64/` and run configure with these flags, and finally run `make`.

*Note: set the EPREFIX and PREFIX to the root directory of your build directory.*

```bash
$ export PREFIX="$BASE_DIR/dist/"; export EPREFIX="$BASE_DIR/dist/"
$ cd wine64;
$ ./configure --prefix="$PREFIX" --exec-prefix="$EPREFIX" --disable-win16 --enable-win64 --with-x --without-cups --disable-win16 --enable-win64 --without-curses --without-capi --without-glu --without-gphoto --without-gsm --without-hal --without-ldap --without-netapi
$ make
```
Finally walk out of `wine64`, and build `wine32/`. Same flags as before, but we'll define where we built the Wine64 binary.

```bash
$ export PREFIX="$BASE_DIR/dist/"; export EPREFIX="$BASE_DIR/dist/"
$ cd wine32;
$ ./configure --prefix="$PREFIX" --exec-prefix="$EPREFIX" --disable-win16 --with-wine64="$BASE_DIR/wine64" --with-x --without-cups --disable-win16 --enable-win64 --without-curses --without-capi --without-glu --without-gphoto --without-gsm --without-hal --without-ldap --without-netapi
$ make
$ make install
```
Finally, run `make install` inside winetricks.

*Note: set the PREFIX to the root directory of your build directory.*

```bash
$ cd winetricks
$ make
$ make PREFIX="$BASE_DIR/dist" install
```
Then finally get `warp-packer` and package the finalized distribution. Make sure you copy `hyperwine.sh` to your build directory before packaging.

```bash 
$ cp -Rf hyperwine.sh dist/


# Grab warp-packer
$ curl -Lo warp-packer https://github.com/dgiagio/warp/releases/download/v0.3.0/linux-x64.warp-packer
$ chmod +x warp-packer

# you can replace --input-dir and --output directories with your own
$ ./warp-packer --arch linux-x64 --input_dir $BUILD_DIR --exec hyperwine.sh --output "$BASE_DIR/release/hyperwine"

```

And that's it! You just built your version of hyperwine.

Now try executing your hyperwine installation.

```bash
$ chmod +x hyperwine
$ ./hyperwine wine --version
```