param(
    [string]$errFile = ".flatten_errors"
)

if (Test-Path $errFile) {
    Write-Host "$errFile already exists. Overwrite the existing file and continue?" -ForegroundColor Yellow
    $continue = Read-Host "(y/n): " 
    switch ($continue) { 
        Y { 
            Write-host "Yes, Overwrite and continue"; 
            "" | Out-File $errFile 
        } 
        N { Write-Host "No, Exit"; exit } 
        Default { Write-Host "Default, Exit"; exit } 
    } 
}

$success = $true
$wd = $pwd.Path

Write-Output "flattening $wd"

$dirs = gci -Attributes D
$stuffInDirs = $dirs |% { gci -r "$($_.FullName)" -Attributes !D }

$stuffInDirs |% {
    $src = $_.FullName
    $dst = [System.IO.Path]::Combine($wd, $_.Name)
    try {
        mv "$src" "$dst" -ErrorAction "Stop"
    } catch {
        $success = $false
        "Couldn't move '$src' to '$dst'..." | Out-File $errFile -Append
        $_.Exception.Message | Out-File $errFile -Append
        "" | Out-File $errFile -Append
    }
}

if ($success) {
    "Flattened $wd successfully"
} else {
    "Encountered errors while flattening $wd; see $errFile for details."
}
