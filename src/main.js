import Engine from './engine/engine.js';
import RenderPipelineBuilder from './engine/renderPipeline.js';
import quadShaderCode from './shaders/quad.wgsl?raw';
import rayTracer from './shaders/rayTracer.wgsl?raw';

export default async function webgpu() {
  const canvas = document.querySelector('canvas');
  const engine  = await Engine.initialize(canvas);
  const device = engine.device;

  // Set the canvas size to match the window size and device pixel ratio
  // This ensures that the canvas is rendered at the correct resolution
  const devicePixelRatio = window.devicePixelRatio || 1;
  canvas.width = window.innerWidth * devicePixelRatio;
  canvas.height = window.innerHeight * devicePixelRatio ;

  canvas.style.width = `${window.innerWidth}px`;
  canvas.style.height = `${window.innerHeight}px`;

  const vertexData = new Float32Array([
    // x,    y
    -1.0, -1.0, // bottom left
     1.0, -1.0, // bottom right
    -1.0,  1.0, // top left
    -1.0,  1.0, // top left
     1.0, -1.0, // bottom right
     1.0,  1.0  // top right
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

  const canvasSize = new Float32Array([
    canvas.width,
    canvas.height
  ]); 
  const canvasSizeBuffer = device.createBuffer({
    size: canvasSize.byteLength,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });
  device.queue.writeBuffer(canvasSizeBuffer, 0, canvasSize);

  const timeData = new Float32Array([0.0]);
  const timeBuffer = device.createBuffer({
    size: 16,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
  });
  device.queue.writeBuffer(timeBuffer, 0, timeData);
 
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

  // Create the bind group
  let bindGroup = device.createBindGroup({
      layout: bindGroupLayout,
      entries: [
        { binding: 0, resource: { buffer: canvasSizeBuffer }}, 
        { binding: 1, resource: { buffer: timeBuffer }},
      ]
  });

  function render(currentTime) {
    // Update the time uniform
    timeData[0] = currentTime * 0.001;
    device.queue.writeBuffer(timeBuffer, 0, timeData);
    const commandBuffer = engine.encodeRenderPass(6, renderPipeline, vertexBuffer, bindGroup);
    engine.submitCommand(commandBuffer);
    requestAnimationFrame(render);
  }
  requestAnimationFrame(render);
}

webgpu(); 
