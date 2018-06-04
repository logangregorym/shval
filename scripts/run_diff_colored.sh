#!/bin/bash
set -x

SHVALDIR=~/src/shval

EXE=$1
shift

shval diff -T -- "$EXE" "$@"

ruby $SHVALDIR/scripts/filter_diff_colored.rb  <trace.dot >ins_"$@".dot
ruby $SHVALDIR/scripts/filter_diff_colored.rb -c <trace.dot >func_"$@".dot

mv trace.dot "$EXE"_"$@".dot

dot -Tsvg -o ins_"$@".svg ins_"$@".dot
dot -Tsvg -o func_"$@".svg func_"$@".dot

rm *.log
