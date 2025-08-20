struct VertexOutput {
    @builtin(position) position: vec4f,
};
@group(0) @binding(0) var<uniform> canvas_size: vec2f; 
@group(0) @binding(1) var<uniform> time: f32;

@vertex
fn vs_main(
    @location(0) position: vec2f,
) -> VertexOutput {
    var output: VertexOutput;
    // Transform the position to clip space
    output.position = vec4f(position, 0.0, 1.0);
    return output;
}

fn is_front_facing(ray_direction: vec3f, normal: vec3f) -> bool {
    return dot(ray_direction, normal) > 0.0; 
}
// https://dekoolecentrale.nl/wgsl-fns/rand11Sin
// Generates a random float
fn rand11(n: f32) -> f32 { 
    return fract(sin(n) * 43758.5453123); 
}

fn hash22(p: vec2<f32>) -> vec2<f32> {
  var p3 = fract(vec3<f32>(p.xyx) * vec3<f32>(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}
fn noise2D(p: vec2<f32>) -> f32 {
  let i = floor(p);
  let f = fract(p);
  let u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(dot(hash22(i + vec2<f32>(0.0, 0.0)), f - vec2<f32>(0.0, 0.0)),
        dot(hash22(i + vec2<f32>(1.0, 0.0)), f - vec2<f32>(1.0, 0.0)), u.x),
    mix(dot(hash22(i + vec2<f32>(0.0, 1.0)), f - vec2<f32>(0.0, 1.0)),
        dot(hash22(i + vec2<f32>(1.0, 1.0)), f - vec2<f32>(1.0, 1.0)), u.x), u.y);
}
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3f {
    let c = v * s;
    let x = c * (1.0 - abs(((h * 6.0) % 2.0) - 1.0));
    let m = v - c;
    
    if (h < 1.0/6.0) { return vec3f(c + m, x + m, m); }
    else if (h < 2.0/6.0) { return vec3f(x + m, c + m, m); }
    else if (h < 3.0/6.0) { return vec3f(m, c + m, x + m); }
    else if (h < 4.0/6.0) { return vec3f(m, x + m, c + m); }
    else if (h < 5.0/6.0) { return vec3f(x + m, m, c + m); }
    else { return vec3f(c + m, m, x + m); }
}

// Generates a random vec3 
fn rand_vec3(p:f32) -> vec3f {
    return vec3f(
        fract(sin(p * 12.9898) * 43758.5453),
        fract(sin(p * 78.233) * 24634.6345),
        fract(sin(p * 45.164) * 12345.6789)
    );
}

// Returnns a random unit vector always on the sphere surface
fn rand_unit_vec_analytic(seed: f32) -> vec3f {
    let v = rand_vec3(seed); 
    let u1 = v.x; 
    let u2 = v.y;
    let z = 1.0 - 2.0 * u1; 
    let r = sqrt(max(0.0, 1.0 - z * z));
    let phi = 2.0 * 3.141592653589793 * u2; 
    return vec3f(r * cos(phi), r * sin(phi), z);
}

// Checks if a random vector is in the same hemisphere as the normal
fn find_hemisphere(rand_vector: vec3f, normal: vec3f) -> vec3f {
    if (dot(rand_vector, normal) < 0.0) {
        return -rand_vector;
    } else {
        return rand_vector;
    }
}

// Checks for intersection with a sphere
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

// Calculates the color of the ray based on bounces
fn ray_color(initial_ray_direction: vec3f, initial_ray_origin: vec3f) -> vec3f {
    var ray_direction: vec3f = initial_ray_direction;
    var ray_origin: vec3f = initial_ray_origin;
    var attenuation: vec3f = vec3f(1.0, 1.0, 1.0);
    
    let sphere: vec3f = vec3f(0.0, 0.0, -6.0);
    let max_bounces: i32 = 10;
    
    for (var bounce: i32 = 0; bounce < max_bounces; bounce++) {
        let t = hit_sphere(sphere, 1.0, ray_origin, ray_direction);
        
        if (t > 0.0) {
            let hit_point: vec3f  = ray_origin + t * ray_direction; 
            let normal: vec3f  = normalize(hit_point - sphere);
            
            // Generate a NEW random vector for THIS specific bounce
            let bounce_seed: f32 = f32(bounce) * 123.456 + dot(hit_point, vec3f(1.0, 1.0, 1.0));
            let random_vec: vec3f = rand_unit_vec_analytic(bounce_seed);
            let hemisphere_vec: vec3f = find_hemisphere(random_vec, normal);
            
            // Set up the NEXT ray for the next bounce
            ray_origin = hit_point + normal * 0.001; // Small offset
            ray_direction = normalize(hemisphere_vec);

            let plasma_coord = hit_point.xy * 3.0;
            let plasma1 = noise2D(plasma_coord + time * vec2f(0.1, 0.2));
            let plasma2 = noise2D(plasma_coord * 1.3 + time * vec2f(-0.15, 0.1));
            let plasma3 = noise2D(plasma_coord * 0.7 + time * vec2f(0.05, -0.25));

            let combined_plasma = (plasma1 + plasma2 + plasma3) / 3.0;

            // Use plasma to control sphere visibility
            let disappear_threshold = sin(time * 0.5) * 0.5 + 0.5; 
            let plasma_alpha = combined_plasma * 0.5 + 0.5; 

            if (plasma_alpha < disappear_threshold) {
                continue; 
            }

            // For visible parts, apply plasma coloring
            let hue = fract(combined_plasma + time * 0.05);
            let plasma_color = hsv_to_rgb(hue, 0.8, 0.9);
            attenuation = attenuation * plasma_color;
        } else {
            // Ray missed - hit background, return sky color
            let a = 0.5 * (ray_direction.y + 1.0); 
            let sky_color = mix(vec3f(1.0, 1.0, 1.0), vec3f(0.5, 0.7, 1.0), a);
            return attenuation * sky_color;
        }
    }
    
    // Used all bounces - return black
    return vec3f(0.0, 0.0, 0.0);
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4f {

    let aspect_ratio = canvas_size.x/ canvas_size.y;

    // Camera setup
    let fov = 30.0; 
    let focal_length = 1.0 / tan(radians(fov) * 0.5);
    let camera_position = vec3f(0.0, 0.0, 0.0);

    // Convert input.color.xy to screen space
    let pixel_coords = input.position.xy / canvas_size; 
    let ndc = pixel_coords * 2.0 - 1.0; 
    // Map to viewport coordinates
    let viewport_x = ndc.x * aspect_ratio; 
    let viewport_y = ndc.y ; 
    // Calculate ray direction
    let camera_ray_direction = normalize(vec3f(viewport_x, viewport_y, -focal_length));
    let pixel_color = ray_color(camera_ray_direction, camera_position); 
    return vec4f(pixel_color, 1.0); 

}