#!/bin/bash

# Fix the sign_in_with_apple Swift file issue
PODS_DIR="$PODS_ROOT/sign_in_with_apple/ios/Classes"
FIXED_FILE="$SRCROOT/Pods/Local/sign_in_with_apple/ios/Classes/SignInWithAppleError.swift"

if [ -f "$PODS_DIR/SignInWithAppleError.swift" ]; then
  echo "Applying fix for SignInWithAppleError.swift..."
  cp -f "$FIXED_FILE" "$PODS_DIR/SignInWithAppleError.swift"
  echo "Fixed file applied successfully!"
else
  echo "Target file not found: $PODS_DIR/SignInWithAppleError.swift"
fi 