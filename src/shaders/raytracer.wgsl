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

fn hit_sphere(sphere_center: vec3f, radius: f32, ray_origin: vec3f, ray_direction: vec3f) -> f32 {
    let oc = sphere_center - ray_origin; 
    let a = dot(ray_direction, ray_direction);
    let b = -2.0 * dot(oc, ray_direction);
    let c = dot(oc, oc) - radius * radius;
    let discriminant = b * b - 4.0 * a * c;

    if (discriminant < 0.0) {
        return -1.0; // No intersection
    } else {
        return (-b - sqrt(discriminant)) / (2.0 * a); // Return the nearest intersection point
    }; 

}

fn ray_color(ray_direction: vec3f, ray_origin: vec3f) -> vec3f {
    var hit_point: vec3f;
    var normal: vec3f;
    let sphere_count = 3; 
    let animated_offset = sin(uniforms.time) * 0.5; 
    let spheres = array<vec3f, 3>(
        vec3f(animated_offset, 0.0, -3.0), // Sphere center
        vec3f(1.0 + cos(uniforms.time * 0.5), 0.0, -3.0), // Ground plane
        vec3f(-1.0, sin(uniforms.time * 2.0) * 0.3, -3.0) // Another sphere for variety
    );
    var i = 0u;
    for(var i: i32; i < sphere_count; i++) {
        let t = hit_sphere(spheres[i], 0.5, ray_origin, ray_direction);
        if (t > 0.0) {
            hit_point = ray_origin + t * ray_direction; 
            normal = normalize(hit_point - spheres[i]);
            return 0.5 * (normal + vec3f(1.0, 1.0, 1.0)); // Simple shading based on normal
        }
    }
    
    let a = 0.5 *(ray_direction.y + 1.0); 
    let white = vec3f(1.0, 1.0, 1.0); 
    let blue = vec3f(0.5, 0.7, 1.0); 

    return mix(white, blue, a); 
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4f {

    let aspect_ratio = uniforms.canvas_size.x/ uniforms.canvas_size.y;

    // Camera setup
    let fov = 30.0; 
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