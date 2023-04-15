# Run a pipeline and return "null" in case of error instead of failing
#
# Example:
#
#	input:
#       [1, "nope"] | opt(tonumber)
#
#	output:
#       [1, null]
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
#    	{
#   		major: 1,
#   		minor: 20,
#   		patch: 3,
#   		release: "1.20.3",
#           release_group: [1, 20]
#           release_semver: [1, 20, 3]
#    	}
#
# See: https://stackoverflow.com/a/75770668/1081818
def to_semver:
    . as $in
    | sub("\\+.*$"; "")
    | capture("^(?<v>[^-]+)(?:-(?<p>.*))?$")

    # [0] is semver data [1] is overflow/unparsed
    | [.v, .p // empty]

    # make "1.20.3" into ["1", "20", "3"]
    | map(split(".")

    # make ["1", "20", "3"] into [1, 20, 3]
    | map(opt(tonumber)))
    | .[1] |= (. // {})

    # Construct the result output
    | {
        major: .[0][0],
        minor: .[0][1],

        # go1.20 is same as 1.20.0, Go omits patch version from a new minor series,
        # so we're going to set "0" as the default
        patch: (.[0][2] // 0),

        # preserve the original input semver value
        release: $in,
    }

    # Compute group and semver slices for sorting and filtering and merge with previous step
    | . += {
        # used to group releases in the same group together
        release_group: [
            .major,
            .minor
        ],

        # used to sort releases within a group by semver rather than number/string
        release_semver: [
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

    # remove the "go" string prefix from release names
    | .version[2:]

    # cast releases to semver
    | to_semver

    # remove releases older than configured
    | select(.release_group >= ($input.minimum_release_group | to_semver).release_group)
]

# put all (X.Y) releases are in the same slice
| group_by(.release_group)

# select N most recent releases per group
| map(.[:$input.number_of_releases_per_group])

# merge additional releases from config file
| . + [
    (
        $input.additional_releases
        | map(to_semver)
    )
]

# remove the nested release group slice from output
| flatten

# ensure that [$input.additional_releases] additions doesn't duplicate existing entries
| unique

# sort each release group by semver semantics and not numberically or by string
#
# Example: [1.18.9, 1.18.10]
#
| sort_by(.release_semver)

# extract the releases we want to support
| map(.release)

# print releases as a string
| join("\n")
