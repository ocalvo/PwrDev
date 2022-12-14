@{
    ## Module Info
    ModuleVersion      = '0.0.2'
    Description        = 'Dev scripts to deal with build errors'
    GUID               = '563978bc-d4fd-4c00-99f1-05afd5df0219'
    HelpInfoURI        = 'https://github.com/ocalvo/PwrDev'

    ## Module Components
    RootModule         = @("PwrDev.psm1")
    ScriptsToProcess   = @()
    TypesToProcess     = @()
    FormatsToProcess   = @()
    FileList           = @()

    ## Public Interface
    CmdletsToExport    = ''
    FunctionsToExport  = @(
        "Execute-Razzle",
        "Get-BuildErrors",
        "Edit-BuildErrors")
    VariablesToExport  = @()
    AliasesToExport    = @("goerror")
    # DscResourcesToExport = @()
    # DefaultCommandPrefix = ''

    ## Requirements
    # CompatiblePSEditions = @()
    PowerShellVersion      = '3.0'
    # PowerShellHostName     = ''
    # PowerShellHostVersion  = ''
    RequiredModules        = @()
    RequiredAssemblies     = @()
    ProcessorArchitecture  = 'None'
    DotNetFrameworkVersion = '2.0'
    CLRVersion             = '2.0'

    ## Author
    Author             = 'https://github.com/ocalvo'
    CompanyName        = ''
    Copyright          = ''

    ## Private Data
    PrivateData        = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @("productivity","razzle","VS","vsshell", "vs-shell", "msbuild")

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/ocalvo/PwrDev'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @"
## 2022-08-11 - Version 0.0.2

- Minor fix for vscode

## 2022-08-11 - Version 0.0.1

- Initial release

"@
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}
