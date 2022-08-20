#!/bin/bash

set -eu

RELEASE_MD=release.md

latest_version=$(gh release list -L 1 | cut -f1)
patch_version=$(echo $latest_version | sed 's/v[0-9]*\.[0-9]*\.\([0-9]*\)/\1/')
new_patch_version=$((patch_version+1))
new_version=$(echo $latest_version | sed "s/v\([0-9]*\)\.\([0-9]*\)\..*/v\1.\2.$new_patch_version/")
echo "latest_version: $latest_version, new_version: $new_version"
git tag -a $new_version -m "release"
git push origin --tag
gh release create $new_version --generate-notes
gh release view $new_version --json body -q .body > $RELEASE_MD

echo "## Versions" >> $RELEASE_MD
gh release edit $new_version --notes-file $RELEASE_MD
rm $RELEASE_MD
