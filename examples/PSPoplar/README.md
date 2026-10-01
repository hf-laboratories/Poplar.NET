# PSPoplar PowerShell Module

The PSPoplar module provides an ergonomic PowerShell interface to the Graphcore Poplar SDK, enabling IPU programming and machine learning workflows through intuitive cmdlets.

## Overview

PSPoplar is built on top of the C# bindings layer (`PoplarCppAPIWrapper.csproj`, in the parent directory) and provides high-level PowerShell cmdlets for:

- **Device Management**: Discover, connect to, and manage IPU devices
- **Graph Operations**: Create and manipulate computation graphs
- **Engine Operations**: Compile and execute programs on IPUs
- **Model Operations**: Load and run ONNX models via PopART
- **Pipeline Operations**: Chain operations together with automatic resource management
- **Tensor Operations**: Create, validate, and manipulate tensor data
- **Utility Functions**: Performance profiling, data import/export, system diagnostics

## Architecture

```
PowerShell Scripts (PSPoplar)
         ↓
    C# Bindings Layer (PoplarCppAPIWrapper) 
         ↓
    C ABI Wrapper (abi-shim)
         ↓
    Poplar C++ SDK
```

## Installation and Setup

### Prerequisites

1. **Poplar SDK 2.6.0+** installed and configured in HyperV
2. **PowerShell 5.1+** or **PowerShell Core 6+**
3. **.NET 6.0 Runtime**
4. Built C# bindings in `../bin/`
5. Built ABI Shim in '../abi-shim/'

### Loading the Module

```powershell
# Import the module
Import-Module ".\PSPoplar\PSPoplar.psd1" -Verbose

# Verify installation
Test-PoplarInstallation

# Get system information
Get-PoplarSystemInfo
```

## Core Concepts

### Device Management

```powershell
# Discover available devices
Get-PoplarDevice

# Connect to a specific device
$device = Connect-PoplarDevice -DeviceId 0

# Test device connectivity
Test-PoplarDevice -DeviceId 0

# Get detailed device information
Get-PoplarDeviceInfo
```

### Graph Operations

```powershell
# Create a computation graph
$graph = New-PoplarGraph -DeviceId 0 -Name "MyGraph"

# Add tensors to the graph
$inputTensor = Add-PoplarTensor -Graph $graph -Shape @(1, 128) -DataType "Float" -Name "input"
$outputTensor = Add-PoplarTensor -Graph $graph -Shape @(1, 10) -DataType "Float" -Name "output"

# Get tensor information
Get-PoplarTensorInfo -Graph $graph -TensorName "input"

# Clean up
Remove-PoplarGraph -Graph $graph
```

### Engine Operations

```powershell
# Create and load an engine
$engine = New-PoplarEngine -Graph $graph -ProgramName "MyProgram"
Start-PoplarEngine -Engine $engine

# Execute the program
Invoke-PoplarEngine -Engine $engine

# Stop the engine when done
Stop-PoplarEngine -Engine $engine
```

### Model Operations (PopART/ONNX)

```powershell
# Load an ONNX model
$session = Import-ONNXModel -ModelPath "model.onnx" -SessionName "MyModel"

# Run inference
$results = Invoke-PoplarInference -Session $session -InputData $inputData -OutputSize 10

# Clean up
Remove-PoplarSession -Session $session
```

### Pipeline Operations

```powershell
# Create a pipeline
$pipeline = New-PoplarPipeline -Name "MLPipeline" -DeviceId 0

# Add pipeline steps
$pipeline | Add-PoplarPipelineStep -StepType "CreateGraph" -Parameters @{Name="MainGraph"}
$pipeline | Add-PoplarPipelineStep -StepType "AddTensor" -Parameters @{
    GraphName="MainGraph"; Name="input"; Shape=@(1,128); DataType="Float"
}
$pipeline | Add-PoplarPipelineStep -StepType "CreateEngine" -Parameters @{
    GraphName="MainGraph"; Name="MainEngine"
}

# Execute the pipeline
$results = Invoke-PoplarPipeline -Pipeline $pipeline -ContinueOnError
```

### Data Operations

```powershell
# Import data from various formats
$tensorData = Import-PoplarData -Path "data.csv" -Format CSV -Shape @(100, 10) -DataType "Float"

# Create tensor specifications
$spec = New-PoplarTensorSpec -Shape @(2, 2) -DataType "Float" -Name "matrix"

# Convert data formats
$tensorData = ConvertTo-PoplarTensor -Data $array -Shape @(10, 10) -DataType "Float"

# Validate tensor data
$validation = Test-PoplarTensorData -TensorData $tensor -ExpectedShape @(10, 10) -CheckNaN

# Export results
Export-PoplarData -TensorData $results -Path "output.json" -Format JSON
```

## Configuration Management

```powershell
# View current configuration
Get-PoplarConfiguration

# Update configuration
Set-PoplarConfiguration -DefaultDevice 1 -EnableLogging $true -LogLevel "Information"

# Reset to defaults
Reset-PoplarConfiguration
```

## Performance and Profiling

```powershell
# Measure operation performance
$perf = Measure-PoplarPerformance -ScriptBlock { 
    $graph = New-PoplarGraph -DeviceId 0
    Remove-PoplarGraph -Graph $graph
} -Iterations 10

# Profile memory usage
$memory = Measure-PoplarMemoryUsage -ScriptBlock { 
    $engine = New-PoplarEngine -Graph $graph 
}

# System diagnostics
$systemInfo = Get-PoplarSystemInfo
```

## Available Cmdlets

### Device Management
- `Get-PoplarDevice` - List available IPU devices
- `Get-PoplarDeviceInfo` - Get detailed device information  
- `Test-PoplarDevice` - Test device connectivity
- `Connect-PoplarDevice` - Connect to a device
- `Disconnect-PoplarDevice` - Disconnect from device(s)

### Graph Operations  
- `New-PoplarGraph` - Create computation graph
- `Add-PoplarTensor` - Add tensor to graph
- `Get-PoplarTensorInfo` - Get tensor information
- `Remove-PoplarGraph` - Clean up graph resources

### Engine Operations
- `New-PoplarEngine` - Create and compile engine
- `New-PoplarEngine` - Create and compile engine
- `Start-PoplarEngine` - Load the engine onto the target device
- `Invoke-PoplarEngine` - Execute compiled program
- `Stop-PoplarEngine` - Unload/clean up engine resources
### Model Operations
- `Import-ONNXModel` - Load ONNX model
- `Invoke-PoplarInference` - Run model inference
- `New-PoplarSession` / `Remove-PoplarSession` - Create/clean up a PopART session

### Pipeline Operations
- `New-PoplarPipeline` - Create execution pipeline
- `Add-PoplarPipelineStep` - Add step to pipeline
- `Invoke-PoplarPipeline` - Execute pipeline

### Tensor Operations
- `New-PoplarTensorSpec` - Create tensor specification
- `ConvertTo-PoplarTensor` - Convert data to tensor format
- `ConvertFrom-PoplarTensor` - Convert tensor to standard format
- `Test-PoplarTensorShape` - Validate tensor shape

### Configuration
- `Get-PoplarConfiguration` - Get current configuration
- `Set-PoplarConfiguration` - Update configuration
- `Reset-PoplarConfiguration` - Reset to defaults

### Data Operations
- `Import-PoplarData` - Import data from files (CSV, JSON, Binary, Text)
- `Export-PoplarData` - Export data to files
- `Test-PoplarTensorData` - Validate tensor data

### Utility Functions
- `Get-PoplarSystemInfo` - Get system information
- `Test-PoplarInstallation` - Test installation health
- `Measure-PoplarPerformance` - Profile operation performance
- `Measure-PoplarMemoryUsage` - Profile memory usage

## Error Handling

The module provides comprehensive error handling with detailed error messages:

```powershell
try {
    $graph = New-PoplarGraph -DeviceId 99  # Invalid device
}
catch [HFLabs.PoplarBindings.PoplarDeviceException] {
    Write-Host "Device error: $($_.Exception.Message)" -ForegroundColor Red
}
catch [HFLabs.PoplarBindings.PoplarException] {
    Write-Host "Poplar error: $($_.Exception.Message)" -ForegroundColor Red
}
catch {
    Write-Host "Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
}
```

## Advanced Usage

### Custom Pipeline Steps

```powershell
# Add custom step to pipeline
$pipeline | Add-PoplarPipelineStep -StepType "Custom" -Parameters @{
    ScriptBlock = { 
        param($Pipeline, $Args)
        # Custom logic here
        Write-Host "Executing custom step with pipeline $($Pipeline.Name)"
        return "Custom result"
    }
    Arguments = @{CustomParam = "value"}
}
```

### Batch Processing

```powershell
# Process multiple models
$models = @("model1.onnx", "model2.onnx", "model3.onnx")
$results = @()

foreach ($modelPath in $models) {
    $session = Import-ONNXModel -ModelPath $modelPath
    $result = Invoke-PoplarInference -Session $session -InputData $batchData
    $results += $result
    Remove-PopARTSession -Session $session
}
```

### Performance Optimization

```powershell
# Configure for performance
Set-PoplarConfiguration -DefaultDevice 0 -DefaultTimeout 60

# Use pipelines for complex workflows
$pipeline = New-PoplarPipeline -Name "OptimizedPipeline" -DeviceId 0
# ... add optimized steps
$results = Invoke-PoplarPipeline -Pipeline $pipeline -Parallel
```

## Troubleshooting

### Common Issues

1. **Module Loading Fails**
   ```powershell
   # Check if C# bindings are built
   Test-Path "../bin/Debug/net10.0/PoplarBindingsExample.dll"
   
   # Build if necessary
   dotnet build "../PoplarBindingsExample.csproj"
   ```

2. **No Devices Found**
   ```powershell
   # Check Poplar environment
   $env:POPLAR_SDK_ENABLED
   
   # Test installation
   Test-PoplarInstallation -IncludeHardware
   ```

3. **Memory Issues**
   ```powershell
   # Monitor memory usage
   $memory = Measure-PoplarMemoryUsage -ScriptBlock { ... }
   
   # Clean up resources explicitly
   Remove-PoplarGraph -Graph $graph
   Disconnect-PoplarDevice
   ```

### Debug Mode

```powershell
# Enable verbose logging
$VerbosePreference = "Continue"
Set-PoplarConfiguration -EnableLogging $true -LogLevel "Information"

# Run with detailed output
Test-PoplarInstallation -Verbose
```

## Examples

See the `examples/` directory for complete examples:

- `BasicGraphExample.ps1` - Basic graph operations
- `ONNXInferenceExample.ps1` - ONNX model inference
- `PipelineExample.ps1` - Complex pipeline workflows
- `PerformanceProfilingExample.ps1` - Performance measurement
- `DataProcessingExample.ps1` - Data import/export operations

## API Reference

For detailed API documentation, use PowerShell's built-in help:

```powershell
# Get help for specific cmdlets
Get-Help New-PoplarGraph -Full
Get-Help Invoke-PoplarInference -Examples
Get-Help Measure-PoplarPerformance -Detailed

# List all available cmdlets
Get-Command -Module PSPoplar
```

## Contributing

1. Follow PowerShell best practices and naming conventions
2. Include comprehensive help documentation with examples
3. Add error handling for all failure scenarios
4. Include unit tests for new functionality
5. Update this README for new features

## Version History

- **v1.0.0** - Initial release with core device, graph, and engine operations
- **v1.1.0** - Added PopART/ONNX support and pipeline operations
- **v1.2.0** - Added utility functions, performance profiling, and data operations

## License

This module is part of the HFLabs IPU Services project and follows the same licensing terms.

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Run `Test-PoplarInstallation` to verify your setup
3. Use `Get-PoplarSystemInfo` to gather diagnostic information
4. Consult the Poplar SDK documentation for low-level details
