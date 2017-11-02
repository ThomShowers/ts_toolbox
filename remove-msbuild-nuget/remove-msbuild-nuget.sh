#!/usr/bin/env sh

##
# Removes the MSBuild NuGet target from all CSPROJ files in the specified directory.
##

IFS=$'\n'

for csproj in `find $1 -name *csproj`; do

    tmp="$csproj.tmp"
    
    awk '
        /<Import\s+Project="\$\(SolutionDir\)\\\.nuget\\NuGet\.targets"/ { inNuGetTarget = 1 }
        inNuGetTarget {
            if ( /<\/Target>/ ) {
                inNuGetTarget = 0
            } 
            { next }
        } 
        { print }' "$csproj" > "$tmp"

    mv "$tmp" "$csproj"

done
