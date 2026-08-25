#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# The defaults file that every scenario starts from.
#
# It is deliberately hostile to a sloppier reading of the version than the one
# the script does. Two decoys sit above `reactflux_version`, both of which a
# `_version:` substring match (or an unanchored regex) would find first, and
# both of which are Jinja expressions rather than literals - exactly the kind of
# value that has ended up inside a tag elsewhere in the fleet. A commented-out
# example sits above them for good measure, standing in for the block comment
# that defaults/main.yml really carries above `reactflux_version`.
write_defaults() {
	local version="$1"

	cat > defaults/main.yml <<-EOF
		# An example of pinning, which is not in effect:
		# reactflux_version: 9.9.9

		reactflux_identifier: reactflux

		reactflux_container_image_self_build_repo_version: "{{ reactflux_version if reactflux_version != 'latest' else 'main' }}"
		reactflux_container_image_tag: "{{ reactflux_version }}"

		reactflux_version: ${version}

		reactflux_container_http_port: 2000
	EOF
}

# Starts a scenario with a repository that is where this one actually is: no
# upstream version to speak of, and a `v2025.6.2-N` release history that has
# already gone past a single digit.
#
# The two `v2025.06.02-N` tags are real history too. They are from before the
# naming settled, they are a different prefix, and picking one of them up would
# produce a tag that sorts below every release since.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	write_defaults latest
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	git tag 'v2025.06.02-0'
	git tag 'v2025.06.02-1'

	local release_number
	for release_number in $(seq 0 10); do
		git tag "v2025.6.2-$release_number"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

pin_version="write_defaults 1.2.3"
pin_commit_hash="write_defaults cebdc310b6940688b020570f3992a81a08a6509c"
unpin_version="write_defaults latest"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_molecule="mkdir -p molecule/default && printf 'a test\n' >> molecule/default/verify.yml"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The everyday case for this repository: nothing upstream ever changes, so every
# release is driven by a change to the role itself, continuing the `v2025.6.2-N`
# series past the two-digit boundary it is already at.
scenario 'Role changes with no upstream version to speak of'
expect 'task edit' v2025.6.2-11 "$(merge "$edit_task")"
expect 'template'  v2025.6.2-12 "$(merge "$edit_template")"

# The decoys in defaults/main.yml must not be mistaken for the version, and
# neither the commented-out example nor a Jinja expression may reach the tag.
scenario 'Decoy version variables and a commented-out example'
expect 'task edit' v2025.6.2-11 "$(merge "$edit_task")"

scenario 'Commits that do not affect the role'
expect 'README'   ''            "$(merge "$edit_readme")"
expect 'a test'   ''            "$(merge "$edit_molecule")"
expect 'a script' ''            "$(merge "$edit_script")"
expect 'a task'   v2025.6.2-11  "$(merge "$edit_task")"

# Should ReactFlux ever publish versioned images and this role pin one, the tag
# series follows the pinned version with no change to the script.
scenario 'Pinning a real version, once upstream publishes one'
expect 'pin 1.2.3' v1.2.3-0 "$(merge "$pin_version")"
expect 'task edit' v1.2.3-1 "$(merge "$edit_task")"

# Pinning one of the commit-hash tags Docker Hub does carry is something an
# operator can do today, and defaults/main.yml documents it. If it is ever done
# here, the tag has to remain something a consuming playbook can order, so a
# hash must not end up inside one.
scenario 'Pinning a commit-hash tag'
expect 'pin a hash' vcebdc310b6940688b020570f3992a81a08a6509c-0 "$(merge "$pin_commit_hash")"

# The same two updates in the other order must still release each one exactly
# once, so that the result does not depend on the order things get merged in.
scenario 'A version pin merged after other role changes'
expect 'task edit' v2025.6.2-11 "$(merge "$edit_task")"
expect 'pin 1.2.3' v1.2.3-0     "$(merge "$pin_version")"

# Going back to `latest` lands on a release that already exists, so there is
# nothing new to publish - unless something else changed along with it.
scenario 'Unpinning back to latest'
merge "$pin_version" > /dev/null
expect 'unpin' '' "$(merge "$unpin_version")"

scenario 'Unpinning back to latest, with a change'
merge "$pin_version" > /dev/null
expect 'unpin' v2025.6.2-11 "$(merge "$unpin_version && $edit_task")"

# -9 must not be read as the newest release when -10 exists. This repository is
# already past that boundary, so a lexicographic sort would tag on top of an
# existing release here rather than after it.
scenario 'Release numbers past 9'
expect 'a task' v2025.6.2-11 "$(merge "$edit_task")"

# The zero-padded `v2025.06.02-N` tags this repository started out with are a
# different prefix than the `v2025.6.2-N` series that replaced them. Reading a
# release number out of them would produce `v2025.6.2-2`, which was published
# more than a year ago.
scenario 'The zero-padded tags from before the naming settled'
expect 'a task' v2025.6.2-11 "$(merge "$edit_task")"

# A change to meta/main.yml is a change to the role: it is what tells Ansible
# and ansible-lint how to place it.
scenario 'A change to the role metadata'
expect 'meta' v2025.6.2-11 "$(merge "mkdir -p meta && printf 'galaxy_info:\n' > meta/main.yml")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
