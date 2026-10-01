# BasicGraphExample.ps1
# Demonstrates basic Poplar graph operations using PSPoplar

param(
    [int]$DeviceId = 0
)

Write-Host "=== PSPoplar Basic Graph Example ===" -ForegroundColor Cyan

try {
    # Import the module
    Write-Host "Loading PSPoplar module..." -ForegroundColor Yellow
    Import-Module (Join-Path $PSScriptRoot "..\PSPoplar.psd1") -Force -Verbose:$false
    
    # Test installation
    Write-Host "Testing Poplar installation..." -ForegroundColor Yellow
    $testResults = Test-PoplarInstallation -Quick
    if ($testResults.OverallStatus -ne "Passed") {
        throw "Installation test failed"
    }
    
    # Get system information
    Write-Host "Getting system information..." -ForegroundColor Yellow
    $systemInfo = Get-PoplarSystemInfo
    Write-Host "  Poplar Version: $($systemInfo.PoplarVersion)" -ForegroundColor Green
    Write-Host "  Device Count: $($systemInfo.DeviceCount)" -ForegroundColor Green
    Write-Host "  System Memory: $($systemInfo.SystemMemory) GB" -ForegroundColor Green
    
    # Connect to device
    Write-Host "Connecting to device $DeviceId..." -ForegroundColor Yellow
    $deviceWrapper = Connect-PoplarDevice -DeviceId $DeviceId
    if (-not $deviceWrapper) {
        throw "Failed to connect to device $DeviceId"
    }
    Write-Host "  Successfully connected to device $DeviceId" -ForegroundColor Green
    
    # Create a computation graph
    Write-Host "Creating computation graph..." -ForegroundColor Yellow
    $graph = New-PoplarGraph -DeviceId $DeviceId -Name "BasicExampleGraph"
    if (-not $graph) {
        throw "Failed to create graph"
    }
    Write-Host "  Created graph: $($graph.Name)" -ForegroundColor Green
    
    # Add input tensor
    Write-Host "Adding input tensor..." -ForegroundColor Yellow
    $inputTensor = Add-PoplarTensor -Graph $graph -Shape @(2, 3) -DataType "Float" -Name "input_matrix"
    if (-not $inputTensor) {
        throw "Failed to add input tensor"
    }
    Write-Host "  Added tensor: $($inputTensor.Name) [shape: $($inputTensor.Shape -join 'x')] [$($inputTensor.ElementCount) elements, $($inputTensor.SizeBytes) bytes]" -ForegroundColor Green
    
    # Add output tensor
    Write-Host "Adding output tensor..." -ForegroundColor Yellow
    $outputTensor = Add-PoplarTensor -Graph $graph -Shape @(2, 3) -DataType "Float" -Name "output_matrix"
    if (-not $outputTensor) {
        throw "Failed to add output tensor"
    }
    Write-Host "  Added tensor: $($outputTensor.Name) [shape: $($outputTensor.Shape -join 'x')] [$($outputTensor.ElementCount) elements, $($outputTensor.SizeBytes) bytes]" -ForegroundColor Green
    
    # Get tensor information
    Write-Host "Getting tensor information..." -ForegroundColor Yellow
    $tensors = Get-PoplarTensorInfo -Graph $graph
    foreach ($tensor in $tensors) {
        Write-Host "  Tensor: $($tensor.Name)" -ForegroundColor Cyan
        Write-Host "    Shape: [$($tensor.Shape -join ', ')]" -ForegroundColor White
        Write-Host "    Type: $($tensor.DataType)" -ForegroundColor White
        Write-Host "    Elements: $($tensor.ElementCount)" -ForegroundColor White
        Write-Host "    Size: $($tensor.SizeBytes) bytes" -ForegroundColor White
        Write-Host "    Created: $($tensor.CreatedTime)" -ForegroundColor White
    }
    
    # Create an engine (this would typically involve adding operations to the graph)
    Write-Host "Creating engine..." -ForegroundColor Yellow
    $engine = New-PoplarEngine -Graph $graph -ProgramName "BasicExample"
    if (-not $engine) {
        throw "Failed to create engine"
    }
    Write-Host "  Created engine: $($engine.ProgramName)" -ForegroundColor Green
    
    # Prepare sample data
    Write-Host "Preparing sample data..." -ForegroundColor Yellow
    $sampleData = @(1.0, 2.0, 3.0, 4.0, 5.0, 6.0)  # 2x3 matrix
    $tensorData = ConvertTo-PoplarTensor -Data $sampleData -Shape @(2, 3) -DataType "Float"
    Write-Host "  Prepared tensor data: [$($tensorData.Data -join ', ')]" -ForegroundColor Green
    
    # Validate the tensor data
    Write-Host "Validating tensor data..." -ForegroundColor Yellow
    $validation = Test-PoplarTensorData -TensorData $tensorData -ExpectedShape @(2, 3) -CheckNaN
    if ($validation.IsValid) {
        Write-Host "  Tensor data is valid" -ForegroundColor Green
        Write-Host "    Min: $($validation.DataInfo.MinValue)" -ForegroundColor White
        Write-Host "    Max: $($validation.DataInfo.MaxValue)" -ForegroundColor White
        Write-Host "    Mean: $($validation.DataInfo.MeanValue)" -ForegroundColor White
    }
    else {
        Write-Host "  Tensor data validation failed: $($validation.Errors -join ', ')" -ForegroundColor Red
    }
    
    # Demonstrate performance measurement
    Write-Host "Measuring graph creation performance..." -ForegroundColor Yellow
    $perfResults = Measure-PoplarPerformance -ScriptBlock {
        $testGraph = New-PoplarGraph -DeviceId $DeviceId -Name "PerfTestGraph"
        Add-PoplarTensor -Graph $testGraph -Shape @(10, 10) -DataType "Float" -Name "perf_tensor" | Out-Null
        Remove-PoplarGraph -Graph $testGraph
    } -Iterations 5 -WarmupIterations 2
    
    Write-Host "  Performance Results:" -ForegroundColor Green
    Write-Host "    Average: $($perfResults.AverageTime) ms" -ForegroundColor White
    Write-Host "    Min: $($perfResults.MinTime) ms" -ForegroundColor White
    Write-Host "    Max: $($perfResults.MaxTime) ms" -ForegroundColor White
    if ($perfResults.StandardDeviation) {
        Write-Host "    Std Dev: $($perfResults.StandardDeviation) ms" -ForegroundColor White
    }
    
    Write-Host "=== Example completed successfully! ===" -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}
finally {
    # Clean up resources
    Write-Host "Cleaning up resources..." -ForegroundColor Yellow
    
    if ($engine) {
        Write-Host "  Removing engine..." -ForegroundColor Gray
        Remove-PoplarEngine -Engine $engine -ErrorAction SilentlyContinue
    }
    
    if ($graph) {
        Write-Host "  Removing graph..." -ForegroundColor Gray
        Remove-PoplarGraph -Graph $graph -ErrorAction SilentlyContinue
    }
    
    Write-Host "  Disconnecting devices..." -ForegroundColor Gray
    Disconnect-PoplarDevice -ErrorAction SilentlyContinue
    
    Write-Host "Cleanup completed." -ForegroundColor Yellow
}

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
