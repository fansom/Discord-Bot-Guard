# ============================================
# Codex Designer Watcher - Spec Monitor
# ============================================

. "$PSScriptRoot/utils/logger.ps1"
. "$PSScriptRoot/utils/progress.ps1"
. "$PSScriptRoot/utils/codex-cli.ps1"

$config = @{
    WatchPath = ".dev-flow/spec.md"
    OutputDir = ".dev-flow/tasks"
    HandoffDir = ".dev-flow/handoff"
    PollInterval = 5
    MaxRetries = 3
}

$script:lastHash = $null

function Invoke-CodexAnalysis {
    param(
        [string]$SpecContent
    )

    $prompt = @"
You are a senior software architect. Analyze the following requirements and break them down into executable tasks.

# Requirements
$SpecContent

# Your Task
1. Analyze the requirements.
2. Break them into 3-5 specific tasks.
3. For each task, provide:
   - Task ID such as task-001, task-002.
   - Title.
   - Description.
   - Requirements.
   - Technical specifications.
   - Estimated time.
   - Dependencies.
   - Priority.

# Output Format
Respond only with a valid JSON array:
[
  {
    "task_id": "task-001",
    "title": "Task title",
    "description": "What this task does",
    "requirements": ["Requirement 1", "Requirement 2"],
    "technical_specs": "Technical details",
    "estimated_time": "15 min",
    "dependencies": [],
    "priority": "P0"
  }
]
"@

    $tasks = @(Invoke-CodexJson -Prompt $prompt -Purpose "analysis" -TaskId "spec")

    if ($tasks -and $tasks.Count -gt 0) {
        Write-Log "Codex analysis completed: $($tasks.Count) tasks generated" "INFO"
        return $tasks
    }

    Write-Log "Codex analysis did not return tasks" "ERROR"
    return $null
}

function ConvertTo-TaskList {
    param([object[]]$Items)

    if (-not $Items -or $Items.Count -eq 0) {
        return "- None"
    }

    return ($Items | ForEach-Object { "- [ ] $_" } | Out-String).TrimEnd()
}

function Get-MarkdownSection {
    param(
        [string]$Content,
        [string]$SectionName
    )

    $pattern = "(?ms)^##\s+$([regex]::Escape($SectionName))\s*\r?\n(.*?)(?=^\s*##\s+|\z)"
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return ""
}

function Get-TaskFingerprint {
    param([string]$Content)

    $titleMatch = [regex]::Match($Content, '(?m)^# Task:\s*(.+?)\s*$')
    $title = if ($titleMatch.Success) { $titleMatch.Groups[1].Value.Trim() } else { "" }
    $description = Get-MarkdownSection -Content $Content -SectionName "Description"
    $requirements = Get-MarkdownSection -Content $Content -SectionName "Requirements"
    $technicalSpecs = Get-MarkdownSection -Content $Content -SectionName "Technical Specifications"

    return (($title, $description, $requirements, $technicalSpecs) -join "`n") -replace '\s+', ' '
}

function Get-NextTaskId {
    $max = 0

    if (Test-Path $config.OutputDir) {
        Get-ChildItem -Path $config.OutputDir -Filter "task-*.md" -ErrorAction SilentlyContinue | ForEach-Object {
            $match = [regex]::Match($_.BaseName, '^task-(\d+)$')
            if ($match.Success) {
                $number = [int]$match.Groups[1].Value
                if ($number -gt $max) {
                    $max = $number
                }
            }
        }
    }

    return "task-{0:D3}" -f ($max + 1)
}

function Save-Tasks {
    param([array]$Tasks)

    if (-not $Tasks -or $Tasks.Count -eq 0) {
        Write-Log "No tasks to save" "WARN"
        return
    }

    if (-not (Test-Path $config.OutputDir)) {
        New-Item -ItemType Directory -Path $config.OutputDir -Force | Out-Null
    }

    if (-not (Test-Path $config.HandoffDir)) {
        New-Item -ItemType Directory -Path $config.HandoffDir -Force | Out-Null
    }

    $idMap = @{}

    foreach ($task in $Tasks) {
        $requestedTaskId = $task.task_id
        if (-not $requestedTaskId) {
            Write-Log "Skipping task with missing task_id" "WARN"
            continue
        }

        $mappedDependencies = @($task.dependencies) | ForEach-Object {
            if ($idMap.ContainsKey($_)) {
                $idMap[$_]
            } else {
                $_
            }
        }
        $dependencies = $mappedDependencies -join ', '
        $requirements = ConvertTo-TaskList -Items @($task.requirements)

        $taskId = $requestedTaskId
        $taskFilePath = Join-Path $config.OutputDir "$taskId.md"
        $taskContent = @"
---
task_id: $taskId
title: $($task.title)
priority: $($task.priority)
estimated_time: $($task.estimated_time)
dependencies: $dependencies
created: $(Get-Date -Format 'o')
---

# Task: $($task.title)

## Description
$($task.description)

## Requirements
$requirements

## Technical Specifications
$($task.technical_specs)

## Estimated Time
$($task.estimated_time)

## Dependencies
$dependencies

## Priority
$($task.priority)
"@

        if (Test-Path $taskFilePath) {
            $existingContent = Get-Content $taskFilePath -Raw
            $existingFingerprint = Get-TaskFingerprint -Content $existingContent
            $newFingerprint = Get-TaskFingerprint -Content $taskContent

            if ($existingFingerprint -eq $newFingerprint) {
                $idMap[$requestedTaskId] = $taskId
                Write-Log "Task already exists with matching content; skipping: $taskFilePath" "INFO"
                Write-ProgressEvent -Watcher "codex-designer" -TaskId $taskId -Phase "task_write" -Status "skipped" -Message "Task already exists with matching content" -Data @{
                    task_file = $taskFilePath
                    requested_task_id = $requestedTaskId
                }
                continue
            }

            $taskId = Get-NextTaskId
            $idMap[$requestedTaskId] = $taskId
            Write-Log "Task ID $requestedTaskId already exists with different content; creating new task $taskId" "WARN"
            Write-ProgressEvent -Watcher "codex-designer" -TaskId $taskId -Phase "task_write" -Status "remapped" -Level "WARN" -Message "Existing task ID had different content; creating a new task" -Data @{
                task_file = $taskFilePath
                requested_task_id = $requestedTaskId
            }
            $taskFilePath = Join-Path $config.OutputDir "$taskId.md"
            $taskContent = $taskContent -replace "task_id: $([regex]::Escape($requestedTaskId))", "task_id: $taskId"
        } else {
            $idMap[$requestedTaskId] = $taskId
        }

        $taskContent | Out-File $taskFilePath -Encoding UTF8
        Write-Log "Saved task: $taskFilePath" "INFO"
        Write-ProgressEvent -Watcher "codex-designer" -TaskId $taskId -Phase "task_write" -Status "completed" -Message "Saved task file" -Data @{
            task_file = $taskFilePath
            requested_task_id = $requestedTaskId
        }

        $handoffFilePath = Join-Path $config.HandoffDir "to-claude-$taskId.md"
        $handoffContent = @"
---
task_id: $taskId
task_type: development
priority: $($task.priority)
estimated_time: $($task.estimated_time)
dependencies: $dependencies
created: $(Get-Date -Format 'o')
---

# Task: $($task.title)

## Background
This task is part of the project requirements defined in spec.md.

## Objectives
$requirements

## Technical Specifications
$($task.technical_specs)

## Implementation Guide
Please implement this task following the technical specifications above.

Ensure:
1. Code follows project conventions.
2. Include appropriate error handling.
3. Add unit tests where appropriate.
4. Document meaningful non-obvious code.

## Expected Deliverables
- Implemented code.
- Unit tests.
- Updated documentation if needed.

## Testing Requirements
- Run the relevant project tests.
- Report test command output in the implementation summary.

After completion, submit for verification.
"@

        $handoffContent | Out-File $handoffFilePath -Encoding UTF8 -Force
        Write-Log "Created handoff file: $handoffFilePath" "INFO"
        Write-ProgressEvent -Watcher "codex-designer" -TaskId $taskId -Phase "handoff" -Status "queued" -Message "Created Claude handoff file" -Data @{
            handoff_file = $handoffFilePath
        }
    }

    Write-Log "All tasks saved and ready for Claude Code" "INFO"
}

Write-Log "File watcher started - monitoring spec.md" "INFO"
Write-Log "Using Codex CLI model: $(Get-CodexModel)" "INFO"
Write-Log "Press Ctrl+C to stop" "INFO"
Write-ProgressEvent -Watcher "codex-designer" -Phase "watcher" -Status "started" -Message "Codex designer watcher started" -Data @{
    watch_path = $config.WatchPath
    output_dir = $config.OutputDir
    handoff_dir = $config.HandoffDir
}
Write-Host ""

while ($true) {
    try {
        if (-not (Test-Path $config.WatchPath)) {
            Start-Sleep -Seconds $config.PollInterval
            continue
        }

        $currentHash = (Get-FileHash $config.WatchPath -Algorithm MD5).Hash

        if ($currentHash -ne $script:lastHash) {
            Write-Log "Spec change detected" "INFO"
            Write-ProgressEvent -Watcher "codex-designer" -TaskId "spec" -Phase "spec" -Status "changed" -Message "Spec change detected" -Data @{
                watch_path = $config.WatchPath
                hash = $currentHash
            }
            $specContent = Get-Content $config.WatchPath -Raw
            Write-ProgressEvent -Watcher "codex-designer" -TaskId "spec" -Phase "analysis" -Status "running" -Message "Analyzing spec with Codex"
            $tasks = Invoke-CodexAnalysis -SpecContent $specContent

            if ($tasks) {
                Save-Tasks -Tasks $tasks
                Write-Log "Analysis complete: $($tasks.Count) tasks created" "INFO"
                Write-ProgressEvent -Watcher "codex-designer" -TaskId "spec" -Phase "analysis" -Status "completed" -Message "Analysis complete" -Data @{
                    task_count = $tasks.Count
                }
            } else {
                Write-Log "Failed to generate tasks from Codex" "ERROR"
                Write-ProgressEvent -Watcher "codex-designer" -TaskId "spec" -Phase "analysis" -Status "failed" -Level "ERROR" -Message "Failed to generate tasks from Codex"
            }

            $script:lastHash = $currentHash
        }

        Start-Sleep -Seconds $config.PollInterval
    } catch {
        Write-Log "Error in main loop: $_" "ERROR"
        Start-Sleep -Seconds $config.PollInterval
    }
}
