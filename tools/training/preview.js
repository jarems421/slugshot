import * as THREE from 'three';
import {GLTFLoader} from './vendor/GLTFLoader.js';
import {OrbitControls} from './vendor/OrbitControls.js';

const status=document.querySelector('#status'), loading=document.querySelector('#loading');
const stage=document.querySelector('#stage'), fallback=document.querySelector('#fallback');
let scene, camera, renderer, controls, asset, room=[], active='island', rotating=false;
let dummySpeed=7,dummyPhase=0,lastTime=0,mover=[];
const speedInput=document.querySelector('#speed'),speedLabel=document.querySelector('#speedLabel');
function setSpeed(speed){dummySpeed=Math.max(0,Math.min(20,Number(speed)||0));speedInput.value=String(dummySpeed);speedLabel.textContent=dummySpeed===0?'Stationary':`${dummySpeed} studs/s`;}
speedInput.addEventListener('input',()=>setSpeed(speedInput.value));
document.querySelector('#stationary').onclick=()=>setSpeed(0);
function moveDummy(dt){dummyPhase+=dt*dummySpeed/10;for(const {object,x} of mover)object.position.x=x+Math.sin(dummyPhase)*10;}
const views={
  island:{eye:[210,180,290],target:[0,-12,0],fov:40},
  above:{eye:[0,285,65],target:[0,0,0],fov:40},
  underside:{eye:[210,-65,270],target:[0,-34,0],fov:40},
  inside:{eye:[3,8,76],target:[2,7,-30],fov:70},
  room:{eye:[680,430,710],target:[0,-10,0],fov:45}
};
function visibility(){
  if(!asset)return;
  const view=active;
  for(const o of room){
    if(view==='inside')o.visible=true;
    else if(view!=='room')o.visible=false;
    else if(o.name.includes('Ceiling')||o.name.includes('Bottom'))o.visible=false;
    else {
      const p=new THREE.Vector3();o.getWorldPosition(p);
      o.visible=p.x*camera.position.x+p.z*camera.position.z<0;
    }
  }
}
function setView(name){
  active=name;
  document.querySelectorAll('[data-view]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.view===name)));
  if(renderer){
    const v=views[name];camera.position.fromArray(v.eye);camera.fov=v.fov;camera.updateProjectionMatrix();controls.target.fromArray(v.target);controls.update();visibility();
    scene.fog=name==='inside'?new THREE.Fog(0x26343a,180,820):null;
  }else{
    fallback.src=`${name==='room'?'island':name}.png`;fallback.style.display='block';
  }
}
document.querySelectorAll('[data-view]').forEach(b=>b.addEventListener('click',()=>setView(b.dataset.view)));
document.querySelector('#reset').onclick=()=>{rotating=false;if(controls)controls.autoRotate=false;document.querySelector('#rotate').setAttribute('aria-pressed','false');setView('island');};
document.querySelector('#rotate').onclick=()=>{rotating=!rotating;if(controls)controls.autoRotate=rotating;document.querySelector('#rotate').setAttribute('aria-pressed',String(rotating));};
function useFallback(message){
  renderer?.dispose();renderer=null;stage.replaceChildren();loading.style.display='none';fallback.style.display='block';fallback.src='island.png';status.textContent='Rendered review';document.querySelector('#error').textContent=message;
  document.querySelector('#rotate').disabled=true;window.trainingReview={mode:'rendered',setView};
}
async function init(){
  try{
    renderer=new THREE.WebGLRenderer({antialias:true,alpha:false});renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.setSize(innerWidth,innerHeight);renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.1;
    renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;stage.appendChild(renderer.domElement);
    scene=new THREE.Scene();scene.background=new THREE.Color(0x17232b);camera=new THREE.PerspectiveCamera(40,innerWidth/innerHeight,0.2,2500);
    scene.add(new THREE.HemisphereLight(0xd4e4ec,0x34454c,2.0));
    const sun=new THREE.DirectionalLight(0xffead0,3.0);sun.position.set(-80,170,110);sun.castShadow=true;sun.shadow.mapSize.set(2048,2048);Object.assign(sun.shadow.camera,{left:-130,right:130,top:130,bottom:-130,near:1,far:500});sun.shadow.bias=-0.0003;sun.shadow.normalBias=0.2;scene.add(sun);
    const fill=new THREE.DirectionalLight(0xb9e1e7,1.2);fill.position.set(100,40,-80);scene.add(fill);
    const lower=new THREE.DirectionalLight(0xa3b7c4,0.8);lower.position.set(60,-90,40);scene.add(lower);
    controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.dampingFactor=0.08;controls.minDistance=5;controls.maxDistance=1400;controls.autoRotateSpeed=0.45;
    const gltf=await new GLTFLoader().loadAsync('./slugshot-training-arena.glb',e=>{if(e.total)status.textContent=`Loading ${Math.round(e.loaded/e.total*100)}%`;});
    asset=gltf.scene;scene.add(asset);let objects=0,triangles=0;
    asset.traverse(o=>{if(o.name.startsWith('ROOM_'))room.push(o);if(o.isMesh){objects++;triangles+=(o.geometry.index?.count??o.geometry.attributes.position.count)/3;o.castShadow=!o.name.includes('_Ink')&&!o.name.startsWith('ROOM_');o.receiveShadow=!o.name.includes('_Ink');if(o.name.startsWith('TARGET_STRAFE_'))mover.push({object:o,x:o.position.x});}});
    loading.style.display='none';status.textContent='Ready to inspect';setView('island');
    window.trainingReview={mode:'webgl',setView,setSpeed,stats:{objects,triangles},get speed(){return dummySpeed},get moverX(){return mover[0]?.object.position.x},get active(){return active},get roomVisible(){return room.filter(o=>o.visible).length},camera,controls};
    renderer.setAnimationLoop(time=>{const dt=lastTime?Math.min((time-lastTime)/1000,0.1):0;lastTime=time;moveDummy(dt);controls.update();if(active==='room')visibility();renderer.render(scene,camera);});
    addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight);});
  }catch(error){console.warn('Training preview:',error);useFallback('This browser could not open the interactive view. The rendered angles and downloadable 3D asset are available.');}
}
init();
