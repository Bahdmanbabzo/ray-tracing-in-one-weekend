struct VertexOutput {
    @builtin(position) position: vec4f,
};
struct Hittable {
    position: vec4f,
    radius: f32,
    material: f32,
    albedo: vec4f,
    fuzz: f32,
};
@group(0) @binding(0) var<uniform> canvas_size: vec2f; 
@group(0) @binding(1) var<storage, read> hittable_objects: array<Hittable>;
@group(0) @binding(2) var<uniform> hittable_count: i32;

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
    let max_bounces: i32 = 10;

    for (var bounce: i32 = 0; bounce < max_bounces; bounce++) {
        var closest_t: f32 = -1.0;
        var hit_sphere_index: i32 = -1;
        
        // Use the actual hittable buffer
        for(var i: i32 = 0; i < hittable_count; i++) {
            let t = hit_sphere(
                hittable_objects[i].position.xyz,  // ✅ Use buffer position
                hittable_objects[i].radius,        // ✅ Use buffer radius
                ray_origin, 
                ray_direction
            );
            if (t > 0.0 && (closest_t < 0.0 || t < closest_t)) {
                closest_t = t;
                hit_sphere_index = i;
            }
        }

        if (hit_sphere_index >= 0) {
            let hit_object = hittable_objects[hit_sphere_index];  // ✅ Use buffer data
            let hit_point = ray_origin + closest_t * ray_direction; 
            let normal = normalize(hit_point - hit_object.position.xyz);
            
            let bounce_seed = f32(bounce) * 123.456 + dot(hit_point, vec3f(1.0, 1.0, 1.0));
            ray_origin = hit_point + normal * 0.001;
            
            if (hit_object.material == 2.0) {
                var random_vector = rand_unit_vec_analytic(bounce_seed);
                var scattered_direction = find_hemisphere(random_vector, normal);
                ray_direction = normalize(scattered_direction);     
            }else{
                var reflected = reflect(normalize(ray_direction), normal);
                var fuzz_vec = rand_unit_vec_analytic(bounce_seed) * hit_object.fuzz;  // ✅ Use buffer fuzz
                ray_direction = normalize(reflected + fuzz_vec);
            }

            attenuation = attenuation * hit_object.albedo.xyz;  // ✅ Use buffer color
        } else {
            let a = 0.5 * (ray_direction.y + 1.0); 
            let sky_color = mix(vec3f(1.0, 1.0, 1.0), vec3f(0.5, 0.7, 1.0), a);
            return attenuation * sky_color;
        }
    }
    
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