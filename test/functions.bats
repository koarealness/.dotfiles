#!/usr/bin/env bats

setup() {
	# Ensure we reference the repository root even when running in temporary directories.
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	ORIGINAL_PATH="$PATH"
	ORIGINAL_PWD="$PWD"

	WORKDIR="$(mktemp -d)"
	BIN_DIR="${WORKDIR}/bin"
	mkdir -p "$BIN_DIR"

	# Provide only the commands targz relies on, ensuring zopfli and pigz are unavailable.
	ln -s "$(command -v tar)" "${BIN_DIR}/tar"
	ln -s "$(command -v gzip)" "${BIN_DIR}/gzip"
	ln -s "$(command -v stat)" "${BIN_DIR}/stat"
	ln -s "$(command -v rm)" "${BIN_DIR}/rm"
	ln -s "$(command -v grep)" "${BIN_DIR}/grep"

	PATH="${BIN_DIR}"

	cd "$WORKDIR"

	# shellcheck source=/dev/null
	source "${REPO_ROOT}/.functions"
}

teardown() {
	PATH="$ORIGINAL_PATH"
	cd "$ORIGINAL_PWD"
	[ -d "$WORKDIR" ] && rm -rf "$WORKDIR"
}

@test "targz creates .tar.gz and removes the intermediate .tar when zopfli and pigz are unavailable" {
	mkdir -p project
	printf "hello\n" > project/file.txt

	run targz project

	[ "$status" -eq 0 ]
	[[ "$output" == *"gzip"* ]]
	[ -f "project.tar.gz" ]
	[ ! -f "project.tar" ]
	tar -tf project.tar.gz | grep -q "project/file.txt"
}
