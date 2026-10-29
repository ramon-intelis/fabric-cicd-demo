# Sets up the Oceaneering demo environment in Fabric, all on the trial capacity:
# - 3 BI workspaces (Dev/QA/Prod) + a 3-stage deployment pipeline (BI items via Git + pipeline)
# - 3 data workspaces (Dev/QA/Prod) holding the stage lakehouses; NOT in the pipeline or Git
#   (lakehouses and data are created by scripts/setup-data.ps1)
# Prereq: Fabric CLI (fab) installed and logged in (`fab auth login`).

$ErrorActionPreference = 'Stop'

$CapacityName = 'Trial-20260826T231130Z-TYVxtLIaj0-_DMkJez1iqQ'
$PipelineName = 'Oceaneering Demo Pipeline'
$Stages = [ordered]@{
    'Development' = 'Oceaneering Demo - Dev'
    'QA'          = 'Oceaneering Demo - QA'
    'Production'  = 'Oceaneering Demo - Prod'
}
$DataWorkspaces = 'Oceaneering Demo Data - Dev', 'Oceaneering Demo Data - QA', 'Oceaneering Demo Data - Prod'

# 1. Available capacities
fab ls .capacities -l

# 2. BI and data workspaces on the trial capacity
foreach ($ws in @($Stages.Values) + $DataWorkspaces) {
    fab mkdir "$ws.Workspace" -P "capacityname=$CapacityName"
}

# 3. Deployment pipeline with 3 stages (no native fab command -> Fabric REST API)
$body = @{
    displayName = $PipelineName
    description = 'Dev -> QA -> Prod pipeline for the Oceaneering demo'
    stages      = @($Stages.Keys | ForEach-Object { @{ displayName = $_; description = ''; isPublic = $false } })
} | ConvertTo-Json -Depth 5
# JSON goes through a file: PowerShell 5.1 mangles embedded quotes in native-exe args
$bodyFile = Join-Path $env:TEMP 'fab-pipeline.json'
$body | Set-Content -Path $bodyFile -Encoding ascii
$pipelineId = "$(fab api -X post deploymentPipelines -i $bodyFile -q text.id)".Trim()
Write-Host "Pipeline id: $pipelineId"

$stageList = (fab api "deploymentPipelines/$pipelineId/stages" | ConvertFrom-Json).text.value

foreach ($stage in $stageList) {
    $ws = $Stages[$stage.displayName]
    $wsId = "$(fab get "$ws.Workspace" -q id)".Trim()
    $assignFile = Join-Path $env:TEMP 'fab-assign.json'
    @{ workspaceId = $wsId } | ConvertTo-Json | Set-Content -Path $assignFile -Encoding ascii
    fab api -X post "deploymentPipelines/$pipelineId/stages/$($stage.id)/assignWorkspace" -i $assignFile
    Write-Host "Assigned '$ws' -> stage '$($stage.displayName)'"
}

# Verify
fab api "deploymentPipelines/$pipelineId/stages"
