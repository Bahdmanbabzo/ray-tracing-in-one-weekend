# Ray Tracing in One Weekend (WebGPU / WGSL)

A modern JavaScript/WebGPU port of the classic "Ray Tracing in One Weekend" tutorial. This project demonstrates real-time path tracing with spheres, materials (diffuse, metal, glass), and interactive controls using dat.gui.

## Features
- Real-time ray tracing in the browser using WebGPU and WGSL shaders
- Multiple spheres with adjustable position, color, material, and fuzz
- Ground plane for realistic scenes
- Material system: diffuse, metal, and glass (with refraction)
- Interactive UI controls for camera and object properties
- Multi-sampling for noise reduction
- Clean, modular code structure

## Getting Started

### Prerequisites
- Node.js (v16+ recommended)
- A browser with WebGPU support (Chrome Canary, Edge, or recent Chrome)

### Installation
```sh
npm install
```

### Running the Project
```sh
npm run dev
```
Then open [http://localhost:5173](http://localhost:5173) in your browser.

## Project Structure
```
index.html                # Entry point
package.json              # Project metadata
src/
  main.js                 # WebGPU setup, dat.gui controls
  hittables.js            # Sphere data structure
  engine/
    engine.js             # WebGPU engine utilities
    renderPipeline.js     # Pipeline setup
  shaders/
    raytracer.wgsl        # WGSL ray tracing shader
    quad.wgsl             # Fullscreen quad shader
  style.css               # Basic styles
public/
  vite.svg                # Vite logo
  javascript.svg          # JS logo
```

## How It Works
- Spheres and ground are defined in JavaScript and sent to the GPU as storage buffers
- The WGSL shader performs ray-sphere intersection and path tracing for each pixel
- Materials are handled in the shader: diffuse (matte), metal (reflective), glass (refractive)
- Camera and object properties can be adjusted in real time via dat.gui
- Multi-sampling and gamma correction reduce noise and improve image quality

## Limitations
- Only supports spheres and ground plane (no triangle meshes)
- No acceleration structures (BVH, KD-tree)
- Performance may vary depending on browser and hardware

## Credits
- Based on [Ray Tracing in One Weekend](https://raytracing.github.io/books/RayTracingInOneWeekend.html) by Peter Shirley
- WebGPU and WGSL documentation
- dat.gui for UI controls

## License
MIT
