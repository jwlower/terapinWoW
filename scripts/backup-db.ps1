<#
    Dump the databases to backup/, which is GITIGNORED.

        pwsh -File scripts/backup-db.ps1

    WHY THIS IS NOT A COMMITTED ARTEFACT
      tw_logon holds account password hashes - yours and every test account's. Committing it
      would publish credentials the moment this repo is shared, and git history keeps them
      even after a later delete. tw_char holds characters, which are personal and which your
      friends should be creating for themselves rather than receiving copies of.

      So these dumps live OUTSIDE version control. backup/ is in .gitignore; keep it that
      way. Copy the files somewhere off-machine if you want them safe.

    tw_world is NOT dumped here on purpose. Everything this project changed about it is in
    db/ as ordered, idempotent migrations - which diff properly, review properly, and
    reproduce on a stock Turtle database. A 324 MB binary blob does none of that.
#>
param(
    [string]$MysqlDumpPath = "D:\Games\turtlewow\tortoise-oneclick-compiler\DB\bin\mysqldump.exe",
    [string]$MysqlHost = "127.0.0.1",
    [int]   $Port      = 3307,
    [string]$User      = "mangos",
    [string]$Password  = "mangos"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $MysqlDumpPath)) { throw "mysqldump.exe not found at $MysqlDumpPath" }

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$dest = Join-Path $root "backup"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$stamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
foreach ($db in @("tw_char", "tw_logon")) {
    $file = Join-Path $dest "$db`_$stamp.dump.sql"
    Write-Host ("  {0,-12} -> {1}" -f $db, (Split-Path -Leaf $file))
    & $MysqlDumpPath "-h$MysqlHost" "-P$Port" "-u$User" "-p$Password" --single-transaction $db |
        Out-File -FilePath $file -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw "mysqldump failed for $db" }
}

Write-Host "`nWritten to $dest (gitignored - these must never be committed)."
