---
layout: page
title: "My First Post"
permalink: /URL-PATH
---

# My First Post

This is the content of my first post using the Midnight theme.
variables:
  - name: KustomizationPaths
    value: |
      path/to/dev
      path/to/staging
      path/to/production

jobs:
- job: DeployToEnvironments
  displayName: 'Deploy to multiple environments'
  steps:
    - ${{ each path in variables.KustomizationPaths.split('\n') }}:
        - task: PowerShell@2
          inputs:
            targetType: 'inline'
            script: |
              Write-Host "Deploying to environment with KustomizationPath: ${{ path.trim() }}"
              # ここにPowerShellで実行したいコマンドを追加
              # 例: 
              # kustomize build ${{ path.trim() }} | kubectl apply -f -
          displayName: 'Execute PowerShell Script for ${{ path.trim() }}'
