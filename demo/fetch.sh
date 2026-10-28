#!/bin/sh
# Downloads the font the bake measures the booleans' budget on (with
# Bitstream Vera, which ovg carries) and checks it against its SHA-256:
# Adwaita Sans (OFL 1.1) from GNOME's repository at the tag 49.0. It isn't
# in the repository (it's 880 KB): run this once before baking
# (media/.gitignore keeps it out of commits).
set -eu
cd "$(dirname "$0")/media"
sum() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -c1-64; }
fetch() { # name url sha256 credit
	if [ -f "$1" ] && [ "$(sum "$1")" = "$3" ]; then return; fi
	curl -fsSL -o "$1" "$2"
	if [ "$(sum "$1")" != "$3" ]; then echo "fetch.sh: $1 isn't the file pinned here (from $2)" >&2; rm -f "$1"; exit 1; fi
	echo "fetched $1: $4"
}
fetch AdwaitaSans-Regular.ttf https://gitlab.gnome.org/GNOME/adwaita-fonts/-/raw/49.0/sans/AdwaitaSans-Regular.ttf 8381c33b9a44f066f2b99dba3d416a2342891e28c956a35dfd8d16ee2987e6d4 "Adwaita Sans, the GNOME project (from Inter), SIL OFL 1.1"
