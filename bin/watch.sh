#!/bin/bash -eu

function block_for_change {
  fswatch -1 --recursive assets
}

make all

while block_for_change; do
  make all
done
