#!/bin/bash
NEW=$1
OLD=$2
./hotpatch.sh <(radiff2 "$OLD" "$NEW" | sed "s/ =>.*$//")
