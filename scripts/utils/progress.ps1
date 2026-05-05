# ============================================
# Progress Event Utility
# ============================================

function Write-ProgressEvent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Watcher,

        [string]$TaskId = "",

        [Parameter(Mandatory = $true)]
        [string]$Phase,

        [Parameter(Mandatory = $true)]
        [string]$Status,

        [string]$Message = "",

        [string]$Level = "INFO",

        [hashtable]$Data = @{}
    )

    $progressDir = ".dev-flow/progress"
    if (-not (Test-Path $progressDir)) {
        New-Item -ItemType Directory -Path $progressDir -Force | Out-Null
    }

    $event = [ordered]@{
        timestamp = Get-Date -Format "o"
        watcher = $Watcher
        task_id = $TaskId
        phase = $Phase
        status = $Status
        level = $Level
        message = $Message
        data = $Data
    }

    $json = $event | ConvertTo-Json -Depth 10 -Compress
    $eventsFile = Join-Path $progressDir "events-$(Get-Date -Format 'yyyy-MM-dd').jsonl"
    $latestFile = Join-Path $progressDir "latest.json"

    $mutex = [System.Threading.Mutex]::new($false, "Global\DiscordBotGuardAiHarnessProgress")
    $lockTaken = $false

    try {
        $lockTaken = $mutex.WaitOne(5000)
        if (-not $lockTaken) {
            throw "Timed out waiting for progress event lock"
        }

        $json | Out-File $eventsFile -Append -Encoding UTF8
        $json | Out-File $latestFile -Encoding UTF8 -Force

        if ($TaskId) {
            $taskFile = Join-Path $progressDir "$TaskId.latest.json"
            $json | Out-File $taskFile -Encoding UTF8 -Force
        }
    } catch {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log "Failed to write progress event: $_" "WARN"
        }
    } finally {
        if ($lockTaken) {
            $mutex.ReleaseMutex()
        }
        $mutex.Dispose()
    }
}
