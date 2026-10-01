# PoplarCppAPIWrapper TODO

**Breadcrumbs:** [Documentation](../../README.md) > [IPU Services](../README.md) > [PoplarCppAPIWrapper](./README.md) > TODO

Last reviewed: 2026-07-05

Development tasks, improvements, and roadmap for the Poplar C++ API Wrapper.

## Open

### Graph Construction
- [ ] **Control Flow**: `Repeat`, `If`, and `Switch` control flow constructs are not present in
  `PoplarGraph.cs` — no matches found for these constructs in the file. Still needed.

### Device Management
- [ ] **PoplarDevice**: No support for attaching to remote IPU devices — no `Remote*` members in
  `PoplarDevice.cs`.
- [ ] **Multi-IPU**: No multi-IPU device partitioning support — no `Partition`/`MultiIPU` members
  in `PoplarDevice.cs`.

### Execution
- [ ] **Async Execution**: `PoplarEngine.Run()` (`PoplarEngine.cs:199`) and `LoadAndRun()`
  (`PoplarEngine.cs:223`) are both synchronous. Making them awaitable is still open.
- [ ] **Profiling options via EngineOptions**: no `EngineOptions` class exists anywhere in this
  project (`grep -rln "class EngineOptions"` found nothing). This item can't be scoped until an
  `EngineOptions` type is designed — see Stale section below.

## Recently completed

- **Safe handle wrappers** (`NativeHandles.cs`): full `PoplarSafeHandle` abstract base plus
  device/graph/tensor/engine/compute-set safe handle subclasses are implemented.
- **C++ exception propagation** (`PoplarExceptions.cs`): `PoplarException` base class with
  `PoplarDeviceException` and other typed subclasses implemented.
- **PSPoplar pipeline cmdlets** (`PSPoplar/PSPoplar-PipelineOperations.ps1`): `New-PoplarPipeline`,
  `Add-PoplarPipelineStep`, `Invoke-PoplarPipeline`, tensor spec/shape/conversion cmdlets all present.
- **Graph variables/constants** (`PoplarGraph.cs:90` `AddVariable`, `PoplarGraph.cs:139`
  `AddConstant`): implemented.

## Stale / needs clarification

- **Shim Layer — "expose Poplar SDK 3.256 features"**: `abi-shim/shim.cpp` exists (1226 lines) and
  references `poplar::versionString()`, so some SDK-version-aware code is present, but the original
  todo doesn't specify which 3.3-specific features are missing. Can't verify done/not-done without
  a concrete feature list — needs the original author to specify what's still missing, or this
  item should be dropped as too vague to act on.
- **"Expose Poplar profiling options via EngineOptions"**: references a type (`EngineOptions`) that
  does not exist in the codebase. Either this was renamed/removed, or it was never built. Needs
  clarification on whether profiling options should hang off `PoplarEngine` directly or a new
  options type should be introduced — see `Profiling/README.md` cross-link for related context.

---

**Breadcrumbs:** [Documentation](../../README.md) > [IPU Services](../README.md) > [PoplarCppAPIWrapper](./README.md) > TODO
