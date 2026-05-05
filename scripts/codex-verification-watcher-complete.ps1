# ============================================
# Verification Watcher - Quality Checker
# ============================================

. "$PSScriptRoot/utils/logger.ps1"
. "$PSScriptRoot/utils/progress.ps1"
. "$PSScriptRoot/utils/codex-cli.ps1"

$config = @{
    WatchPath = ".dev-flow/handoff/to-verification*.md"
    ResultDir = ".dev-flow/verification"
    HandoffDir = ".dev-flow/handoff"
    TasksDir = ".dev-flow/tasks"
    PollInterval = 5
}

function Format-ListLines {
    param([object[]]$Items)

    if (-not $Items -or $Items.Count -eq 0) {
        return "- None"
    }

    return ($Items | ForEach-Object { "- $_" } | Out-String).TrimEnd()
}

function Get-ScoreStatus {
    param(
        [int]$Score,
        [int]$PassScore
    )

    if ($Score -ge $PassScore) {
        return "PASS"
    }

    return "FAIL"
}

function Invoke-CodexVerification {
    param(
        [string]$TaskId,
        [string]$OriginalTask,
        [string]$ImplementationReport
    )

    $prompt = @"
You are a senior code reviewer conducting quality verification.

## Task ID
$TaskId

## Original Requirements
$OriginalTask

## Implementation Report
$ImplementationReport

## Your Task
Verify if the implementation meets all requirements. Score each category:

1. Requirements Compliance: 40 points.
2. Code Quality: 25 points.
3. Test Coverage: 20 points.
4. Documentation: 10 points.
5. Security: 5 points.

Decision thresholds:
- Score >= 75: APPROVED
- Score 60-74: REVISION_NEEDED
- Score < 60: REJECTED

Respond only with valid JSON:
{
  "verification_status": "APPROVED | REVISION_NEEDED | REJECTED",
  "overall_score": 85,
  "requirements_compliance": {
    "score": 38,
    "max": 40,
    "met": ["requirement 1"],
    "partial": [],
    "missing": []
  },
  "code_quality": {
    "score": 23,
    "max": 25,
    "issues": []
  },
  "test_coverage": {
    "score": 18,
    "max": 20,
    "current_coverage": 85,
    "target_coverage": 80
  },
  "documentation": {
    "score": 8,
    "max": 10,
    "issues": []
  },
  "security": {
    "score": 5,
    "max": 5,
    "vulnerabilities": []
  },
  "decision_reasoning": "Brief reasoning",
  "critical_issues": [],
  "minor_issues": [],
  "next_actions": "What should happen next"
}
"@

    return Invoke-CodexJson -Prompt $prompt -Purpose "verification" -TaskId $TaskId
}

function Save-VerificationResult {
    param(
        [string]$TaskId,
        [object]$Verification
    )

    if (-not (Test-Path $config.ResultDir)) {
        New-Item -ItemType Directory -Path $config.ResultDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'o'
    $rawJson = $Verification | ConvertTo-Json -Depth 10
    $resultContent = @(
        "---",
        "task_id: $TaskId",
        "verification_status: $($Verification.verification_status)",
        "overall_score: $($Verification.overall_score)",
        "verified_at: $timestamp",
        "verified_by: codex",
        "---",
        "",
        "# Verification Result: $($Verification.verification_status)",
        "",
        "## Overall Score",
        "$($Verification.overall_score)/100",
        "",
        "## Decision Reasoning",
        "$($Verification.decision_reasoning)",
        "",
        "## Detailed Scores",
        "",
        "| Category | Score | Max | Status |",
        "|----------|-------|-----|--------|",
        "| Requirements | $($Verification.requirements_compliance.score) | $($Verification.requirements_compliance.max) | $(Get-ScoreStatus -Score $Verification.requirements_compliance.score -PassScore 32) |",
        "| Code Quality | $($Verification.code_quality.score) | $($Verification.code_quality.max) | $(Get-ScoreStatus -Score $Verification.code_quality.score -PassScore 20) |",
        "| Test Coverage | $($Verification.test_coverage.score) | $($Verification.test_coverage.max) | $(Get-ScoreStatus -Score $Verification.test_coverage.score -PassScore 16) |",
        "| Documentation | $($Verification.documentation.score) | $($Verification.documentation.max) | $(Get-ScoreStatus -Score $Verification.documentation.score -PassScore 7) |",
        "| Security | $($Verification.security.score) | $($Verification.security.max) | $(Get-ScoreStatus -Score $Verification.security.score -PassScore 5) |",
        "",
        "## Requirements Analysis",
        "",
        "### Met Requirements",
        (Format-ListLines -Items $Verification.requirements_compliance.met),
        "",
        "### Partial Requirements",
        (Format-ListLines -Items $Verification.requirements_compliance.partial),
        "",
        "### Missing Requirements",
        (Format-ListLines -Items $Verification.requirements_compliance.missing),
        "",
        "## Issues Found",
        "",
        "### Critical Issues",
        (Format-ListLines -Items $Verification.critical_issues),
        "",
        "### Minor Issues",
        (Format-ListLines -Items $Verification.minor_issues),
        "",
        "## Next Actions",
        "$($Verification.next_actions)",
        "",
        "## Raw Data",
        '```json',
        $rawJson,
        '```'
    ) -join [Environment]::NewLine

    $resultFile = Join-Path $config.ResultDir "verification-result-$TaskId.md"
    $resultContent | Out-File $resultFile -Encoding UTF8 -Force
    Write-Log "Verification result saved: $resultFile" "INFO"
    Write-ProgressEvent -Watcher "codex-verification" -TaskId $TaskId -Phase "verification_result" -Status "saved" -Message "Verification result saved" -Data @{
        result_file = $resultFile
        verification_status = $Verification.verification_status
        overall_score = $Verification.overall_score
    }
}

function Invoke-PostVerificationAction {
    param(
        [string]$TaskId,
        [object]$Verification
    )

    if ($Verification.verification_status -eq "APPROVED") {
        Write-Log "Task $TaskId approved" "INFO"
        Write-ProgressEvent -Watcher "codex-verification" -TaskId $TaskId -Phase "post_verification" -Status "approved" -Message "Task approved" -Data @{
            overall_score = $Verification.overall_score
        }
        return
    }

    if ($Verification.verification_status -eq "REVISION_NEEDED") {
        Write-Log "Task $TaskId needs revision" "WARN"
        Write-ProgressEvent -Watcher "codex-verification" -TaskId $TaskId -Phase "post_verification" -Status "revision_needed" -Level "WARN" -Message "Task needs revision" -Data @{
            overall_score = $Verification.overall_score
        }

        $fixTaskContent = @(
            "---",
            "task_id: fix-$TaskId",
            "original_task: $TaskId",
            "task_type: revision",
            "priority: P0",
            "verification_score: $($Verification.overall_score)",
            "created: $(Get-Date -Format 'o')",
            "---",
            "",
            "# Revision Required: Task $TaskId",
            "",
            "## Verification Summary",
            "Score: $($Verification.overall_score)/100. Approval requires >= 75.",
            "",
            "## Critical Issues to Fix",
            (Format-ListLines -Items $Verification.critical_issues),
            "",
            "## Minor Issues",
            (Format-ListLines -Items $Verification.minor_issues),
            "",
            "## Code Quality Issues",
            (Format-ListLines -Items $Verification.code_quality.issues),
            "",
            "## Documentation Issues",
            (Format-ListLines -Items $Verification.documentation.issues),
            "",
            "## Required Actions",
            "$($Verification.next_actions)",
            "",
            "## Verification Criteria",
            "1. Fix all critical issues.",
            "2. Achieve overall score >= 75.",
            "3. Meet minimum requirements in each category."
        ) -join [Environment]::NewLine

        $fixTaskFile = Join-Path $config.HandoffDir "to-claude-fix-$TaskId.md"
        $fixTaskContent | Out-File $fixTaskFile -Encoding UTF8 -Force
        Write-Log "Created fix task: $fixTaskFile" "INFO"
        Write-ProgressEvent -Watcher "codex-verification" -TaskId $TaskId -Phase "revision_handoff" -Status "queued" -Message "Created Claude fix handoff file" -Data @{
            fix_task_file = $fixTaskFile
        }
        return
    }

    if ($Verification.verification_status -eq "REJECTED") {
        Write-Log "Task $TaskId rejected; reporting to Codex" "ERROR"
        Write-ProgressEvent -Watcher "codex-verification" -TaskId $TaskId -Phase "post_verification" -Status "rejected" -Level "ERROR" -Message "Task rejected" -Data @{
            overall_score = $Verification.overall_score
        }

        $rejectionContent = @(
            "---",
            "task_id: $TaskId",
            "status: rejected",
            "verification_score: $($Verification.overall_score)",
            "requires_replanning: true",
            "created: $(Get-Date -Format 'o')",
            "---",
            "",
            "# Task Rejection Report: $TaskId",
            "",
            "## Verification Failed",
            "Score: $($Verification.overall_score)/100. Required: >= 60.",
            "",
            "## Reason",
            "$($Verification.decision_reasoning)",
            "",
            "## Critical Problems",
            (Format-ListLines -Items $Verification.critical_issues),
            "",
            "## Recommendation",
            "$($Verification.next_actions)"
        ) -join [Environment]::NewLine

        $rejectionFile = Join-Path $config.HandoffDir "to-codex-rejection-$TaskId.md"
        $rejectionContent | Out-File $rejectionFile -Encoding UTF8 -Force
        Write-Log "Created rejection report: $rejectionFile" "ERROR"
        Write-ProgressEvent -Watcher "codex-verification" -TaskId $TaskId -Phase "rejection_handoff" -Status "queued" -Level "ERROR" -Message "Created Codex rejection handoff file" -Data @{
            rejection_file = $rejectionFile
        }
        return
    }

    Write-Log "Unknown verification status for task ${TaskId}: $($Verification.verification_status)" "ERROR"
}

Write-Log "Verification watcher started" "INFO"
Write-Log "Using Codex CLI model: $(Get-CodexModel)" "INFO"
Write-Log "Press Ctrl+C to stop" "INFO"
Write-ProgressEvent -Watcher "codex-verification" -Phase "watcher" -Status "started" -Message "Codex verification watcher started" -Data @{
    watch_path = $config.WatchPath
    result_dir = $config.ResultDir
    handoff_dir = $config.HandoffDir
}
Write-Host ""

while ($true) {
    try {
        $verificationFiles = Get-ChildItem $config.WatchPath -ErrorAction SilentlyContinue

        foreach ($verificationFile in $verificationFiles) {
            $taskId = [regex]::Match($verificationFile.Name, 'to-verification-(.+)\.md').Groups[1].Value
            Write-Log "Verifying task: $taskId" "INFO"
            Write-ProgressEvent -Watcher "codex-verification" -TaskId $taskId -Phase "handoff" -Status "claimed" -Message "Claimed verification handoff file" -Data @{
                verification_file = $verificationFile.FullName
            }

            $verificationRequest = Get-Content $verificationFile.FullName -Raw
            $originalTaskFile = Join-Path $config.TasksDir "$taskId.md"
            $originalTask = if (Test-Path $originalTaskFile) {
                Get-Content $originalTaskFile -Raw
            } else {
                "[Original task not found]"
            }

            $verification = Invoke-CodexVerification -TaskId $taskId -OriginalTask $originalTask -ImplementationReport $verificationRequest

            if ($verification) {
                Save-VerificationResult -TaskId $taskId -Verification $verification
                Invoke-PostVerificationAction -TaskId $taskId -Verification $verification
                Write-Log "Verification complete: $($verification.verification_status)" "INFO"
                Write-ProgressEvent -Watcher "codex-verification" -TaskId $taskId -Phase "verification" -Status "completed" -Message "Verification complete" -Data @{
                    verification_status = $verification.verification_status
                    overall_score = $verification.overall_score
                }
            } else {
                Write-Log "Verification failed for task $taskId" "ERROR"
                Write-ProgressEvent -Watcher "codex-verification" -TaskId $taskId -Phase "verification" -Status "failed" -Level "ERROR" -Message "Verification failed"
            }

            Remove-Item $verificationFile.FullName -Force
            Write-ProgressEvent -Watcher "codex-verification" -TaskId $taskId -Phase "handoff" -Status "removed" -Message "Removed processed verification handoff file" -Data @{
                verification_file = $verificationFile.FullName
            }
            Write-Host ""
        }

        Start-Sleep -Seconds $config.PollInterval
    } catch {
        Write-Log "Error in main loop: $_" "ERROR"
        Start-Sleep -Seconds $config.PollInterval
    }
}
