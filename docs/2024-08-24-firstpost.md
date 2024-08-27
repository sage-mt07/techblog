---
layout: page
title: "My First Post"
permalink: /URL-PATH
---

# My First Post


trigger:
- main

pool:
  name: 'Self-hosted-pool-name'  # セルフホステッドエージェントプールの名前を指定

steps:
- powershell: |
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Host "Installing PowerShell Core..."
        Invoke-WebRequest -Uri https://github.com/PowerShell/PowerShell/releases/download/v7.3.4/PowerShell-7.3.4-win-x64.msi -OutFile PowerShell.msi
        Start-Process msiexec.exe -ArgumentList '/i PowerShell.msi /quiet' -Wait
        Write-Host "PowerShell Core installed successfully."
    }
    else {
        Write-Host "PowerShell Core is already installed."
    }
  displayName: 'Install PowerShell Core if not present'

- powershell: |
    Write-Host "PowerShell Core Version:"
    pwsh -Command '$PSVersionTable.PSVersion'
  displayName: 'Check PowerShell Core Version'

- powershell: |
    Write-Host "This is a PowerShell script running in the pipeline."
  displayName: 'Run PowerShell Script'
  pwsh: true
