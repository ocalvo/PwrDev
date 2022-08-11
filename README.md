# PwrDev
Scripts to help developer

# Setup ([via Powershell gallery](https://docs.microsoft.com/en-us/powershell/scripting/gallery/getting-started?view=powershell-7.1))
```
Install-module PwrDev -Scope CurrentUser
```

# Manual Setup

1. Clone the repo into your Modules folder:
  - For PowerShell core:
  ```
  git clone https://github.com/ocalvo/PwrDev.git "$env:HomeDrive$env:HomePath\Documents\PowerShell\Modules\PwrDev"
  ```
  - For Windows Power Shell:
  ```
  git clone https://github.com/ocalvo/PwrDev.git "$env:HomeDrive$env:HomePath\Documents\WindowsPowerShell\Modules\PwrDev"
  ```
2. In a VS command like shell execute:
```
Import-Module PwrDev
```

# Usage

```
msbuild ...

goerror  # This will open the editor in the first error detected
Get-BuildErrors # Lists all errors detected
Edit-BuildErrors # Opens the editor in all errors detected.
```
