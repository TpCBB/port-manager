#!/bin/zsh
set -eu
task_root="${0:A:h:h}"
mkdir -p "$task_root/dist"
xcrun swiftc -swift-version 5 -parse-as-library \
  "$task_root/Sources/PortService.swift" "$task_root/Sources/ProcessOrigin.swift" "$task_root/Tests/PortServiceTests.swift" \
  -o "$task_root/dist/PortServiceTests"
"$task_root/dist/PortServiceTests"
