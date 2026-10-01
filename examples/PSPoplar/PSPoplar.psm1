# PSPoplar.psm1
# PowerShell Module for Poplar IPU Operations

# Module initialization
$script:ModulePath = $PSScriptRoot
$script:CSBindingsPath = Join-Path (Split-Path $PSScriptRoot -Parent) "cs-bindings"
$script:PoplarDeviceCache = @{}
$script:PoplarConfiguration = @{
    DefaultDevice = 0
    EnableLogging = $true
    LogLevel = "Information"
    TensorDataType = "Float"
    DefaultTimeout = 30
}

# Load the C# bindings assembly
function Import-PoplarBindings {
    [CmdletBinding()]
    param()
    
    try {
        # First try to load from built assembly
        $assemblyPath = Join-Path $script:CSBindingsPath "bin\Debug\net6.0\PoplarBindingsExample.dll"
        if (Test-Path $assemblyPath) {
            Add-Type -Path $assemblyPath
            Write-Verbose "Loaded Poplar bindings from: $assemblyPath"
            return $true
        }
        
        # Fallback: compile on-the-fly from source files
        $sourceFiles = Get-ChildItem -Path $script:CSBindingsPath -Filter "*.cs" | Where-Object { $_.Name -ne "Program.cs" }
        if ($sourceFiles.Count -gt 0) {
            $sourceCode = $sourceFiles | ForEach-Object { Get-Content $_.FullName -Raw }
            Add-Type -TypeDefinition ($sourceCode -join "`n") -ReferencedAssemblies @("System.dll", "System.Runtime.InteropServices.dll")
            Write-Verbose "Compiled Poplar bindings from source files"
            return $true
        }
        
        Write-Error "Could not load Poplar C# bindings. Please build the cs-bindings project first."
        return $false
    }
    catch {
        Write-Error "Failed to load Poplar bindings: $($_.Exception.Message)"
        return $false
    }
}

# Initialize module with comprehensive fallback mechanisms
$initializationResult = Import-PoplarBindings
if (-not $initializationResult) {
    Write-Warning "Primary initialization failed. Attempting fallback strategies..."
    
    # Fallback 1: Try alternative binding paths
    $alternativePaths = @(
        "$PSScriptRoot\..\..\bin\Debug\net6.0\HFLabs.IPUServices.dll",
        "$PSScriptRoot\..\..\bin\Release\net6.0\HFLabs.IPUServices.dll",
        "$PSScriptRoot\..\bin\cs-bindings.dll",
        "$PSScriptRoot\cs-bindings.dll"
    )
    
    $fallbackSuccess = $false
    foreach ($altPath in $alternativePaths) {
        if (Test-Path $altPath) {
            try {
                Add-Type -Path $altPath
                Write-Warning "Successfully loaded bindings from alternative path: $altPath"
                $fallbackSuccess = $true
                break
            }
            catch {
                Write-Verbose "Alternative path failed: $altPath - $($_.Exception.Message)"
            }
        }
    }
    
    # Fallback 2: Try loading minimal bindings for diagnostics
    if (-not $fallbackSuccess) {
        try {
            # Create minimal stub classes for diagnostic purposes
            $stubCode = @"
namespace HFLabs.IPUServices.PoplarBindings {
    public static class PoplarUtilities {
        public static int GetDeviceCount() {
            Write-Warning "Poplar bindings not available. Install Poplar SDK and rebuild bindings to enable full functionality.";
        }
        public static string GetVersion() {
            return "No Poplar SDK detected";
        }
        public static string GetPlatformInfo() {
            return "Platform: Unknown (Poplar SDK not available)";
        }
    }
}
"@
            Add-Type -TypeDefinition $stubCode
            Write-Warning "Loaded diagnostic stub bindings. Limited functionality available."
            $fallbackSuccess = $true
        }
        catch {
            Write-Error "All fallback attempts failed: $($_.Exception.Message)"
        }
    }
    
    # Fallback 3: Provide guidance for manual resolution
    if (-not $fallbackSuccess) {
        $errorMessage = @"
❌ Failed to initialize PSPoplar module: Could not load C# bindings

Troubleshooting steps:
1. Verify Poplar SDK installation:
   • Check POPLAR_SDK_ROOT environment variable
   • Run 'source `$POPLAR_SDK_ROOT/enable.sh' (Linux) or equivalent (Windows)
   
2. Build the C# bindings:
   • Navigate to the cs-bindings directory
   • Run 'dotnet build' or 'msbuild cs-bindings.csproj'
   
3. Check file permissions:
   • Ensure PowerShell can access the DLL files
   • Try running as administrator if needed
   
4. Verify .NET requirements:
   • Ensure .NET 6.0 or later is installed
   • Check that required dependencies are available
   
5. Alternative approaches:
   • Use the standalone executable instead of PowerShell module
   • Contact support for manual configuration assistance

For immediate diagnostics, run: Test-PoplarEnvironment
"@
        throw $errorMessage
    }
}

#region Device Management

<#
.SYNOPSIS
Gets available Poplar IPU devices.

.DESCRIPTION
Retrieves information about available Graphcore IPU devices in the system.

.PARAMETER DeviceId
Specific device ID to retrieve. If not specified, returns all available devices.

.PARAMETER Detailed
Include detailed device information.

.EXAMPLE
Get-PoplarDevice
Gets all available IPU devices.

.EXAMPLE
Get-PoplarDevice -DeviceId 0 -Detailed
Gets detailed information about device 0.
#>
function Get-PoplarDevice {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [int]$DeviceId = -1,
        
        [switch]$Detailed
    )
    
    try {
        # Attempt to get device count with enhanced error handling
        try {
        $deviceCount = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetDeviceCount()
        }
        catch [System.NotImplementedException] {
            Write-Warning "Poplar bindings not properly loaded. Using diagnostic mode."
            return @([PSCustomObject]@{
                DeviceId = -1
                Status = "Not Available"
                Type = "IPU (Diagnostic Mode)"
                IsConnected = $false
                Error = "Poplar SDK not available or bindings not loaded"
            })
        }
        catch {
            Write-Warning "Failed to query IPU devices: $($_.Exception.Message)"
            Write-Host "Troubleshooting device detection issues:" -ForegroundColor Yellow
            Write-Host "• Check IPU hardware connectivity" -ForegroundColor Yellow
            Write-Host "• Verify IPU drivers are installed and loaded" -ForegroundColor Yellow
            Write-Host "• Run 'gc-info -l' to check hardware status" -ForegroundColor Yellow
            Write-Host "• Try restarting IPU services: sudo systemctl restart gc-services" -ForegroundColor Yellow
            
            return @([PSCustomObject]@{
                DeviceId = -1
                Status = "Error"
                Type = "IPU"
                IsConnected = $false
                Error = $_.Exception.Message
            })
        }
        
        if ($deviceCount -eq 0) {
            Write-Warning "No IPU devices found. This could indicate:"
            Write-Host "• No Graphcore IPU hardware is installed" -ForegroundColor Yellow
            Write-Host "• IPU hardware is not properly initialized" -ForegroundColor Yellow
            Write-Host "• Driver issues preventing device detection" -ForegroundColor Yellow
            Write-Host "• Insufficient permissions to access IPU devices" -ForegroundColor Yellow
            Write-Host "" -ForegroundColor Yellow
            Write-Host "Run Test-PoplarEnvironment for detailed diagnostics." -ForegroundColor Cyan
            return @()
        }
        
        $devices = @()
        $startId = if ($DeviceId -ge 0) { $DeviceId } else { 0 }
        $endId = if ($DeviceId -ge 0) { $DeviceId } else { $deviceCount - 1 }
        
        for ($i = $startId; $i -le $endId; $i++) {
            $deviceInfo = [PSCustomObject]@{
                DeviceId = $i
                Status = "Available"
                Type = "IPU"
                IsConnected = $script:PoplarDeviceCache.ContainsKey($i)
            }
            
            if ($Detailed) {
                $deviceInfo | Add-Member -NotePropertyName "Version" -NotePropertyValue ([HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetVersion())
                $deviceInfo | Add-Member -NotePropertyName "PlatformInfo" -NotePropertyValue ([HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetPlatformInfo())
            }
            
            $devices += $deviceInfo
        }
        
        return $devices
    }
    catch {
        Write-Error "Failed to get Poplar devices: $($_.Exception.Message)"
        return @()
    }
}

<#
.SYNOPSIS
Gets detailed information about Poplar system and devices.

.DESCRIPTION
Provides comprehensive information about the Poplar environment, SDK version, and device capabilities.

.EXAMPLE
Get-PoplarDeviceInfo
Shows detailed system and device information.
#>
function Get-PoplarDeviceInfo {
    [CmdletBinding()]
    param()
    
    try {
        $info = [PSCustomObject]@{
            PoplarVersion = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetVersion()
            DeviceCount = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetDeviceCount()
            PlatformSupported = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::IsPlatformSupported()
            PlatformInfo = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetPlatformInfo()
            DevicesAvailable = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::AreDevicesAvailable()
            ConnectedDevices = $script:PoplarDeviceCache.Count
            Configuration = $script:PoplarConfiguration
        }
        
        return $info
    }
    catch {
        Write-Error "Failed to get device info: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Tests if Poplar devices are available and accessible.

.DESCRIPTION
Performs a comprehensive test of the Poplar environment and device accessibility.

.PARAMETER DeviceId
Specific device to test. If not specified, tests all devices.

.EXAMPLE
Test-PoplarDevice
Tests all available devices.

.EXAMPLE
Test-PoplarDevice -DeviceId 0
Tests specific device 0.
#>
function Test-PoplarDevice {
    [CmdletBinding()]
    param(
        [int]$DeviceId = -1
    )
    
    try {
        Write-Verbose "Testing Poplar environment..."
        
        # Test platform support
        if (-not [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::IsPlatformSupported()) {
            Write-Error "Platform not supported or native libraries not found"
            return $false
        }
        
        # Test device availability
        $deviceCount = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetDeviceCount()
        if ($deviceCount -eq 0) {
            Write-Warning "No IPU devices available"
            return $false
        }
        
        Write-Verbose "Found $deviceCount IPU device(s)"
        
        # Test specific device or all devices
        $testResults = @()
        $startId = if ($DeviceId -ge 0) { $DeviceId } else { 0 }
        $endId = if ($DeviceId -ge 0) { $DeviceId } else { $deviceCount - 1 }
        
        for ($i = $startId; $i -le $endId; $i++) {
            $testResult = Test-SingleDevice -DeviceId $i
            $testResults += $testResult
        }
        
        return $testResults
    }
    catch {
        Write-Error "Device test failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-SingleDevice {
    param([int]$DeviceId)
    
    try {
        Write-Verbose "Testing device $DeviceId..."
        
        $deviceManager = New-Object HFLabs.IPUServices.PoplarBindings.PoplarDeviceManager
        try {
            $device = $deviceManager.AcquireDevice($DeviceId)
            try {
                $graph = $device.CreateGraph()
                try {
                    $result = [PSCustomObject]@{
                        DeviceId = $DeviceId
                        Status = "Pass"
                        CanAcquire = $true
                        CanCreateGraph = $true
                        Error = $null
                    }
                    
                    Write-Verbose "Device $DeviceId test passed"
                    return $result
                }
                finally {
                    $graph.Dispose()
                }
            }
            finally {
                $device.Dispose()
            }
        }
        finally {
            $deviceManager.Dispose()
        }
    }
    catch {
        return [PSCustomObject]@{
            DeviceId = $DeviceId
            Status = "Fail"
            CanAcquire = $false
            CanCreateGraph = $false
            Error = $_.Exception.Message
        }
    }
}

<#
.SYNOPSIS
Connects to a Poplar IPU device.

.DESCRIPTION
Establishes a connection to a specific IPU device and caches it for subsequent operations.

.PARAMETER DeviceId
The ID of the device to connect to.

.PARAMETER Force
Force reconnection even if already connected.

.EXAMPLE
Connect-PoplarDevice -DeviceId 0
Connects to IPU device 0.
#>
function Connect-PoplarDevice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DeviceId,
        
        [switch]$Force
    )
    
    try {
        if ($script:PoplarDeviceCache.ContainsKey($DeviceId) -and -not $Force) {
            Write-Verbose "Device $DeviceId already connected"
            return $script:PoplarDeviceCache[$DeviceId]
        }
        
        Write-Verbose "Connecting to device $DeviceId..."
        
        $deviceManager = New-Object HFLabs.IPUServices.PoplarBindings.PoplarDeviceManager
        $device = $deviceManager.AcquireDevice($DeviceId)
        
        $deviceWrapper = [PSCustomObject]@{
            DeviceId = $DeviceId
            Device = $device
            DeviceManager = $deviceManager
            ConnectedTime = Get-Date
            IsConnected = $true
        }
        
        $script:PoplarDeviceCache[$DeviceId] = $deviceWrapper
        
        Write-Verbose "Successfully connected to device $DeviceId"
        return $deviceWrapper
    }
    catch {
        Write-Error "Failed to connect to device $DeviceId`: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Disconnects from a Poplar IPU device.

.DESCRIPTION
Disconnects from a specific IPU device and cleans up resources.

.PARAMETER DeviceId
The ID of the device to disconnect from. If not specified, disconnects from all devices.

.EXAMPLE
Disconnect-PoplarDevice -DeviceId 0
Disconnects from device 0.

.EXAMPLE
Disconnect-PoplarDevice
Disconnects from all connected devices.
#>
function Disconnect-PoplarDevice {
    [CmdletBinding()]
    param(
        [int]$DeviceId = -1
    )
    
    try {
        if ($DeviceId -ge 0) {
            # Disconnect specific device
            if ($script:PoplarDeviceCache.ContainsKey($DeviceId)) {
                $deviceWrapper = $script:PoplarDeviceCache[$DeviceId]
                $deviceWrapper.Device.Dispose()
                $deviceWrapper.DeviceManager.Dispose()
                $script:PoplarDeviceCache.Remove($DeviceId)
                Write-Verbose "Disconnected from device $DeviceId"
            }
            else {
                Write-Warning "Device $DeviceId is not connected"
            }
        }
        else {
            # Disconnect all devices
            $deviceIds = @($script:PoplarDeviceCache.Keys)
            foreach ($id in $deviceIds) {
                Disconnect-PoplarDevice -DeviceId $id
            }
            Write-Verbose "Disconnected from all devices"
        }
    }
    catch {
        Write-Error "Failed to disconnect from device: $($_.Exception.Message)"
    }
}

#endregion

#region Graph Operations

<#
.SYNOPSIS
Creates a new Poplar computation graph.

.DESCRIPTION
Creates a new computation graph on the specified device for building ML operations.

.PARAMETER DeviceId
The device ID to create the graph on.

.PARAMETER Name
Optional name for the graph.

.EXAMPLE
New-PoplarGraph -DeviceId 0 -Name "MyGraph"
Creates a new graph named "MyGraph" on device 0.
#>
function New-PoplarGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DeviceId,
        
        [string]$Name = "Graph_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    )
    
    try {
        # Ensure device is connected
        $deviceWrapper = $script:PoplarDeviceCache[$DeviceId]
        if (-not $deviceWrapper) {
            $deviceWrapper = Connect-PoplarDevice -DeviceId $DeviceId
            if (-not $deviceWrapper) {
                throw "Failed to connect to device $DeviceId"
            }
        }
        
        Write-Verbose "Creating graph '$Name' on device $DeviceId..."
        
        $graph = $deviceWrapper.Device.CreateGraph()
        
        $graphWrapper = [PSCustomObject]@{
            Name = $Name
            DeviceId = $DeviceId
            Graph = $graph
            Tensors = @{}
            CreatedTime = Get-Date
            IsActive = $true
        }
        
        Write-Verbose "Successfully created graph '$Name'"
        return $graphWrapper
    }
    catch {
        Write-Error "Failed to create graph: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Adds a tensor to a Poplar graph.

.DESCRIPTION
Adds a tensor variable to an existing Poplar computation graph.

.PARAMETER Graph
The graph wrapper object to add the tensor to.

.PARAMETER Shape
The shape of the tensor as an array of dimensions.

.PARAMETER DataType
The data type of the tensor (Float, Half, Int, UnsignedInt).

.PARAMETER Name
Name for the tensor variable.

.EXAMPLE
$tensor = Add-PoplarTensor -Graph $graph -Shape @(1, 128) -DataType "Float" -Name "input"
Adds a float tensor with shape [1, 128] named "input".
#>
function Add-PoplarTensor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Graph,
        
        [Parameter(Mandatory = $true)]
        [int[]]$Shape,
        
        [ValidateSet("Float", "Half", "Int", "UnsignedInt")]
        [string]$DataType = $script:PoplarConfiguration.TensorDataType,
        
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    try {
        if (-not $Graph.IsActive) {
            throw "Graph is not active"
        }
        
        Write-Verbose "Adding tensor '$Name' with shape [$($Shape -join ', ')] and type $DataType..."
        
        # Convert string to enum
        $dataTypeEnum = [HFLabs.IPUServices.PoplarBindings.PoplarDataType]::$DataType
        
        $tensor = $Graph.Graph.AddVariable($dataTypeEnum, $Shape, $Name)
        
        $tensorWrapper = [PSCustomObject]@{
            Name = $Name
            Shape = $Shape
            DataType = $DataType
            ElementCount = ([HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::CalculateElementCount($Shape))
            SizeBytes = $tensor.TotalSizeBytes
            Tensor = $tensor
            GraphName = $Graph.Name
            CreatedTime = Get-Date
        }
        
        $Graph.Tensors[$Name] = $tensorWrapper
        
        Write-Verbose "Successfully added tensor '$Name'"
        return $tensorWrapper
    }
    catch {
        Write-Error "Failed to add tensor: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Gets information about tensors in a graph.

.DESCRIPTION
Retrieves information about tensors in a Poplar computation graph.

.PARAMETER Graph
The graph wrapper object to query.

.PARAMETER TensorName
Specific tensor name to get info for. If not specified, returns all tensors.

.EXAMPLE
Get-PoplarTensorInfo -Graph $graph
Gets info for all tensors in the graph.

.EXAMPLE
Get-PoplarTensorInfo -Graph $graph -TensorName "input"
Gets info for the "input" tensor.
#>
function Get-PoplarTensorInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Graph,
        
        [string]$TensorName
    )
    
    try {
        if ($TensorName) {
            if ($Graph.Tensors.ContainsKey($TensorName)) {
                return $Graph.Tensors[$TensorName]
            }
            else {
                Write-Warning "Tensor '$TensorName' not found in graph '$($Graph.Name)'"
                return $null
            }
        }
        else {
            return $Graph.Tensors.Values
        }
    }
    catch {
        Write-Error "Failed to get tensor info: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Removes a Poplar graph and cleans up resources.

.DESCRIPTION
Properly disposes of a Poplar computation graph and all associated resources.

.PARAMETER Graph
The graph wrapper object to remove.

.EXAMPLE
Remove-PoplarGraph -Graph $graph
Removes the specified graph.
#>
function Remove-PoplarGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Graph
    )
    
    try {
        Write-Verbose "Removing graph '$($Graph.Name)'..."
        
        # Dispose tensors
        foreach ($tensor in $Graph.Tensors.Values) {
            $tensor.Tensor.Dispose()
        }
        
        # Dispose graph
        $Graph.Graph.Dispose()
        $Graph.IsActive = $false
        
        Write-Verbose "Successfully removed graph '$($Graph.Name)'"
    }
    catch {
        Write-Error "Failed to remove graph: $($_.Exception.Message)"
    }
}

#endregion

<#
.SYNOPSIS
Tests the Poplar environment and provides comprehensive diagnostics.

.DESCRIPTION
Performs a comprehensive test of the Poplar SDK installation, environment configuration,
hardware detection, and module functionality. Provides detailed diagnostic information
and troubleshooting guidance.

.PARAMETER IncludeHardwareTest
Include hardware detection and device enumeration tests.

.PARAMETER Verbose
Provide detailed diagnostic output.

.EXAMPLE
Test-PoplarEnvironment
Performs basic environment diagnostics.

.EXAMPLE
Test-PoplarEnvironment -IncludeHardwareTest -Verbose
Performs comprehensive diagnostics including hardware tests.
#>
function Test-PoplarEnvironment {
    [CmdletBinding()]
    param(
        [switch]$IncludeHardwareTest,
        [switch]$ShowRecommendations = $true
    )
    
    Write-Host "🔍 Poplar Environment Diagnostics" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    
    $diagnosticResults = @{
        EnvironmentVariables = @{}
        BindingsStatus = ""
        HardwareStatus = @{}
        Recommendations = @()
        OverallStatus = "Unknown"
    }
    
    # Test 1: Environment Variables
    Write-Host "`n📋 Environment Variables:" -ForegroundColor Yellow
    $envVars = @("POPLAR_SDK_ROOT", "POPVISION_PATH", "PATH", "LD_LIBRARY_PATH")
    
    foreach ($envVar in $envVars) {
        $value = [Environment]::GetEnvironmentVariable($envVar)
        if ($value) {
            $diagnosticResults.EnvironmentVariables[$envVar] = $value
            if ($envVar -eq "PATH" -and $value.Contains("poplar")) {
                Write-Host "  ✅ $envVar contains Poplar paths" -ForegroundColor Green
            }
            elseif ($envVar -ne "PATH") {
                Write-Host "  ✅ $envVar = $($value.Substring(0, [Math]::Min(60, $value.Length)))..." -ForegroundColor Green
            }
        }
        else {
            Write-Host "  ❌ $envVar not set" -ForegroundColor Red
            $diagnosticResults.Recommendations += "Set $envVar environment variable"
        }
    }
    
    # Test 2: C# Bindings Status
    Write-Host "`n🔧 C# Bindings Status:" -ForegroundColor Yellow
    try {
        $version = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetVersion()
        Write-Host "  ✅ Bindings loaded successfully" -ForegroundColor Green
        Write-Host "  📦 Version: $version" -ForegroundColor Cyan
        $diagnosticResults.BindingsStatus = "Loaded"
    }
    catch [System.NotImplementedException] {
        Write-Host "  ⚠️  Diagnostic stub bindings active" -ForegroundColor Yellow
        $diagnosticResults.BindingsStatus = "Stub"
        $diagnosticResults.Recommendations += "Build and install full C# bindings"
    }
    catch {
        Write-Host "  ❌ Bindings failed to load: $($_.Exception.Message)" -ForegroundColor Red
        $diagnosticResults.BindingsStatus = "Failed"
        $diagnosticResults.Recommendations += "Fix C# bindings loading issues"
    }
    
    # Test 3: Hardware Detection (if requested)
    if ($IncludeHardwareTest) {
        Write-Host "`n🖥️  Hardware Detection:" -ForegroundColor Yellow
        try {
            $devices = Get-PoplarDevice -ErrorAction SilentlyContinue
            if ($devices -and $devices.Count -gt 0 -and $devices[0].DeviceId -ge 0) {
                Write-Host "  ✅ Found $($devices.Count) IPU device(s)" -ForegroundColor Green
                foreach ($device in $devices) {
                    Write-Host "    • Device $($device.DeviceId): $($device.Status)" -ForegroundColor Cyan
                }
                $diagnosticResults.HardwareStatus["DeviceCount"] = $devices.Count
                $diagnosticResults.HardwareStatus["Status"] = "Available"
            }
            else {
                Write-Host "  ⚠️  No IPU devices detected" -ForegroundColor Yellow
                $diagnosticResults.HardwareStatus["DeviceCount"] = 0
                $diagnosticResults.HardwareStatus["Status"] = "Not Available"
                $diagnosticResults.Recommendations += "Check IPU hardware installation and drivers"
            }
        }
        catch {
            Write-Host "  ❌ Hardware detection failed: $($_.Exception.Message)" -ForegroundColor Red
            $diagnosticResults.HardwareStatus["Status"] = "Error"
            $diagnosticResults.HardwareStatus["Error"] = $_.Exception.Message
        }
    }
    
    # Test 4: Command Line Tools
    Write-Host "`n🛠️  Command Line Tools:" -ForegroundColor Yellow
    $tools = @("gc-info", "popc", "gc-monitor")
    foreach ($tool in $tools) {
        try {
            $result = & $tool "--version" 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ $tool available" -ForegroundColor Green
            }
            else {
                Write-Host "  ⚠️  $tool available but returned error" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  ❌ $tool not found in PATH" -ForegroundColor Red
            $diagnosticResults.Recommendations += "Install or add $tool to PATH"
        }
    }
    
    # Overall Assessment
    Write-Host "`n📊 Overall Assessment:" -ForegroundColor Yellow
    $criticalIssues = ($diagnosticResults.BindingsStatus -eq "Failed") -or 
                     ($IncludeHardwareTest -and $diagnosticResults.HardwareStatus["Status"] -eq "Error")
    
    if ($criticalIssues) {
        $diagnosticResults.OverallStatus = "Critical Issues"
        Write-Host "  ❌ Critical issues detected" -ForegroundColor Red
    }
    elseif ($diagnosticResults.Recommendations.Count -gt 0) {
        $diagnosticResults.OverallStatus = "Minor Issues"
        Write-Host "  ⚠️  Minor issues or optimizations available" -ForegroundColor Yellow
    }
    else {
        $diagnosticResults.OverallStatus = "Healthy"
        Write-Host "  ✅ Environment appears healthy" -ForegroundColor Green
    }
    
    # Recommendations
    if ($ShowRecommendations -and $diagnosticResults.Recommendations.Count -gt 0) {
        Write-Host "`n💡 Recommendations:" -ForegroundColor Yellow
        foreach ($recommendation in $diagnosticResults.Recommendations) {
            Write-Host "  • $recommendation" -ForegroundColor White
        }
    }
    
    return $diagnosticResults
}

# Continue with more functions in next part...

# Load additional module components
. (Join-Path $PSScriptRoot "PSPoplar-EngineOperations.ps1")
. (Join-Path $PSScriptRoot "PSPoplar-PipelineOperations.ps1") 
. (Join-Path $PSScriptRoot "PSPoplar-UtilityFunctions.ps1")

# Module cleanup
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    # Clean up device connections
    Disconnect-PoplarDevice
    Write-Verbose "PSPoplar module cleanup completed"
}

# Export module members
Export-ModuleMember -Function * -Variable PoplarDeviceCache, PoplarConfiguration
