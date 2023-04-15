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
# See: https://stackoverflow.com/a/75770668/1081818
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
    | . += {
        release_group: (. | to_release_group),
        release_slice: [
            .major,
            .minor,
            .patch
        ],
    }
;


# Release transformation pipeline
[
    .[]

    # we only care about stable releases
    | select(.stable == true)

    # remove the "go" prefix from release names
    | .version[2:]

    # cast releases to semver
    | to_semver

    # remove releases older than configured
    | select(.release_group >= ($input.minimum_release_group | to_semver | to_release_group))
]

# put all (X.Y) releases are in the same slice
| group_by(to_release_group)

# select N most recent releases per group
| map(.[:$input.number_of_releases_per_group])

# sort each release group by semver semantics and not numberically or by string
#
# Example: [1.18.9, 1.18.10]
#
| map(sort_by(.release_slice))

# select the releases we want to support
| map(.[].full)

# print releases as a string
| join("\n")
