# PoplarCppAPIWrapper Features

**Breadcrumbs:** [📘 Home](../../README.md) → [IPU Services](../README.md) → [PoplarCppAPIWrapper](./README.md) → Features

## Feature Overview

| Category | Feature | Status |
|----------|---------|--------|
| Device | Device Discovery | ✅ Complete |
| Device | Device Acquisition | ✅ Complete |
| Graph | Graph Construction | ✅ Complete |
| Graph | Tensor Management | ✅ Complete |
| Execution | Engine Loading | ✅ Complete |
| Execution | Program Execution | ✅ Complete |
| IO | Tensor Read/Write | ✅ Complete |
| Interop | Safe Handles | ✅ Complete |

## Device Features

### Device Discovery ✅
Find available IPU devices:

- Enumerate devices
- Device properties
- Capability queries
- Hardware info

### Device Acquisition ✅
Acquire IPU for use:

- Exclusive access
- Session management
- Multi-device support
- Release handling

## Graph Features

### Graph Construction ✅
Build computation graphs:

- Variable tensors
- Constant tensors
- Operation nodes
- Graph optimization

### Tensor Management ✅
Manage tensor data:

- Shape definition
- Data type support
- Memory allocation
- Lifetime management

## Execution Features

### Engine Loading ✅
Load compiled graphs:

- Program compilation
- Engine creation
- Memory mapping
- Configuration

### Program Execution ✅
Run computations:

- Named programs
- Execution sequencing
- Sync/async modes
- Error handling

## IO Features

### Tensor Read/Write ✅
Host-device data transfer:

- Write input tensors
- Read output tensors
- Streaming support
- Zero-copy options

## Interop Features

### Safe Handles ✅
Managed resource cleanup:

| Handle | Purpose |
|--------|---------|
| DeviceHandle | IPU device |
| GraphHandle | Computation graph |
| EngineHandle | Execution engine |
| TensorHandle | Tensor data |

### P/Invoke Layer ✅
Native bindings:

- C ABI shim
- Error propagation
- Type marshaling
- Memory safety

## Data Types

| C# Type | Poplar Type |
|---------|-------------|
| `float` | FLOAT |
| `half` | HALF |
| `int` | INT |
| `bool` | BOOL |

## Roadmap

- [ ] Async execution
- [ ] Multi-replica support
- [ ] Custom vertex programs

## Related Documentation

- [PoplarCppAPIWrapper README](./README.md)
- [SqlIpuBridgeMicroservice](../SqlIpuBridgeMicroservice/README.md)
- [IPUoRDMA](../IPUoRDMA/README.md)

---

*Last updated: 2026-01*
