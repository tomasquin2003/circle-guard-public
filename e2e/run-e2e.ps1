#Requires -Version 5.1
<#
.SYNOPSIS
    CircleGuard hybrid E2E smoke/functional test suite.
.DESCRIPTION
    Validates operational availability of the Docker Compose stack and executes
    functional E2E checks against real REST endpoints where auth and seed data
    allow it. BLOCKED_BY_AUTH and SKIPPED_* results are documented evidence and
    do not fail the suite; critical smoke failures and functional FAIL results do.
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
$SCRIPT_VERSION = "1.1.0"
$REPORT_DIR = Join-Path $PSScriptRoot "results"
$REPORT_FILE = Join-Path $REPORT_DIR "e2e-report.md"
$TIMEOUT_SEC = 10
$RUN_TIMESTAMP = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$ACCEPTABLE_CODES = @(200, 201, 204, 301, 302, 400, 401, 403, 404, 405)
$ALLOWED_FUNCTIONAL_STATES = @("PASS", "FAIL", "BLOCKED_BY_AUTH", "SKIPPED_NO_SEED", "SKIPPED_NOT_AVAILABLE")

# ---------------------------------------------------------------------------
#  Result tracking
# ---------------------------------------------------------------------------
$global:SmokeResults = [System.Collections.Generic.List[hashtable]]::new()
$global:FunctionalResults = [System.Collections.Generic.List[hashtable]]::new()
$global:EvidenceRequests = [System.Collections.Generic.List[hashtable]]::new()
$global:AllPassed = $true
$global:Neo4jHealthStatus = "not checked"
$global:NotificationReachability = "not checked"

# ---------------------------------------------------------------------------
#  General helpers
# ---------------------------------------------------------------------------

function Write-Banner {
    $line = "=" * 62
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  CircleGuard E2E Suite  v$SCRIPT_VERSION" -ForegroundColor Cyan
    Write-Host "  $RUN_TIMESTAMP" -ForegroundColor Gray
    Write-Host $line -ForegroundColor Cyan
    Write-Host ""
}

function Escape-Markdown {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return "" }
    $text = [string]$Value
    return $text.Replace("\", "\\").Replace("|", "\|").Replace("`r", " ").Replace("`n", "<br>")
}

function ConvertTo-CompactJson {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return "" }
    if ($Value -is [string]) { return $Value }
    return ($Value | ConvertTo-Json -Depth 10 -Compress)
}

function Add-EvidenceRequest {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Url,
        [AllowNull()][object]$RequestBody,
        [AllowNull()][object]$StatusCode
    )

    $global:EvidenceRequests.Add(@{
        Name = $Name
        Method = $Method
        Url = $Url
        RequestBody = ConvertTo-CompactJson -Value $RequestBody
        StatusCode = $StatusCode
    })
}

function Assert-DockerContainerRunning {
    param([Parameter(Mandatory)][string]$ContainerName)

    try {
        $state = docker inspect --format "{{.State.Status}}" $ContainerName 2>&1
        if ($LASTEXITCODE -ne 0) { return $false }
        return ($state -match "running")
    } catch {
        return $false
    }
}

function Get-DockerSummary {
    try {
        $raw = docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" 2>&1
        return ($raw -join "`n")
    } catch {
        return "(docker ps failed: $($_.Exception.Message))"
    }
}

function Get-ResponseBodyFromWebException {
    param([Parameter(Mandatory)][System.Net.WebException]$WebException)

    $response = $WebException.Response -as [System.Net.HttpWebResponse]
    if ($null -eq $response) { return "" }

    try {
        $stream = $response.GetResponseStream()
        if ($null -eq $stream) { return "" }
        $reader = New-Object System.IO.StreamReader($stream)
        return $reader.ReadToEnd()
    } catch {
        return ""
    }
}

# ---------------------------------------------------------------------------
#  HTTP helpers
# ---------------------------------------------------------------------------

function Invoke-E2ERequest {
    <#
    .SYNOPSIS
        Executes an HTTP request and captures status, body, pass/fail and classification.
    #>
    param(
        [Parameter(Mandatory)][ValidateSet("GET", "POST")][string]$Method,
        [Parameter(Mandatory)][string]$Url,
        [AllowNull()][object]$Body = $null,
        [AllowNull()][hashtable]$Headers = $null,
        [int]$TimeoutSec = $TIMEOUT_SEC
    )

    $result = @{
        Method = $Method
        Url = $Url
        StatusCode = $null
        Body = ""
        Passed = $false
        Classification = "FAIL"
        Error = ""
    }

    $params = @{
        Uri = $Url
        Method = $Method
        TimeoutSec = $TimeoutSec
        UseBasicParsing = $true
        ErrorAction = "Stop"
    }

    if ($null -ne $Headers) {
        $params.Headers = $Headers
    }

    if ($null -ne $Body) {
        $params.ContentType = "application/json"
        $params.Body = ConvertTo-CompactJson -Value $Body
    }

    try {
        $response = Invoke-WebRequest @params
        $result.StatusCode = [int]$response.StatusCode
        $result.Body = [string]$response.Content
        if ($result.StatusCode -ge 200 -and $result.StatusCode -lt 300) {
            $result.Passed = $true
            $result.Classification = "PASS"
        }
    }
    catch [System.Net.WebException] {
        $httpResp = $_.Exception.Response -as [System.Net.HttpWebResponse]
        if ($null -ne $httpResp) {
            $result.StatusCode = [int]$httpResp.StatusCode
            $result.Body = Get-ResponseBodyFromWebException -WebException $_.Exception
            if ($result.StatusCode -eq 401 -or $result.StatusCode -eq 403) {
                $result.Classification = "BLOCKED_BY_AUTH"
            } else {
                $result.Classification = "FAIL"
            }
        } else {
            $result.Error = $_.Exception.Message
            $result.Classification = "FAIL"
        }
    }
    catch {
        $result.Error = $_.Exception.Message
        $result.Classification = "FAIL"
    }

    return $result
}

# ---------------------------------------------------------------------------
#  Smoke checks
# ---------------------------------------------------------------------------

function Write-SmokeResult {
    param([Parameter(Mandatory)][hashtable]$Result)

    $icon = if ($Result.Passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Result.Passed) { "Green" } else { "Red" }
    $docker = if ($Result.ContainerOk) { "UP" } else { "DOWN" }

    Write-Host ("{0,-8} Check {1}: {2}" -f $icon, $Result.CheckId, $Result.Name) -ForegroundColor $color
    Write-Host ("         URL:       {0}" -f $Result.Url) -ForegroundColor Gray
    Write-Host ("         Container: {0} [{1}]" -f $Result.ContainerName, $docker) -ForegroundColor Gray
    Write-Host ("         Status:    {0}" -f $Result.Message) -ForegroundColor Gray
    Write-Host ""

    if (-not $Result.Passed) { $global:AllPassed = $false }
    $global:SmokeResults.Add($Result)
}

function Test-HttpEndpoint {
    param(
        [Parameter(Mandatory)][int]$CheckId,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$ContainerName,
        [Parameter(Mandatory)][string]$Description
    )

    $result = @{
        CheckId = $CheckId
        Name = $Name
        Url = $Url
        ContainerName = $ContainerName
        Description = $Description
        StatusCode = $null
        Passed = $false
        Message = ""
        ContainerOk = $false
    }

    $result.ContainerOk = Assert-DockerContainerRunning -ContainerName $ContainerName
    if (-not $result.ContainerOk) {
        $result.Message = "FAIL - Container '$ContainerName' is NOT running or does not exist."
        Write-SmokeResult -Result $result
        return $result
    }

    $response = Invoke-E2ERequest -Method GET -Url $Url -TimeoutSec $TIMEOUT_SEC
    $result.StatusCode = $response.StatusCode
    if ($null -ne $result.StatusCode -and $result.StatusCode -in $ACCEPTABLE_CODES) {
        $result.Passed = $true
        $result.Message = "PASS - HTTP $($result.StatusCode)"
    } elseif ($response.Error -ne "") {
        $result.Message = "FAIL - Network error: $($response.Error)"
    } else {
        $result.Message = "FAIL - Unexpected HTTP $($result.StatusCode)"
    }

    Write-SmokeResult -Result $result
    return $result
}

function Test-Neo4jHealth {
    $neo4jContainer = "circleguard-neo4j"
    $result = @{
        Container = $neo4jContainer
        Passed = $false
        Status = "unknown"
        Message = ""
    }

    try {
        $healthStatus = (docker inspect --format "{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}" $neo4jContainer 2>&1).Trim()
        if ($LASTEXITCODE -ne 0) {
            $result.Status = "not running"
            $result.Message = "${neo4jContainer}: NOT RUNNING"
        } elseif ($healthStatus -match "healthy") {
            $result.Passed = $true
            $result.Status = "healthy"
            $result.Message = "${neo4jContainer}: HEALTHY"
        } elseif ($healthStatus -match "none" -or $healthStatus -eq "") {
            if (Assert-DockerContainerRunning -ContainerName $neo4jContainer) {
                $result.Passed = $true
                $result.Status = "running (no healthcheck)"
                $result.Message = "${neo4jContainer}: RUNNING (no healthcheck)"
            } else {
                $result.Status = "not running"
                $result.Message = "${neo4jContainer}: NOT RUNNING"
            }
        } else {
            $result.Status = $healthStatus
            $result.Message = "${neo4jContainer}: $healthStatus"
        }
    } catch {
        $result.Status = "error"
        $result.Message = "${neo4jContainer}: $($_.Exception.Message)"
    }

    $global:Neo4jHealthStatus = $result.Status
    return $result
}

function Test-NotificationReachability {
    $url = "http://localhost:8082/actuator/health"
    $response = Invoke-E2ERequest -Method GET -Url $url -TimeoutSec $TIMEOUT_SEC
    Add-EvidenceRequest -Name "notification-service HTTP reachability (additional smoke evidence)" -Method "GET" -Url $url -RequestBody $null -StatusCode $response.StatusCode

    if ($null -ne $response.StatusCode -and $response.StatusCode -in $ACCEPTABLE_CODES) {
        $global:NotificationReachability = "HTTP $($response.StatusCode) - reachable"
    } elseif ($response.Error -ne "") {
        $global:NotificationReachability = "network error - $($response.Error)"
    } else {
        $global:NotificationReachability = "unexpected HTTP $($response.StatusCode)"
    }
}

# ---------------------------------------------------------------------------
#  Functional checks
# ---------------------------------------------------------------------------

function Write-FunctionalResult {
    param(
        [Parameter(Mandatory)][string]$Flow,
        [Parameter(Mandatory)][string]$Endpoints,
        [Parameter(Mandatory)][ValidateSet("PASS", "FAIL", "BLOCKED_BY_AUTH", "SKIPPED_NO_SEED", "SKIPPED_NOT_AVAILABLE")][string]$Status,
        [AllowNull()][object]$HttpStatus = $null,
        [Parameter(Mandatory)][string]$Explanation,
        [AllowNull()][object]$RequestBodies = $null
    )

    $result = @{
        Flow = $Flow
        Endpoints = $Endpoints
        Status = $Status
        Classification = $Status
        HttpStatus = $HttpStatus
        Passed = ($Status -eq "PASS")
        CriticalFailure = ($Status -eq "FAIL")
        Explanation = $Explanation
        RequestBodies = ConvertTo-CompactJson -Value $RequestBodies
    }

    $icon = switch ($Status) {
        "PASS" { "[PASS]" }
        "FAIL" { "[FAIL]" }
        "BLOCKED_BY_AUTH" { "[AUTH]" }
        "SKIPPED_NO_SEED" { "[SKIP]" }
        "SKIPPED_NOT_AVAILABLE" { "[SKIP]" }
    }

    $color = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "BLOCKED_BY_AUTH" { "Yellow" }
        default { "DarkYellow" }
    }

    Write-Host ("{0,-8} {1}" -f $icon, $Flow) -ForegroundColor $color
    Write-Host ("         Endpoint(s): {0}" -f $Endpoints) -ForegroundColor Gray
    Write-Host ("         Status:      {0}" -f $Status) -ForegroundColor Gray
    Write-Host ("         Detail:      {0}" -f $Explanation) -ForegroundColor Gray
    Write-Host ""

    if ($result.CriticalFailure) { $global:AllPassed = $false }
    $global:FunctionalResults.Add($result)
}

function Test-FunctionalIdentityMapLookup {
    $realIdentity = "e2e-user@circleguard.test"
    $mapUrl = "http://localhost:8083/api/v1/identities/map"
    $body = @{ realIdentity = $realIdentity }

    $mapResponse = Invoke-E2ERequest -Method POST -Url $mapUrl -Body $body -TimeoutSec $TIMEOUT_SEC
    Add-EvidenceRequest -Name "Identity map" -Method "POST" -Url $mapUrl -RequestBody $body -StatusCode $mapResponse.StatusCode

    if ($mapResponse.StatusCode -ne 200) {
        Write-FunctionalResult `
            -Flow "Identity map/lookup" `
            -Endpoints "POST /api/v1/identities/map; GET /api/v1/identities/lookup/{id}" `
            -Status "FAIL" `
            -HttpStatus $mapResponse.StatusCode `
            -Explanation "The public identity map endpoint should create or reuse an anonymousId, but returned HTTP $($mapResponse.StatusCode)." `
            -RequestBodies $body
        return
    }

    try {
        $parsed = $mapResponse.Body | ConvertFrom-Json
        $anonymousId = [string]$parsed.anonymousId
    } catch {
        $anonymousId = ""
    }

    if ([string]::IsNullOrWhiteSpace($anonymousId)) {
        Write-FunctionalResult `
            -Flow "Identity map/lookup" `
            -Endpoints "POST /api/v1/identities/map; GET /api/v1/identities/lookup/{id}" `
            -Status "FAIL" `
            -HttpStatus $mapResponse.StatusCode `
            -Explanation "Identity map returned HTTP 200 but did not include anonymousId in the JSON body." `
            -RequestBodies $body
        return
    }

    $lookupUrl = "http://localhost:8083/api/v1/identities/lookup/$anonymousId"
    $lookupResponse = Invoke-E2ERequest -Method GET -Url $lookupUrl -TimeoutSec $TIMEOUT_SEC
    Add-EvidenceRequest -Name "Identity lookup" -Method "GET" -Url $lookupUrl -RequestBody $null -StatusCode $lookupResponse.StatusCode

    if ($lookupResponse.StatusCode -eq 401 -or $lookupResponse.StatusCode -eq 403) {
        Write-FunctionalResult `
            -Flow "Identity map/lookup" `
            -Endpoints "POST /api/v1/identities/map; GET /api/v1/identities/lookup/$anonymousId" `
            -Status "BLOCKED_BY_AUTH" `
            -HttpStatus "POST 200 / GET $($lookupResponse.StatusCode)" `
            -Explanation "POST created anonymousId '$anonymousId'. Lookup is correctly protected by Spring Security without a JWT containing identity:lookup." `
            -RequestBodies $body
        return
    }

    if ($lookupResponse.StatusCode -eq 200) {
        try {
            $lookupBody = $lookupResponse.Body | ConvertFrom-Json
            if ([string]$lookupBody.realIdentity -eq $realIdentity) {
                Write-FunctionalResult `
                    -Flow "Identity map/lookup" `
                    -Endpoints "POST /api/v1/identities/map; GET /api/v1/identities/lookup/$anonymousId" `
                    -Status "PASS" `
                    -HttpStatus "POST 200 / GET 200" `
                    -Explanation "Identity was mapped and lookup returned the expected realIdentity." `
                    -RequestBodies $body
            } else {
                Write-FunctionalResult `
                    -Flow "Identity map/lookup" `
                    -Endpoints "POST /api/v1/identities/map; GET /api/v1/identities/lookup/$anonymousId" `
                    -Status "FAIL" `
                    -HttpStatus "POST 200 / GET 200" `
                    -Explanation "Lookup returned 200 but realIdentity did not match the mapped value." `
                    -RequestBodies $body
            }
        } catch {
            Write-FunctionalResult `
                -Flow "Identity map/lookup" `
                -Endpoints "POST /api/v1/identities/map; GET /api/v1/identities/lookup/$anonymousId" `
                -Status "FAIL" `
                -HttpStatus "POST 200 / GET 200" `
                -Explanation "Lookup returned 200 but response body could not be parsed as JSON." `
                -RequestBodies $body
        }
        return
    }

    Write-FunctionalResult `
        -Flow "Identity map/lookup" `
        -Endpoints "POST /api/v1/identities/map; GET /api/v1/identities/lookup/$anonymousId" `
        -Status "FAIL" `
        -HttpStatus "POST 200 / GET $($lookupResponse.StatusCode)" `
        -Explanation "Lookup returned an unexpected HTTP status. Expected 200, 401 or 403." `
        -RequestBodies $body
}

function Test-FunctionalCertificates {
    $url = "http://localhost:8086/api/v1/certificates/pending"
    $response = Invoke-E2ERequest -Method GET -Url $url -TimeoutSec $TIMEOUT_SEC
    Add-EvidenceRequest -Name "Certificates pending" -Method "GET" -Url $url -RequestBody $null -StatusCode $response.StatusCode

    if ($response.StatusCode -eq 200) {
        $count = "unknown"
        try {
            $parsed = $response.Body | ConvertFrom-Json
            if ($null -eq $parsed) {
                $count = 0
            } elseif ($parsed -is [System.Array]) {
                $count = $parsed.Count
            } else {
                $count = 1
            }
        } catch {
            $count = "unparseable"
        }

        Write-FunctionalResult `
            -Flow "Certificates/Form pending list" `
            -Endpoints "GET /api/v1/certificates/pending" `
            -Status "PASS" `
            -HttpStatus 200 `
            -Explanation "Endpoint returned 200. Pending certificate count: $count. Empty data is valid when no seed surveys exist." `
            -RequestBodies $null
        return
    }

    if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403) {
        Write-FunctionalResult `
            -Flow "Certificates/Form pending list" `
            -Endpoints "GET /api/v1/certificates/pending" `
            -Status "BLOCKED_BY_AUTH" `
            -HttpStatus $response.StatusCode `
            -Explanation "Endpoint exists in CertificateValidationController but runtime security blocked unauthenticated access." `
            -RequestBodies $null
        return
    }

    Write-FunctionalResult `
        -Flow "Certificates/Form pending list" `
        -Endpoints "GET /api/v1/certificates/pending" `
        -Status "FAIL" `
        -HttpStatus $response.StatusCode `
        -Explanation "Endpoint exists in form-service; HTTP $($response.StatusCode) is not accepted as a functional PASS." `
        -RequestBodies $null
}

function Test-FunctionalPromotionRecovery {
    Write-FunctionalResult `
        -Flow "Promotion health recovery" `
        -Endpoints "POST /api/v1/health/recovery/{id}" `
        -Status "SKIPPED_NO_SEED" `
        -HttpStatus "N/A" `
        -Explanation "The endpoint exists and is covered by integration tests with Testcontainers, but the running E2E stack has no known seeded Neo4j user id and no HEALTH_CENTER JWT credentials. No synthetic id was invented." `
        -RequestBodies $null
}

function Test-FunctionalGatewayValidate {
    $url = "http://localhost:8087/api/v1/gate/validate"
    $body = @{ token = "e2e-invalid-token" }
    $response = Invoke-E2ERequest -Method POST -Url $url -Body $body -TimeoutSec $TIMEOUT_SEC
    Add-EvidenceRequest -Name "Gateway QR validation" -Method "POST" -Url $url -RequestBody $body -StatusCode $response.StatusCode

    if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403) {
        Write-FunctionalResult `
            -Flow "Gateway QR validation route" `
            -Endpoints "POST /api/v1/gate/validate" `
            -Status "BLOCKED_BY_AUTH" `
            -HttpStatus $response.StatusCode `
            -Explanation "Gateway route exists but runtime security blocked unauthenticated access." `
            -RequestBodies $body
        return
    }

    if ($response.StatusCode -ne 200) {
        Write-FunctionalResult `
            -Flow "Gateway QR validation route" `
            -Endpoints "POST /api/v1/gate/validate" `
            -Status "FAIL" `
            -HttpStatus $response.StatusCode `
            -Explanation "Gateway route should respond to a validation request, but returned HTTP $($response.StatusCode)." `
            -RequestBodies $body
        return
    }

    try {
        $parsed = $response.Body | ConvertFrom-Json
        if ($parsed.valid -eq $false -and [string]$parsed.status -eq "RED") {
            Write-FunctionalResult `
                -Flow "Gateway QR validation route" `
                -Endpoints "POST /api/v1/gate/validate" `
                -Status "PASS" `
                -HttpStatus 200 `
                -Explanation "Route processed a real request and rejected an invalid QR token as RED, proving controller/service path is active." `
                -RequestBodies $body
        } else {
            Write-FunctionalResult `
                -Flow "Gateway QR validation route" `
                -Endpoints "POST /api/v1/gate/validate" `
                -Status "FAIL" `
                -HttpStatus 200 `
                -Explanation "Gateway returned 200 but did not classify the invalid token as RED/invalid." `
                -RequestBodies $body
        }
    } catch {
        Write-FunctionalResult `
            -Flow "Gateway QR validation route" `
            -Endpoints "POST /api/v1/gate/validate" `
            -Status "FAIL" `
            -HttpStatus 200 `
            -Explanation "Gateway returned 200 but response body could not be parsed as JSON." `
            -RequestBodies $body
    }
}

# ---------------------------------------------------------------------------
#  Report
# ---------------------------------------------------------------------------

function Write-MarkdownReport {
    param([string]$DockerSummary)

    $smokePassed = @($global:SmokeResults | Where-Object { $_.Passed }).Count
    $smokeFailed = @($global:SmokeResults | Where-Object { -not $_.Passed }).Count
    $functionalPassed = @($global:FunctionalResults | Where-Object { $_.Status -eq "PASS" }).Count
    $functionalFailed = @($global:FunctionalResults | Where-Object { $_.Status -eq "FAIL" }).Count
    $functionalBlocked = @($global:FunctionalResults | Where-Object { $_.Status -eq "BLOCKED_BY_AUTH" }).Count
    $functionalSkipped = @($global:FunctionalResults | Where-Object { $_.Status -eq "SKIPPED_NO_SEED" -or $_.Status -eq "SKIPPED_NOT_AVAILABLE" }).Count
    $overallStatus = if ($global:AllPassed) { "PASSED" } else { "FAILED" }

    $sb = [System.Text.StringBuilder]::new()
    $fence = '```'

    $null = $sb.AppendLine("# CircleGuard E2E Report")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Summary")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("- Execution date: $RUN_TIMESTAMP")
    $null = $sb.AppendLine("- Suite version: $SCRIPT_VERSION")
    $null = $sb.AppendLine("- Overall result: $overallStatus")
    $null = $sb.AppendLine("- Smoke checks: $smokePassed passed / $smokeFailed failed")
    $null = $sb.AppendLine("- Functional checks: $functionalPassed passed / $functionalFailed failed / $functionalBlocked blocked / $functionalSkipped skipped")
    $null = $sb.AppendLine("- Timeout per HTTP check: ${TIMEOUT_SEC}s")
    $null = $sb.AppendLine("")

    $null = $sb.AppendLine("## Smoke / Operational Checks")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| # | Check | Endpoint | Container | Docker | HTTP Status | Result |")
    $null = $sb.AppendLine("|---|-------|----------|-----------|--------|-------------|--------|")
    foreach ($r in $global:SmokeResults) {
        $pass = if ($r.Passed) { "PASS" } else { "FAIL" }
        $docker = if ($r.ContainerOk) { "UP" } else { "DOWN" }
        $code = if ($null -ne $r.StatusCode) { $r.StatusCode } else { "N/A" }
        $null = $sb.AppendLine("| $($r.CheckId) | $(Escape-Markdown $r.Name) | $(Escape-Markdown $r.Url) | $(Escape-Markdown $r.ContainerName) | $docker | $code | $pass |")
    }
    $null = $sb.AppendLine("")

    $null = $sb.AppendLine("## Functional E2E Checks")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Flow | Endpoint(s) | Status | Classification | Result | Explanation |")
    $null = $sb.AppendLine("|------|-------------|--------|----------------|--------|-------------|")
    foreach ($r in $global:FunctionalResults) {
        $result = if ($r.CriticalFailure) { "FAILS_SUITE" } elseif ($r.Status -eq "PASS") { "PASS" } else { "DOCUMENTED_NON_CRITICAL" }
        $http = if ($null -ne $r.HttpStatus) { "HTTP $($r.HttpStatus)" } else { "HTTP N/A" }
        $explanation = "$http - $($r.Explanation)"
        $null = $sb.AppendLine("| $(Escape-Markdown $r.Flow) | $(Escape-Markdown $r.Endpoints) | $($r.Status) | $($r.Classification) | $result | $(Escape-Markdown $explanation) |")
    }
    $null = $sb.AppendLine("")

    $null = $sb.AppendLine("## Evidence")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("### Docker ps snapshot")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine($fence)
    $null = $sb.AppendLine($DockerSummary)
    $null = $sb.AppendLine($fence)
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("### Neo4j health status")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("- circleguard-neo4j: $global:Neo4jHealthStatus")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("### Notification service reachability")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("- http://localhost:8082/actuator/health: $global:NotificationReachability")
    $null = $sb.AppendLine("- No functional notification REST endpoint was found in notification-service controllers; the service is Kafka-listener based.")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("### Endpoints invoked")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Name | Method | URL | HTTP Status | Request body |")
    $null = $sb.AppendLine("|------|--------|-----|-------------|--------------|")
    foreach ($e in $global:EvidenceRequests) {
        $code = if ($null -ne $e.StatusCode) { $e.StatusCode } else { "N/A" }
        $body = if ([string]::IsNullOrWhiteSpace($e.RequestBody)) { "(none)" } else { $e.RequestBody }
        $null = $sb.AppendLine("| $(Escape-Markdown $e.Name) | $($e.Method) | $(Escape-Markdown $e.Url) | $code | $(Escape-Markdown $body) |")
    }
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("### Non-sensitive request bodies")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("- Identity map body uses only the synthetic test identity ``e2e-user@circleguard.test``.")
    $null = $sb.AppendLine("- Gateway validation body uses an intentionally invalid non-secret token string.")
    $null = $sb.AppendLine("- No real credentials, JWTs, LDAP users or production identifiers are embedded in this suite.")
    $null = $sb.AppendLine("")

    $null = $sb.AppendLine("## Limitations")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("- The smoke checks validate real availability of the local Docker Compose stack.")
    $null = $sb.AppendLine("- The functional checks validate real REST endpoints when auth and seed data make that possible.")
    $null = $sb.AppendLine("- Some flows can be ``BLOCKED_BY_AUTH`` because Spring Security/JWT protections are active and no seed credentials are available.")
    $null = $sb.AppendLine("- Some flows can be ``SKIPPED_NO_SEED`` because the running stack has no known seeded business data, such as a Neo4j health user for recovery.")
    $null = $sb.AppendLine("- This suite does not replace Java integration tests, contract tests, security tests or performance tests.")
    $null = $sb.AppendLine("- Kafka and Redis are still validated indirectly through dependent endpoints; deeper broker/cache assertions remain integration-test territory.")
    $null = $sb.AppendLine("- Locust remains pending for the performance-testing part of the workshop.")
    $null = $sb.AppendLine("")
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

Write-Host "[ CONTAINERS ] Current stack status:" -ForegroundColor Yellow
docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"
Write-Host ""

$dockerSnapshot = Get-DockerSummary

Write-Host "[ SMOKE / OPERATIONAL CHECKS ]" -ForegroundColor Cyan
Write-Host ("-" * 62) -ForegroundColor Cyan
Write-Host ""

Test-HttpEndpoint `
    -CheckId 1 `
    -Name "auth-service HTTP reachability" `
    -Url "http://localhost:8180/actuator/health" `
    -ContainerName "circleguard-auth-service" `
    -Description "Validates auth-service (port 8180) is reachable. Any HTTP response confirms Spring Boot is running." `
    | Out-Null

Test-HttpEndpoint `
    -CheckId 2 `
    -Name "identity-service HTTP reachability" `
    -Url "http://localhost:8083/actuator/health" `
    -ContainerName "circleguard-identity-service" `
    -Description "Validates identity-service (port 8083) is reachable. A protected 401/403 is still PASS because the JVM accepts connections." `
    | Out-Null

Test-HttpEndpoint `
    -CheckId 3 `
    -Name "form-service HTTP reachability" `
    -Url "http://localhost:8086/actuator/health" `
    -ContainerName "circleguard-form-service" `
    -Description "Validates form-service (port 8086) is reachable. Depends on PostgreSQL and Kafka." `
    | Out-Null

Test-HttpEndpoint `
    -CheckId 4 `
    -Name "gateway-service HTTP reachability" `
    -Url "http://localhost:8087/actuator/health" `
    -ContainerName "circleguard-gateway-service" `
    -Description "Validates gateway-service (port 8087) is reachable. Entry point for external traffic and Redis-backed QR validation." `
    | Out-Null

$promotionSmoke = Test-HttpEndpoint `
    -CheckId 5 `
    -Name "promotion-service + Neo4j health" `
    -Url "http://localhost:8088/actuator/health" `
    -ContainerName "circleguard-promotion-service" `
    -Description "Validates promotion-service (port 8088) reachability and the Neo4j Docker healthcheck."

Write-Host "[ SUB-CHECK ] Neo4j container state..." -ForegroundColor Yellow
$neo4jResult = Test-Neo4jHealth
if ($neo4jResult.Passed) {
    Write-Host "              $($neo4jResult.Message) [OK]" -ForegroundColor Green
    $promotionSmoke.Message = "$($promotionSmoke.Message); Neo4j $($neo4jResult.Status)"
} else {
    Write-Host "              $($neo4jResult.Message) [FAIL]" -ForegroundColor Red
    $promotionSmoke.Passed = $false
    $promotionSmoke.Message = "$($promotionSmoke.Message); Neo4j $($neo4jResult.Status)"
    $global:AllPassed = $false
}
Write-Host ""

Write-Host "[ ADDITIONAL OPERATIONAL EVIDENCE ]" -ForegroundColor Cyan
Write-Host ("-" * 62) -ForegroundColor Cyan
Test-NotificationReachability
Write-Host ("         notification-service: {0}" -f $global:NotificationReachability) -ForegroundColor Gray
Write-Host ""

Write-Host "[ FUNCTIONAL E2E CHECKS ]" -ForegroundColor Cyan
Write-Host ("-" * 62) -ForegroundColor Cyan
Write-Host ""

Test-FunctionalIdentityMapLookup
Test-FunctionalCertificates
Test-FunctionalPromotionRecovery
Test-FunctionalGatewayValidate

Write-Host "[ REPORT ] Writing Markdown report..." -ForegroundColor Yellow
Write-MarkdownReport -DockerSummary $dockerSnapshot
Write-Host "           Saved to: $REPORT_FILE" -ForegroundColor Green
Write-Host ""

$smokePassed = @($global:SmokeResults | Where-Object { $_.Passed }).Count
$smokeFailed = @($global:SmokeResults | Where-Object { -not $_.Passed }).Count
$smokeTotal = $global:SmokeResults.Count
$functionalPassed = @($global:FunctionalResults | Where-Object { $_.Status -eq "PASS" }).Count
$functionalFailed = @($global:FunctionalResults | Where-Object { $_.Status -eq "FAIL" }).Count
$functionalBlocked = @($global:FunctionalResults | Where-Object { $_.Status -eq "BLOCKED_BY_AUTH" }).Count
$functionalSkipped = @($global:FunctionalResults | Where-Object { $_.Status -eq "SKIPPED_NO_SEED" -or $_.Status -eq "SKIPPED_NOT_AVAILABLE" }).Count
$functionalTotal = $global:FunctionalResults.Count

Write-Host ("=" * 62) -ForegroundColor Cyan
if ($global:AllPassed) {
    Write-Host "  OVERALL: PASSED" -ForegroundColor Green
} else {
    Write-Host "  OVERALL: FAILED" -ForegroundColor Red
}
Write-Host ("  SMOKE:      {0}/{1} PASSED | {2} FAILED" -f $smokePassed, $smokeTotal, $smokeFailed) -ForegroundColor Gray
Write-Host ("  FUNCTIONAL: {0}/{1} PASS | {2} FAIL | {3} BLOCKED | {4} SKIPPED" -f $functionalPassed, $functionalTotal, $functionalFailed, $functionalBlocked, $functionalSkipped) -ForegroundColor Gray
Write-Host ("=" * 62) -ForegroundColor Cyan
Write-Host ""

if ($global:AllPassed) { exit 0 } else { exit 1 }
