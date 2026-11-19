// A `DescriptorHandle<T>` holds the `uint2` heap index the WGSL lowering reads with `.x`, so WGSL
// declares it as `vec2<u32>` wherever it is stored, like GLSL's `uvec2`. Here the handles live in a
// uniform struct and in a storage buffer. WGSL used to spell them as the resource type itself
// (`texture_2d<f32>`, `sampler`), which a WGSL struct or array cannot hold and which contradicts the
// `.x` read in the same shader.

//TEST:SIMPLE(filecheck=CHECK): -target wgsl -stage compute -entry computeMain

struct Material
{
    Texture2D<float4>.Handle albedo;
    SamplerState.Handle linearSampler;
}

ConstantBuffer<Material> material;
StructuredBuffer<Texture2D<float4>.Handle> perThreadTextures;
RWStructuredBuffer<float4> outputBuffer;

[shader("compute")]
[numthreads(1, 1, 1)]
void computeMain(uint3 tid : SV_DispatchThreadID)
{
    float2 uv = float2(0.5, 0.5);
    outputBuffer[tid.x] = material.albedo.SampleLevel(material.linearSampler, uv, 0.0)
        + perThreadTextures[tid.x].SampleLevel(material.linearSampler, uv, 0.0);
}

// CHECK: struct Material_std140
// CHECK-NEXT: {
// CHECK-NEXT: albedo{{[_0-9]*}} : vec2<u32>,
// CHECK-NEXT: linearSampler{{[_0-9]*}} : vec2<u32>,
// CHECK: perThreadTextures{{[_0-9]*}} : array<vec2<u32>>;
// CHECK: material{{[_0-9]*}}.albedo{{[_0-9]*}}.x
