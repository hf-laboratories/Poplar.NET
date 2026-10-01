# PoplarCppAPIWrapper Documentation Index

**Breadcrumbs:** [📘 Home](../../README.md) → [IPU Services](../README.md) → [PoplarCppAPIWrapper](./README.md) → Index

## Main Documents

- [README](./README.md) - Module overview
- [Features](./FEATURE-MAPPING.md) - Feature list
- [Development Roadmap](./todo.md) - Development tasks
- [Index](./index.md) - This document

## Components

### [Core](../Core/README.md) Classes

| Class | File | Purpose |
|-------|------|---------|
| `PoplarDevice` | `PoplarDevice.cs` | IPU device wrapper |
| `PoplarGraph` | `PoplarGraph.cs` | Computation graph construction |
| `PoplarProgram` | `PoplarEngine.cs` | Named program sequence |
| `PoplarEngine` | `PoplarEngine.cs` | Engine execution and tensor IO |
| `PoplarNative` | `PoplarNative.cs` | P/Invoke for C ABI shim |

### Native Handles

| Handle | Purpose |
|--------|---------|
| `DeviceHandle` | SafeHandle for IPU device |
| `GraphHandle` | SafeHandle for computation graph |
| `EngineHandle` | SafeHandle for execution engine |
| `TensorHandle` | SafeHandle for tensor data |

## API Reference

### PoplarDevice

```csharp
public class PoplarDevice : IDisposable
{
    // Discover available devices
    static IEnumerable<DeviceInfo> GetAvailableDevices();
    
    // Acquire device by ID
    static PoplarDevice Acquire(int deviceId = 0);
    
    // Device properties
    int TileCount { get; }
    string Type { get; }
}
```

### PoplarGraph

```csharp
public class PoplarGraph : IDisposable
{
    // Create graph for device
    PoplarGraph(PoplarDevice device);
    
    // Add tensor
    TensorHandle AddVariable(string name, DataType type, int[] shape);
    
    // Add constant
    TensorHandle AddConstant(string name, float[] data, int[] shape);
}
```

### PoplarEngine

```csharp
public class PoplarEngine : IDisposable
{
    // Load engine from graph
    PoplarEngine(PoplarGraph graph, params PoplarProgram[] programs);
    
    // Write tensor to device
    void WriteTensor(string name, ReadOnlySpan<float> data);
    
    // Read tensor from device
    void ReadTensor(string name, Span<float> data);
    
    // Run program
    void Run(string programName);
}
```

## [Examples](../Examples/README.md)

### Device Discovery

```csharp
var devices = PoplarDevice.GetAvailableDevices();
foreach (var info in devices)
{
    Console.WriteLine($"Device {info.Id}: {info.Type}, {info.TileCount} tiles");
}
```

### Graph Construction and Execution

```csharp
using var device = PoplarDevice.Acquire(0);
using var graph = new PoplarGraph(device);

var input = graph.AddVariable("input", DataType.Float, new[] { 1, 64 });
var output = graph.AddVariable("output", DataType.Float, new[] { 1, 64 });

using var engine = new PoplarEngine(graph, new PoplarProgram("main", mainSequence));

engine.WriteTensor("input", inputData);
engine.Run("main");
engine.ReadTensor("output", outputData);
```

## Related Documentation

- [SqlIpuBridgeMicroservice](../SqlIpuBridgeMicroservice/README.md) - Uses Poplar bindings
- [Accelerator](../Accelerator/README.md) - IPU execution
- [IPU Services](../README.md) - All services

---

*Last updated: 2026-01*
