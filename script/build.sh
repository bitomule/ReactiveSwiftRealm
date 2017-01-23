#!/bin/bash

BUILD_DIRECTORY="build"
CONFIGURATION=Release

if [[ -z $TRAVIS_XCODE_WORKSPACE ]]; then
    echo "Error: \$TRAVIS_XCODE_WORKSPACE is not set."
    exit 1
fi

if [[ -z $TRAVIS_XCODE_SCHEME ]]; then
    echo "Error: \$TRAVIS_XCODE_SCHEME is not set!"
    exit 1
fi

if [[ -z $XCODE_ACTION ]]; then
    echo "Error: \$XCODE_ACTION is not set!"
    exit 1
fi

if [[ -z $XCODE_SDK ]]; then
    echo "Error: \$XCODE_SDK is not set!"
    exit 1
fi

if [[ -z $XCODE_DESTINATION ]]; then
    echo "Error: \$XCODE_DESTINATION is not set!"
    exit 1
fi

set -o pipefail
xcodebuild $XCODE_ACTION \
    -workspace "$TRAVIS_XCODE_WORKSPACE" \
    -scheme "$TRAVIS_XCODE_SCHEME" \
    -sdk "$XCODE_SDK" \
    -destination "$XCODE_DESTINATION" \
    -derivedDataPath "${BUILD_DIRECTORY}" \
    -configuration $CONFIGURATION \
    ENABLE_TESTABILITY=YES \
    GCC_GENERATE_DEBUGGING_SYMBOLS=NO \
    RUN_CLANG_STATIC_ANALYZER=NO | xcpretty
result=$?

if [ "$result" -ne 0 ]; then
    exit $result
fi

# Compile code in playgrounds 
if [[ $XCODE_SDK = "macosx" ]]; then
    echo "SDK is $XCODE_SDK, validating playground..."
    . script/validate-playground.sh
fi