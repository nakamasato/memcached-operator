#!/bin/bash

set -ue

gsed -i -e '/<!-- contents start -->/,/<!-- contents end -->/d' README.md
gsed -i '/^## Contents/a <!-- contents start -->' README.md
gsed -i '/^<!-- contents start -->/a <!-- contents end -->' README.md

for f in docs/*-*.md; do
	echo $f
	first_line=$(head -1 $f)
	title=$(echo $first_line | sed 's/# [0-9]*\. //g')
	gsed -i "/^<!-- contents end -->/i 1. [$title]($f)" README.md
done
