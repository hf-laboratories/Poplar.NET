# PSPoplar-UtilityFunctions.ps1
# Utility and helper functions for PSPoplar module

#region System Information and Diagnostics

<#
.SYNOPSIS
Gets Poplar system information.

.DESCRIPTION
Retrieves comprehensive information about the Poplar installation and system.

.EXAMPLE
Get-PoplarSystemInfo
Returns system information including Poplar version, devices, and configuration.
#>
function Get-PoplarSystemInfo {
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Gathering Poplar system information..."
        
        $systemInfo = [PSCustomObject]@{
            PoplarVersion = "Unknown"
            PopARTVersion = "Unknown"
            DeviceCount = 0
            Devices = @()
            SystemMemory = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
            OSInfo = "$($env:OS) - $(Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty Caption)"
            ProcessorInfo = (Get-WmiObject -Class Win32_Processor | Select-Object -First 1).Name
            PoplarEnvironment = @{
                POPLAR_SDK_ENABLED = $env:POPLAR_SDK_ENABLED
                POPLAR_LOG_LEVEL = $env:POPLAR_LOG_LEVEL
            }
            ModuleInfo = @{
                PSPoplarVersion = (Get-Module PSPoplar).Version.ToString()
                LoadedTime = Get-Date
                ConfigurationValid = $script:PoplarConfiguration -ne $null
            }
            RuntimeInfo = @{
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                DotNetVersion = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
                Is64Bit = [System.Environment]::Is64BitProcess
                ProcessorCount = [System.Environment]::ProcessorCount
            }
        }
        
        # Try to get device information
        try {
            $deviceCount = Get-PoplarDeviceCount
            $systemInfo.DeviceCount = $deviceCount
            
            for ($i = 0; $i -lt $deviceCount; $i++) {
                $deviceInfo = Get-PoplarDeviceInfo -DeviceId $i
                $systemInfo.Devices += $deviceInfo
            }
        }
        catch {
            Write-Warning "Could not retrieve device information: $($_.Exception.Message)"
        }
        
        # Try to get Poplar version information
        try {
            $systemInfo.PoplarVersion = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetPoplarVersion()
            $systemInfo.PopARTVersion = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::GetPopARTVersion()
            Write-Verbose "Retrieved version information - Poplar: $($systemInfo.PoplarVersion), PopART: $($systemInfo.PopARTVersion)"
        }
        catch {
            $versionError = $_.Exception.Message
            Write-Warning "Could not retrieve version information: $versionError"
            
            # Provide more detailed diagnostics
            if ($versionError -match "Method not found|MissingMethodException") {
                Write-Warning "Version retrieval methods not available - check PoplarBindings assembly version"
                $systemInfo.PoplarVersion = "Unknown (Method not available)"
                $systemInfo.PopARTVersion = "Unknown (Method not available)"
            }
            elseif ($versionError -match "FileNotFoundException|DllNotFoundException") {
                Write-Warning "PopART/Poplar runtime libraries not found - verify SDK installation"
                Write-Warning "Check that Poplar SDK is properly installed and environment variables are set"
                $systemInfo.PoplarVersion = "Unknown (SDK not found)"
                $systemInfo.PopARTVersion = "Unknown (SDK not found)"
            }
            elseif ($versionError -match "AccessViolationException|SEHException") {
                Write-Warning "Native library access error - possible version incompatibility"
                Write-Warning "Try restarting PowerShell session or checking SDK compatibility"
                $systemInfo.PoplarVersion = "Unknown (Access error)"
                $systemInfo.PopARTVersion = "Unknown (Access error)"
            }
            else {
                Write-Warning "Unexpected version retrieval error - using fallback detection"
                
                # Try alternative version detection methods
                try {
                    $poplarPath = $env:POPLAR_SDK_PATH
                    if ($poplarPath -and (Test-Path $poplarPath)) {
                        $versionFile = Join-Path $poplarPath "VERSION"
                        if (Test-Path $versionFile) {
                            $fallbackVersion = Get-Content $versionFile -ErrorAction SilentlyContinue | Select-Object -First 1
                            $systemInfo.PoplarVersion = "Fallback: $fallbackVersion"
                            Write-Verbose "Using fallback version detection: $fallbackVersion"
                        }
                    }
                }
                catch {
                    Write-Verbose "Fallback version detection failed: $($_.Exception.Message)"
                }
                
                if (-not $systemInfo.PoplarVersion) {
                    $systemInfo.PoplarVersion = "Unknown (Error: $versionError)"
                }
                if (-not $systemInfo.PopARTVersion) {
                    $systemInfo.PopARTVersion = "Unknown (Error: $versionError)"
                }
            }
            
            # Log detailed error information for debugging
            Write-Verbose "Version retrieval error details:"
            Write-Verbose "  Exception Type: $($_.Exception.GetType().FullName)"
            Write-Verbose "  Inner Exception: $($_.Exception.InnerException?.Message)"
            Write-Verbose "  Stack Trace: $($_.Exception.StackTrace)"
        }
        
        Write-Verbose "System information gathered successfully"
        return $systemInfo
    }
    catch {
        Write-Error "Failed to get system information: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Tests the Poplar installation.

.DESCRIPTION
Performs a comprehensive test of the Poplar installation and PSPoplar module.

.PARAMETER Quick
Perform only basic tests.

.PARAMETER IncludeHardware
Include hardware-specific tests.

.EXAMPLE
Test-PoplarInstallation
Performs a full installation test.

.EXAMPLE
Test-PoplarInstallation -Quick
Performs only basic tests.
#>
function Test-PoplarInstallation {
    [CmdletBinding()]
    param(
        [switch]$Quick,
        
        [switch]$IncludeHardware
    )
    
    $testResults = [PSCustomObject]@{
        OverallStatus = "Unknown"
        TestResults = @()
        StartTime = Get-Date
        EndTime = $null
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
        SkippedTests = 0
    }
    
    Write-Host "Testing Poplar installation..." -ForegroundColor Yellow
    
    # Test 1: Module loading
    $testResults.TestResults += Test-PoplarComponent -Name "PSPoplar Module Loading" -TestScript {
        return (Get-Module PSPoplar) -ne $null
    }
    
    # Test 2: C# bindings
    $testResults.TestResults += Test-PoplarComponent -Name "C# Bindings" -TestScript {
        return [HFLabs.IPUServices.PoplarBindings.PoplarUtilities] -ne $null
    }
    
    # Test 3: Configuration
    $testResults.TestResults += Test-PoplarComponent -Name "Configuration" -TestScript {
        $config = Get-PoplarConfiguration
        return $config -ne $null -and $config.DefaultDevice -ge 0
    }
    
    if (-not $Quick) {
        # Test 4: Device enumeration
        $testResults.TestResults += Test-PoplarComponent -Name "Device Enumeration" -TestScript {
            $deviceCount = Get-PoplarDeviceCount
            return $deviceCount -ge 0
        }
        
        # Test 5: Graph creation
        $testResults.TestResults += Test-PoplarComponent -Name "Graph Creation" -TestScript {
            $graph = New-PoplarGraph -DeviceId 0 -Name "TestGraph"
            $result = $graph -ne $null
            if ($graph) {
                Remove-PoplarGraph -Graph $graph
            }
            return $result
        }
        
        # Test 6: Tensor operations
        $testResults.TestResults += Test-PoplarComponent -Name "Tensor Operations" -TestScript {
            $spec = New-PoplarTensorSpec -Shape @(2, 2) -DataType "Float" -Name "TestTensor"
            return $spec -ne $null -and $spec.IsValid
        }
        
        if ($IncludeHardware) {
            # Test 7: Engine creation
            $testResults.TestResults += Test-PoplarComponent -Name "Engine Creation" -TestScript {
                $graph = New-PoplarGraph -DeviceId 0 -Name "TestEngineGraph"
                if ($graph) {
                    $engine = New-PoplarEngine -Graph $graph -ProgramName "TestEngine"
                    $result = $engine -ne $null
                    Remove-PoplarEngine -Engine $engine -ErrorAction SilentlyContinue
                    Remove-PoplarGraph -Graph $graph -ErrorAction SilentlyContinue
                    return $result
                }
                return $false
            }
        }
    }
    
    # Calculate results
    $testResults.EndTime = Get-Date
    $testResults.TotalTests = $testResults.TestResults.Count
    $testResults.PassedTests = ($testResults.TestResults | Where-Object { $_.Status -eq "Passed" }).Count
    $testResults.FailedTests = ($testResults.TestResults | Where-Object { $_.Status -eq "Failed" }).Count
    $testResults.SkippedTests = ($testResults.TestResults | Where-Object { $_.Status -eq "Skipped" }).Count
    
    $testResults.OverallStatus = if ($testResults.FailedTests -eq 0) { "Passed" } else { "Failed" }
    
    # Display results
    Write-Host "`nTest Results:" -ForegroundColor Cyan
    foreach ($test in $testResults.TestResults) {
        $color = switch ($test.Status) {
            "Passed" { "Green" }
            "Failed" { "Red" }
            "Skipped" { "Yellow" }
        }
        Write-Host "  $($test.Name): $($test.Status)" -ForegroundColor $color
        if ($test.Error -and $test.Status -eq "Failed") {
            Write-Host "    Error: $($test.Error)" -ForegroundColor DarkRed
        }
    }
    
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "  Total Tests: $($testResults.TotalTests)" -ForegroundColor White
    Write-Host "  Passed: $($testResults.PassedTests)" -ForegroundColor Green
    Write-Host "  Failed: $($testResults.FailedTests)" -ForegroundColor Red
    Write-Host "  Skipped: $($testResults.SkippedTests)" -ForegroundColor Yellow
    Write-Host "  Overall Status: $($testResults.OverallStatus)" -ForegroundColor $(if ($testResults.OverallStatus -eq "Passed") { "Green" } else { "Red" })
    
    return $testResults
}

function Test-PoplarComponent {
    param(
        [string]$Name,
        [scriptblock]$TestScript
    )
    
    $result = [PSCustomObject]@{
        Name = $Name
        Status = "Unknown"
        Error = $null
        Duration = $null
        StartTime = Get-Date
    }
    
    try {
        Write-Host "  Testing $Name..." -NoNewline
        
        $testResult = & $TestScript
        
        if ($testResult) {
            $result.Status = "Passed"
            Write-Host " PASSED" -ForegroundColor Green
        }
        else {
            $result.Status = "Failed"
            $result.Error = "Test returned false"
            Write-Host " FAILED" -ForegroundColor Red
        }
    }
    catch {
        $result.Status = "Failed"
        $result.Error = $_.Exception.Message
        Write-Host " FAILED" -ForegroundColor Red
        Write-Verbose "Test error: $($_.Exception.Message)"
    }
    finally {
        $result.Duration = (Get-Date) - $result.StartTime
    }
    
    return $result
}

#endregion

#region Performance and Profiling

<#
.SYNOPSIS
Measures the performance of a Poplar operation.

.DESCRIPTION
Times and profiles the execution of Poplar operations.

.PARAMETER ScriptBlock
Script block containing the operation(s) to measure.

.PARAMETER Iterations
Number of iterations to run for averaging.

.PARAMETER WarmupIterations
Number of warmup iterations before measurement.

.EXAMPLE
$perf = Measure-PoplarPerformance -ScriptBlock { 
    $graph = New-PoplarGraph -DeviceId 0
    Remove-PoplarGraph -Graph $graph
} -Iterations 10
Measures graph creation/deletion performance.
#>
function Measure-PoplarPerformance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [int]$Iterations = 1,
        
        [int]$WarmupIterations = 0
    )
    
    try {
        Write-Verbose "Starting performance measurement with $Iterations iterations..."
        
        $results = [PSCustomObject]@{
            TotalIterations = $Iterations
            WarmupIterations = $WarmupIterations
            Times = @()
            AverageTime = $null
            MinTime = $null
            MaxTime = $null
            StandardDeviation = $null
            StartTime = Get-Date
            EndTime = $null
            Success = $true
            Errors = @()
        }
        
        # Warmup iterations
        if ($WarmupIterations -gt 0) {
            Write-Verbose "Running $WarmupIterations warmup iterations..."
            for ($i = 0; $i -lt $WarmupIterations; $i++) {
                try {
                    & $ScriptBlock | Out-Null
                }
                catch {
                    Write-Warning "Warmup iteration $($i + 1) failed: $($_.Exception.Message)"
                }
            }
        }
        
        # Measurement iterations
        Write-Verbose "Running $Iterations measurement iterations..."
        for ($i = 0; $i -lt $Iterations; $i++) {
            $iterationStart = Get-Date
            
            try {
                & $ScriptBlock | Out-Null
                $iterationEnd = Get-Date
                $iterationTime = ($iterationEnd - $iterationStart).TotalMilliseconds
                $results.Times += $iterationTime
                
                Write-Verbose "Iteration $($i + 1): $([math]::Round($iterationTime, 2))ms"
            }
            catch {
                $results.Success = $false
                $results.Errors += "Iteration $($i + 1): $($_.Exception.Message)"
                Write-Warning "Iteration $($i + 1) failed: $($_.Exception.Message)"
            }
        }
        
        # Calculate statistics
        if ($results.Times.Count -gt 0) {
            $results.AverageTime = [math]::Round(($results.Times | Measure-Object -Average).Average, 2)
            $results.MinTime = [math]::Round(($results.Times | Measure-Object -Minimum).Minimum, 2)
            $results.MaxTime = [math]::Round(($results.Times | Measure-Object -Maximum).Maximum, 2)
            
            if ($results.Times.Count -gt 1) {
                $variance = ($results.Times | ForEach-Object { [math]::Pow($_ - $results.AverageTime, 2) } | Measure-Object -Sum).Sum / ($results.Times.Count - 1)
                $results.StandardDeviation = [math]::Round([math]::Sqrt($variance), 2)
            }
        }
        
        $results.EndTime = Get-Date
        
        Write-Verbose "Performance measurement completed"
        Write-Verbose "Average: $($results.AverageTime)ms, Min: $($results.MinTime)ms, Max: $($results.MaxTime)ms"
        
        return $results
    }
    catch {
        Write-Error "Failed to measure performance: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Profiles memory usage during Poplar operations.

.DESCRIPTION
Monitors memory usage while executing Poplar operations.

.PARAMETER ScriptBlock
Script block containing the operation(s) to profile.

.PARAMETER SampleInterval
Memory sampling interval in milliseconds.

.EXAMPLE
$profile = Measure-PoplarMemoryUsage -ScriptBlock { 
    $engine = New-PoplarEngine -Graph $graph 
}
Profiles memory usage during engine creation.
#>
function Measure-PoplarMemoryUsage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [int]$SampleInterval = 100
    )
    
    try {
        Write-Verbose "Starting memory usage profiling..."
        
        $results = [PSCustomObject]@{
            StartMemory = [GC]::GetTotalMemory($false)
            EndMemory = 0
            PeakMemory = 0
            MemorySamples = @()
            SampleInterval = $SampleInterval
            StartTime = Get-Date
            EndTime = $null
            Success = $true
            Error = $null
        }
        
        $job = Start-Job -ScriptBlock {
            param($Interval, $StartTime)
            
            $samples = @()
            $startTicks = $StartTime.Ticks
            
            while ((Get-Date).Ticks - $startTicks -lt 600000000) { # 60 seconds max
                $memory = [GC]::GetTotalMemory($false)
                $samples += [PSCustomObject]@{
                    Time = Get-Date
                    Memory = $memory
                }
                Start-Sleep -Milliseconds $Interval
            }
            
            return $samples
        } -ArgumentList $SampleInterval, $results.StartTime
        
        try {
            # Execute the script block
            & $ScriptBlock
            $results.Success = $true
        }
        catch {
            $results.Success = $false
            $results.Error = $_.Exception.Message
            Write-Error "Script block execution failed: $($_.Exception.Message)"
        }
        finally {
            $results.EndTime = Get-Date
            $results.EndMemory = [GC]::GetTotalMemory($false)
            
            # Stop and get memory samples
            Stop-Job -Job $job
            $samples = Receive-Job -Job $job
            Remove-Job -Job $job
            
            if ($samples) {
                $results.MemorySamples = $samples | Where-Object { $_.Time -ge $results.StartTime -and $_.Time -le $results.EndTime }
                if ($results.MemorySamples.Count -gt 0) {
                    $results.PeakMemory = ($results.MemorySamples | Measure-Object -Property Memory -Maximum).Maximum
                }
            }
        }
        
        Write-Verbose "Memory profiling completed"
        Write-Verbose "Start: $([math]::Round($results.StartMemory / 1MB, 2))MB, End: $([math]::Round($results.EndMemory / 1MB, 2))MB, Peak: $([math]::Round($results.PeakMemory / 1MB, 2))MB"
        
        return $results
    }
    catch {
        Write-Error "Failed to profile memory usage: $($_.Exception.Message)"
        return $null
    }
}

#endregion

#region Data Conversion and Validation

<#
.SYNOPSIS
Converts various data formats to Poplar-compatible arrays.

.DESCRIPTION
Converts CSV files, JSON arrays, binary data, and other formats to Poplar tensor data.

.PARAMETER Path
Path to the data file.

.PARAMETER Format
Format of the input data (CSV, JSON, Binary, Text).

.PARAMETER Shape
Target tensor shape.

.PARAMETER DataType
Target data type.

.EXAMPLE
$data = Import-PoplarData -Path "data.csv" -Format CSV -Shape @(100, 10) -DataType Float
Imports CSV data as tensor data.
#>
function Import-PoplarData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("CSV", "JSON", "Binary", "Text")]
        [string]$Format,
        
        [int[]]$Shape,
        
        [ValidateSet("Float", "Half", "Int", "UnsignedInt")]
        [string]$DataType = $script:PoplarConfiguration.TensorDataType
    )
    
    try {
        if (-not (Test-Path $Path)) {
            throw "File not found: $Path"
        }
        
        Write-Verbose "Importing data from $Path (format: $Format)..."
        
        $rawData = switch ($Format) {
            "CSV" {
                $csv = Import-Csv -Path $Path
                $values = @()
                foreach ($row in $csv) {
                    foreach ($prop in $row.PSObject.Properties) {
                        if ($prop.Value -match '^-?\d*\.?\d+$') {
                            $values += [double]$prop.Value
                        }
                    }
                }
                $values
            }
            
            "JSON" {
                $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
                if ($json -is [Array]) {
                    $json | ForEach-Object { [double]$_ }
                }
                else {
                    # Assume it's an object with numeric properties
                    $values = @()
                    foreach ($prop in $json.PSObject.Properties) {
                        if ($prop.Value -is [Array]) {
                            $values += $prop.Value | ForEach-Object { [double]$_ }
                        }
                        elseif ($prop.Value -match '^-?\d*\.?\d+$') {
                            $values += [double]$prop.Value
                        }
                    }
                    $values
                }
            }
            
            "Binary" {
                $bytes = [System.IO.File]::ReadAllBytes($Path)
                switch ($DataType) {
                    "Float" {
                        for ($i = 0; $i -lt $bytes.Length; $i += 4) {
                            if ($i + 3 -lt $bytes.Length) {
                                [BitConverter]::ToSingle($bytes, $i)
                            }
                        }
                    }
                    "Int" {
                        for ($i = 0; $i -lt $bytes.Length; $i += 4) {
                            if ($i + 3 -lt $bytes.Length) {
                                [BitConverter]::ToInt32($bytes, $i)
                            }
                        }
                    }
                    default {
                        # Convert bytes to numeric values
                        $bytes | ForEach-Object { [double]$_ }
                    }
                }
            }
            
            "Text" {
                $content = Get-Content -Path $Path -Raw
                # Extract numeric values from text
                [regex]::Matches($content, '-?\d*\.?\d+') | ForEach-Object { [double]$_.Value }
            }
        }
        
        if (-not $rawData -or $rawData.Count -eq 0) {
            throw "No numeric data found in file"
        }
        
        # Apply shape if specified
        if ($Shape) {
            $expectedElements = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::CalculateElementCount($Shape)
            
            if ($rawData.Count -lt $expectedElements) {
                # Pad with zeros
                $padded = @($rawData)
                while ($padded.Count -lt $expectedElements) {
                    $padded += 0
                }
                $rawData = $padded
            }
            elseif ($rawData.Count -gt $expectedElements) {
                # Truncate
                $rawData = $rawData[0..($expectedElements - 1)]
            }
        }
        
        # Convert to tensor data
        $tensorData = ConvertTo-PoplarTensor -Data $rawData -Shape $Shape -DataType $DataType
        
        Write-Verbose "Successfully imported $($rawData.Count) data elements"
        return $tensorData
    }
    catch {
        Write-Error "Failed to import data: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
Exports Poplar tensor data to various formats.

.DESCRIPTION
Exports tensor data to CSV, JSON, binary, or text formats.

.PARAMETER TensorData
Tensor data to export.

.PARAMETER Path
Output file path.

.PARAMETER Format
Output format (CSV, JSON, Binary, Text).

.EXAMPLE
Export-PoplarData -TensorData $results -Path "output.csv" -Format CSV
Exports tensor data to CSV file.
#>
function Export-PoplarData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $TensorData,
        
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("CSV", "JSON", "Binary", "Text")]
        [string]$Format
    )
    
    try {
        Write-Verbose "Exporting tensor data to $Path (format: $Format)..."
        
        $data = ConvertFrom-PoplarTensor -TensorData $TensorData
        
        switch ($Format) {
            "CSV" {
                # Convert to CSV format
                $csvData = @()
                for ($i = 0; $i -lt $data.Count; $i++) {
                    $csvData += [PSCustomObject]@{
                        Index = $i
                        Value = $data[$i]
                    }
                }
                $csvData | Export-Csv -Path $Path -NoTypeInformation
            }
            
            "JSON" {
                $jsonData = @{
                    Data = $data
                    Shape = $TensorData.Shape
                    DataType = $TensorData.DataType
                    ElementCount = $data.Count
                    ExportTime = Get-Date
                }
                $jsonData | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
            }
            
            "Binary" {
                $bytes = @()
                foreach ($value in $data) {
                    switch ($TensorData.DataType) {
                        "Float" { $bytes += [BitConverter]::GetBytes([float]$value) }
                        "Int" { $bytes += [BitConverter]::GetBytes([int]$value) }
                        default { $bytes += [BitConverter]::GetBytes([float]$value) }
                    }
                }
                [System.IO.File]::WriteAllBytes($Path, $bytes)
            }
            
            "Text" {
                $textContent = $data -join "`n"
                $textContent | Set-Content -Path $Path
            }
        }
        
        Write-Verbose "Successfully exported $($data.Count) data elements to $Path"
    }
    catch {
        Write-Error "Failed to export data: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
Validates tensor data consistency.

.DESCRIPTION
Performs comprehensive validation of tensor data for consistency and correctness.

.PARAMETER TensorData
Tensor data to validate.

.PARAMETER ExpectedShape
Expected tensor shape.

.PARAMETER ExpectedDataType
Expected data type.

.PARAMETER CheckNaN
Check for NaN values.

.PARAMETER CheckInfinite
Check for infinite values.

.EXAMPLE
$validation = Test-PoplarTensorData -TensorData $tensor -ExpectedShape @(10, 10) -CheckNaN
Validates tensor data and checks for NaN values.
#>
function Test-PoplarTensorData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $TensorData,
        
        [int[]]$ExpectedShape,
        
        [ValidateSet("Float", "Half", "Int", "UnsignedInt")]
        [string]$ExpectedDataType,
        
        [switch]$CheckNaN,
        
        [switch]$CheckInfinite
    )
    
    try {
        Write-Verbose "Validating tensor data..."
        
        $validation = [PSCustomObject]@{
            IsValid = $true
            Errors = @()
            Warnings = @()
            DataInfo = @{
                ElementCount = 0
                Shape = $null
                DataType = $null
                MinValue = $null
                MaxValue = $null
                MeanValue = $null
                HasNaN = $false
                HasInfinite = $false
            }
            ValidationTime = Get-Date
        }
        
        # Extract data array
        if ($TensorData.Data) {
            $data = $TensorData.Data
            $validation.DataInfo.Shape = $TensorData.Shape
            $validation.DataInfo.DataType = $TensorData.DataType
        }
        else {
            $data = $TensorData
        }
        
        if (-not $data -or $data.Count -eq 0) {
            $validation.IsValid = $false
            $validation.Errors += "Tensor data is null or empty"
            return $validation
        }
        
        $validation.DataInfo.ElementCount = $data.Count
        
        # Shape validation
        if ($ExpectedShape) {
            $expectedElements = [HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::CalculateElementCount($ExpectedShape)
            if ($data.Count -ne $expectedElements) {
                $validation.IsValid = $false
                $validation.Errors += "Element count ($($data.Count)) does not match expected shape ($([HFLabs.IPUServices.PoplarBindings.PoplarUtilities]::FormatShape($ExpectedShape)), $expectedElements elements)"
            }
        }
        
        # Data type validation
        if ($ExpectedDataType -and $validation.DataInfo.DataType -ne $ExpectedDataType) {
            $validation.Warnings += "Data type ($($validation.DataInfo.DataType)) does not match expected type ($ExpectedDataType)"
        }
        
        # Statistical analysis
        $numericData = $data | Where-Object { $_ -is [ValueType] -and -not [double]::IsNaN($_) -and -not [double]::IsInfinity($_) }
        
        if ($numericData.Count -gt 0) {
            $validation.DataInfo.MinValue = ($numericData | Measure-Object -Minimum).Minimum
            $validation.DataInfo.MaxValue = ($numericData | Measure-Object -Maximum).Maximum
            $validation.DataInfo.MeanValue = [math]::Round(($numericData | Measure-Object -Average).Average, 6)
        }
        
        # Check for problematic values
        if ($CheckNaN) {
            $nanCount = ($data | Where-Object { [double]::IsNaN($_) }).Count
            if ($nanCount -gt 0) {
                $validation.DataInfo.HasNaN = $true
                $validation.Warnings += "Found $nanCount NaN values"
            }
        }
        
        if ($CheckInfinite) {
            $infCount = ($data | Where-Object { [double]::IsInfinity($_) }).Count
            if ($infCount -gt 0) {
                $validation.DataInfo.HasInfinite = $true
                $validation.Warnings += "Found $infCount infinite values"
            }
        }
        
        Write-Verbose "Tensor validation completed: $($validation.IsValid)"
        return $validation
    }
    catch {
        Write-Error "Failed to validate tensor data: $($_.Exception.Message)"
        return $null
    }
}

#endregion

# Export utility functions
Export-ModuleMember -Function Get-PoplarSystemInfo, Test-PoplarInstallation
Export-ModuleMember -Function Measure-PoplarPerformance, Measure-PoplarMemoryUsage
Export-ModuleMember -Function Import-PoplarData, Export-PoplarData, Test-PoplarTensorData
