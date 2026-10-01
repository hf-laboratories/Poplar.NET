# PSPoplar-EngineOperations.ps1
# Engine and execution operations for PSPoplar module

#region Engine Operations

<#
.SYNOPSIS
Creates a new Poplar execution engine.

.DESCRIPTION
Creates an execution engine from a computation graph and program for running on IPU hardware.

.PARAMETER Graph
The graph wrapper object to create the engine from.

.PARAMETER ProgramName
Optional name for the program/engine.

.EXAMPLE
$engine = New-PoplarEngine -Graph $graph -ProgramName "MyEngine"
Creates a new engine from the specified graph.
#>
function New-PoplarEngine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Graph,
        
        [string]$ProgramName = "Engine_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    )
    
    try {
        if (-not $Graph.IsActive) {
            throw "Graph is not active"
        }
        
        Write-Verbose "Creating engine '$ProgramName' from graph '$($Graph.Name)'..."
        
        # Create program
        $program = $Graph.Graph.CreateProgram()
        
        # Create engine
        $engine = $Graph.Graph.CreateEngine($program)
        
        $engineWrapper = [PSCustomObject]@{
            Name = $ProgramName
            GraphName = $Graph.Name
            DeviceId = $Graph.DeviceId
            Engine = $engine
            Program = $program
            IsLoaded = $false
            IsRunning = $false
            CreatedTime = Get-Date
            LastRunTime = $null
            ExecutionCount = 0
        }
        
        Write-Verbose "Successfully created engine '$ProgramName'"
        return $engineWrapper
    }
    catch {
        Write-Error "Failed to create engine: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Starts (loads) a Poplar engine on the target device.

.DESCRIPTION
Loads the execution engine onto the IPU device, preparing it for execution.

.PARAMETER Engine
The engine wrapper object to start.

.EXAMPLE
Start-PoplarEngine -Engine $engine
Loads the engine onto the target device.
#>
function Start-PoplarEngine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Engine
    )
    
    try {
        if ($Engine.IsLoaded) {
            Write-Verbose "Engine '$($Engine.Name)' is already loaded"
            return $true
        }
        
        Write-Verbose "Loading engine '$($Engine.Name)' on device $($Engine.DeviceId)..."
        
        # Get the device from cache
        $deviceWrapper = $script:PoplarDeviceCache[$Engine.DeviceId]
        if (-not $deviceWrapper) {
            throw "Device $($Engine.DeviceId) is not connected"
        }
        
        # Load engine
        $Engine.Engine.Load($deviceWrapper.Device)
        $Engine.IsLoaded = $true
        
        Write-Verbose "Successfully loaded engine '$($Engine.Name)'"
        return $true
    }
    catch {
        Write-Error "Failed to start engine: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
Stops (unloads) a Poplar engine.

.DESCRIPTION
Stops the execution engine and cleans up resources.

.PARAMETER Engine
The engine wrapper object to stop.

.EXAMPLE
Stop-PoplarEngine -Engine $engine
Stops the specified engine.
#>
function Stop-PoplarEngine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Engine
    )
    
    try {
        Write-Verbose "Stopping engine '$($Engine.Name)'..."
        
        $Engine.IsRunning = $false
        
        # Dispose resources
        if ($Engine.Engine) {
            $Engine.Engine.Dispose()
        }
        if ($Engine.Program) {
            $Engine.Program.Dispose()
        }
        
        $Engine.IsLoaded = $false
        
        Write-Verbose "Successfully stopped engine '$($Engine.Name)'"
        return $true
    }
    catch {
        Write-Error "Failed to stop engine: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
Executes a Poplar engine.

.DESCRIPTION
Runs the loaded engine on the IPU device, executing the computation graph.

.PARAMETER Engine
The engine wrapper object to execute.

.PARAMETER LoadIfNeeded
Automatically load the engine if not already loaded.

.PARAMETER Timeout
Timeout in seconds for execution (default: 30).

.EXAMPLE
Invoke-PoplarEngine -Engine $engine
Executes the loaded engine.

.EXAMPLE
Invoke-PoplarEngine -Engine $engine -LoadIfNeeded -Timeout 60
Loads and executes the engine with 60-second timeout.
#>
function Invoke-PoplarEngine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Engine,
        
        [switch]$LoadIfNeeded,
        
        [int]$Timeout = $script:PoplarConfiguration.DefaultTimeout
    )
    
    try {
        # Load engine if needed
        if (-not $Engine.IsLoaded) {
            if ($LoadIfNeeded) {
                if (-not (Start-PoplarEngine -Engine $Engine)) {
                    throw "Failed to load engine"
                }
            }
            else {
                throw "Engine is not loaded. Use -LoadIfNeeded or call Start-PoplarEngine first."
            }
        }
        
        Write-Verbose "Executing engine '$($Engine.Name)'..."
        $Engine.IsRunning = $true
        
        # Run with timeout
        $job = Start-Job -ScriptBlock {
            param($engineObj)
            $engineObj.Engine.Run()
        } -ArgumentList $Engine
        
        $result = Wait-Job -Job $job -Timeout $Timeout
        
        if ($result) {
            Receive-Job -Job $job
            $Engine.IsRunning = $false
            $Engine.LastRunTime = Get-Date
            $Engine.ExecutionCount++
            
            Write-Verbose "Successfully executed engine '$($Engine.Name)'"
            return $true
        }
        else {
            Stop-Job -Job $job
            $Engine.IsRunning = $false 
            throw "Engine execution timed out after $Timeout seconds"
        }
    }
    catch {
        $Engine.IsRunning = $false
        Write-Error "Failed to execute engine: $($_.Exception.Message)"
        return $false
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

#endregion

#region PopART Operations

<#
.SYNOPSIS
Imports an ONNX model for PopART inference.

.DESCRIPTION
Loads an ONNX model file and prepares it for inference on IPU hardware.

.PARAMETER ModelPath
Path to the ONNX model file.

.PARAMETER SessionName
Optional name for the inference session.

.EXAMPLE
$session = Import-ONNXModel -ModelPath "model.onnx" -SessionName "MyModel"
Imports an ONNX model for inference.
#>
function Import-ONNXModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$ModelPath,
        
        [string]$SessionName = "Session_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    )
    
    try {
        Write-Verbose "Importing ONNX model from '$ModelPath'..."
        
        # Resolve full path
        $fullPath = Resolve-Path $ModelPath
        
        # Create PopART session
        $session = New-Object HFLabs.IPUServices.PoplarBindings.PopARTInferenceSession($fullPath.Path)
        
        $sessionWrapper = [PSCustomObject]@{
            Name = $SessionName
            ModelPath = $fullPath.Path
            Session = $session
            CreatedTime = Get-Date
            InferenceCount = 0
            LastInferenceTime = $null
            IsActive = $true
        }
        
        Write-Verbose "Successfully imported model '$($fullPath.Path)'"
        return $sessionWrapper
    }
    catch {
        Write-Error "Failed to import ONNX model: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Runs inference on a PopART session.

.DESCRIPTION
Executes inference using a loaded ONNX model with the provided input data.

.PARAMETER Session
The PopART session wrapper object.

.PARAMETER InputData
Input data array for inference.

.PARAMETER OutputSize
Expected size of the output array.

.EXAMPLE
$output = Invoke-PoplarInference -Session $session -InputData $inputArray -OutputSize 10
Runs inference and returns the output array.
#>
function Invoke-PoplarInference {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Session,
        
        [Parameter(Mandatory = $true)]
        [float[]]$InputData,
        
        [Parameter(Mandatory = $true)]
        [int]$OutputSize
    )
    
    try {
        if (-not $Session.IsActive) {
            throw "Session is not active"
        }
        
        Write-Verbose "Running inference on session '$($Session.Name)' with input size $($InputData.Length)..."
        
        $outputData = $Session.Session.RunInference($InputData, $OutputSize)
        
        $Session.InferenceCount++
        $Session.LastInferenceTime = Get-Date
        
        Write-Verbose "Successfully completed inference. Output size: $($outputData.Length)"
        return $outputData
    }
    catch {
        Write-Error "Failed to run inference: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Creates a new PopART session.

.DESCRIPTION
Creates a new PopART inference session from an ONNX model file.

.PARAMETER ModelPath
Path to the ONNX model file.

.PARAMETER SessionName
Optional name for the session.

.EXAMPLE
$session = New-PoplarSession -ModelPath "model.onnx"
Creates a new PopART session.
#>
function New-PoplarSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModelPath,
        
        [string]$SessionName = "Session_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    )
    
    return Import-ONNXModel -ModelPath $ModelPath -SessionName $SessionName
}

<#
.SYNOPSIS
Removes a PopART session and cleans up resources.

.DESCRIPTION
Properly disposes of a PopART inference session and all associated resources.

.PARAMETER Session
The session wrapper object to remove.

.EXAMPLE
Remove-PoplarSession -Session $session
Removes the specified session.
#>
function Remove-PoplarSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Session
    )
    
    try {
        Write-Verbose "Removing session '$($Session.Name)'..."
        
        $Session.Session.Dispose()
        $Session.IsActive = $false
        
        Write-Verbose "Successfully removed session '$($Session.Name)'"
    }
    catch {
        Write-Error "Failed to remove session: $($_.Exception.Message)"
    }
}

#endregion

#region Utility Operations

<#
.SYNOPSIS
Gets the Poplar SDK version.

.DESCRIPTION
Returns the version of the installed Poplar SDK.

.EXAMPLE
Get-PoplarVersion
Returns the Poplar SDK version string.
#>
function Get-PoplarVersion {
    [CmdletBinding()]
    param()
    
    try {
        return [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetVersion()
    }
    catch {
        Write-Error "Failed to get Poplar version: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Tests the Poplar environment and configuration.

.DESCRIPTION
Performs comprehensive testing of the Poplar environment, devices, and configuration.

.PARAMETER Detailed
Include detailed test results.

.EXAMPLE
Test-PoplarEnvironment -Detailed
Performs detailed environment testing.
#>
function Test-PoplarEnvironment {
    [CmdletBinding()]
    param(
        [switch]$Detailed
    )
    
    try {
        Write-Verbose "Testing Poplar environment..."
        
        $results = [PSCustomObject]@{
            PlatformSupported = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::IsPlatformSupported()
            DevicesAvailable = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::AreDevicesAvailable()
            DeviceCount = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetDeviceCount()
            Version = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetVersion()
            PlatformInfo = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetPlatformInfo()
            TestTime = Get-Date
            OverallStatus = "Unknown"
        }
        
        # Determine overall status
        if ($results.PlatformSupported -and $results.DevicesAvailable -and $results.DeviceCount -gt 0) {
            $results.OverallStatus = "Pass"
        }
        elseif ($results.PlatformSupported) {
            $results.OverallStatus = "Platform OK, No Devices"
        }
        else {
            $results.OverallStatus = "Fail"
        }
        
        if ($Detailed) {
            # Add device tests
            $deviceTests = Test-PoplarDevice
            $results | Add-Member -NotePropertyName "DeviceTests" -NotePropertyValue $deviceTests
        }
        
        return $results
    }
    catch {
        Write-Error "Failed to test environment: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Gets comprehensive Poplar system information.

.DESCRIPTION
Provides detailed information about the Poplar system, devices, and current state.

.EXAMPLE
Get-PoplarSystemInfo
Returns comprehensive system information.
#>
function Get-PoplarSystemInfo {
    [CmdletBinding()]
    param()
    
    try {
        $systemInfo = [PSCustomObject]@{
            # Poplar information
            PoplarVersion = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetVersion()
            PlatformInfo = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetPlatformInfo()
            PlatformSupported = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::IsPlatformSupported()
            
            # Device information
            DeviceCount = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetDeviceCount()
            DevicesAvailable = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::AreDevicesAvailable()
            ConnectedDevices = $script:PoplarDeviceCache.Count
            ConnectedDeviceIds = @($script:PoplarDeviceCache.Keys)
            
            # Module information
            ModuleVersion = (Get-Module PSPoplar).Version
            ModulePath = $script:ModulePath
            CSBindingsPath = $script:CSBindingsPath
            Configuration = $script:PoplarConfiguration
            
            # System information
            PowerShellVersion = $PSVersionTable.PSVersion
            OperatingSystem = [System.Environment]::OSVersion
            ProcessorCount = [System.Environment]::ProcessorCount
            MachineName = [System.Environment]::MachineName
            
            # Timestamps
            QueryTime = Get-Date
        }
        
        return $systemInfo
    }
    catch {
        Write-Error "Failed to get system info: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Clears any pending Poplar error messages.

.DESCRIPTION
Clears the thread-local error message storage in the native Poplar library.

.EXAMPLE
Clear-PoplarError
Clears any pending error messages.
#>
function Clear-PoplarError {
    [CmdletBinding()]
    param()
    
    try {
        [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::ClearErrors()
        Write-Verbose "Cleared Poplar error messages"
    }
    catch {
        Write-Error "Failed to clear errors: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
Gets the last Poplar error message.

.DESCRIPTION
Retrieves the last error message from the native Poplar library.

.EXAMPLE
Get-PoplarError
Returns the last error message, if any.
#>
function Get-PoplarError {
    [CmdletBinding()]
    param()
    
    try {
        $error = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetLastError()
        if ([string]::IsNullOrEmpty($error)) {
            return "No error messages"
        }
        return $error
    }
    catch {
        Write-Error "Failed to get error: $($_.Exception.Message)"
        return $null
    }
}

#endregion

# Export additional functions
Export-ModuleMember -Function New-PoplarEngine, Start-PoplarEngine, Stop-PoplarEngine, Invoke-PoplarEngine
Export-ModuleMember -Function Import-ONNXModel, Invoke-PoplarInference, New-PoplarSession, Remove-PoplarSession
Export-ModuleMember -Function Get-PoplarVersion, Test-PoplarEnvironment, Get-PoplarSystemInfo, Clear-PoplarError, Get-PoplarError
