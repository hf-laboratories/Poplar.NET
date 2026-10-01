# PoplarCppAPIWrapper - C# Bindings for Poplar SDK

**Breadcrumbs:** Home > PoplarCppAPIWrapper

## Overview

PoplarCppAPIWrapper provides C# bindings for the Graphcore Poplar SDK, enabling .NET applications to program IPU hardware. It wraps the Poplar C++ API with C# interfaces, handles native interop, and provides graph construction, tensor operations, and program execution capabilities.

**Project Path:** `src/HFLabs/Hardware/Poplar.NET/`

**Key Responsibilities:**
- C# bindings for Poplar C++ API
- C ABI interface to Poplar
- Native interop and type marshaling
- Memory management and resource cleanup
- Graph construction and manipulation
- Tensor operations and device management
- Error handling and exceptions

See: [Architecture](../../../../../docs/ARCHITECTURE.md)

## Features

PoplarCppAPIWrapper offers the following capabilities:

### Core Features
- **PoplarDevice** - IPU device discovery and management
- **PoplarGraph** - Computation graph construction
- **PoplarProgram** - Program sequence definition
- **PoplarEngine** - Engine loading and execution
- **Tensor IO** - Host-device data transfer
- **Native Interop** - C ABI shim for Poplar SDK
- **Safe Handles** - Managed resource cleanup

### Key Classes

| Class | File | Purpose |
|-------|------|---------|
| `PoplarDevice` | `PoplarDevice.cs` | IPU device wrapper with discovery |
| `PoplarGraph` | `PoplarGraph.cs` | Computation graph construction |
| `PoplarProgram` | `PoplarEngine.cs` | Named program sequence |
| `PoplarEngine` | `PoplarEngine.cs` | Engine execution and tensor IO |
| `PoplarNative` | `PoplarNative.cs` | P/Invoke declarations for C ABI shim |
| `PoplarExceptions` | `PoplarExceptions.cs` | Custom exception types |
| `DeviceInfo` | `DeviceInfo.cs` | Device information model |
| `NativeHandles` | `NativeHandles.cs` | SafeHandle wrappers for native pointers |

## Architecture

### Layer Structure

```
┌─────────────────────────────────────┐
│      C# Application Code            │
├─────────────────────────────────────┤
│   PoplarCppAPIWrapper (Managed)     │
│   - PoplarDevice, PoplarGraph       │
│   - PoplarProgram, PoplarEngine     │
├─────────────────────────────────────┤
│   PoplarNative (P/Invoke)           │
│   - Function declarations           │
│   - Type marshaling                 │
├─────────────────────────────────────┤
│   C ABI Shim (abi-shim/)            │
│   - Extern "C" functions            │
│   - Poplar SDK calls                │
├─────────────────────────────────────┤
│   Poplar SDK (C++)                  │
│   - Device, Graph, Program, Engine  │
└─────────────────────────────────────┘
```

### PoplarEngine

The main execution engine:

```csharp
public class PoplarEngine : IDisposable
{
    public IntPtr Handle { get; }
    public bool IsLoaded { get; }
    
    public void Load(PoplarDevice device);
    public void Run();
    public void LoadAndRun(PoplarDevice device);
    
    public void WriteTensor(string handleName, IntPtr data, UIntPtr numBytes);
    public void ReadTensor(string handleName, IntPtr data, UIntPtr numBytes);
}
```

## Usage

### Enumerate IPU Devices

```csharp
using HFLabs.PoplarBindings;

// Enumerate available devices
var devices = PoplarDevice.EnumerateDevices();
foreach (var info in devices)
{
    Console.WriteLine($"Device {info.Id}: {info.Type} ({info.NumTiles} tiles)");
}

// Attach to first available device
using var device = PoplarDevice.Attach(deviceId: 0);
```

### Build and Execute Graph

```csharp
// Create graph on device
using var graph = PoplarGraph.Create(device);

// Add tensors and operations (via native graph builders)
// ...

// Create program
using var program = new PoplarProgram("main");

// Create engine from graph and program
using var engine = graph.CreateEngine(program);

// Load and execute
engine.LoadAndRun(device);
```

### Host-Device Data Transfer

```csharp
// Write data to device tensor
float[] inputData = new float[1024];
// ... populate inputData ...

unsafe
{
    fixed (float* ptr = inputData)
    {
        engine.WriteTensor("input_handle", (IntPtr)ptr, 
            (UIntPtr)(inputData.Length * sizeof(float)));
    }
}

// Execute computation
engine.Run();

// Read results back
float[] outputData = new float[1024];
unsafe
{
    fixed (float* ptr = outputData)
    {
        engine.ReadTensor("output_handle", (IntPtr)ptr,
            (UIntPtr)(outputData.Length * sizeof(float)));
    }
}
```

### FIFO Streams (Host-Compatible)

For streaming data paths compatible with the FPGA well-behaved host interface,
use FIFO streams and connect host buffers with size and alignment checks.

```csharp
// Create FIFO stream tensor
var stream = graph.AddHostToDeviceFifo("h2d_stream", PoplarDataType.Float, new[] { 1024 }, numBuffers: 2);

// Compute required bytes and connect the stream (64-byte alignment for 512-bit paths)
UIntPtr required = engine.GetStreamBufferSizeBytes(stream, numBuffers: 2);
engine.ConnectStream("h2d_stream", stream, bufferPtr, numBuffers: 2, alignmentBytes: 64);
```

For device-to-host FIFO streams, use `AddDeviceToHostFifo` with the same sizing
rules. These map cleanly to Poplar's `addHostToDeviceFIFO` and
`addDeviceToHostFIFO` and preserve FIFO backpressure semantics.

## Configuration

### Environment Variables

- `POPLAR_SDK_PATH` - Path to Poplar SDK installation
- `IPU_ATTACH_TIMEOUT` - Device attachment timeout in seconds
- `IPU_DEVICE_COUNT` - Limit number of IPUs to use

## Dependencies

**Required:**
- Poplar SDK (Graphcore)
- C ABI shim library (abi-shim/)

**Related Services:**
- [TileMapping](../../TileMapping/docs/README.md) - Tile placement optimization
- [Accelerator](../../Accelerator/docs/README.md) - Graph acceleration


## Performance Considerations

- **Device Attachment** - Attach to devices once and reuse
- **Engine Compilation** - Compile engines ahead of time when possible
- **Tensor Transfer** - Use pinned memory for large transfers
- **SafeHandle Pattern** - Ensures native resources are cleaned up

## Host Streams (FIFO)

For streaming IO, prefer FIFO-based host streams. These align with the FPGA
`well_behaved_host` interface by respecting backpressure and fixed element sizes.

**Graph setup:**
- `AddHostToDeviceFifo(handleName, dataType, shape, numBuffers)`
- `AddDeviceToHostFifo(handleName, dataType, shape, numBuffers)`

**Engine setup:**
- `ConnectStream(handleName, bufferPtr, numBytes)` before `Run()`

Use `CreateHostWrite`/`CreateHostRead` with `WriteTensor`/`ReadTensor` for
non-streaming, bulk transfers.

## Troubleshooting

### Common Issues

#### Engine Not Loaded
**Symptom:** "Engine must be loaded before running"  
**Cause:** Calling `Run()` before `Load(device)`  
**Solution:** Call `Load(device)` first or use `LoadAndRun(device)`

#### Failed to Load Engine
**Symptom:** "Failed to load engine" error  
**Cause:** Device not available or graph incompatible  
**Solution:** Check device availability and graph configuration

#### Tensor Handle Not Found
**Symptom:** "Failed to write/read tensor via 'handle_name'"  
**Cause:** Host handle not created with `CreateHostWrite`/`CreateHostRead`  
**Solution:** Create handles during graph construction

## TODO

See: [TODO List](./todo.md) for planned improvements and known issues.

## Related Documentation

- [Architecture](../../../../../docs/ARCHITECTURE.md)
- [TileMapping](../../TileMapping/docs/README.md) - Tile placement
- [Accelerator](../../Accelerator/docs/README.md) - Graph acceleration
- [Developer Guide](../../../../../docs/guides/dev-guide.md)

---

**Breadcrumbs:** Home > PoplarCppAPIWrapper

*Last updated: December 2025*

