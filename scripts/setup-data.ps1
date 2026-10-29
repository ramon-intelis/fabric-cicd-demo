# Creates the demo data layer: one Lakehouse per stage in the dedicated data
# workspaces ("Oceaneering Demo Data - *"), loaded with a synthetic "sales" Delta
# table. Data workspaces are outside the deployment pipeline and Git.
# Prereq: scripts/setup-fabric.ps1 already ran; fab logged in.

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path $PSScriptRoot -Parent
$DataDir  = Join-Path $RepoRoot 'data'

$Envs = @(
    @{ Stage = 'Development'; Workspace = 'Oceaneering Demo Data - Dev';  Lakehouse = 'lh_demo_dev';  Label = 'DEV';  Scale = 1;   Seed = 101 }
    @{ Stage = 'QA';          Workspace = 'Oceaneering Demo Data - QA';   Lakehouse = 'lh_demo_qa';   Label = 'QA';   Scale = 10;  Seed = 202 }
    @{ Stage = 'Production';  Workspace = 'Oceaneering Demo Data - Prod'; Lakehouse = 'lh_demo_prod'; Label = 'PROD'; Scale = 100; Seed = 303 }
)
$Regions  = 'Gulf of Mexico', 'North Sea', 'Brazil', 'West Africa', 'Asia Pacific'
$Products = 'ROV Services', 'Subsea Products', 'Offshore Projects', 'Integrity Management'

# 1. Synthetic CSVs: 12 months x 5 regions = 60 rows per stage.
#    Amounts scale by stage (DEV ~1k-10k, QA ~10k-100k, PROD ~100k-1M) so each env is obvious in reports.
New-Item -ItemType Directory -Force $DataDir | Out-Null
$inv = [Globalization.CultureInfo]::InvariantCulture
foreach ($e in $Envs) {
    $rng  = New-Object System.Random $e.Seed
    $rows = foreach ($m in 1..12) {
        for ($r = 0; $r -lt $Regions.Count; $r++) {
            [pscustomobject]@{
                month     = '2025-{0:D2}' -f $m
                region    = $Regions[$r]
                product   = $Products[($m + $r) % $Products.Count]
                amount    = ([math]::Round((1000 + $rng.NextDouble() * 9000) * $e.Scale, 2)).ToString('0.00', $inv)
                env_label = $e.Label
            }
        }
    }
    $csv = Join-Path $DataDir "sales_$($e.Label.ToLower()).csv"
    $rows | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } |
        Set-Content -Path $csv -Encoding ascii
    Write-Host "Wrote $csv ($($rows.Count) rows)"
}

# 2. Lakehouses + 3. load CSV -> Delta table "sales"
foreach ($e in $Envs) {
    $lh  = "$($e.Workspace).Workspace/$($e.Lakehouse).Lakehouse"
    $csv = Join-Path $DataDir "sales_$($e.Label.ToLower()).csv"
    $remoteCsv = "$lh/Files/raw/sales_$($e.Label.ToLower()).csv"

    if ("$(fab exists $lh)".Trim() -notmatch 'true') { fab mkdir $lh }
    if ("$(fab exists "$lh/Files/raw")".Trim() -notmatch 'true') { fab mkdir "$lh/Files/raw" }
    fab cp $csv $remoteCsv -f
    fab table load "$lh/Tables/sales" --file $remoteCsv --mode overwrite
}

# 4. Summary: SQL analytics endpoint per lakehouse
$Envs | ForEach-Object {
    $lh = "$($_.Workspace).Workspace/$($_.Lakehouse).Lakehouse"
    $sql = fab get $lh -q properties.sqlEndpointProperties | ConvertFrom-Json
    [pscustomobject]@{
        Stage     = $_.Stage
        Workspace = $_.Workspace
        Lakehouse = $_.Lakehouse
        SqlServer = $sql.connectionString
        Database  = $_.Lakehouse
    }
} | Format-Table -AutoSize | Out-String -Width 300
