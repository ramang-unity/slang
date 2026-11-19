// With `-capability wgsl_resource_table`, WGSL's `getResource` accepts only sampled textures and
// samplers, so dereferencing a handle to a buffer or to a storage texture is rejected (E41400) rather
// than emitting a `getResource` call that WGSL validation would reject. A combined texture-sampler
// reads its texture and its sampler from two separate table indices, so building one from a single
// `ResourceDescriptorHeap[i]` index is rejected at both conversion sites, as on HLSL (#13085).

//DIAGNOSTIC_TEST:SIMPLE(filecheck=BUFFER,exit-code=2): -target wgsl -stage compute -entry bufferMain -capability wgsl_resource_table
//DIAGNOSTIC_TEST:SIMPLE(filecheck=STORAGE,exit-code=2): -target wgsl -stage compute -entry storageTextureMain -capability wgsl_resource_table
//DIAGNOSTIC_TEST:SIMPLE(filecheck=COMBINED,exit-code=2): -target wgsl -stage fragment -entry combinedMain -capability wgsl_resource_table

struct Handles
{
    StructuredBuffer<float4>.Handle buffer;
    RWTexture2D<float4>.Handle storageTexture;
}

ConstantBuffer<Handles> handles;
RWStructuredBuffer<float4> outputBuffer;

[shader("compute")]
[numthreads(1, 1, 1)]
void bufferMain(uint3 tid : SV_DispatchThreadID)
{
    outputBuffer[tid.x] = handles.buffer[tid.x];
}

// BUFFER: error[E41400]
// BUFFER: A WGSL resource table holds only sampled textures and samplers

[shader("compute")]
[numthreads(1, 1, 1)]
void storageTextureMain(uint3 tid : SV_DispatchThreadID)
{
    outputBuffer[tid.x] = handles.storageTexture[tid.xy];
}

// STORAGE: error[E41400]
// STORAGE: A WGSL resource table holds only sampled textures and samplers

[shader("fragment")]
float4 combinedMain(float2 uv : TEXCOORD0) : SV_Target
{
    // Site 1: the `_Texture` type's own single-index initializer.
    Sampler2D fromTexture = ResourceDescriptorHeap[11];

    // Site 2: the `.Handle` (DescriptorHandle<T>) single-index initializer.
    Sampler2D.Handle handle = ResourceDescriptorHeap[12];
    Sampler2D fromHandle = handle;

    return fromTexture.Sample(uv) + fromHandle.Sample(uv);
}

// COMBINED: error[E41400]
// COMBINED: Cannot initialize a combined texture-sampler from a single ResourceDescriptorHeap index
// COMBINED: error[E41400]
// COMBINED: its .Handle cannot be built from a single ResourceDescriptorHeap index
