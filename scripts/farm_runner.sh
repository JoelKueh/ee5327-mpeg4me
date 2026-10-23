#!/bin/zsh
set -e

REMOTE=vlsi

local_wd=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
remote_wd="${local_wd#*/src/}"

rclone mkdir $REMOTE:$remote_wd
rclone sync --transfers=8 --checkers=8 -cu $local_wd/src $REMOTE:$remote_wd -P
rclone sync --transfers=8 --checkers=8 -cu $local_wd/scripts $REMOTE:$remote_wd -P
rclone sync --transfers=8 --checkers=8 -cu $local_wd/lib $REMOTE:$remote_wd -P
ssh $REMOTE "mkdir -p $remote_wd/output && cd $remote_wd/output && ${argv[@]:1}"
rclone sync --transfers=8 --checkers=8 -cu $REMOTE:$remote_wd/output $local_wd -P
