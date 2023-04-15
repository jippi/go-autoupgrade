#!/bin/bash

if [ ! -e releases.json ]
then
    curl -o releases.json "https://go.dev/dl/?mode=json&include=all"
fi

exec jq \
    -r \
    --argjson input "$(cat args.json)" \
    "$(cat update.jq)" releases.json | tee runtimes.txt
