struct VertexOutput {
    @builtin(position) position: vec4f,
};
struct Uniforms {
    canvas_size: vec2f, 
    time: f32,
};
@group(0) @binding(0) var<uniform> uniforms: Uniforms; 

@vertex
fn vs_main(
    @location(0) position: vec2f,
) -> VertexOutput {
    var output: VertexOutput;
    // Transform the position to clip space
    output.position = vec4f(position, 0.0, 1.0);
    return output;
}

// SDF for a sphere
fn sdf_sphere(point: vec3f, center: vec3f, radius: f32) -> f32 {
    return length(point - center) - radius;
}

// Smooth union operation for metaballs effect
fn smooth_union(d1: f32, d2: f32, k: f32) -> f32 {
    let h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

// Scene SDF - combines all objects with metaballs effect
fn scene_sdf(point: vec3f) -> f32 {
    let animated_offset = sin(uniforms.time) * 0.8;
    let sphere1 = sdf_sphere(point, vec3f(animated_offset, 0.0, -3.0), 0.6);
    let sphere2 = sdf_sphere(point, vec3f(1.2 + cos(uniforms.time * 0.7), 0.0, -3.0), 0.5);
    let sphere3 = sdf_sphere(point, vec3f(-1.2, sin(uniforms.time * 1.5) * 0.6, -3.0), 0.7);
    let sphere4 = sdf_sphere(point, vec3f(cos(uniforms.time * 0.3) * 0.8, sin(uniforms.time * 0.9) * 0.5, -2.5), 0.4);
    
    // Smooth blending parameter - controls how "blobby" the effect is
    let blend_factor = 0.8;
    
    // Create metaballs effect using smooth unions
    var result = sphere1;
    result = smooth_union(result, sphere2, blend_factor);
    result = smooth_union(result, sphere3, blend_factor);
    result = smooth_union(result, sphere4, blend_factor);
    
    return result;
}

// Calculate surface normal using gradient estimation
fn calculate_normal(point: vec3f) -> vec3f {
    let epsilon = 0.001;
    let gradient = vec3f(
        scene_sdf(point + vec3f(epsilon, 0.0, 0.0)) - scene_sdf(point - vec3f(epsilon, 0.0, 0.0)),
        scene_sdf(point + vec3f(0.0, epsilon, 0.0)) - scene_sdf(point - vec3f(0.0, epsilon, 0.0)),
        scene_sdf(point + vec3f(0.0, 0.0, epsilon)) - scene_sdf(point - vec3f(0.0, 0.0, epsilon))
    );
    return normalize(gradient);
}

// Raymarching function
fn raymarch(ray_origin: vec3f, ray_direction: vec3f) -> f32 {
    let max_steps = 64;
    let max_distance = 100.0;
    let epsilon = 0.001;
    
    var total_distance = 0.0;
    
    for (var i = 0; i < max_steps; i++) {
        let current_position = ray_origin + total_distance * ray_direction;
        let distance_to_scene = scene_sdf(current_position);
        
        if (distance_to_scene < epsilon) {
            return total_distance; // Hit surface
        }
        
        total_distance += distance_to_scene;
        
        if (total_distance > max_distance) {
            break; // Ray escaped
        }
    }
    
    return -1.0; // No hit
}

fn ray_color(ray_direction: vec3f, ray_origin: vec3f) -> vec3f {
    let t = raymarch(ray_origin, ray_direction);
    
    if (t > 0.0) {
        let hit_point = ray_origin + t * ray_direction;
        let normal = calculate_normal(hit_point);
        return 0.5 * (normal + vec3f(1.0, 1.0, 1.0)); // Simple shading based on normal
    }
    
    let a = 0.5 * (ray_direction.y + 1.0);
    let white = vec3f(1.0, 1.0, 1.0);
    let blue = vec3f(0.5, 0.7, 1.0);
    
    return mix(white, blue, a); 
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4f {

    let aspect_ratio = uniforms.canvas_size.x/ uniforms.canvas_size.y;

    // Camera setup
    let fov = 60.0; 
    let focal_length = 1.0 / tan(radians(fov) * 0.5);
    let camera_position = vec3f(0.0, 0.0, 0.0);

    // Convert input.color.xy to screen space
    let pixel_coords = input.position.xy / uniforms.canvas_size; 
    let ndc = pixel_coords * 2.0 - 1.0; 
    // Map to viewport coordinates
    let viewport_x = ndc.x * aspect_ratio; 
    let viewport_y = ndc.y ; 

    // Calculate ray direction
    let ray_direction = normalize(vec3f(viewport_x, viewport_y, -focal_length));
    let pixel_color = ray_color(ray_direction, camera_position); 
    return vec4f(pixel_color, 1.0); 

}