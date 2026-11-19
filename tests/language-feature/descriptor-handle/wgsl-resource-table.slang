// With `-capability wgsl_resource_table`, a `DescriptorHandle<T>` to a sampled texture or a sampler is
// read from the WebGPU resource table. Each dereference becomes WGSL's `getResource<T>(index)`, which
// the `chromium_experimental_resource_table` extension provides, and the index is the handle's `.x`.
// The TABLE run pins one `getResource` per resource type that WGSL accepts there. The TABLE_ABSENT run
// pins what must not appear anywhere in that output. The HEAP run compiles the same shader without the
// capability and pins the default `binding_array` heaps, so the resource table is strictly opt-in.

//TEST:SIMPLE(filecheck=TABLE): -target wgsl -stage compute -entry computeMain -capability wgsl_resource_table
//TEST:SIMPLE(filecheck=TABLE_ABSENT): -target wgsl -stage compute -entry computeMain -capability wgsl_resource_table
//TEST:SIMPLE(filecheck=HEAP): -target wgsl -stage compute -entry computeMain

struct Material
{
    Texture2D<float4>.Handle albedo;
    Texture2D<uint4>.Handle objectIds;
    TextureCube<float4>.Handle environment;
    Texture2DArray<float4>.Handle layers;
    Texture3D<float4>.Handle volume;
    Texture2DMS<float4>.Handle multisampled;
    DepthTexture2D.Handle shadowMap;
    SamplerState.Handle linearSampler;
    SamplerComparisonState.Handle shadowSampler;
}

ConstantBuffer<Material> material;
StructuredBuffer<Texture2D<float4>.Handle> perThreadTextures;
RWStructuredBuffer<float4> outputBuffer;

[shader("compute")]
[numthreads(4, 1, 1)]
void computeMain(uint3 tid : SV_DispatchThreadID)
{
    float2 uv = float2(0.5, 0.5);

    // `albedo` has two uses. WGSL has no function-scope variable that can hold a texture, so each
    // use reads the table itself instead of sharing a temporary.
    Texture2D<float4> albedo = material.albedo;
    uint width, height;
    albedo.GetDimensions(width, height);
    float4 result = albedo.SampleLevel(material.linearSampler, uv, 0.0) * float(width);

    result += float4(material.objectIds.Load(int3(0, 0, 0)));
    result += material.environment.SampleLevel(material.linearSampler, float3(0.0, 0.0, 1.0), 0.0);
    result += material.layers.SampleLevel(material.linearSampler, float3(uv, 1.0), 0.0);
    result += material.volume.SampleLevel(material.linearSampler, float3(uv, 0.5), 0.0);
    result += material.multisampled.Load(int2(0, 0), 0);
    result += material.shadowMap.SampleCmpLevelZero(material.shadowSampler, uv, 0.5);

    // A handle that differs per thread is marked `nonuniform`. WGSL puts no uniformity requirement
    // on the `getResource` index, so the marker leaves no trace in the output.
    result += nonuniform(perThreadTextures[tid.x])->SampleLevel(material.linearSampler, uv, 0.0);

    // HLSL SM6.6 direct heap indexing reads the same single table.
    Texture2D<float4> fromHeap = ResourceDescriptorHeap[tid.y];
    SamplerState samplerFromHeap = SamplerDescriptorHeap[tid.z];
    result += fromHeap.SampleLevel(samplerFromHeap, uv, 0.0);

    outputBuffer[tid.x] = result;
}

// TABLE: enable chromium_experimental_resource_table;
// TABLE: struct Material_std140
// TABLE-NEXT: {
// TABLE-NEXT: albedo{{[_0-9]*}} : vec2<u32>,
// TABLE: perThreadTextures{{[_0-9]*}} : array<vec2<u32>>;
// TABLE: var [[ALBEDO:_S[0-9]+]] : u32 = material{{[_0-9]*}}.albedo{{[_0-9]*}}.x;
// TABLE-DAG: textureDimensions((getResource<texture_2d<f32>>([[ALBEDO]])))
// TABLE-DAG: textureSampleLevel((getResource<texture_2d<f32>>([[ALBEDO]])), (getResource<sampler>(material{{[_0-9]*}}.linearSampler{{[_0-9]*}}.x))
// TABLE-DAG: getResource<texture_2d<u32>>(material{{[_0-9]*}}.objectIds{{[_0-9]*}}.x)
// TABLE-DAG: getResource<texture_cube<f32>>(material{{[_0-9]*}}.environment{{[_0-9]*}}.x)
// TABLE-DAG: getResource<texture_2d_array<f32>>(material{{[_0-9]*}}.layers{{[_0-9]*}}.x)
// TABLE-DAG: getResource<texture_3d<f32>>(material{{[_0-9]*}}.volume{{[_0-9]*}}.x)
// TABLE-DAG: getResource<texture_multisampled_2d<f32>>(material{{[_0-9]*}}.multisampled{{[_0-9]*}}.x)
// TABLE-DAG: getResource<texture_depth_2d>(material{{[_0-9]*}}.shadowMap{{[_0-9]*}}.x)
// TABLE-DAG: getResource<sampler_comparison>(material{{[_0-9]*}}.shadowSampler{{[_0-9]*}}.x)
// TABLE-DAG: var _S{{[0-9]+}} : vec2<u32> = perThreadTextures{{[_0-9]*}}[
// TABLE-DAG: getResource<texture_2d<f32>>(_S{{[0-9]+}}.x)
// TABLE-DAG: getResource<texture_2d<f32>>(tid{{[_0-9]*}}.y)
// TABLE-DAG: getResource<sampler>(tid{{[_0-9]*}}.z)

// TABLE_ABSENT-NOT: binding_array
// TABLE_ABSENT-NOT: _slang_resource_heap
// TABLE_ABSENT-NOT: NonUniform
// TABLE_ABSENT-NOT: {{(var|let) [A-Za-z0-9_]+ : (texture|sampler)}}

// HEAP-NOT: enable chromium_experimental_resource_table
// HEAP: var _slang_resource_heap{{[_0-9]*}} : binding_array<
// HEAP-NOT: getResource
