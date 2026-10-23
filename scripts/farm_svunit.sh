#!/bin/zsh
set -e

# Remote half of 'make farm-test' — launched by scripts/farm_runner.sh with
# cwd = $remote_wd/output on the farm.
#
# $1  local repo root; used to re-root the absolute paths in build/svunit/dut.f

local_root=$1
repo_root=$(cd .. && pwd)

# dut.f was generated with local absolute paths; re-root it to this checkout
sed "s|^${local_root}/|${repo_root}/|" ../build/svunit/dut.f > dut.f

# Use the vendored in-tree svunit — the workstation's SVUNIT_INSTALL
# (/home/joel/opt/svunit-master) does not exist on the farm
export SVUNIT_INSTALL="$repo_root/lib/svunit-master"
export PATH="$repo_root/lib/svunit-master/bin:$PATH"

# Lab VCS environment: zsh translation of ~/EE5327.cshrc on the farm
source "$HOME/EE5327.zshrc"

# -full64: this VCS build needs 64-bit mode to actually run
runSVUnit -s vcs -o . -f dut.f -c_arg -full64 \
    --directory ../src/tb/module \
    --directory ../src/tb/full

# Drop bulky VCS build artifacts before syncing back
rm -rf csrc simv simv.daidir DVEfiles ucf.dir vc_hdrs.h vcs.log
