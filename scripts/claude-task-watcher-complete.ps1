# ============================================
# Claude Task Watcher (with Claude Code CLI)
# ============================================

. "$PSScriptRoot/utils/logger.ps1"
. "$PSScriptRoot/utils/progress.ps1"

$config = @{
    WatchPath = ".dev-flow/handoff/to-claude*.md"
    HandoffDir = ".dev-flow/handoff"
    VerificationDir = ".dev-flow/handoff"
    PollInterval = 5
    TimeoutMinutes = 10
}

# ─────────────────────────────────────────
# Claude Code Functions
# ─────────────────────────────────────────

function Test-ClaudeCodeInstalled {
    try {
        $version = & claude --version 2>&1
        Write-Log "Claude Code detected: $version" "INFO"
        return $true
    } catch {
        Write-Log "Claude Code CLI not found. Please install: npm install -g @anthropic-ai/claude-code" "ERROR"
        return $false
    }
}

function Test-ClaudeRateLimit {
    # Check if we've hit the rate limit (25 uses per day)
    # This is a simple check - you may want to implement more sophisticated tracking
    
    $usageFile = "$env:USERPROFILE\.claude\usage.json"
    
    if (Test-Path $usageFile) {
        try {
            $usage = Get-Content $usageFile | ConvertFrom-Json
            $dailyCount = $usage.daily_count
            $resetTime = Get-Date "23:10:00"
            
            if ($dailyCount -ge 25) {
                $now = Get-Date
                if ($now -lt $resetTime) {
                    $waitMinutes = [math]::Ceiling(($resetTime - $now).TotalMinutes)
                    Write-Log "Rate limit reached (25/25). Resets at 23:10 (wait ~$waitMinutes min)" "WARN"
                    return $false
                }
            }
            
            Write-Log "Claude Code usage: $dailyCount/25" "INFO"
            return $true
            
        } catch {
            # If we can't read the file, assume OK
            return $true
        }
    }
    
    return $true
}

function Invoke-ClaudeCode {
    param(
        [string]$TaskFile
    )
    
    Write-Log "Executing Claude Code for task: $TaskFile" "INFO"
    
    # Read task content
    $taskContent = Get-Content $TaskFile -Raw
    
    # Extract task ID
    $taskId = [regex]::Match((Split-Path $TaskFile -Leaf), 'to-claude-(.+)\.md').Groups[1].Value
    Write-ProgressEvent -Watcher "claude-task" -TaskId $taskId -Phase "claude_execution" -Status "starting" -Message "Preparing Claude Code execution" -Data @{
        task_file = $TaskFile
    }
    
    # Create a temporary prompt file for Claude Code
    $promptFile = New-TemporaryFile
    $taskContent | Out-File $promptFile -Encoding UTF8
    
    try {
        # Execute Claude Code
        # Note: Adjust the command based on how Claude Code CLI works
        # This is a simplified version - you may need to customize based on actual CLI
        
        Write-Log "Starting Claude Code execution..." "INFO"
        Write-ProgressEvent -Watcher "claude-task" -TaskId $taskId -Phase "claude_execution" -Status "running" -Message "Claude Code process started"
        
        $startTime = Get-Date
        
        # Method 1: If Claude Code can read from stdin
        $process = Start-Process -FilePath "claude" `
            -ArgumentList "dev" `
            -NoNewWindow `
            -PassThru `
            -RedirectStandardInput $promptFile `
            -RedirectStandardOutput "$env:TEMP\claude-stdout-$taskId.log" `
            -RedirectStandardError "$env:TEMP\claude-stderr-$taskId.log" `
            -Wait `
        
        $executionTime = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
        
        # Read outputs
        $stdout = Get-Content "$env:TEMP\claude-stdout-$taskId.log" -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content "$env:TEMP\claude-stderr-$taskId.log" -Raw -ErrorAction SilentlyContinue
        
        # Determine success
        $success = $process.ExitCode -eq 0
        
        if ($success) {
            Write-Log "Claude Code completed successfully (${executionTime}m)" "INFO"
            Write-ProgressEvent -Watcher "claude-task" -TaskId $taskId -Phase "claude_execution" -Status "completed" -Message "Claude Code completed successfully" -Data @{
                exit_code = $process.ExitCode
                execution_time_minutes = $executionTime
            }
        } else {
            Write-Log "Claude Code exited with code $($process.ExitCode)" "ERROR"
            Write-ProgressEvent -Watcher "claude-task" -TaskId $taskId -Phase "claude_execution" -Status "failed" -Level "ERROR" -Message "Claude Code exited with a non-zero code" -Data @{
                exit_code = $process.ExitCode
                execution_time_minutes = $executionTime
            }
        }
        
        # Clean up temp files
        Remove-Item $promptFile -Force -ErrorAction SilentlyContinue
        
        return @{
            Success = $success
            ExitCode = $process.ExitCode
            ExecutionTime = $executionTime
            StdOut = $stdout
            StdErr = $stderr
            TaskId = $taskId
        }
        
    } catch {
        Write-Log "Claude Code execution failed: $_" "ERROR"
        Write-ProgressEvent -Watcher "claude-task" -TaskId $taskId -Phase "claude_execution" -Status "failed" -Level "ERROR" -Message "Claude Code execution threw an exception" -Data @{
            error = "$_"
        }
        
        Remove-Item $promptFile -Force -ErrorAction SilentlyContinue
        
        return @{
            Success = $false
            ExitCode = -1
            ExecutionTime = 0
            StdOut = ""
            StdErr = $_.Exception.Message
            TaskId = $taskId
        }
    }
}

function New-VerificationRequest {
    param(
        [object]$ExecutionResult
    )
    
    $taskId = $ExecutionResult.TaskId
    $timestamp = Get-Date -Format 'o'
    
    # Read original task
    $originalTaskFile = Join-Path $config.HandoffDir "to-claude-$taskId.md"
    $originalTask = if (Test-Path $originalTaskFile) {
        Get-Content $originalTaskFile -Raw
    } else {
        "[Original task file not found]"
    }
    
    # Create verification request
    $verificationContent = @"
---
task_id: $taskId
original_task: to-claude-$taskId.md
submitted_at: $timestamp
execution_time: $($ExecutionResult.ExecutionTime) min
claude_exit_code: $($ExecutionResult.ExitCode)
---

## 🔍 Verification Request

### Original Task Requirements
$originalTask

### Implementation Summary
Status: $(if ($ExecutionResult.Success) { "Completed" } else { "Failed" })
Exit Code: $($ExecutionResult.ExitCode)
Execution Time: $($ExecutionResult.ExecutionTime) minutes

### Execution Output
``````
$($ExecutionResult.StdOut)
``````

### Errors (if any)
``````
$($ExecutionResult.StdErr)
``````

### Request for Review
Please verify if this implementation meets the task requirements defined in to-claude-$taskId.md

Specifically review:
- Functional completeness
- Code quality
- Test coverage
- Documentation
- Security considerations

If approved, mark task as completed.
If revision needed, specify what needs to be fixed.
If rejected, explain why and suggest next steps.
"@
    
    $verificationFile = Join-Path $config.VerificationDir "to-verification-$taskId.md"
    $verificationContent | Out-File $verificationFile -Encoding UTF8 -Force
    
    Write-Log "Created verification request: $verificationFile" "INFO"
    Write-ProgressEvent -Watcher "claude-task" -TaskId $taskId -Phase "verification_handoff" -Status "queued" -Message "Created verification handoff file" -Data @{
        verification_file = $verificationFile
    }
}

# ─────────────────────────────────────────
# Main Loop
# ─────────────────────────────────────────

function New-ClaudeErrorReport {
    param(
        [object]$ExecutionResult
    )

    $taskId = $ExecutionResult.TaskId
    $timestamp = Get-Date -Format 'o'

    $originalTaskFile = Join-Path $config.HandoffDir "to-claude-$taskId.md"
    $originalTask = if (Test-Path $originalTaskFile) {
        Get-Content $originalTaskFile -Raw
    } else {
        "[Original task file not found]"
    }

    $errorContent = @"
---
task_id: $taskId
status: blocked
failure_category: TOOL_FAILURE
created: $timestamp
claude_exit_code: $($ExecutionResult.ExitCode)
execution_time: $($ExecutionResult.ExecutionTime) min
---

# Claude Execution Failed: $taskId

## Original Task
$originalTask

## Failure Summary
Claude Code did not complete successfully, so this task was not submitted for verification.

## Execution Output
``````
$($ExecutionResult.StdOut)
``````

## Errors
``````
$($ExecutionResult.StdErr)
``````

## Next Action
Fix the tool/runtime failure, then requeue this task for Claude execution.
"@

    $errorFile = Join-Path $config.HandoffDir "to-human-error-$taskId.md"
    $errorContent | Out-File $errorFile -Encoding UTF8 -Force
    Write-Log "Created Claude error report: $errorFile" "ERROR"
    Write-ProgressEvent -Watcher "claude-task" -TaskId $taskId -Phase "error_handoff" -Status "blocked" -Level "ERROR" -Message "Created Claude execution error report" -Data @{
        error_file = $errorFile
        exit_code = $ExecutionResult.ExitCode
    }
}

Write-Log "Claude task watcher started" "INFO"
Write-Log "Press Ctrl+C to stop" "INFO"
Write-ProgressEvent -Watcher "claude-task" -Phase "watcher" -Status "started" -Message "Claude task watcher started" -Data @{
    watch_path = $config.WatchPath
    handoff_dir = $config.HandoffDir
}
Write-Host ""

# Check if Claude Code is installed
if (-not (Test-ClaudeCodeInstalled)) {
    Write-Log "Exiting: Claude Code CLI not found" "ERROR"
    exit 1
}

while ($true) {
    try {
        # Check rate limit before processing
        if (-not (Test-ClaudeRateLimit)) {
            Write-Log "Waiting for rate limit reset..." "WARN"
            Start-Sleep -Seconds 60
            continue
        }
        
        $taskFiles = Get-ChildItem $config.WatchPath -ErrorAction SilentlyContinue
        
        foreach ($taskFile in $taskFiles) {
            $taskId = [regex]::Match($taskFile.Name, 'to-claude-(.+)\.md').Groups[1].Value
            
            Write-Log "=== Processing task: $taskId ===" "INFO"
            Write-ProgressEvent -Watcher "claude-task" -TaskId $taskId -Phase "handoff" -Status "claimed" -Message "Claimed Claude handoff file" -Data @{
                task_file = $taskFile.FullName
            }
            
            # Execute Claude Code
            $result = Invoke-ClaudeCode -TaskFile $taskFile.FullName
            
            if ($result.Success) {
                New-VerificationRequest -ExecutionResult $result
                Write-Log "=== Task $taskId submitted for verification ===" "INFO"
            } else {
                New-ClaudeErrorReport -ExecutionResult $result
                Write-Log "=== Task $taskId blocked by Claude execution failure ===" "ERROR"
            }
            
            # Remove processed task file
            Remove-Item $taskFile.FullName -Force
            Write-Log "Removed processed task file: $($taskFile.Name)" "INFO"
            Write-ProgressEvent -Watcher "claude-task" -TaskId $taskId -Phase "handoff" -Status "removed" -Message "Removed processed Claude handoff file" -Data @{
                task_file = $taskFile.FullName
            }
            Write-Host ""
        }
        
        Start-Sleep -Seconds $config.PollInterval
        
    } catch {
        Write-Log "Error in main loop: $_" "ERROR"
        Start-Sleep -Seconds $config.PollInterval
    }
}
