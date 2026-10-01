# Poplar SafeHandle Wrappers

> Traceability: listed under [DocDocDoc](../DocDocDoc.md#document-index) · Content planning entry #PAT-NATIVE-009

- **Pattern ID:** PAT-NATIVE-009
- **Area:** NativeInterop | [PoplarCppAPIWrapper](./README.md)
- **Problem:** Direct P/Invoke access to Poplar's C API requires manual lifetime tracking for devices, graphs, tensors, and engines. Forgetting to release handles leaks IPU resources and crashes long-lived services.
- **Constraints:**
  - Works under .NET safe handle infrastructure so GC-driven cleanup is deterministic and exception-safe.
  - Must wrap every Poplar resource type the wrapper exposes (device, graph, tensor, engine, plans).
  - Compatible with conditional builds where Poplar SDK may be missing; no runtime dependency when native symbols are absent.
- **Solution:**
  - `PoplarSafeHandle` derives from `SafeHandle` and centralizes the zero/invalid semantics.
  - Resource-specific subclasses (`PoplarDeviceSafeHandle`, `PoplarGraphSafeHandle`, `PoplarTensorSafeHandle`, `PoplarEngineSafeHandle`, etc.) override `ReleaseHandle` to call the matching `poplar_*` destroy function.
  - Higher-level abstractions (`PoplarGraph`, `PoplarEngine`, `PoplarDevice`) expose managed `IDisposable` wrappers that own the safe handles, ensuring deterministic disposal even when exceptions bubble.
  - Interop shims in `PoplarNative.cs` only return raw `IntPtr` once before immediately wrapping them in safe handles.
- **Anti-patterns:**
  - Holding bare `IntPtr` fields in managed objects and calling `poplar_destroy_*` manually at each call site.
  - Sharing a single safe handle implementation for all resource types (risks calling the wrong destruction routine).
  - Bypassing the wrapper entirely and invoking P/Invoke methods from arbitrary services.
- **Detectors:**
  - Manual review plus `clang-tidy`/`cppcheck` steps called via `cmake --build build --target tidy` to ensure RAII semantics remain intact when native code changes.
  - Planned analyzer `PATTERN070` to block new P/Invoke exports that do not return/consume safe handles.
- **References:**
  - `src/HFLabs/Hardware/Poplar.NET/NativeHandles.cs`
  - `src/HFLabs/Hardware/Poplar.NET/PoplarDevice.cs`
  - `src/HFLabs/Hardware/Poplar.NET/PoplarGraph.cs`
  - `src/HFLabs/Hardware/Poplar.NET/PoplarEngine.cs`
  - `src/HFLabs/Hardware/Poplar.NET/PoplarNative.cs`

