#!/bin/sh
# Hyperwine delegate script
# Copyright 2019 (c) Kibo Hikari et al.
# Licensed under MIT

HYPERWINE_VERSION="0.0.0"
DIR="$(cd "$(dirname "$0")" ; pwd -P)"
WINE_BIN_PATH=$DIR/bin/
WINE_LIB_PATH=$DIR/lib/


print_help() {
   echo "hyperwine is a wine distribution that packages wine into a single binary"
   echo "this is intended for Flatpak/container deployments."
   echo "This hyperwine version ($HYPERWINE_VERSION) is built on Lutris Wine 4.8 with Winetricks,"
   echo "wine-mono and wine-gecko."
}

# Little sanity check placed to make sure it only executes files inside our binary.
if [ -n "$1" ]; then
 if [ -f "$1" ]; then
   # call the wine binary its trying to call along with args.
   exec "$WINE_BIN_PATH/$1" "$@"
 else
    printf "No such command $1\n\n"
    print_help
    exit 1;
  fi
else 
  print_help;
  exit 0;
fi