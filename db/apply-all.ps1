<#
    Apply every migration, in order, to a running database.

        pwsh -File db/apply-all.ps1
        pwsh -File db/apply-all.ps1 -MysqlPath "D:\path\to\mysql.exe"

    ORDER MATTERS, and it is the directory numbering:

      1-tuning/   rates, loot, stack sizes, gathering yield, professions. Broad UPDATEs
                  against stock Turtle data.
      2-setup/    custom NPCs - trainers, questgivers, the supplier - and RBAC. These add
                  rows, so they want the tuning already in place.
      3-content/  new spells, items, recipes and shields. 00-remove-old-ids.sql must run
                  first, which the numeric prefix guarantees.

    Every file is IDEMPOTENT by design: re-running the whole set is a no-op, not a
    duplication. That is what makes this safe to use as the rebuild path rather than
    restoring a database dump.
#>
param(
    [string]$MysqlPath = "D:\Games\turtlewow\tortoise-oneclick-compiler\DB\bin\mysql.exe",
    [string]$MysqlHost = "127.0.0.1",
    [int]   $Port      = 3307,
    [string]$User      = "mangos",
    [string]$Password  = "mangos"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $MysqlPath)) { throw "mysql.exe not found at $MysqlPath - pass -MysqlPath" }

# Fail fast rather than half-applying against a database that is not up.
& $MysqlPath "-h$MysqlHost" "-P$Port" "-u$User" "-p$Password" -e "SELECT 1" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "cannot reach the database - is MySQL running on port $Port?" }

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$applied = 0; $failed = @()

foreach ($dir in @("1-tuning", "2-setup", "3-content")) {
    $path = Join-Path $root $dir
    if (-not (Test-Path $path)) { continue }
    Write-Host "`n== $dir ==" -ForegroundColor Cyan
    foreach ($f in Get-ChildItem -Path $path -Filter *.sql | Sort-Object Name) {
        Write-Host ("  {0,-46}" -f $f.Name) -NoNewline
        $out = & $MysqlPath "-h$MysqlHost" "-P$Port" "-u$User" "-p$Password" -e "source $($f.FullName)" 2>&1
        if ($LASTEXITCODE -eq 0) { Write-Host " ok" -ForegroundColor Green; $applied++ }
        else { Write-Host " FAILED" -ForegroundColor Red; $failed += $f.Name; Write-Host "      $out" }
    }
}

Write-Host "`n$applied applied, $($failed.Count) failed"
if ($failed.Count) { $failed | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }; exit 1 }
