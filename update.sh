#!/bin/bash

set -e

filename="runtimes.txt"
branch_name=$(date +%Y%m%d-%H%M)

echo "=> Change branch to ${branch_name}"
git co -b "${branch_name}"
echo

if [ ! -e releases.json ]
then
    echo "=> Fetching Golang releases"
    curl -o releases.json "https://go.dev/dl/?mode=json&include=all"
    echo
fi

# extract go runtimes
echo "=> Generate ${filename}"
jq -r --argjson config "$(cat config.json)" -f update.jq releases.json | tee $filename
echo

echo "=> Check for updates"
if git diff --quiet $filename
then
    echo "no changes, good"
    echo
    exit 1
fi

echo "=> Detected change!"
git --no-pager diff $filename
echo

echo "=> Commit changes"
git commit \
    -m "update go versions" \
    $filename
echo

# https://docs.gitlab.com/ee/user/project/push_options.html#push-options-for-merge-requests
echo "=> Push changes"
git push \
    -f \
    -u origin \
    $(date +%Y%m%d-%H%M) \
    -o merge_request.create \
    -o merge_request.merge_when_pipeline_succeeds \
    -o merge_request.remove_source_branch \
    -o merge_request.label=automatic-upgrade
echo
