# ============================================
# Codex Task Watcher - Feedback Processor
# ============================================

. "$PSScriptRoot/utils/logger.ps1"
. "$PSScriptRoot/utils/codex-cli.ps1"

$config = @{
    WatchPath = ".dev-flow/handoff/to-codex*.md"
    VerificationDir = ".dev-flow/verification"
    HandoffDir = ".dev-flow/handoff"
    TaskStatusFile = ".dev-flow/task-status.json"
    PollInterval = 5
}

function New-DefaultTaskStatus {
    return [pscustomobject]@{
        version = "1.0"
        last_updated = Get-Date -Format 'o'
        statistics = [pscustomobject]@{
            total_tasks = 0
            completed = 0
            in_progress = 0
            pending = 0
            failed = 0
            blocked = 0
        }
        tasks = [pscustomobject]@{}
    }
}

function Set-NoteProperty {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Value
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($property) {
        $property.Value = $Value
    } else {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
}

function Get-TaskStatus {
    if (Test-Path $config.TaskStatusFile) {
        try {
            return (Get-Content $config.TaskStatusFile -Raw | ConvertFrom-Json)
        } catch {
            Write-Log "Could not parse task status file; using empty status: $_" "WARN"
        }
    }

    return (New-DefaultTaskStatus)
}

function Save-TaskStatus {
    param([object]$StatusData)

    $statusDir = Split-Path $config.TaskStatusFile -Parent
    if ($statusDir -and -not (Test-Path $statusDir)) {
        New-Item -ItemType Directory -Path $statusDir -Force | Out-Null
    }

    $StatusData | ConvertTo-Json -Depth 10 | Out-File $config.TaskStatusFile -Encoding UTF8 -Force
}

function Update-TaskStatus {
    param(
        [string]$TaskId,
        [string]$Status,
        [int]$VerificationScore = 0
    )

    $statusData = Get-TaskStatus

    if (-not $statusData.tasks) {
        Set-NoteProperty -Object $statusData -Name "tasks" -Value ([pscustomobject]@{})
    }

    $taskEntry = $statusData.tasks.PSObject.Properties[$TaskId].Value
    if (-not $taskEntry) {
        $taskEntry = [pscustomobject]@{}
        Set-NoteProperty -Object $statusData.tasks -Name $TaskId -Value $taskEntry
    }

    Set-NoteProperty -Object $taskEntry -Name "status" -Value $Status
    Set-NoteProperty -Object $taskEntry -Name "updated_at" -Value (Get-Date -Format 'o')

    if ($VerificationScore -gt 0) {
        Set-NoteProperty -Object $taskEntry -Name "verification_score" -Value $VerificationScore
    }

    Set-NoteProperty -Object $statusData -Name "last_updated" -Value (Get-Date -Format 'o')

    $taskValues = @($statusData.tasks.PSObject.Properties | ForEach-Object { $_.Value })
    if (-not $statusData.statistics) {
        Set-NoteProperty -Object $statusData -Name "statistics" -Value ([pscustomobject]@{})
    }

    Set-NoteProperty -Object $statusData.statistics -Name "total_tasks" -Value $taskValues.Count
    Set-NoteProperty -Object $statusData.statistics -Name "completed" -Value (@($taskValues | Where-Object { $_.status -eq "completed" }).Count)
    Set-NoteProperty -Object $statusData.statistics -Name "in_progress" -Value (@($taskValues | Where-Object { $_.status -eq "in_progress" }).Count)
    Set-NoteProperty -Object $statusData.statistics -Name "pending" -Value (@($taskValues | Where-Object { $_.status -eq "pending" }).Count)
    Set-NoteProperty -Object $statusData.statistics -Name "failed" -Value (@($taskValues | Where-Object { $_.status -eq "failed" }).Count)
    Set-NoteProperty -Object $statusData.statistics -Name "blocked" -Value (@($taskValues | Where-Object { $_.status -eq "blocked" }).Count)

    Save-TaskStatus -StatusData $statusData
}

function Invoke-CodexDecision {
    param(
        [string]$FeedbackContent,
        [object]$TaskStatus
    )

    $prompt = @"
You are a project manager AI. Based on the feedback, decide the next action.

## Current Task Status
```json
$($TaskStatus | ConvertTo-Json -Depth 5)
```

## Latest Feedback
$FeedbackContent

## Your Task
Analyze the situation and decide the next action:

1. next_task - Current task is complete, proceed to next task.
2. all_complete - All known tasks are finished.
3. human - Human intervention is required.

Decision rules:
- If the task is approved and more task handoff files exist, choose next_task.
- If all known tasks are completed, choose all_complete.
- If rejected, unclear, looping, or system error, choose human.

Respond only with valid JSON:
{
  "decision": "next_task | all_complete | human",
  "reason": "Brief explanation",
  "next_task_id": "task-002",
  "human_message": "Message for human"
}
"@

    return Invoke-CodexJson -Prompt $prompt -Purpose "decision" -TaskId "feedback"
}

function New-HumanInterventionFile {
    param(
        [string]$Reason,
        [string]$Message
    )

    $humanContent = @"
---
alert_level: warning
requires_action: true
created: $(Get-Date -Format 'o')
---

# Human Intervention Required

## Situation
$Reason

## Message
$Message

## Files to Review
- .dev-flow/task-status.json
- .dev-flow/verification/
- .dev-flow/handoff/
"@

    $humanFile = Join-Path $config.HandoffDir "to-human-intervention-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    $humanContent | Out-File $humanFile -Encoding UTF8 -Force
    Write-Log "Created human intervention file: $humanFile" "WARN"
}

function Invoke-NextAction {
    param([object]$Decision)

    switch ($Decision.decision) {
        "next_task" {
            $nextTaskId = $Decision.next_task_id
            if (-not $nextTaskId) {
                Write-Log "No next task ID provided" "WARN"
                return
            }

            $nextTaskFile = Join-Path $config.HandoffDir "to-claude-$nextTaskId.md"
            if (Test-Path $nextTaskFile) {
                Write-Log "Next task file ready: $nextTaskFile" "INFO"
                Update-TaskStatus -TaskId $nextTaskId -Status "pending"
            } else {
                Write-Log "Next task file not found: $nextTaskFile" "WARN"
                New-HumanInterventionFile -Reason "Codex selected missing next task $nextTaskId" -Message "Review task queue and handoff files."
            }
        }

        "all_complete" {
            Write-Log "All tasks completed" "INFO"
            $summaryContent = @"
# Project Completion Summary

All known tasks have been completed successfully.

- Completed at: $(Get-Date -Format 'o')
- Decision reason: $($Decision.reason)
"@
            $summaryFile = Join-Path $config.HandoffDir "to-human-completion.md"
            $summaryContent | Out-File $summaryFile -Encoding UTF8 -Force
            Write-Log "Created completion summary: $summaryFile" "INFO"
        }

        "human" {
            New-HumanInterventionFile -Reason $Decision.reason -Message $Decision.human_message
        }

        default {
            New-HumanInterventionFile -Reason "Unknown Codex decision: $($Decision.decision)" -Message "Review Codex decision output."
        }
    }
}

Write-Log "Codex feedback watcher started" "INFO"
Write-Log "Using Codex CLI model: $(Get-CodexModel)" "INFO"
Write-Log "Press Ctrl+C to stop" "INFO"
Write-Host ""

while ($true) {
    try {
        $feedbackFiles = Get-ChildItem $config.WatchPath -ErrorAction SilentlyContinue

        foreach ($feedbackFile in $feedbackFiles) {
            $fileName = $feedbackFile.Name

            if ($fileName -match 'to-codex-rejection-(.+)\.md') {
                $taskId = $matches[1]
                Write-Log "Processing rejection for task: $taskId" "WARN"

                Update-TaskStatus -TaskId $taskId -Status "rejected"
                New-HumanInterventionFile -Reason "Task $taskId was rejected by verification" -Message "Review the rejection report and decide next steps."
            } elseif ($fileName -match 'to-codex-(.+)\.md') {
                $taskId = $matches[1]
                Write-Log "Processing feedback for task: $taskId" "INFO"

                $feedbackContent = Get-Content $feedbackFile.FullName -Raw
                $decision = Invoke-CodexDecision -FeedbackContent $feedbackContent -TaskStatus (Get-TaskStatus)

                if ($decision) {
                    Invoke-NextAction -Decision $decision
                    Write-Log "Decision executed: $($decision.decision)" "INFO"
                } else {
                    Write-Log "Failed to get Codex decision" "ERROR"
                }
            }

            Remove-Item $feedbackFile.FullName -Force
            Write-Host ""
        }

        $verificationFiles = Get-ChildItem "$($config.VerificationDir)/verification-result-*.md" -ErrorAction SilentlyContinue
        foreach ($verificationFile in $verificationFiles) {
            $taskId = [regex]::Match($verificationFile.Name, 'verification-result-(.+)\.md').Groups[1].Value
            $content = Get-Content $verificationFile.FullName -Raw

            if ($content -match 'verification_status:\s*APPROVED') {
                Write-Log "Task $taskId was approved" "INFO"
                Update-TaskStatus -TaskId $taskId -Status "completed"

                $decision = Invoke-CodexDecision -FeedbackContent "Task $taskId completed and approved." -TaskStatus (Get-TaskStatus)
                if ($decision) {
                    Invoke-NextAction -Decision $decision
                }

                $archiveDir = ".dev-flow/archive/verifications"
                if (-not (Test-Path $archiveDir)) {
                    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
                }
                Move-Item $verificationFile.FullName (Join-Path $archiveDir $verificationFile.Name) -Force
            }
        }

        Start-Sleep -Seconds $config.PollInterval
    } catch {
        Write-Log "Error in main loop: $_" "ERROR"
        Start-Sleep -Seconds $config.PollInterval
    }
}
