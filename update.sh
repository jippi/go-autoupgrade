#!/bin/bash

if [ ! -e releases.json ]
then
	curl -o releases.json "https://go.dev/dl/?mode=json&include=all"
fi

#set -xe

read -r -d '' jq_semver <<'EOF'
# Run a func and return "null" in case of error
#
# Example:
#
#	input: [1, "nope"] | opt(tonumber)
#	output: [1, null]
#
def opt(f):
	. as $in
	| try f catch $in
;

# Convert a semver string to a semver object
#
# Example:
#
# 	input:
#		"1.20.3" | to_semver"
#
# 	output:
# 	{
#		major: 1,
#		minor: 20,
#		patch: 3,
#		full: "1.20.3"
# 	}
#
def to_semver:
	. as $in
	| sub("\\+.*$"; "")
	| capture("^(?<v>[^-]+)(?:-(?<p>.*))?$")
	| [.v, .p // empty]
	| map(split(".")			# make "1.20.3" into ["1", "20", "3"]
	| map(opt(tonumber)))		# make ["1", "20", "3"] into [1, 20, 3]
	| .[1] |= (. // {})
	| {
		major: .[0][0],
		minor: .[0][1],
		patch: (.[0][2] // 0), 	# go1.20 is same as 1.20.0, Go omits patch version from a new minor series
		full: $in,				# preserve the original input semver value
	}
;

# Return an array with major + minor sem-ver release used to group Go releases by their release "group"
#
# We cant use strings like "1.20" to group, due to jq ordering/bugs in convering (string) "1.20" to (number) 1.2
# so we use a slice for comparison and grouping which *do* work.
#
# Example:
#
# 	input:
#		"1.20.3" | to_semver | to_release_group"
#
# 	output:
# 	{
#		major: 1,
#		minor: 20
# 	}
#
def to_release_group:
	[
		.major,
		.minor
	]
;

# Release peline
[
	.[]
	| select(.stable == true) 				# we only care about stable releases)
	| .version[2:] 							# remove the "go" prefix from release names
	| to_semver								# cast releases to semver
	| select(.major >= 1 and .minor >= 16) 	# we care about Go 1.16 or newer
]
| group_by(. | to_release_group)			# put all (X.Y) releases are in the same slice
| map(.[:3])								# select 3 most recent releases for each release group
| reverse									# newest releases first
| map(.[].full)								# select the releases we want to support
| join("\n")								# print releases
EOF

exec jq -r "$jq_semver" releases.json
