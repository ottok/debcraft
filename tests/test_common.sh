#!/bin/bash

# Common test setup and utilities
oneTimeSetUp() {
    # Setup that happens once before all tests
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    
    # Source common functions that will be tested
    # shellcheck source=../src/build.inc.sh
    . "${PROJECT_ROOT}/src/build.inc.sh"

    # Create a temporary directory for all tests
    TESTS_TMP_DIR="$(mktemp -d)"
}

oneTimeTearDown() {
    # Cleanup after all tests complete
    rm -rf "${TESTS_TMP_DIR}"
}

setUp() {
    # Setup that happens before each test
    TEST_DIR="$(mktemp -d -p "${TESTS_TMP_DIR}")"
    OLD_PWD="${PWD}"
    cd "${TEST_DIR}" || exit 1
}

tearDown() {
    # Cleanup after each test
    cd "${OLD_PWD}" || exit 1
    rm -rf "${TEST_DIR}"
}

# Helper functions for tests
create_mock_source_dir() {
    mkdir -p "${TEST_DIR}/source"
    echo "mock content" > "${TEST_DIR}/source/testfile"
}

assert_dir_exists() {
    assertTrue "Directory $1 should exist" "[ -d '$1' ]"
}

assert_dir_empty() {
    local count
    count=$(find "$1" -mindepth 1 -maxdepth 1 | wc -l)
    assertEquals "Directory $1 should be empty" "0" "${count}"
}
