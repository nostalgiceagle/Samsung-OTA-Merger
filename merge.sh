#!/bin/bash
#
# Copyright (C) 2025 Ksawlii
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

set -e

# Variables
OUT_DIR="out"
AP_DIR="$OUT_DIR/AP/"
UP_BIN_DIR="$OUT_DIR/up_bin/"
START_TIME=$(date +%s)
BASE_TAR="$1"
UPDATE_ZIP="$2"
PATH="$PATH:$(pwd)/bin"
MERGED="$OUT_DIR/merged"
TOOLS="$HOME/.local/bin/tools"

DEPS(){
    local DIR="$(readlink -f .)"
  

    if [ ! -f "$TOOLS/lpunpack" ] || [ ! -f "$TOOLS/simg2img" ]; then
        if [ ! -d "$TOOLS/android-tools" ]; then
            echo "Cloning android-tools"
            git clone "https://github.com/nmeum/android-tools.git" "$TOOLS/android-tools" -q
        fi
        cd "$TOOLS/android-tools"
        git submodule update --quiet --init --recursive
        [ -d "$(pwd)/.git/rebase-apply" ] && git am "--abort"
        cmake -B "build" -DCMAKE_C_COMPILER="clang" -DCMAKE_CXX_COMPILER="clang++" -DCMAKE_SYSTEM_NAME="$(uname -s)" -DCMAKE_SYSTEM_PROCESSOR="$(uname -m)" \
                         -DCMAKE_BUILD_TYPE="Release" -DANDROID_TOOLS_USE_BUNDLED_FMT="ON" -DANDROID_TOOLS_USE_BUNDLED_LIBUSB="ON" >/dev/null
        echo "Building android-tools"
        make "-j$(nproc --all)" -C "build" >/dev/null
   
        [ ! -d "$TOOLS" ] && mkdir -p "$TOOLS"
        cp -fa "build/vendor/lpunpack" "build/vendor/simg2img" "$TOOLS"
    fi
    
    if [ ! -f "$TOOLS/BlockImageUpdate" ]; then
        if [ ! -d "$TOOLS/imgpatchtools" ]; then
            echo "Cloning imgpatchtools"
            git clone "https://github.com/erfanoabdi/imgpatchtools.git" "$TOOLS/imgpatchtools" -q
        fi
        cd "$TOOLS/imgpatchtools"
        make >/dev/null
   
        [ ! -d "$TOOLS" ] && mkdir -p "$TOOLS"
        cp -fa "bin/BlockImageUpdate" "$TOOLS"
    fi
    
    cd "$DIR"
}

CLEAN() {
    if [ -d "$OUT_DIR" ]; then
        echo "Running cleanup..." 
        rm -rf "$OUT_DIR"
        echo "Cleanup complete."
    else
        echo "Nothing to clean"
    fi
}

EXTRACT_AP(){
    echo "Extracting super.img.lz4 from AP..."
    mkdir -p "$AP_DIR/extracted"
    tar -xf "$BASE_TAR" --wildcards --no-same-owner -C "$AP_DIR/extracted/" "super.img.lz4"

    if [ ! -f "$AP_DIR/extracted/super.img.lz4" ]; then
        echo "ERROR: super.img.lz4 not found in AP package!"
        exit 1
    fi
}

EXTRACT_LZ4(){
    echo "Decompressing super.img.lz4"
    lz4 -d -f -q "$AP_DIR/extracted/super.img.lz4" "$AP_DIR/extracted/super.img"
}

CONVERT_RAW(){
    echo "Converting super to raw"
    "$TOOLS/simg2img" "$AP_DIR/extracted/super.img" "$AP_DIR/extracted/super-raw.img" >/dev/null
}

EXTRACT_SUPER(){
    echo "Extracting super"
    "$TOOLS/lpunpack" "$AP_DIR/extracted/super-raw.img" "$AP_DIR" >/dev/null
}

EXTRACT_BIN(){
    echo "Extracting update bin..."
    mkdir -p "$UP_BIN_DIR"
    unzip -n -q "$UPDATE_ZIP" -d "$UP_BIN_DIR"
}

MERGE(){
    SYSTEM=
    PRODUCT=
    ODM=
    VENDOR=
    SYSTEM_DLKM=
    VENDOR_DLKM=
    SYSTEM_EXT=
    
    [ -f "$AP_DIR/system.img" ] && SYSTEM=1
    [ -f "$AP_DIR/product.img" ] && PRODUCT=1
    [ -f "$AP_DIR/odm.img" ] && ODM=1
    [ -f "$AP_DIR/vendor.img" ] && VENDOR=1
    [ -f "$AP_DIR/system_dlkm.img" ] && SYSTEM_DLKM=1
    [ -f "$AP_DIR/vendor_dlkm.img" ] && VENDOR_DLKM=1
    [ -f "$AP_DIR/system_ext.img" ] && SYSTEM_EXT=1

    mkdir -p "$MERGED"
    echo "Starting Merge"
   
    if [ "$SYSTEM" = "1" ]; then
        echo "Merging system"
        "$TOOLS/BlockImageUpdate" "$AP_DIR/system.img" "$UP_BIN_DIR/system.transfer.list" "$UP_BIN_DIR/system.new.dat" "$UP_BIN_DIR/system.patch.dat" >/dev/null
        mv "$AP_DIR/system.img" "$MERGED"
    fi

    if [ "$PRODUCT" = "1" ]; then
        echo "Merging product"
        "$TOOLS/BlockImageUpdate" "$AP_DIR/product.img" "$UP_BIN_DIR/product.transfer.list" "$UP_BIN_DIR/product.new.dat" "$UP_BIN_DIR/product.patch.dat" >/dev/null
        mv "$AP_DIR/product.img" "$MERGED"
    fi

    if [ "$ODM" = "1" ]; then
        echo "Merging odm"
        "$TOOLS/BlockImageUpdate" "$AP_DIR/odm.img" "$UP_BIN_DIR/odm.transfer.list" "$UP_BIN_DIR/odm.new.dat" "$UP_BIN_DIR/odm.patch.dat" >/dev/null
        mv "$AP_DIR/odm.img" "$MERGED"
    fi

    if [ "$VENDOR" = "1" ]; then
        echo "Merging vendor"
        "$TOOLS/BlockImageUpdate" "$AP_DIR/vendor.img" "$UP_BIN_DIR/vendor.transfer.list" "$UP_BIN_DIR/vendor.new.dat" "$UP_BIN_DIR/vendor.patch.dat" >/dev/null
        mv "$AP_DIR/vendor.img" "$MERGED"
    fi

    if [ "$SYSTEM_DLKM" = "1" ]; then
        echo "Merging system_dlkm"
        "$TOOLS/BlockImageUpdate" "$AP_DIR/system_dlkm.img" "$UP_BIN_DIR/system_dlkm.transfer.list" "$UP_BIN_DIR/system_dlkm.new.dat" "$UP_BIN_DIR/system_dlkm.patch.dat" >/dev/null
        mv "$AP_DIR/system_dlkm.img" "$MERGED"
    fi

    if [ "$VENDOR_DLKM" = "1" ]; then
        echo "Merging vendor_dlkm"
        "$TOOLS/BlockImageUpdate" "$AP_DIR/vendor_dlkm.img" "$UP_BIN_DIR/vendor_dlkm.transfer.list" "$UP_BIN_DIR/vendor_dlkm.new.dat" "$UP_BIN_DIR/vendor_dlkm.patch.dat" >/dev/null
        mv "$AP_DIR/vendor_dlkm.img" "$MERGED"
    fi

    if [ "$SYSTEM_EXT" = "1" ]; then
        echo "Merging system_ext"
        "$TOOLS/BlockImageUpdate" "$AP_DIR/system_ext.img" "$UP_BIN_DIR/system_ext.transfer.list" "$UP_BIN_DIR/system_ext.new.dat" "$UP_BIN_DIR/system_ext.patch.dat" >/dev/null
        mv "$AP_DIR/system_ext.img" "$MERGED"
    fi

    rm -f "$(pwd)/Progress.txt"
}

if [ $# -lt 2 ]; then
    echo "Usage: $0 [path to base firmware TAR archive] [path to update bin ZIP] [args]"
    echo "Arguments: c = cleans Out dir"
    exit 1
fi

echo ""
echo "===== Samsung Bin Firmware Merger ====="
echo "Base firmware: $BASE_TAR"
echo "Update binary: $UPDATE_ZIP"
echo "Base script by @EndaDwagon (GitHub)"
echo "Completely rewriten by @Ksawlii (GitHub)"
echo ""

if [ ! -d "$TOOLS" ]; then
    echo "ERROR: bin dir not found"
    exit 1
fi

# TODO: Improve args
if [ "$3" = "c" ]; then
    CLEAN 
fi

DEPS

if [ ! -f "$AP_DIR/extracted/super.img.lz4" ]; then
    EXTRACT_AP 
fi

if [ ! -f "$AP_DIR/extracted/super.img" ]; then
    EXTRACT_LZ4
fi

if [ ! -f "$AP_DIR/extracted/super-raw.img" ]; then
    CONVERT_RAW
fi

if [ ! -f "$AP_DIR/odm.img" ] || [ ! -f "$AP_DIR/product.img" ] || [ ! -f "$AP_DIR/system.img" ] || [ ! -f "$AP_DIR/vendor.img" ]; then
   EXTRACT_SUPER
fi

EXTRACT_BIN
MERGE

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
HOURS=$((ELAPSED / 3600))
MINS=$(((ELAPSED % 3600) / 60))
SECS=$((ELAPSED % 60))
echo
if [ $HOURS -gt 0 ]; then
    echo "Merge complete in ${HOURS}hr ${MINS}min ${SECS}sec"
elif [ $MINS -gt 0 ]; then
    echo "Merge complete in ${MINS}min ${SECS}sec"
else
    echo "Merge complete in ${SECS}sec"
fi
