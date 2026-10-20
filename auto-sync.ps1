# Auto-Sync Watcher for GitHub
# Watches the folder for changes and automatically commits & pushes to GitHub

$folder = "C:\AI WEB\GAME DEV PLAPI BORD"
$repoName = "tic-tac-toe"

Write-Host "=== Auto-Sync Watcher Started ===" -ForegroundColor Green
Write-Host "Watching: $folder" -ForegroundColor Cyan
Write-Host "Repo: $repoName" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

# Set working directory
Set-Location $folder

# Create FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $folder
$watcher.Filter = "*.*"
$watcher.IncludeSubdirectories = $false
$watcher.EnableRaisingEvents = $true

# Debounce timer to avoid multiple rapid commits
$timer = null
$pendingChanges = $false

function Sync-Changes {
    global: $pendingChanges = $false
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] Changes detected, syncing to GitHub..." -ForegroundColor Cyan
    
    # Stage all changes
    $addOutput = git add . 2>&1
    
    # Check if there are changes to commit
    $statusOutput = git status --porcelain 2>&1
    
    if ($statusOutput -match "M|A|D|\?\?") {
        $commitMsg = "Auto-sync: $timestamp"
        $commitOutput = git commit -m "$commitMsg" 2>&1
        Write-Host "[$timestamp] Committed: $commitMsg" -ForegroundColor Green
        
        # Push to GitHub
        $pushOutput = git push origin main 2>&1
        if ($pushOutput -match "main -> main|up to date|Everything up-to-date") {
            Write-Host "[$timestamp] Pushed to GitHub successfully!" -ForegroundColor Green
        } else {
            Write-Host "[$timestamp] Push output: $pushOutput" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[$timestamp] No changes to commit." -ForegroundColor Gray
    }
    
    Write-Host ""
}

# Event handler for file changes
$action = {
    global: $pendingChanges = $true
    
    # Reset timer on each change (debounce)
    if ($timer) {
        $timer.Dispose()
    }
    
    $timer = New-Object System.Timers.Timer
    $timer.Interval = 3000  # Wait 3 seconds after last change
    $timer.AutoReset = $false
    $timer.Add_Elapsed({ Sync-Changes })
    $timer.Start()
}

Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action
Register-ObjectEvent -InputObject $watcher -EventName "Created" -Action $action
Register-ObjectEvent -InputObject $watcher -EventName "Deleted" -Action $action
Register-ObjectEvent -InputObject $watcher -EventName "Renamed" -Action $action

Write-Host "Watcher is running. Changes will auto-sync after 3 seconds of inactivity." -ForegroundColor Green
Write-Host ""

# Keep script running
try {
    while ($true) {
        Start-Sleep -Seconds 1
    }
} catch {
    Write-Host "Stopping watcher..." -ForegroundColor Yellow
    $watcher.Dispose()
    if ($timer) { $timer.Dispose() }
    Unregister-Event -SourceIdentifier *
    Write-Host "Watcher stopped." -ForegroundColor Yellow
}