#!/bin/zsh
set -e

REMOTE=vlsi
local_wd=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
remote_wd="${local_wd/#\/src/\$HOME\/src}"

rclone copy -cu $local_wd vlsi:$remote_wd
ssh $REMOTE "cd $remote_wd/output && ${argv[@]:1}"
rclone copy -cu $REMOTE:$remote_wd/output $local_wd
