#!/bin/bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

log "Checking required executables..."
SWIFT_BIN=${SWIFT_BIN:-$(command -v swift || xcrun -f swift)} || fatal "SWIFT_BIN unset and no swift on PATH"

CURRENT_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(git -C "${CURRENT_SCRIPT_DIR}" rev-parse --show-toplevel)"
PACKAGE_NAME=$(basename "$REPO_ROOT")
TMP_DIR=$(/usr/bin/mktemp -d -p "${TMPDIR-/tmp}" "$(basename "$0").XXXXXXXXXX")
WORK_DIR="$TMP_DIR/$PACKAGE_NAME"
/bin/mkdir -p "$WORK_DIR"

git archive HEAD "${REPO_ROOT}" --format tar | tar -C "${WORK_DIR}" -xvf-

EXAMPLES_PATH="$WORK_DIR/Examples"
for EXAMPLE_PACKAGE_PATH in $(find "${EXAMPLES_PATH}" -maxdepth 2 -name Package.swift -type f -print0 | xargs -0 dirname | sort); do
    EXAMPLE_PACKAGE_NAME=$(basename "$EXAMPLE_PACKAGE_PATH")
    log "Building example package: ${EXAMPLE_PACKAGE_NAME}"
    "${SWIFT_BIN}" build --build-tests \
        --package-path "${EXAMPLE_PACKAGE_PATH}" \
        --skip-update
    log "✅ Successfully built the example package ${EXAMPLE_PACKAGE_NAME}."

    if [ -d "${EXAMPLE_PACKAGE_PATH}/Tests" ]; then
        log "Running tests for example package: ${EXAMPLE_PACKAGE_NAME}"
        "${SWIFT_BIN}" test \
            --package-path "${EXAMPLE_PACKAGE_PATH}" \
            --skip-update
        log "✅ Passed the tests for the example package ${EXAMPLE_PACKAGE_NAME}."
    fi
done
