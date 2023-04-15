#!/bin/bash

if [ ! -e releases.json ]
then
    curl -o releases.json "https://go.dev/dl/?mode=json&include=all"
fi

# extract go runtimes
jq -r --argjson input "$(cat args.json)" "$(cat update.jq)" releases.json | tee runtimes.txt

if git diff-index --quiet HEAD --
then
    echo "no changes, good"
    exit 1
fi

echo "found changes"
git commit \
    -a \
    -m "update go versions"

git push \
    -u origin \
    master:$(date +%Y%m%d-%H%M)
    -o merge_request.create \
    -o merge_request.merge_when_pipeline_succeeds \
    -o merge_request.remove_source_branch \
    -o merge_request.label=automatic-upgrade
