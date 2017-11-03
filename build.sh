#!/usr/bin/env sh

DIR=`dirname $0`

# Install msi-file-report
cp "$DIR/msi-file-report/msi-file-report.ps1" "$DIR/bin/"

# Install remove-msbuild-nuget
cp "$DIR/remove-msbuild-nuget/remove-msbuild-nuget.sh" "$DIR/bin/"
