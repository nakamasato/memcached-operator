#!/bin/bash

set -eu


echo "======== CLEAN UP ==========="

rm -rf api config controllers hack bin 2> /dev/null
for f in .dockerignore .gitignore *.go go.* Makefile PROJECT Dockerfile; do
    if [ -f "$f" ] ; then
        rm $f
    fi
done

VERSIONS=$(operator-sdk version | sed 's/operator-sdk version: "\([v0-9\.]*\)".*kubernetes version: \"\([v0-9\.]*\)\".* go version: \"\(go[0-9\.]*\)\".*/operator-sdk: \1, kubernetes: \2, go: \3/g')
echo $VERSIONS
commit_message="Remove all files to upgrade versions ($VERSIONS)"
last_commit_message=$(git log -1 --pretty=%B)
if [ -n "$(git status --porcelain)" ]; then
    echo "there are changes";
    if [[ $commit_message = $last_commit_message ]]; then
        echo "duplicated commit -> amend"
        git add . && git commit -a --amend --no-edit
    else
        echo "create a commit"
        git add . && git commit -m "$commit_message"
    fi
else
  echo "no changes";
  echo "======== CLEAN UP COMPLETED ==========="
  exit 0
fi

echo "======== CLEAN UP COMPLETED ==========="


echo "======== INIT PROJECT ==========="

# 1. Init a project
rm -rf docs mkdocs.yml # need to make the dir clean before initializing a project
operator-sdk init --domain example.com --repo github.com/example/memcached-operator
echo "======== INIT PROJECT operator-sdk init completed =========="

until [ ! -f .git/index.lock ]
do
    echo ".git/index.lock found before checkout"
    sleep 5
done
echo "git checkout docs mkdocs.yml"
git checkout docs mkdocs.yml
until [ ! -f .git/index.lock ]
do
    echo ".git/index.lock found after checkout"
    sleep 5
done
echo "git add & commit"
git add . && git commit -m "1. Create a project"

echo "======== INIT PROJECT COMPLETED ==========="
