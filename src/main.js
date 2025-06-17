import Engine from './engine/engine.js';
import RenderPipelineBuilder from './engine/renderPipeline.js';
import rayTracer from './shaders/raytracer.wgsl?raw';

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

  const uniformsData = new Float32Array([
    canvas.width,
    canvas.height, 
    0.0,// time
    0.0 // padding
  ]
); 
  const uniformsBuffer = device.createBuffer({
    size: uniformsData.byteLength,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });
  device.queue.writeBuffer(uniformsBuffer, 0, uniformsData);

 
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

   function animate() {
    const currentTime = performance.now() / 1000;
    
    // Update time at offset 8 (third float)
    device.queue.writeBuffer(uniformsBuffer, 8, new Float32Array([currentTime]));
    
    // Recreate bind group (or create once outside loop)
    const bindGroup = device.createBindGroup({
        layout: bindGroupLayout,
        entries: [{
            binding: 0,
            resource: { buffer: uniformsBuffer }
        }]
    });
    
    const commandBuffer = engine.encodeRenderPass(6, renderPipeline, vertexBuffer, bindGroup);
    engine.submitCommand(commandBuffer);
    
    requestAnimationFrame(animate);
}

 requestAnimationFrame(animate); 
}

webgpu(); 
