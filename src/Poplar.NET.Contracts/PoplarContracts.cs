using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace HFLabs.Poplar
{
    public enum PoplarDataType
    {
        Float = 0,
        Half = 1,
        Int = 2,
        UnsignedInt = 3,
        Char = 4,
        UnsignedChar = 5,
        Short = 6,
        UnsignedShort = 7,
        Bool = 8
    }

    public enum PoplarDeviceType
    {
        Ipu = 0,
        IpuModel = 1,
        Cpu = 2
    }

    public enum PoplarOptimizationLevel
    {
        None = 0,
        Speed = 1,
        Memory = 2
    }

    public sealed class PoplarDevice : IDisposable
    {
        public IntPtr NativeHandle { get; }
        public IntPtr Target { get; }
        public uint DeviceId { get; }
        public uint NumIpus { get; }
        public uint TilesPerIpu { get; }
        public bool IsAttached { get; }

        public static PoplarDevice AcquireAvailable(uint deviceCount = 1) => throw new NotImplementedException("Reference assembly - runtime implementation in HFLabs.Poplar.NET.dll");
        public static PoplarDevice CreateIpuModel(uint numIpus = 1, uint tilesPerIpu = 1472, string? ipuVersion = "ipu2") => throw new NotImplementedException("Reference assembly - runtime implementation in HFLabs.Poplar.NET.dll");
        public void Attach() => throw new NotImplementedException();
        public void Detach() => throw new NotImplementedException();
        public void Dispose() => throw new NotImplementedException();
    }

    public sealed class PoplarGraph : IDisposable
    {
        public IntPtr NativeHandle { get; }
        public IntPtr Target { get; }

        public PoplarGraph(IntPtr target) => throw new NotImplementedException("Reference assembly - runtime implementation in HFLabs.Poplar.NET.dll");
        public PoplarTensor AddVariable(PoplarDataType type, ReadOnlySpan<long> shape, string debugContext = "") => throw new NotImplementedException();
        public PoplarTensor AddConstant(PoplarDataType type, ReadOnlySpan<long> shape, float value, string debugContext = "") => throw new NotImplementedException();
        public PoplarProgram CreateSequence() => throw new NotImplementedException();
        public void Dispose() => throw new NotImplementedException();
    }

    public sealed class PoplarTensor : IDisposable
    {
        public IntPtr NativeHandle { get; }
        public PoplarDataType DataType { get; }
        public ReadOnlyMemory<long> Shape { get; }
        public int Rank { get; }
        public void Dispose() => throw new NotImplementedException();
    }

    public sealed class PoplarProgram : IDisposable
    {
        public IntPtr NativeHandle { get; }
        public void Dispose() => throw new NotImplementedException();
    }

    public sealed class PoplarEngine : IDisposable
    {
        public IntPtr NativeHandle { get; }
        public PoplarEngine(PoplarGraph graph, PoplarProgram program, PoplarOptimizationLevel optLevel = PoplarOptimizationLevel.Speed) => throw new NotImplementedException("Reference assembly - runtime implementation in HFLabs.Poplar.NET.dll");
        public void Load(PoplarDevice device) => throw new NotImplementedException();
        public void Run(uint programIndex = 0) => throw new NotImplementedException();
        public void WriteTensor(string handle, ReadOnlySpan<float> data) => throw new NotImplementedException();
        public void ReadTensor(string handle, Span<float> destination) => throw new NotImplementedException();
        public void Dispose() => throw new NotImplementedException();
    }

    public sealed class PopARTSession : IDisposable
    {
        public IntPtr NativeHandle { get; }
        public static PopARTSession CreateInferenceSession(string onnxModelPath, PoplarDevice device) => throw new NotImplementedException("Reference assembly - runtime implementation in HFLabs.Poplar.NET.dll");
        public void Run(Dictionary<string, ReadOnlyMemory<float>> inputs, Dictionary<string, Memory<float>> outputs) => throw new NotImplementedException();
        public void Dispose() => throw new NotImplementedException();
    }

    public sealed class IpuFanGovernor : IDisposable
    {
        public double TargetTempCelsius { get; set; }
        public void SetFanSpeedPercentage(int percentage) => throw new NotImplementedException("Reference assembly - runtime implementation in HFLabs.Poplar.NET.dll");
        public void Start() => throw new NotImplementedException();
        public void Stop() => throw new NotImplementedException();
        public void Dispose() => throw new NotImplementedException();
    }

    public static class PoplarResidentGraphs
    {
        public static PoplarEngine CreateLlmComponentGraph(PoplarDevice device, int hiddenSize, int numHeads, int seqLen) => throw new NotImplementedException("Resident Graph - runtime implementation in HFLabs.Poplar.NET.dll");
        public static PoplarEngine CreatePsoVelocityGraph(PoplarDevice device, int swarmSize, int dimensions) => throw new NotImplementedException("Resident Graph - runtime implementation in HFLabs.Poplar.NET.dll");
        public static PoplarEngine CreateDeMutationGraph(PoplarDevice device, int populationSize, int dimensions) => throw new NotImplementedException("Resident Graph - runtime implementation in HFLabs.Poplar.NET.dll");
        public static PoplarEngine CreateCmaesCovarianceGraph(PoplarDevice device, int dimensions) => throw new NotImplementedException("Resident Graph - runtime implementation in HFLabs.Poplar.NET.dll");
        public static PoplarEngine CreateKgeGraph(PoplarDevice device, int numEntities, int embeddingDim) => throw new NotImplementedException("Resident Graph - runtime implementation in HFLabs.Poplar.NET.dll");
    }
}
