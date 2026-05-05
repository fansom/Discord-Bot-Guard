# ============================================
# Codex CLI Utility
# ============================================

function Get-CodexModel {
    if ($env:CODEX_MODEL -and $env:CODEX_MODEL.Trim().Length -gt 0) {
        return $env:CODEX_MODEL.Trim()
    }

    return "gpt-5.5"
}

function Get-JsonFromText {
    param(
        [string]$Text
    )

    if (-not $Text) {
        throw "Codex returned an empty response"
    }

    $clean = $Text -replace '```json\s*', '' -replace '```\s*', ''
    $clean = $clean.Trim()

    try {
        $clean | ConvertFrom-Json | Out-Null
        return $clean
    } catch {
        # Codex CLI stderr/stdout can add transcript text around the final answer.
    }

    $arrayStart = $clean.IndexOf('[')
    $objectStart = $clean.IndexOf('{')

    if ($arrayStart -ge 0 -and ($objectStart -lt 0 -or $arrayStart -lt $objectStart)) {
        $arrayEnd = $clean.LastIndexOf(']')
        if ($arrayEnd -gt $arrayStart) {
            $candidate = $clean.Substring($arrayStart, $arrayEnd - $arrayStart + 1).Trim()
            $candidate | ConvertFrom-Json | Out-Null
            return $candidate
        }
    }

    if ($objectStart -ge 0) {
        $objectEnd = $clean.LastIndexOf('}')
        if ($objectEnd -gt $objectStart) {
            $candidate = $clean.Substring($objectStart, $objectEnd - $objectStart + 1).Trim()
            $candidate | ConvertFrom-Json | Out-Null
            return $candidate
        }
    }

    throw "No JSON object or array found in Codex response"
}

function Invoke-CodexJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [string]$Purpose = "codex-json",
        [string]$TaskId = "general",
        [string]$Model = (Get-CodexModel)
    )

    $safeTaskId = $TaskId -replace '[^a-zA-Z0-9_.-]', '_'
    $safePurpose = $Purpose -replace '[^a-zA-Z0-9_.-]', '_'
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $outFile = Join-Path $env:TEMP "codex-$safePurpose-$safeTaskId-$stamp.out"
    $errFile = Join-Path $env:TEMP "codex-$safePurpose-$safeTaskId-$stamp.err"

    Write-Log "Calling Codex CLI for $Purpose (model: $Model)" "INFO"
    if (Get-Command Write-ProgressEvent -ErrorAction SilentlyContinue) {
        Write-ProgressEvent -Watcher "codex-cli" -TaskId $TaskId -Phase $Purpose -Status "running" -Message "Calling Codex CLI" -Data @{
            model = $Model
            output_file = $outFile
            error_file = $errFile
        }
    }

    try {
        $stdout = $Prompt | & codex exec `
            --model $Model `
            --cd (Get-Location).Path `
            --sandbox read-only `
            --output-last-message $outFile `
            - 2> $errFile | Out-String

        $exitCode = $LASTEXITCODE
        $stderr = Get-Content $errFile -Raw -ErrorAction SilentlyContinue

        if ($stderr) {
            Write-Log "Codex stderr saved to $errFile" "DEBUG"
        }

        if ($exitCode -ne 0) {
            Write-Log "Codex CLI failed with exit code $exitCode" "ERROR"
            if ($stderr) {
                Write-Log ($stderr.Substring(0, [Math]::Min(1000, $stderr.Length))) "ERROR"
            }
            throw "Codex CLI exited with code $exitCode"
        }

        $responseText = Get-Content $outFile -Raw -ErrorAction SilentlyContinue
        if (-not $responseText -and $stdout) {
            $responseText = $stdout
        }

        $jsonText = Get-JsonFromText -Text $responseText
        Write-Log "Codex JSON response parsed" "INFO"
        if (Get-Command Write-ProgressEvent -ErrorAction SilentlyContinue) {
            Write-ProgressEvent -Watcher "codex-cli" -TaskId $TaskId -Phase $Purpose -Status "completed" -Message "Codex JSON response parsed" -Data @{
                model = $Model
                output_file = $outFile
                error_file = $errFile
            }
        }

        return ($jsonText | ConvertFrom-Json)
    } catch {
        Write-Log "Codex JSON call failed: $_" "ERROR"
        if (Get-Command Write-ProgressEvent -ErrorAction SilentlyContinue) {
            Write-ProgressEvent -Watcher "codex-cli" -TaskId $TaskId -Phase $Purpose -Status "failed" -Level "ERROR" -Message "Codex JSON call failed" -Data @{
                model = $Model
                error = "$_"
                output_file = $outFile
                error_file = $errFile
            }
        }
        if (Test-Path $outFile) {
            $raw = Get-Content $outFile -Raw -ErrorAction SilentlyContinue
            if ($raw) {
                Write-Log "Codex output was: $($raw.Substring(0, [Math]::Min(1000, $raw.Length)))" "DEBUG"
            }
        }
        return $null
    }
}
