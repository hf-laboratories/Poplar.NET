# PSPoplar.psd1
# PowerShell Module Manifest for Poplar IPU Operations

@{
    # Module metadata
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'HFLabs'
    CompanyName = 'HFLabs'
    Copyright = 'Copyright (c) 2025 HFLabs. All rights reserved.'
    Description = 'PowerShell module for Graphcore Poplar IPU operations with ergonomic cmdlets'
    
    # PowerShell version requirements
    PowerShellVersion = '5.1'
    
    # Required modules
    RequiredModules = @()
    
    # Required assemblies (will be loaded from cs-bindings)
    RequiredAssemblies = @()
    
    # Module components
    RootModule = 'PSPoplar.psm1'
    
    # Functions to export
    FunctionsToExport = @(
        # Device management
        'Get-PoplarDevice',
        'Get-PoplarDeviceInfo',
        'Test-PoplarDevice',
        'Connect-PoplarDevice',
        'Disconnect-PoplarDevice',
        
        # Graph operations
        'New-PoplarGraph',
        'Add-PoplarTensor',
        'Get-PoplarTensorInfo',
        'Remove-PoplarGraph',
        
        # Engine operations
        'New-PoplarEngine',
        'Start-PoplarEngine',
        'Stop-PoplarEngine',
        'Invoke-PoplarEngine',
        
        # PopART operations
        'Import-ONNXModel',
        'Invoke-PoplarInference',
        'New-PoplarSession',
        'Remove-PoplarSession',
        
        # Utility operations
        'Get-PoplarVersion',
        'Test-PoplarEnvironment',
        'Get-PoplarSystemInfo',
        'Clear-PoplarError',
        'Get-PoplarError',
        
        # Pipeline operations
        'New-PoplarPipeline',
        'Add-PoplarPipelineStep',
        'Invoke-PoplarPipeline',
        
        # Tensor operations
        'New-PoplarTensorSpec',
        'ConvertTo-PoplarTensor',
        'ConvertFrom-PoplarTensor',
        'Test-PoplarTensorShape',
        
        # Configuration
        'Set-PoplarConfiguration',
        'Get-PoplarConfiguration',
        'Reset-PoplarConfiguration'
    )
    
    # Cmdlets to export
    CmdletsToExport = @()
    
    # Variables to export
    VariablesToExport = @(
        'PoplarDeviceCache',
        'PoplarConfiguration'
    )
    
    # Aliases to export
    AliasesToExport = @(
        'poplar-info',
        'poplar-run',
        'poplar-devices',
        'poplar-inference'
    )
    
    # Private data
    PrivateData = @{
        PSVersion = '5.1'
        Tags = @('Graphcore', 'IPU', 'MachineLearning', 'AI', 'Poplar', 'ONNX')
        LicenseUri = ''
        ProjectUri = ''
        IconUri = ''
        ReleaseNotes = 'Initial release of PSPoplar module for Graphcore IPU operations'
    }
    
    # Help info
    HelpInfoURI = ''
}
