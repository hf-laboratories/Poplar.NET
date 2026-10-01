# PerformanceProfilingExample.ps1
# Demonstrates performance profiling and system diagnostics using PSPoplar

param(
    [int]$DeviceId = 0,
    [int]$Iterations = 10,
    [switch]$DetailedProfiling
)

Write-Host "=== PSPoplar Performance Profiling Example ===" -ForegroundColor Cyan

try {
    # Import the module
    Write-Host "Loading PSPoplar module..." -ForegroundColor Yellow
    Import-Module (Join-Path $PSScriptRoot "..\PSPoplar.psd1") -Force -Verbose:$false
    
    # Get comprehensive system information
    Write-Host "Gathering system information..." -ForegroundColor Yellow
    $systemInfo = Get-PoplarSystemInfo
    
    Write-Host "System Information:" -ForegroundColor Green
    Write-Host "  Poplar Version: $($systemInfo.PoplarVersion)" -ForegroundColor White
    Write-Host "  PopART Version: $($systemInfo.PopARTVersion)" -ForegroundColor White
    Write-Host "  Device Count: $($systemInfo.DeviceCount)" -ForegroundColor White
    Write-Host "  System Memory: $($systemInfo.SystemMemory) GB" -ForegroundColor White
    Write-Host "  OS: $($systemInfo.OSInfo)" -ForegroundColor White
    Write-Host "  Processor: $($systemInfo.ProcessorInfo)" -ForegroundColor White
    Write-Host "  PowerShell: $($systemInfo.RuntimeInfo.PowerShellVersion)" -ForegroundColor White
    Write-Host "  .NET: $($systemInfo.RuntimeInfo.DotNetVersion)" -ForegroundColor White
    Write-Host "  64-bit: $($systemInfo.RuntimeInfo.Is64Bit)" -ForegroundColor White
    Write-Host "  CPU Cores: $($systemInfo.RuntimeInfo.ProcessorCount)" -ForegroundColor White
    
    if ($systemInfo.Devices.Count -gt 0) {
        Write-Host "  Available Devices:" -ForegroundColor White
        foreach ($device in $systemInfo.Devices) {
            Write-Host "    Device $($device.DeviceId): $($device.Status)" -ForegroundColor Cyan
        }
    }
    
    # Performance Test 1: Device Connection
    Write-Host "`nProfiling device connection performance..." -ForegroundColor Yellow
    $deviceConnectionPerf = Measure-PoplarPerformance -ScriptBlock {
        $device = Connect-PoplarDevice -DeviceId $DeviceId
        Disconnect-PoplarDevice -DeviceId $DeviceId
    } -Iterations $Iterations -WarmupIterations 2
    
    Write-Host "Device Connection Performance:" -ForegroundColor Green
    Write-Host "  Average: $($deviceConnectionPerf.AverageTime) ms" -ForegroundColor White
    Write-Host "  Min: $($deviceConnectionPerf.MinTime) ms" -ForegroundColor White
    Write-Host "  Max: $($deviceConnectionPerf.MaxTime) ms" -ForegroundColor White
    if ($deviceConnectionPerf.StandardDeviation) {
        Write-Host "  Std Dev: $($deviceConnectionPerf.StandardDeviation) ms" -ForegroundColor White
    }
    Write-Host "  Success Rate: $(if ($deviceConnectionPerf.Success) { '100%' } else { 'Failed' })" -ForegroundColor $(if ($deviceConnectionPerf.Success) { "Green" } else { "Red" })
    
    # Performance Test 2: Graph Creation
    Write-Host "`nProfiling graph creation performance..." -ForegroundColor Yellow
    $graphCreationPerf = Measure-PoplarPerformance -ScriptBlock {
        $device = Connect-PoplarDevice -DeviceId $DeviceId
        $graph = New-PoplarGraph -DeviceId $DeviceId -Name "PerfTestGraph"
        Remove-PoplarGraph -Graph $graph
        Disconnect-PoplarDevice -DeviceId $DeviceId
    } -Iterations $Iterations -WarmupIterations 2
    
    Write-Host "Graph Creation Performance:" -ForegroundColor Green
    Write-Host "  Average: $($graphCreationPerf.AverageTime) ms" -ForegroundColor White
    Write-Host "  Min: $($graphCreationPerf.MinTime) ms" -ForegroundColor White
    Write-Host "  Max: $($graphCreationPerf.MaxTime) ms" -ForegroundColor White
    if ($graphCreationPerf.StandardDeviation) {
        Write-Host "  Std Dev: $($graphCreationPerf.StandardDeviation) ms" -ForegroundColor White
    }
    
    # Performance Test 3: Tensor Operations
    Write-Host "`nProfiling tensor operations performance..." -ForegroundColor Yellow
    $tensorOpsPerf = Measure-PoplarPerformance -ScriptBlock {
        $device = Connect-PoplarDevice -DeviceId $DeviceId
        $graph = New-PoplarGraph -DeviceId $DeviceId -Name "TensorPerfGraph"
        
        # Add multiple tensors of different sizes
        $tensor1 = Add-PoplarTensor -Graph $graph -Shape @(10, 10) -DataType "Float" -Name "small_tensor"
        $tensor2 = Add-PoplarTensor -Graph $graph -Shape @(100, 100) -DataType "Float" -Name "medium_tensor"
        $tensor3 = Add-PoplarTensor -Graph $graph -Shape @(1000, 10) -DataType "Float" -Name "large_tensor"
        
        Remove-PoplarGraph -Graph $graph
        Disconnect-PoplarDevice -DeviceId $DeviceId
    } -Iterations ($Iterations / 2) -WarmupIterations 1  # Fewer iterations for more complex operations
    
    Write-Host "Tensor Operations Performance:" -ForegroundColor Green
    Write-Host "  Average: $($tensorOpsPerf.AverageTime) ms" -ForegroundColor White
    Write-Host "  Min: $($tensorOpsPerf.MinTime) ms" -ForegroundColor White
    Write-Host "  Max: $($tensorOpsPerf.MaxTime) ms" -ForegroundColor White
    if ($tensorOpsPerf.StandardDeviation) {
        Write-Host "  Std Dev: $($tensorOpsPerf.StandardDeviation) ms" -ForegroundColor White
    }
    
    # Memory Usage Test
    Write-Host "`nProfiling memory usage..." -ForegroundColor Yellow
    $memoryProfile = Measure-PoplarMemoryUsage -ScriptBlock {
        $device = Connect-PoplarDevice -DeviceId $DeviceId
        $graphs = @()
        
        # Create multiple graphs to observe memory usage
        for ($i = 0; $i -lt 5; $i++) {
            $graph = New-PoplarGraph -DeviceId $DeviceId -Name "MemoryTestGraph_$i"
            
            # Add various tensors
            Add-PoplarTensor -Graph $graph -Shape @(100, 100) -DataType "Float" -Name "tensor_$i_1" | Out-Null
            Add-PoplarTensor -Graph $graph -Shape @(50, 200) -DataType "Float" -Name "tensor_$i_2" | Out-Null
            
            $graphs += $graph
            
            # Force garbage collection occasionally
            if ($i % 2 -eq 0) {
                [GC]::Collect()
                Start-Sleep -Milliseconds 10
            }
        }
        
        # Clean up
        foreach ($graph in $graphs) {
            Remove-PoplarGraph -Graph $graph
        }
        
        Disconnect-PoplarDevice -DeviceId $DeviceId
    } -SampleInterval 50
    
    Write-Host "Memory Usage Profile:" -ForegroundColor Green
    Write-Host "  Start Memory: $([math]::Round($memoryProfile.StartMemory / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "  End Memory: $([math]::Round($memoryProfile.EndMemory / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "  Peak Memory: $([math]::Round($memoryProfile.PeakMemory / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "  Memory Delta: $([math]::Round(($memoryProfile.EndMemory - $memoryProfile.StartMemory) / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "  Peak Delta: $([math]::Round(($memoryProfile.PeakMemory - $memoryProfile.StartMemory) / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "  Samples Collected: $($memoryProfile.MemorySamples.Count)" -ForegroundColor White
    
    if ($DetailedProfiling) {
        # Detailed tensor data operations profiling
        Write-Host "`nDetailed tensor data operations profiling..." -ForegroundColor Yellow
        
        # Test different tensor sizes
        $tensorSizes = @(
            @(10, 10),      # Small: 100 elements
            @(100, 100),    # Medium: 10,000 elements
            @(1000, 100),   # Large: 100,000 elements
            @(100, 100, 10) # 3D: 100,000 elements
        )
        
        foreach ($shape in $tensorSizes) {
            $elementCount = 1
            foreach ($dim in $shape) { $elementCount *= $dim }
            
            Write-Host "  Testing tensor shape [$($shape -join 'x')] ($elementCount elements)..." -ForegroundColor Cyan
            
            # Test tensor spec creation
            $specPerf = Measure-PoplarPerformance -ScriptBlock {
                $spec = New-PoplarTensorSpec -Shape $shape -DataType "Float" -Name "perf_tensor"
                $validation = Test-PoplarTensorShape -Shape $shape
            } -Iterations 100
            
            # Test data conversion
            $sampleData = 1..$elementCount | ForEach-Object { [float](Get-Random -Minimum 0.0 -Maximum 1.0) }
            $conversionPerf = Measure-PoplarPerformance -ScriptBlock {
                $tensorData = ConvertTo-PoplarTensor -Data $sampleData -Shape $shape -DataType "Float"
                $backData = ConvertFrom-PoplarTensor -TensorData $tensorData
            } -Iterations 10
            
            # Test data validation
            $tensorData = ConvertTo-PoplarTensor -Data $sampleData -Shape $shape -DataType "Float"
            $validationPerf = Measure-PoplarPerformance -ScriptBlock {
                $validation = Test-PoplarTensorData -TensorData $tensorData -ExpectedShape $shape -CheckNaN
            } -Iterations 50
            
            Write-Host "    Spec Creation: $($specPerf.AverageTime) ms avg" -ForegroundColor White
            Write-Host "    Data Conversion: $($conversionPerf.AverageTime) ms avg" -ForegroundColor White
            Write-Host "    Data Validation: $($validationPerf.AverageTime) ms avg" -ForegroundColor White
        }
        
        # Test different data types
        Write-Host "`nTesting different data types..." -ForegroundColor Yellow
        $dataTypes = @("Float", "Int")
        $testShape = @(100, 100)
        
        foreach ($dataType in $dataTypes) {
            Write-Host "  Testing $dataType data type..." -ForegroundColor Cyan
            
            $sampleData = switch ($dataType) {
                "Float" { 1..10000 | ForEach-Object { [float](Get-Random -Minimum 0.0 -Maximum 1.0) } }
                "Int" { 1..10000 | ForEach-Object { Get-Random -Minimum 0 -Maximum 1000 } }
            }
            
            $dataTypePerf = Measure-PoplarPerformance -ScriptBlock {
                $tensorData = ConvertTo-PoplarTensor -Data $sampleData -Shape $testShape -DataType $dataType
                $validation = Test-PoplarTensorData -TensorData $tensorData -ExpectedShape $testShape
            } -Iterations 20
            
            Write-Host "    $dataType Performance: $($dataTypePerf.AverageTime) ms avg" -ForegroundColor White
        }
    }
    
    # Configuration performance test
    Write-Host "`nTesting configuration operations..." -ForegroundColor Yellow
    $configPerf = Measure-PoplarPerformance -ScriptBlock {
        $originalConfig = Get-PoplarConfiguration
        Set-PoplarConfiguration -DefaultDevice 1
        Set-PoplarConfiguration -EnableLogging $false
        Set-PoplarConfiguration -DefaultDevice $originalConfig.DefaultDevice -EnableLogging $originalConfig.EnableLogging
    } -Iterations 100
    
    Write-Host "Configuration Operations:" -ForegroundColor Green
    Write-Host "  Average: $($configPerf.AverageTime) ms" -ForegroundColor White
    
    # Summary report
    Write-Host "`n=== Performance Summary ===" -ForegroundColor Cyan
    Write-Host "Test Environment:" -ForegroundColor Yellow
    Write-Host "  Device: IPU $DeviceId" -ForegroundColor White
    Write-Host "  Iterations: $Iterations" -ForegroundColor White
    Write-Host "  Detailed Profiling: $($DetailedProfiling.IsPresent)" -ForegroundColor White
    
    Write-Host "`nPerformance Metrics:" -ForegroundColor Yellow
    Write-Host "  Device Connection: $($deviceConnectionPerf.AverageTime) ms avg" -ForegroundColor White
    Write-Host "  Graph Creation: $($graphCreationPerf.AverageTime) ms avg" -ForegroundColor White
    Write-Host "  Tensor Operations: $($tensorOpsPerf.AverageTime) ms avg" -ForegroundColor White
    Write-Host "  Configuration: $($configPerf.AverageTime) ms avg" -ForegroundColor White
    
    Write-Host "`nMemory Metrics:" -ForegroundColor Yellow
    Write-Host "  Peak Memory Usage: $([math]::Round($memoryProfile.PeakMemory / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "  Memory Efficiency: $(if (($memoryProfile.EndMemory - $memoryProfile.StartMemory) -lt 5MB) { 'Good' } else { 'Review' })" -ForegroundColor $(if (($memoryProfile.EndMemory - $memoryProfile.StartMemory) -lt 5MB) { 'Green' } else { 'Yellow' })
    
    # Performance recommendations
    Write-Host "`nPerformance Recommendations:" -ForegroundColor Yellow
    if ($deviceConnectionPerf.AverageTime -gt 100) {
        Write-Host "  • Device connection is slow (>100ms). Check IPU driver status." -ForegroundColor Yellow
    }
    else {
        Write-Host "  • Device connection performance is good." -ForegroundColor Green
    }
    
    if ($graphCreationPerf.AverageTime -gt 500) {
        Write-Host "  • Graph creation is slow (>500ms). Consider graph reuse." -ForegroundColor Yellow
    }
    else {
        Write-Host "  • Graph creation performance is acceptable." -ForegroundColor Green
    }
    
    if (($memoryProfile.PeakMemory - $memoryProfile.StartMemory) -gt 100MB) {
        Write-Host "  • High memory usage detected (>100MB delta). Ensure proper resource cleanup." -ForegroundColor Yellow
    }
    else {
        Write-Host "  • Memory usage is within acceptable limits." -ForegroundColor Green
    }
    
    Write-Host "=== Performance profiling completed successfully! ===" -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}
finally {
    # Clean up any remaining resources
    Write-Host "Performing final cleanup..." -ForegroundColor Yellow
    Disconnect-PoplarDevice -ErrorAction SilentlyContinue
    [GC]::Collect()
    Write-Host "Cleanup completed." -ForegroundColor Yellow
}

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
