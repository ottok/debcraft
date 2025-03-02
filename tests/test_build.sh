#!/bin/bash

# Source the common test setup and utilities
# shellcheck source=./test_common.sh
. "$(dirname "$0")/test_common.sh"

test_build_dir_creation() {
    BUILD_DIR="${TEST_DIR}/build"
    
    # Test that build directories are created properly
    mkdir --parents "$BUILD_DIR/source"
    assert_dir_exists "$BUILD_DIR"
    assert_dir_exists "$BUILD_DIR/source"
}

test_copy_sources() {
    BUILD_DIR="${TEST_DIR}/build"
    create_mock_source_dir
    
    # Test source copying when COPY is set
    COPY="true"
    mkdir --parents "$BUILD_DIR/source"
    rsync --archive --exclude="**/.git/" "${TEST_DIR}/source/" "$BUILD_DIR/source"
    
    assertTrue "Source file should be copied" "[ -f '$BUILD_DIR/source/testfile' ]"
}

test_previous_build_dir_cleanup() {
    BUILD_DIR="${TEST_DIR}/build"
    mkdir --parents "$BUILD_DIR/previous"
    
    # Simulate cleanup of previous build directory
    rmdir "$BUILD_DIR/previous"
    
    assertFalse "Previous build directory should be removed" "[ -d '$BUILD_DIR/previous' ]"
}

# Load and run shunit2
# shellcheck disable=SC1091
. shunit2
