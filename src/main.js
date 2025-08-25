import Engine from './engine/engine.js';
import RenderPipelineBuilder from './engine/renderPipeline.js';
import quadShaderCode from './shaders/quad.wgsl?raw';
import rayTracer from './shaders/rayTracer.wgsl?raw';
import { Hittable } from './hittables.js';
import * as dat from 'dat.gui'

export default async function webgpu() {
  const canvas = document.querySelector('canvas');
  const engine  = await Engine.initialize(canvas);
  const device = engine.device;

  // Set the canvas size to match the window size and device pixel ratio
  const devicePixelRatio = window.devicePixelRatio || 1;
  canvas.width = window.innerWidth * devicePixelRatio;
  canvas.height = window.innerHeight * devicePixelRatio ;

  canvas.style.width = `${window.innerWidth}px`;
  canvas.style.height = `${window.innerHeight}px`;

  const vertexData = new Float32Array([
    -1.0, -1.0, 
     1.0, -1.0, 
    -1.0,  1.0, 
    -1.0,  1.0, 
     1.0, -1.0, 
     1.0,  1.0 
  ]);

  const vertexBuffer = device.createBuffer({
    size: vertexData.byteLength,
    usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
  });

  device.queue.writeBuffer(vertexBuffer, 0, vertexData);
  const bufferLayout = {
    arrayStride: 2 * 4,
    attributes: [
      { shaderLocation:0 , offset:0, format: 'float32x2'}
    ]
  };

  const canvasSize = new Float32Array([canvas.width, canvas.height]); 
  const canvasSizeBuffer = device.createBuffer({
    size: canvasSize.byteLength,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });
  device.queue.writeBuffer(canvasSizeBuffer, 0, canvasSize);

  const debugBuffer = device.createBuffer({
    size: 16,
    usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
  });
  device.queue.writeBuffer(debugBuffer, 0, new Float32Array([0.0, 0.0, 0.0]));

  const spheres = [
    new Hittable([0.0, 0.0, -6.0, 0.0], 1.0, 1.0, [1.0, 0.6, 0.2, 0.0], 0.03),
    new Hittable([2.0, 0.0, -7.0, 0.0], 0.5, 1.0, [1.0, 1.0, 1.0, 0.0], 0.3),
    new Hittable([-2.0, 0.0, -8.0, 0.0], 0.5, 1.0, [0.8, 0.8, 1.0, 0.0], 0.1),
     new Hittable([0.0, 100.5, -6.0, 0.0], 100.0, 2.0, [0.5, 0.8, 0.3, 0.0], 0.0)
  ];

  const hittablesBuffer = device.createBuffer({
    size: 256,
    usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
  });

  const hittablesCountBuffer = device.createBuffer({
    size: 4,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
  });
  device.queue.writeBuffer(hittablesCountBuffer, 0, new Int32Array([4]));

  const shaderModule = device.createShaderModule({
    code: rayTracer
  })

  const pipelineBuilder = new RenderPipelineBuilder(device);
  const renderPipeline = pipelineBuilder
    .setShaderModule(shaderModule)
    .setVertexBuffers([bufferLayout])
    .setTargetFormats([engine.canvasFormat])
    .setPrimitive("triangle-list")
    .build()

  const bindGroupLayout = renderPipeline.getBindGroupLayout(0);

  let bindGroup = device.createBindGroup({
      layout: bindGroupLayout,
      entries: [
        { binding: 0, resource: { buffer: canvasSizeBuffer }}, 
        { binding: 1, resource: { buffer: hittablesBuffer}},
        { binding: 2, resource: { buffer: hittablesCountBuffer }}
      ]
  });

  // Function to update spheres and re-render
  function updateAndRender() {
    const allData = spheres.flatMap(sphere => sphere.arrayFormat);
    const hittablesData = new Float32Array(allData);
    device.queue.writeBuffer(hittablesBuffer, 0, hittablesData);
    
    const commandBuffer = engine.encodeRenderPass(6, renderPipeline, vertexBuffer, bindGroup);
    engine.submitCommand(commandBuffer);
  }

  // Set up dat.gui controls
  const gui = new dat.GUI();
  
  // Create control objects for each sphere
  const sphere1Controls = {
    red: spheres[0].albedo[0],
    green: spheres[0].albedo[1], 
    blue: spheres[0].albedo[2],
    fuzz: spheres[0].fuzz,
    radius: spheres[0].radius
  };

  const sphere2Controls = {
    red: spheres[1].albedo[0],
    green: spheres[1].albedo[1],
    blue: spheres[1].albedo[2], 
    fuzz: spheres[1].fuzz,
    radius: spheres[1].radius
  };

  const sphere3Controls = {
    red: spheres[2].albedo[0],
    green: spheres[2].albedo[1],
    blue: spheres[2].albedo[2],
    fuzz: spheres[2].fuzz,
    radius: spheres[2].radius
  };

  // Sphere 1 folder (Gold)
  const sphere1Folder = gui.addFolder('Sphere 1 (Gold)');
  sphere1Folder.add(sphere1Controls, 'red', 0, 1, 0.01).onChange((value) => {
    spheres[0].albedo[0] = value;
    updateAndRender();
  });
  sphere1Folder.add(sphere1Controls, 'green', 0, 1, 0.01).onChange((value) => {
    spheres[0].albedo[1] = value;
    updateAndRender();
  });
  sphere1Folder.add(sphere1Controls, 'blue', 0, 1, 0.01).onChange((value) => {
    spheres[0].albedo[2] = value;
    updateAndRender();
  });
  sphere1Folder.add(sphere1Controls, 'fuzz', 0, 1, 0.01).onChange((value) => {
    spheres[0].fuzz = value;
    updateAndRender();
  });
  sphere1Folder.add(sphere1Controls, 'radius', 0.1, 2, 0.1).onChange((value) => {
    spheres[0].radius = value;
    updateAndRender();
  });
  sphere1Folder.open();

  // Sphere 2 folder (Silver)
  const sphere2Folder = gui.addFolder('Sphere 2 (Silver)');
  sphere2Folder.add(sphere2Controls, 'red', 0, 1, 0.01).onChange((value) => {
    spheres[1].albedo[0] = value;
    updateAndRender();
  });
  sphere2Folder.add(sphere2Controls, 'green', 0, 1, 0.01).onChange((value) => {
    spheres[1].albedo[1] = value;
    updateAndRender();
  });
  sphere2Folder.add(sphere2Controls, 'blue', 0, 1, 0.01).onChange((value) => {
    spheres[1].albedo[2] = value;
    updateAndRender();
  });
  sphere2Folder.add(sphere2Controls, 'fuzz', 0, 1, 0.01).onChange((value) => {
    spheres[1].fuzz = value;
    updateAndRender();
  });
  sphere2Folder.add(sphere2Controls, 'radius', 0.1, 2, 0.1).onChange((value) => {
    spheres[1].radius = value;
    updateAndRender();
  });

  // Sphere 3 folder (Blue)
  const sphere3Folder = gui.addFolder('Sphere 3 (Blue)');
  sphere3Folder.add(sphere3Controls, 'red', 0, 1, 0.01).onChange((value) => {
    spheres[2].albedo[0] = value;
    updateAndRender();
  });
  sphere3Folder.add(sphere3Controls, 'green', 0, 1, 0.01).onChange((value) => {
    spheres[2].albedo[1] = value;
    updateAndRender();
  });
  sphere3Folder.add(sphere3Controls, 'blue', 0, 1, 0.01).onChange((value) => {
    spheres[2].albedo[2] = value;
    updateAndRender();
  });
  sphere3Folder.add(sphere3Controls, 'fuzz', 0, 1, 0.01).onChange((value) => {
    spheres[2].fuzz = value;
    updateAndRender();
  });
  sphere3Folder.add(sphere3Controls, 'radius', 0.1, 2, 0.1).onChange((value) => {
    spheres[2].radius = value;
    updateAndRender();
  });
  // Initial render
  updateAndRender();
}

webgpu();