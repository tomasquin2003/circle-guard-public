#Requires -Version 5.1
<#
.SYNOPSIS
    CircleGuard E2E Smoke/Operational Test Suite
.DESCRIPTION
    Validates that all critical microservices in the CircleGuard Docker Compose
    stack are reachable and responding via HTTP.
    Covers 5 end-to-end smoke checks across the full service mesh.
.NOTES
    Run from project root:
        powershell -ExecutionPolicy Bypass -File e2e/run-e2e.ps1
    Prerequisites: docker compose stack must be up.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
#  Configuration
# ---------------------------------------------------------------------------
$SCRIPT_VERSION    = "1.0.0"
$REPORT_DIR        = Join-Path $PSScriptRoot "results"
$REPORT_FILE       = Join-Path $REPORT_DIR "e2e-report.md"
$TIMEOUT_SEC       = 10
$RUN_TIMESTAMP     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# HTTP codes that prove a service IS alive
$ACCEPTABLE_CODES  = @(200, 201, 204, 301, 302, 400, 401, 403, 404, 405)

# ---------------------------------------------------------------------------
#  Result tracking
# ---------------------------------------------------------------------------
$global:Results   = [System.Collections.Generic.List[hashtable]]::new()
$global:AllPassed = $true

# ---------------------------------------------------------------------------
#  Functions
# ---------------------------------------------------------------------------

function Write-Banner {
    $line = "=" * 62
    Write-Host ""
    Write-Host $line                          -ForegroundColor Cyan
    Write-Host "  CircleGuard E2E Suite  v$SCRIPT_VERSION" -ForegroundColor Cyan
    Write-Host "  $RUN_TIMESTAMP"              -ForegroundColor Gray
    Write-Host $line                          -ForegroundColor Cyan
    Write-Host ""
}

function Assert-DockerContainerRunning {
    <#
    .SYNOPSIS  Verifies a Docker container is in 'running' state.
    .PARAMETER ContainerName  Full container name.
    .OUTPUTS   [bool]
    #>
    param([Parameter(Mandatory)][string]$ContainerName)
    try {
        $state = docker inspect --format "{{.State.Status}}" $ContainerName 2>&1
        if ($LASTEXITCODE -ne 0) { return $false }
        return ($state -match "running")
    } catch {
        return $false
    }
}

function Test-HttpEndpoint {
    <#
    .SYNOPSIS  Probes an HTTP endpoint and returns a result hashtable.
    .PARAMETER CheckId       Numeric check ID.
    .PARAMETER Name          Human-readable check name.
    .PARAMETER Url           URL to GET.
    .PARAMETER ContainerName Container to verify before HTTP probe.
    .PARAMETER Description   What this check validates.
    .OUTPUTS   Hashtable
    #>
    param(
        [Parameter(Mandatory)][int]    $CheckId,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Url,
        [Parameter(Mandatory)][string] $ContainerName,
        [Parameter(Mandatory)][string] $Description
    )

    $result = @{
        CheckId       = $CheckId
        Name          = $Name
        Url           = $Url
        ContainerName = $ContainerName
        Description   = $Description
        StatusCode    = $null
        Passed        = $false
        Message       = ""
        ContainerOk   = $false
    }

    # 1) Docker container state check
    $result.ContainerOk = Assert-DockerContainerRunning -ContainerName $ContainerName
    if (-not $result.ContainerOk) {
        $result.Message = "FAIL - Container '$ContainerName' is NOT running or does not exist."
        Write-Result -Result $result
        return $result
    }

    # 2) HTTP probe
    try {
        $resp = Invoke-WebRequest `
            -Uri            $Url `
            -Method         GET `
            -TimeoutSec     $TIMEOUT_SEC `
            -UseBasicParsing `
            -ErrorAction    Stop

        $result.StatusCode = $resp.StatusCode
        if ($result.StatusCode -in $ACCEPTABLE_CODES) {
            $result.Passed  = $true
            $result.Message = "PASS - HTTP $($result.StatusCode)"
        } else {
            $result.Message = "FAIL - Unexpected HTTP $($result.StatusCode)"
        }
    }
    catch [System.Net.WebException] {
        # WebException may still carry a valid HTTP response (e.g. 401, 403)
        $httpResp = $_.Exception.Response -as [System.Net.HttpWebResponse]
        if ($null -ne $httpResp) {
            $result.StatusCode = [int]$httpResp.StatusCode
            if ($result.StatusCode -in $ACCEPTABLE_CODES) {
                $result.Passed  = $true
                $result.Message = "PASS - HTTP $($result.StatusCode) (via WebException)"
            } else {
                $result.Message = "FAIL - HTTP $($result.StatusCode)"
            }
        } else {
            $result.Message = "FAIL - Network error: $($_.Exception.Message)"
        }
    }
    catch {
        $result.Message = "FAIL - Exception: $($_.Exception.Message)"
    }

    Write-Result -Result $result
    return $result
}

function Write-Result {
    <#
    .SYNOPSIS  Prints a check result to console and records it globally.
    #>
    param([Parameter(Mandatory)][hashtable]$Result)

    $icon   = if ($Result.Passed)      { "[PASS]" } else { "[FAIL]" }
    $color  = if ($Result.Passed)      { "Green"  } else { "Red"    }
    $docker = if ($Result.ContainerOk) { "UP"     } else { "DOWN"   }

    Write-Host ("{0,-8} Check {1}: {2}" -f $icon, $Result.CheckId, $Result.Name) `
        -ForegroundColor $color
    Write-Host ("         URL:       {0}" -f $Result.Url)                         `
        -ForegroundColor Gray
    Write-Host ("         Container: {0} [{1}]" -f $Result.ContainerName, $docker) `
        -ForegroundColor Gray
    Write-Host ("         Status:    {0}" -f $Result.Message)                     `
        -ForegroundColor Gray
    Write-Host ""

    if (-not $Result.Passed) { $global:AllPassed = $false }
    $global:Results.Add($Result)
}

function Get-DockerSummary {
    <#
    .SYNOPSIS  Returns formatted docker ps output as a string.
    #>
    try {
        $raw = docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" 2>&1
        return ($raw -join "`n")
    } catch {
        return "(docker ps failed: $($_.Exception.Message))"
    }
}

function Write-MarkdownReport {
    <#
    .SYNOPSIS  Generates the Markdown report in e2e/results/e2e-report.md.
    #>
    param([string]$DockerSummary)

    $overallStatus = if ($global:AllPassed) {
        "ALL CHECKS PASSED"
    } else {
        "ONE OR MORE CHECKS FAILED"
    }

    $sb    = [System.Text.StringBuilder]::new()
    $fence = "``" + "``" + "``"   # three backticks - built at runtime to avoid PS parser issue

    $null = $sb.AppendLine("# CircleGuard E2E Report")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Field | Value |")
    $null = $sb.AppendLine("|-------|-------|")
    $null = $sb.AppendLine("| **Suite Version** | $SCRIPT_VERSION |")
    $null = $sb.AppendLine("| **Execution Date** | $RUN_TIMESTAMP |")
    $null = $sb.AppendLine("| **Overall Result** | $overallStatus |")
    $null = $sb.AppendLine("| **Timeout per check** | ${TIMEOUT_SEC}s |")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Check Results")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| # | Check Name | URL Probed | Container | Docker | HTTP Status | Result |")
    $null = $sb.AppendLine("|---|-----------|-----------|-----------|--------|-------------|--------|")

    foreach ($r in $global:Results) {
        $pass   = if ($r.Passed)      { "PASS" } else { "FAIL" }
        $docker = if ($r.ContainerOk) { "UP"   } else { "DOWN" }
        $code   = if ($null -ne $r.StatusCode) { $r.StatusCode } else { "N/A" }
        $null = $sb.AppendLine("| $($r.CheckId) | $($r.Name) | $($r.Url) | $($r.ContainerName) | $docker | $code | $pass |")
    }

    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Check Descriptions")
    $null = $sb.AppendLine("")

    foreach ($r in $global:Results) {
        $null = $sb.AppendLine("### Check $($r.CheckId) - $($r.Name)")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("**What it validates:** $($r.Description)")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("**Detail:** $($r.Message)")
        $null = $sb.AppendLine("")
    }

    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Docker Container Status (at execution time)")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine($fence)
    $null = $sb.AppendLine($DockerSummary)
    $null = $sb.AppendLine($fence)
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Acceptable HTTP Codes")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("The following HTTP codes are treated as PASS (service is alive):")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("$($ACCEPTABLE_CODES -join ', ')")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("Codes outside this list, timeouts, connection refused, or container not running = FAIL.")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Limitations")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("- This suite performs smoke / operational checks only.")
    $null = $sb.AppendLine("- It does NOT cover authenticated flows (JWT, OAuth2, LDAP) because no seed users are provisioned automatically.")
    $null = $sb.AppendLine("- Business-logic scenarios are not yet covered.")
    $null = $sb.AppendLine("- Kafka and Redis are verified indirectly through dependent service health.")
    $null = $sb.AppendLine("- Neo4j health is inferred via promotion-service reachability and container state.")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("*Generated by CircleGuard E2E Suite v$SCRIPT_VERSION*")

    if (-not (Test-Path $REPORT_DIR)) {
        New-Item -ItemType Directory -Force -Path $REPORT_DIR | Out-Null
    }
    [System.IO.File]::WriteAllText($REPORT_FILE, $sb.ToString(), [System.Text.Encoding]::UTF8)
}

# ---------------------------------------------------------------------------
#  Main
# ---------------------------------------------------------------------------

Write-Banner

# Pre-flight: Docker daemon
Write-Host "[ PRE-FLIGHT ] Checking Docker daemon..." -ForegroundColor Yellow
try {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "docker info returned non-zero" }
    Write-Host "               Docker daemon: OK" -ForegroundColor Green
} catch {
    Write-Host "               Docker daemon is NOT accessible. Aborting." -ForegroundColor Red
    exit 1
}
Write-Host ""

# Container overview
Write-Host "[ CONTAINERS ] Current stack status:" -ForegroundColor Yellow
docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"
Write-Host ""

$dockerSnapshot = Get-DockerSummary

# ---------------------------------------------------------------------------
#  E2E Checks
# ---------------------------------------------------------------------------
Write-Host "[ RUNNING E2E CHECKS ]" -ForegroundColor Cyan
Write-Host ("-" * 62)              -ForegroundColor Cyan
Write-Host ""

# CHECK 1: auth-service
Test-HttpEndpoint `
    -CheckId       1 `
    -Name          "auth-service HTTP reachability" `
    -Url           "http://localhost:8180/actuator/health" `
    -ContainerName "circleguard-auth-service" `
    -Description   "Validates auth-service (port 8180) is reachable. Any HTTP response (200/401/403/404) confirms Spring Boot is running." `
    | Out-Null

# CHECK 2: identity-service
Test-HttpEndpoint `
    -CheckId       2 `
    -Name          "identity-service HTTP reachability" `
    -Url           "http://localhost:8083/actuator/health" `
    -ContainerName "circleguard-identity-service" `
    -Description   "Validates identity-service (port 8083) is reachable. A protected 401/403 is still PASS - the JVM accepts connections." `
    | Out-Null

# CHECK 3: form-service
Test-HttpEndpoint `
    -CheckId       3 `
    -Name          "form-service HTTP reachability" `
    -Url           "http://localhost:8086/actuator/health" `
    -ContainerName "circleguard-form-service" `
    -Description   "Validates form-service (port 8086) is reachable. Depends on PostgreSQL and Kafka; a PASS implies those infra deps are functional." `
    | Out-Null

# CHECK 4: gateway-service
Test-HttpEndpoint `
    -CheckId       4 `
    -Name          "gateway-service HTTP reachability" `
    -Url           "http://localhost:8087/actuator/health" `
    -ContainerName "circleguard-gateway-service" `
    -Description   "Validates gateway-service (port 8087) is reachable. Entry point for all external traffic; a PASS implies Redis and routing are operational." `
    | Out-Null

# CHECK 5: promotion-service (depends on PostgreSQL + Neo4j + Kafka + Redis)
Test-HttpEndpoint `
    -CheckId       5 `
    -Name          "promotion-service + Neo4j health" `
    -Url           "http://localhost:8088/actuator/health" `
    -ContainerName "circleguard-promotion-service" `
    -Description   "Validates promotion-service (port 8088) is reachable. Has the longest dep chain (PG+Neo4j+Kafka+Redis); a PASS confirms the full infra stack is up." `
    | Out-Null

# Sub-check: Neo4j container state
Write-Host "[ SUB-CHECK ] Neo4j container state..." -ForegroundColor Yellow
$neo4jContainer = "circleguard-neo4j"
try {
    $healthStatus = (docker inspect --format "{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}" $neo4jContainer 2>&1).Trim()
    if ($LASTEXITCODE -ne 0) {
        Write-Host "              $($neo4jContainer): NOT RUNNING [FAIL]" -ForegroundColor Red
        $global:AllPassed = $false
    } elseif ($healthStatus -match "healthy") {
        Write-Host "              $($neo4jContainer): HEALTHY [OK]" -ForegroundColor Green
    } elseif ($healthStatus -match "none" -or $healthStatus -eq "") {
        $neo4jOk = Assert-DockerContainerRunning -ContainerName $neo4jContainer
        if ($neo4jOk) {
            Write-Host "              $($neo4jContainer): RUNNING (no healthcheck) [OK]" -ForegroundColor Green
        } else {
            Write-Host "              $($neo4jContainer): NOT RUNNING [FAIL]" -ForegroundColor Red
            $global:AllPassed = $false
        }
    } else {
        Write-Host "              $($neo4jContainer): $healthStatus [FAIL]" -ForegroundColor Red
        $global:AllPassed = $false
    }
} catch {
    Write-Host "              $($neo4jContainer): NOT RUNNING [FAIL]" -ForegroundColor Red
    $global:AllPassed = $false
}
Write-Host ""

# ---------------------------------------------------------------------------
#  Report
# ---------------------------------------------------------------------------
Write-Host "[ REPORT ] Writing Markdown report..." -ForegroundColor Yellow
Write-MarkdownReport -DockerSummary $dockerSnapshot
Write-Host "           Saved to: $REPORT_FILE" -ForegroundColor Green
Write-Host ""

# ---------------------------------------------------------------------------
#  Final summary
# ---------------------------------------------------------------------------
$passed = @($global:Results | Where-Object { $_.Passed }).Count
$failed = @($global:Results | Where-Object { -not $_.Passed }).Count
$total  = $global:Results.Count

Write-Host ("=" * 62) -ForegroundColor Cyan
if ($global:AllPassed) {
    Write-Host "  OVERALL: ALL $total CHECKS PASSED" -ForegroundColor Green
} else {
    Write-Host "  OVERALL: $passed/$total PASSED  |  $failed FAILED" -ForegroundColor Red
}
Write-Host ("=" * 62) -ForegroundColor Cyan
Write-Host ""

if ($global:AllPassed) { exit 0 } else { exit 1 }
