// With `-capability wgsl_resource_table`, a combined texture-sampler handle carries two resource-table
// indices, the texture's in `.x` and the sampler's in `.y`, as it does on HLSL. WGSL has no combined
// sampler type, so each dereference reads the texture and the sampler from the table separately.

//TEST:SIMPLE(filecheck=CHECK): -target wgsl -stage fragment -entry fragmentMain -capability wgsl_resource_table

struct Params
{
    Sampler2D.Handle combined;
    uint textureIndex;
    uint samplerIndex;
}

ConstantBuffer<Params> params;

[shader("fragment")]
float4 fragmentMain(float2 uv : TEXCOORD0) : SV_Target
{
    // The explicit two-index form, which is how a combined handle is built from separate indices.
    Sampler2D.Handle fromIndices = Sampler2D.Handle(uint2(params.textureIndex, params.samplerIndex));
    return params.combined.Sample(uv) + fromIndices.Sample(uv);
}

// The lowered combined-sampler struct holds a texture and a sampler, which WGSL cannot declare, so
// it must not be emitted.
// CHECK: enable chromium_experimental_resource_table;
// CHECK-NOT: struct Sampler2D
// CHECK: var [[EXPLICIT_TEXTURE:_S[0-9]+]] : u32 = params{{[_0-9]*}}.textureIndex{{[_0-9]*}};
// CHECK: var [[EXPLICIT_SAMPLER:_S[0-9]+]] : u32 = params{{[_0-9]*}}.samplerIndex{{[_0-9]*}};
// CHECK: var [[STORED_TEXTURE:_S[0-9]+]] : u32 = params{{[_0-9]*}}.combined{{[_0-9]*}}[i32(0)];
// CHECK: var [[STORED_SAMPLER:_S[0-9]+]] : u32 = params{{[_0-9]*}}.combined{{[_0-9]*}}[i32(1)];
// CHECK: textureSample((getResource<texture_2d<f32>>([[STORED_TEXTURE]])), (getResource<sampler>([[STORED_SAMPLER]]))
// CHECK: textureSample((getResource<texture_2d<f32>>([[EXPLICIT_TEXTURE]])), (getResource<sampler>([[EXPLICIT_SAMPLER]]))
