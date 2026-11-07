struct Chunk_Data {
    int pos_x;
    int pos_y;
    int pos_z;
    int size;
    uint side;
};

struct Indirect_Draw_Command {
    uint num_vertices;
    uint num_instances;
    uint first_vertex;
    uint first_instance;
};

StructuredBuffer<Indirect_Draw_Command> source_commands : register(t0, space0);
StructuredBuffer<Chunk_Data> chunk_data : register(t1, space0);

RWStructuredBuffer<Indirect_Draw_Command> culled_commands : register(u0, space1);

cbuffer Cull_Params : register(b0, space2) {
    float4x4 mvp;
    uint chunk_count;
    uint do_chunk_back_face_culling;
    uint2 _padding;
    int4 cam_chunk_pos;
};

bool outside_plane(float4 plane, float3 center, float3 half_extent) {
    return dot(plane.xyz, center) + plane.w + dot(abs(plane.xyz), half_extent) < 0.0;
}

bool outside_side(Chunk_Data chunk, int3 camera_pos) {
    int3 min_pos = int3(chunk.pos_x, chunk.pos_y, chunk.pos_z);
    int3 max_pos = min_pos + chunk.size - 1;

    switch (chunk.side) {
        case 0: return camera_pos.x < min_pos.x; // pos_x
        case 1: return camera_pos.x > max_pos.x; // neg_x
        case 2: return camera_pos.y < min_pos.y; // pos_y
        case 3: return camera_pos.y > max_pos.y; // neg_y
        case 4: return camera_pos.z < min_pos.z; // pos_z
        case 5: return camera_pos.z > max_pos.z; // neg_z
        default: return false;                  // extra
    }
}

[numthreads(64, 1, 1)]
void main(uint3 dispatch_id : SV_DispatchThreadID) {
    uint i = dispatch_id.x;
    if (i >= chunk_count) return;

    Chunk_Data chunk = chunk_data[i];
    Indirect_Draw_Command command = source_commands[i];

    float3 chunk_origin = float3(chunk.pos_x, chunk.pos_y, chunk.pos_z) * 32.0;
    float3 half_extent = float3(chunk.size, chunk.size, chunk.size) * 16.0;
    float3 center = chunk_origin + half_extent;

    float4 left_plane   = mvp[3] + mvp[0];
    float4 right_plane  = mvp[3] - mvp[0];
    float4 bottom_plane = mvp[3] + mvp[1];
    float4 top_plane    = mvp[3] - mvp[1];
    float4 near_plane   = mvp[2];
    float4 far_plane    = mvp[3] - mvp[2];

    bool frustum_culled =
        outside_plane(left_plane, center, half_extent) ||
        outside_plane(right_plane, center, half_extent) ||
        outside_plane(bottom_plane, center, half_extent) ||
        outside_plane(top_plane, center, half_extent) ||
        outside_plane(near_plane, center, half_extent) ||
        outside_plane(far_plane, center, half_extent);

    bool side_culled = do_chunk_back_face_culling != 0 && outside_side(chunk, cam_chunk_pos.xyz);

    if (frustum_culled || side_culled) command.num_vertices = 0;

    culled_commands[i] = command;
}
