###
# Generates a line based report of the files contained within an MSI and their sizes. 
# 
# TODO: Make this a module
##

param (
    [Parameter(Mandatory=$True,Position=1)]
    [string]$msi
)

$MsiOpenDatabase = @'
[DllImport("Msi.dll", CharSet = CharSet.Unicode)]
public static extern uint MsiOpenDatabase(string szDatabasePath, string szPersist, ref ulong phDatabase);
'@

$MsiCloseHandle = @'
[DllImport("Msi.dll", CharSet = CharSet.Unicode)]
public static extern uint MsiCloseHandle(ulong hAny);
'@

$MsiDatabaseOpenView = @'
[DllImport("Msi.dll", CharSet = CharSet.Unicode)]
public static extern uint MsiDatabaseOpenView(ulong hDatabase, string szQuery, ref ulong phView);
'@

$MsiViewExecute = @'
[DllImport("Msi.dll", CharSet = CharSet.Unicode)]
public static extern uint MsiViewExecute(ulong hView, ulong hRecord);
'@

$MsiCreateRecord = @'
[DllImport("Msi.dll", CharSet = CharSet.Unicode)]
public static extern ulong MsiCreateRecord(uint cParams);
'@

$MsiViewFetch = @'
[DllImport("Msi.dll", CharSet = CharSet.Unicode)]
public static extern uint MsiViewFetch(ulong hView, ref ulong phRecord);
'@

$MsiRecordGetString = @'
[DllImport("Msi.dll", CharSet = CharSet.Unicode)]
public static extern uint MsiRecordGetString(ulong hRecord, uint iField, byte[] szValueBuf, ref int pcchValueBuf);
'@

$MsiDLL = Add-Type -MemberDefinition $MsiRecordGetString, $MsiViewFetch, $MsiCreateRecord, $MsiOpenDatabase, $MsiCloseHandle, $MsiDatabaseOpenView, $MsiViewExecute -Name 'MsiDLL' -Namespace 'MsiDLL' -PassThru

$msiPath = (Get-Item $msi).FullName

[System.Uint64]$hDatabase = 0
$error = $MsiDLL::MsiOpenDatabase($msiPath, "MSIDBOPEN_READONLY", [ref]$hDatabase);
if ($error -ne 0) {
    Write-Error ("Failed to open database: {0}" -f $error)
    exit
}

[System.Uint64]$hView = 0
$error = $MsiDLL::MsiDatabaseOpenView(
    $hDatabase,
    "SELECT FileName, FileSize FROM File",
    [ref]$hView);
if ($error -ne 0) {
    Write-Error ("Failed to open view for query: {0}" -f $error)
    $error = $MsiDLL::MsiCLoseHandle($hDatabase)
    if ($error -ne 0) {
        Write-Error ("Failed to close database handle: {0}" -f $error)
    }
    exit
}

$error = $MsiDLL::MsiViewExecute($hView, 0)
if ($error -ne 0) {
    Write-Error ("Failed to execute view for query: {0}" -f $error)
    $error = $MsiDLL::MsiCLoseHandle($hView)
    if ($error -ne 0) {
        Write-Error ("Failed to close database handle: {0}" -f $error)
    }
    $error = $MsiDLL::MsiCLoseHandle($hDatabase)
    if ($error -ne 0) {
        Write-Error ("Failed to close database handle: {0}" -f $error)
    }
    exit
}

$record = $MsiDLL::MsiCreateRecord(2)
if (!($record)) {
    Write-Error ("Failed to create record for query results.")
    $error = $MsiDLL::MsiCLoseHandle($hView)
    if ($error -ne 0) {
        Write-Error ("Failed to close database handle: {0}" -f $error)
    }
    $error = $MsiDLL::MsiCLoseHandle($hDatabase)
    if ($error -ne 0) {
        Write-Error ("Failed to close database handle: {0}" -f $error)
    }
    exit
}

do {

    $result = $MsiDLL::MsiViewFetch($hView, [ref]$record);

    if ($result -eq 0) {

        $buffer = [System.Byte[]]::CreateInstance([byte], 256)
        $bufferSize = 255;

        $error = $MsiDLL::MsiRecordGetString($record, 1, $buffer, [ref]$bufferSize)

        if ($error -eq 0) {
            
            $fileName = [System.Text.Encoding]::Unicode.Getstring($buffer, 0, $bufferSize * 2)
            # MSI database uses the format <8.3>|<name> for names that don't fit 8.3
            if ($fileName[12] -eq '|') { $fileName = $fileName.Substring(13) }
            $buffer.Clear()
            $bufferSize = $buffer.Length
            
            $error = $MsiDLL::MsiRecordGetString($record, 2, $buffer, [ref]$bufferSize)
        }
        
        if ($error -eq 0) {

            $fileSize = [System.Text.Encoding]::Unicode.Getstring($buffer, 0, $bufferSize * 2)
            $buffer.Clear()
            $bufferSize = $buffer.Length

            Write-Output ("{0},{1:N0}KB" -f $fileName, $fileSize)
        }
    }
    
} while ($result -eq 0)

if ($result -ne 259) { # ERROR_NO_MORE_ITEMS
    Write-Error ("Failed to fetch record from query results: {0}" -f $error)
}

$error = $MsiDLL::MsiCLoseHandle($record)
if ($error -ne 0) {
    Write-Warning ("Failed to close database handle: {0}" -f $error)
}

$error = $MsiDLL::MsiCLoseHandle($hView)
if ($error -ne 0) {
    Write-Warning ("Failed to close database handle: {0}" -f $error)
}

$error = $MsiDLL::MsiCLoseHandle($hDatabase)
if ($error -ne 0) {
    Write-Warning ("Failed to close database handle: {0}" -f $error)
}
