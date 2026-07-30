[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$InstallDir = $(
        if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "TokenUsageInsights" }
        else { Join-Path $HOME "AppData\Local\TokenUsageInsights" }
    ),
    [string]$BinDir = $(Join-Path $HOME "bin"),
    [int]$Port = 3003,
    [switch]$Autostart
)

$ErrorActionPreference = "Stop"
$AppName = "token-usage-insights"
$TaskName = "TokenUsageInsights"
$InstallDir = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($InstallDir))
$BinDir = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($BinDir))
$TargetBinary = Join-Path $InstallDir "$AppName.exe"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path (Join-Path $ScriptDir "$AppName.exe")) {
    $ReleaseDir = $ScriptDir
} else {
    $ReleaseDir = Split-Path -Parent $ScriptDir
}

$BinarySrc = Join-Path $ReleaseDir "$AppName.exe"
if (!(Test-Path $BinarySrc)) {
    throw "Missing executable: $BinarySrc. Run this installer from an extracted Token 戰情室 release package."
}

foreach ($RequiredItem in @("static", "pricing.csv")) {
    if (!(Test-Path (Join-Path $ReleaseDir $RequiredItem))) {
        throw "Incomplete release package: missing $RequiredItem in $ReleaseDir"
    }
}

if ($PSCmdlet.ShouldProcess($InstallDir, "Install Token Usage Insights")) {
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    $ManageAutostart = $Autostart -or $null -ne $ExistingTask
    if ($ManageAutostart) {
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        $ManagedProcesses = Get-CimInstance Win32_Process -Filter "Name = '$AppName.exe'" |
            Where-Object { $_.ExecutablePath -and [IO.Path]::GetFullPath($_.ExecutablePath) -ieq $TargetBinary }
        foreach ($Process in $ManagedProcesses) {
            Stop-Process -Id $Process.ProcessId -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Milliseconds 500
    }

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

    Copy-Item -Force $BinarySrc $TargetBinary

    foreach ($Item in @("static", "shell", "scripts")) {
        $Source = Join-Path $ReleaseDir $Item
        $Target = Join-Path $InstallDir $Item
        if (Test-Path $Source) {
            if (Test-Path $Target) {
                Remove-Item -Recurse -Force $Target
            }
            Copy-Item -Recurse -Force $Source $Target
        }
    }

    foreach ($File in @("pricing.csv", "README.md", "LICENSE", "VERSION")) {
        $Source = Join-Path $ReleaseDir $File
        if (Test-Path $Source) {
            Copy-Item -Force $Source (Join-Path $InstallDir $File)
        }
    }

    $Shim = Join-Path $BinDir "$AppName.cmd"
    $BatchInstallDir = $InstallDir.Replace("%", "%%")
    @"
@echo off
setlocal
set "PORT=$Port"
pushd "$BatchInstallDir"
"$BatchInstallDir\$AppName.exe" %*
set "APP_EXIT_CODE=%ERRORLEVEL%"
popd
exit /b %APP_EXIT_CODE%
"@ | Set-Content -Encoding ASCII $Shim

    if ($ManageAutostart) {
        $Launcher = Join-Path $InstallDir "start-hidden.vbs"
        $VbsInstallDir = $InstallDir.Replace('"', '""')
        @"
Option Explicit

Const exePath = "$VbsInstallDir\$AppName.exe"
Const workDir = "$VbsInstallDir"
Const port = "$Port"

Dim shell, wmi, processes, process, isRunning
Set shell = CreateObject("WScript.Shell")
shell.CurrentDirectory = workDir
shell.Environment("Process")("PORT") = port

Do
    Set wmi = GetObject("winmgmts:\\.\root\cimv2")
    Set processes = wmi.ExecQuery("SELECT ExecutablePath FROM Win32_Process WHERE Name = '$AppName.exe'")
    isRunning = False
    For Each process In processes
        If Not IsNull(process.ExecutablePath) Then
            If LCase(process.ExecutablePath) = LCase(exePath) Then isRunning = True
        End If
    Next
    If Not isRunning Then shell.Run Chr(34) & exePath & Chr(34), 0, False
    ' ponytail: 60-second polling keeps this dependency-free; use a Windows service for instant restart.
    WScript.Sleep 60000
Loop
"@ | Set-Content -Encoding Unicode $Launcher

        $Action = New-ScheduledTaskAction -Execute (Join-Path $env:WINDIR "System32\wscript.exe") -Argument ('"' + $Launcher + '"') -WorkingDirectory $InstallDir
        $Trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $Settings = New-ScheduledTaskSettingsSet -Hidden -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)
        $Principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Description "Keep TokenUsageInsights running for the current Windows user." -Force | Out-Null
        Start-ScheduledTask -TaskName $TaskName
    }
}

Write-Host "Token 戰情室 installed."
Write-Host ""
Write-Host "Install directory:"
Write-Host "  $InstallDir"
Write-Host ""
Write-Host "Executable shim:"
Write-Host "  $(Join-Path $BinDir "$AppName.cmd")"
Write-Host ""
Write-Host "Run:"
Write-Host "  $(Join-Path $BinDir "$AppName.cmd")"
if ($ManageAutostart) {
    Write-Host "Autostart: enabled at Windows logon"
}
