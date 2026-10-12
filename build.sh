#!/data/data/com.termux/files/usr/bin/bash
# build.sh — build engine + deploy ke $HOME
# PENTING: /storage/ adalah FUSE mount, chmod tidak berfungsi.
# Jalankan via: bash build.sh  atau dari $HOME.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Compiling engine ==="
fpc -Mobjfpc -Sh pascak_noASTnet.pas 2>&1 | grep -E "Error|Fatal" && {
    echo "COMPILE FAILED"
    exit 1
}

echo "=== Copy ke \$HOME (ext4, chmod works) ==="
cp pascak_noASTnet ~/pascak_noASTnet
chmod +x ~/pascak_noASTnet

echo "=== Build OK ==="
ls -la ~/pascak_noASTnet