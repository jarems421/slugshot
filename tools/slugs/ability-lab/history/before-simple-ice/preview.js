import * as T from 'three';
import {GLTFLoader} from './vendor/loaders/GLTFLoader.js';
import {waterConcepts,createWaterStudy} from './impact-studies.js';
import {webConcepts,createWebStudy} from './web-studies.js';
import {frostConcepts,createFrostStudy} from './frost-studies.js';

const concepts = [
 {name:'Backdraft',role:'DISPLACEMENT / SETUP',short:'Win the angle, move the fight.',tagline:'A compressed blast that carries the direction of your shot.',impact:'The hit burns the opponent and compresses a flame bell at the contact point. After a readable delay it vents along the incoming shot direction, dealing a fire burst and pushing anyone still in its narrow cone.',clever:'Shoot from the side to dislodge a defender from cover, push an airborne opponent away from a landing, or line up a follow-up for a teammate. Position determines the shove.',answer:'The compressed core is the warning. Sidestep or dash out of the marked cone before it vents. Solid cover blocks the blast; it does not ricochet around corners.',visual:'A tight amber bell draws inward, then snaps into one broad flame tongue. A faint ground wedge previews its direction.',choice:'Hold position, or leave the blast line?',use:'The opponent stays in the cone. The delayed vent pushes them out of their protected position.',counter:'The opponent sees the amber compression and steps sideways. The jet vents down the original line and misses.',beats:['Pick a shot direction that matters.','Inferno expands and banks into the approach.','Impact compresses the flame: a visible warning.','The stored pressure vents along the shot direction.'],counterbeat:'The opponent leaves the cone before the pressure releases.',pairing:'Confirmed core: impact burn plus a delayed, shot-directed vent. Pushing opponents into another slug’s hazard is a possible chain; the other slugs’ kits remain unselected.',confirmed:true,slug:'inferno',kind:'main'},
 ...[[0,1],[2,3],[6,7]].map(([i,renderIndex])=>({...waterConcepts[i],renderIndex,confirmed:true})),
 ...webConcepts,
 ...frostConcepts
];
const $=s=>document.querySelector(s), clamp=T.MathUtils.clamp;
const smooth=x=>{x=clamp(x,0,1);return x*x*(3-2*x);};
const mix=T.MathUtils.lerp, TAU=Math.PI*2;
const state={index:9,surface:'floor',chain:false,time:0,playing:!matchMedia('(prefers-reduced-motion: reduce)').matches,speed:1,counter:false,overhead:false,yaw:.20,pitch:.55,zoom:1};
const errors=[];window.addEventListener('error',e=>errors.push(e.message));window.addEventListener('unhandledrejection',e=>errors.push(String(e.reason)));
const canvas=$('#scene'), renderer=new T.WebGLRenderer({canvas,antialias:true,alpha:true,preserveDrawingBuffer:true});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.6));renderer.outputColorSpace=T.SRGBColorSpace;renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.15;
const scene=new T.Scene(), camera=new T.PerspectiveCamera(37,1,.1,120);
scene.add(new T.HemisphereLight(0xc5d7ed,0x33303b,2.1));
const key=new T.DirectionalLight(0xffdfb2,3.1);key.position.set(-2,7,5);scene.add(key);
const rim=new T.DirectionalLight(0x7ea9d4,2.7);rim.position.set(4,5,-5);scene.add(rim);
const ink=new T.MeshBasicMaterial({color:0x171821,side:T.BackSide});
const mat=(color,roughness=.65)=>new T.MeshStandardMaterial({color,roughness,metalness:.04});
const stone=mat(0x3e4b57), stone2=mat(0x4a5761), warm=mat(0xe9ad67), blue=mat(0x607c95), teal=mat(0x6eafaa);
function mesh(geometry,material,parent,outline=false){const m=new T.Mesh(geometry,material);parent.add(m);if(outline){const h=new T.Mesh(geometry,ink);h.scale.setScalar(1.045);m.add(h);}return m;}
function box(parent,x,y,z,w,h,d,material=stone,outline=true){const b=mesh(new T.BoxGeometry(w,h,d),material,parent,outline);b.position.set(x,y,z);return b;}
function line(parent,points,color=0xffc67a,radius=.018){const c=new T.CatmullRomCurve3(points.map(p=>new T.Vector3(...p)));return mesh(new T.TubeGeometry(c,Math.max(12,points.length*6),radius,5,false),new T.MeshBasicMaterial({color}),parent);}
function label(text,color='#b6c3cd',scale=1.8){const c=document.createElement('canvas');c.width=512;c.height=80;const x=c.getContext('2d');x.font='600 25px Segoe UI';x.textAlign='center';x.fillStyle=color;x.fillText(text,256,45);const m=new T.SpriteMaterial({map:new T.CanvasTexture(c),transparent:true,depthTest:false});const s=new T.Sprite(m);s.scale.set(scale,scale*.156,1);return s;}
const arena=new T.Group();scene.add(arena);
box(arena,0,-.24,0,14,.42,8.5,mat(0x273640));
for(let x=-6;x<=6;x+=2)for(let z=-3;z<=3;z+=2)box(arena,x,-.018,z,1.975,.035,1.975,(x+z)%4?stone:stone2,false);
for(let i=0;i<7;i++){const x=-6.5+i*2.15;box(arena,x,-.10,-4.25,1.9,.3,.20,mat(0x172530));}
const shootingLine=line(arena,[[-6.4,.02,0],[-3.8,.02,0]],0x82949e,.014);shootingLine.material.transparent=true;shootingLine.material.opacity=.42;
const originLabel=label('SHOT LINE','#a1b0bb',1.45);originLabel.position.set(-5.6,.12,1.3);scene.add(originLabel);
function person(color=blue){const g=new T.Group();scene.add(g);const parts=[];const p=(x,y,z,w,h,d,m)=>{const b=box(g,x,y,z,w,h,d,m);parts.push(b);return b;};
 p(0,1.03,0,.50,.64,.32,color);p(0,.73,0,.46,.15,.34,mat(0x283340));
 const head=mesh(new T.SphereGeometry(.23,16,12),color,g,true);head.position.y=1.58;
 const visor=box(g,0,1.6,.205,.31,.09,.04,warm,false);
 const arms=[p(-.36,1.02,0,.18,.61,.22,color),p(.36,1.02,0,.18,.61,.22,color)];
 const legs=[p(-.15,.35,0,.2,.62,.25,color),p(.15,.35,0,.2,.62,.25,color)];
 g.userData={arms,legs,phase:0};return g;}
const defender=person(), ally=person(teal), secondary=person(mat(0x8c7184));
const targetLabel=label('OPPONENT','#c4c9cc');scene.add(targetLabel);
const allyLabel=label('TEAMMATE','#a1d5c5');scene.add(allyLabel);
const secondaryLabel=label('SECOND OPPONENT','#b6a6bb',2.3);scene.add(secondaryLabel);
const targetMarker=mesh(new T.RingGeometry(.42,.46,48),new T.MeshBasicMaterial({color:0xd6a475,side:T.DoubleSide,transparent:true,opacity:.45}),scene);targetMarker.rotation.x=-Math.PI/2;targetMarker.position.y=.027;
const cover=new T.Group();scene.add(cover);const creases=[];
const wallA=box(cover,1.10,1,-1.05,.62,2.0,2.10),wallB=box(cover,1.10,1,1,.62,2.0,2.0);
for(const z of [-1.5,-.9,-.3,.35,1,1.65]){const crease=line(cover,[[.775,.20,z],[.775,.8,z+.14],[.775,1.3,z-.1]],0x26323b,.012);creases.push({crease,second:z>0});}
const coverLabel=label('CONNECTED DRY COVER','#b3c1c9',2.9);coverLabel.position.set(1.15,2.5,-.2);cover.add(coverLabel);
const backCover=box(scene,1.5,1.02,-.85,2.0,2.04,.50,mat(0x36424e));
const effects=new T.Group();scene.add(effects);
const fx={};
function effect(name){const g=new T.Group();effects.add(g);fx[name]=g;return g;}
function tubeGeometry(n=42,k=16){const g=new T.BufferGeometry(),p=new Float32Array((n+1)*(k+1)*3),cols=new Float32Array(p.length),ix=[];for(let i=0;i<n;i++)for(let j=0;j<k;j++){const a=i*(k+1)+j,b=a+k+1;ix.push(a,a+1,b,b,a+1,b+1);}g.setIndex(ix);g.setAttribute('position',new T.BufferAttribute(p,3));g.setAttribute('color',new T.BufferAttribute(cols,3));return g;}
const flameInk=new T.MeshBasicMaterial({color:0x50241e,side:T.BackSide});flameInk.onBeforeCompile=shader=>{shader.vertexShader=shader.vertexShader.replace('#include <begin_vertex>','vec3 transformed = vec3(position + normal * 0.018);');};
function flow(parent,{radius=.3,color=0xff8937,inner=true}={}){const group=new T.Group();parent.add(group);const g=tubeGeometry();const material=new T.MeshStandardMaterial({color:0xffffff,emissive:0xa72c08,emissiveIntensity:.22,roughness:.8,vertexColors:true,side:T.FrontSide});const outside=mesh(g,material,group);mesh(g,flameInk,group);let inside=null;if(inner){inside=mesh(tubeGeometry(),new T.MeshBasicMaterial({color:0xffd275,vertexColors:true,side:T.DoubleSide}),group);}group.userData={g,inside,radius};return group;}
function deformFlow(flowObject,points,progress,t,width=1){const {g,inside,radius}=flowObject.userData;const curve=new T.CatmullRomCurve3(points.map(p=>new T.Vector3(...p)));const end=Math.max(.005,clamp(progress,0,1));
 const apply=(geometry,core)=>{const p=geometry.attributes.position,c=geometry.attributes.color;const a=new T.Vector3(),tangent=new T.Vector3(),normal=new T.Vector3(),binormal=new T.Vector3();for(let i=0;i<=42;i++){const u=i/42,v=u*end;curve.getPoint(v,a);curve.getTangent(v,tangent);normal.crossVectors(tangent,new T.Vector3(0,1,0));if(normal.lengthSq()<.01)normal.crossVectors(tangent,new T.Vector3(0,0,1));normal.normalize();binormal.crossVectors(tangent,normal).normalize();const r=radius*width*(core?.48:1)*Math.pow(Math.max(.0001,Math.sin(Math.PI*u)),.55)*(1-.35*u);for(let j=0;j<=16;j++){const angle=j/16*TAU;const ripple=1+.13*Math.sin(u*24-t*7+angle*3)+.055*Math.sin(u*39-t*9-angle*2),o=(i*17+j);const q=a.clone().addScaledVector(normal,Math.cos(angle)*r*ripple).addScaledVector(binormal,Math.sin(angle)*r*ripple);p.setXYZ(o,q.x,q.y,q.z);const band=Math.sin(angle+.25*Math.sin(u*12-t*5));const bright=band>.50?1:band>-.35?.48:.12;const heat=core?.92:bright*(1-.35*u);c.setXYZ(o,1,mix(.055,.72,heat),mix(.012,.20,heat));} }p.needsUpdate=true;c.needsUpdate=true;geometry.computeVertexNormals();geometry.computeBoundingSphere();};apply(g,false);if(inside)apply(inside.geometry,true);}
const wake=effect('wake');wake.userData.flow=flow(wake,{radius:.27});
const brand=effect('brand');brand.userData.flow=flow(brand,{radius:.24});
const draft=effect('draft');draft.userData.flow=flow(draft,{radius:.65});
const bell=effect('bell');bell.userData.flow=flow(bell,{radius:.45});
const surface=effect('surface');surface.userData.flow=flow(surface,{radius:.19});
const flare=effect('flare');flare.userData.flow=flow(flare,{radius:.48});
const vent=effect('vent');vent.userData.flow=flow(vent,{radius:.50});
const impact=effect('impact');impact.userData.flow=flow(impact,{radius:.54});
const transformGlow=mesh(new T.SphereGeometry(1,24,16),new T.MeshBasicMaterial({color:0xffc17d,transparent:true,opacity:0,depthWrite:false}),scene);
const wedge=effect('wedge');const ws=new T.Shape();ws.moveTo(0,0);ws.lineTo(3.4,-.73);ws.lineTo(3.4,.73);ws.closePath();const wm=mesh(new T.ShapeGeometry(ws),new T.MeshBasicMaterial({color:0xf8b45c,transparent:true,opacity:.15,side:T.DoubleSide,depthWrite:false}),wedge);wm.rotation.x=-Math.PI/2;wedge.position.set(1.4,.035,0);
line(wedge,[[0,0,0],[3.4,0,.73]],0xb99563,.014);line(wedge,[[0,0,0],[3.4,0,-.73]],0xb99563,.014);
const shell=effect('shell');const shellMat=new T.MeshPhysicalMaterial({color:0x985328,emissive:0xff932a,emissiveIntensity:.42,roughness:.32,metalness:.15,side:T.DoubleSide,transparent:true,opacity:.92});const shellMesh=mesh(new T.SphereGeometry(.83,28,20,0,Math.PI,.14,Math.PI-.28),shellMat,shell);shellMesh.scale.set(1,1.18,.50);shellMesh.rotation.y=Math.PI/2;shell.position.set(1.4,1.0,0);
line(shell,[[.10,-.55,.18],[.36,-.18,.22],[.37,.1,.22],[.17,.55,.2]],0xffd087,.024);
const ash=effect('ash');const ashG=new T.SphereGeometry(1,48,32);const ashRest=new Float32Array(ashG.attributes.position.array);const ashMaterial=new T.MeshStandardMaterial({color:0x555660,roughness:1,vertexColors:true,transparent:true,opacity:.94});const ashMesh=mesh(ashG,ashMaterial,ash);ashG.setAttribute('color',new T.BufferAttribute(new Float32Array(ashRest.length),3));
const ashRim=mesh(new T.SphereGeometry(1,32,24),new T.MeshBasicMaterial({color:0xd78948,side:T.BackSide,transparent:true,opacity:.18,depthWrite:false}),ashMesh);ashRim.scale.setScalar(1.025);
const flashLight=new T.PointLight(0xff862b,0,8,2);scene.add(flashLight);
const loader=new GLTFLoader();
let base,dragon,dragonBones=[];
try{const loaded=await Promise.all([loader.loadAsync('./inferno-base.glb'),loader.loadAsync('./inferno-dragon.glb')]);
 [base,dragon]=loaded.map((asset,index)=>{const outer=new T.Group(),model=asset.scene;outer.add(model);scene.add(outer);model.updateMatrixWorld(true);const bounds=new T.Box3().setFromObject(model),center=bounds.getCenter(new T.Vector3());model.position.sub(center);outer.rotation.y=-Math.PI/2;model.traverse(o=>{if(o.isMesh){o.frustumCulled=false;o.material=o.material.clone();if(o.name.endsWith('MouthLine'))o.visible=false;if(o.material.emissive)o.material.emissiveIntensity=.15;}});return outer;});
 dragon.traverse(o=>{if(o.isBone&&/wing|tail/i.test(o.name))dragonBones.push({node:o,q:o.quaternion.clone(),name:o.name});});
 $('#loading').hidden=true;
}catch(e){$('#loading').textContent='The 3D models could not load.';throw e;}
function walk(g,amount,t){for(let i=0;i<2;i++){g.userData.legs[i].rotation.x=Math.sin(t*9+i*Math.PI)*.42*amount;g.userData.arms[i].rotation.x=-Math.sin(t*9+i*Math.PI)*.38*amount;}}
function setOpacity(group,opacity){group.traverse(o=>{if(o.isMesh&&o.material!==ink){o.material.transparent=opacity<1;o.material.opacity=opacity;}});}
function phaseText(t){const c=concepts[state.index];let phase=t<.65?0:t<3?1:t<3.5?2:3;const flight=t>=1.6&&t<3;const titles=['Shoot.','Spin. Transform.','Impact. Activate.',c.short];if(flight)titles[1]='Big form. Closing in.';if(phase===3&&state.counter)titles[3]='A different decision.';$('#beat-kicker').textContent=flight?'02 / FLIGHT':`0${phase+1} / ${['SHOOT','TRANSFORM','IMPACT','AFTERMATH'][phase]}`;$('#beat-title').textContent=titles[phase];$('#beat-copy').textContent=flight?'The ability waits for contact. Flight alone does not activate it.':phase===3&&state.counter?c.counterbeat:c.beats[phase];if(state.chain&&state.index>0&&t>(c.chainAt??5.35)&&!state.counter){$('#beat-kicker').textContent='05 / PROPOSED FOLLOW-UP';$('#beat-title').textContent=c.chainTitle;$('#beat-copy').textContent=c.chainText;}}
function render(t=state.time){state.time=t;const aquatic=concepts[state.index].slug!=='inferno',n=state.index===0?1:-1,ct=state.counter,after=Math.max(0,t-3),hit=smooth((t-2.94)/.12),endFade=1-smooth((t-7.15)/.65);
 for(const f of Object.values(fx))f.visible=false;cover.visible=n===2;backCover.visible=n===1;secondary.visible=n===0;secondaryLabel.visible=n===0;
 defender.visible=n!==3;ally.visible=n===3||n===4;targetLabel.visible=n!==3;allyLabel.visible=ally.visible&&concepts[state.index].slug!=='arachnet';
 defender.position.set(n===2?1.9:1.4,0,n===2?1.45:0);defender.rotation.set(0,0,0);ally.position.set(n===3?1.4:-2.7,0,n===3?0:2);ally.rotation.set(0,Math.PI/2,0);secondary.position.set(3.9,0,-2.1);secondary.rotation.y=-Math.PI/2;
 walk(defender,0,t);walk(ally,0,t);walk(secondary,0,t);wallB.position.z=ct&&n===2?1.95:1;for(const {crease,second} of creases)crease.position.z=ct&&n===2&&second?.95:0;coverLabel.material.map.needsUpdate=false;
 if(n===0){const moved=smooth(after/(ct?1.6:3.1));defender.position.x=1.4+moved*(ct?1.55:3.7);defender.position.z=moved*(ct?-.8:1.0);if(ct)defender.position.y=Math.sin(Math.PI*clamp((after-.3)/1.3,0,1))*.95;walk(defender,t>3&&after<(ct?1.7:3.2)?1:0,t);secondary.position.z=mix(-2.1,.9,smooth((after-.2)/3));walk(secondary,after>0&&after<3.2?1:0,t);
  const brandLife=hit*endFade*(ct?1-smooth((after-1.6)/.8):1);brand.visible=brandLife>.01;const p=defender.position;deformFlow(brand.userData.flow,[[p.x-.13,p.y+1.25,p.z],[p.x+.1,p.y+1.7,p.z],[p.x+.2,p.y+1.92,p.z-.03]],1,t,brandLife);
  wake.visible=after>.12&&(!ct||after<2.3);const pts=ct?[[1.4,.12,0],[1.48,.13,-.02],[1.7,.13,-.10]]:[[1.4,.12,0],[1.8,.14,-.1],[2.7,.13,.20],[3.7,.14,.5],[4.9,.14,.95]];deformFlow(wake.userData.flow,pts,ct?.95:smooth(after/3.1),t,ct?1-smooth((after-1.6)/.7):endFade);
 }
 if(n===1){const ventTime=after-.8;if(ct)defender.position.z=-1.75*smooth((after-.15)/.58);else defender.position.x+=2.4*smooth(ventTime/.65);walk(defender,ct&&after>.1&&after<.9?1:0,t);if(!ct)defender.rotation.z=-.17*Math.sin(Math.PI*clamp(ventTime/1.1,0,1));
  const burnLife=hit*(1-smooth((after-2.4)/.6));brand.visible=burnLife>.01;const bp=defender.position;deformFlow(brand.userData.flow,[[bp.x-.1,bp.y+1.1,bp.z],[bp.x,bp.y+1.5,bp.z],[bp.x+.1,bp.y+1.72,bp.z]],1,t,.65*burnLife);
  wedge.visible=after>0&&after<2.2;bell.visible=after>0&&after<1.0;deformFlow(bell.userData.flow,[[.72,1.0,0],[1.12,1.05,0],[1.5,1.05,0]],1,t,.9+.14*Math.sin(after*7));draft.visible=ventTime>0&&ventTime<1.4;deformFlow(draft.userData.flow,[[1.25,1.1,0],[2.6,1.2,0],[4.35,1.0,0]],smooth(ventTime/.35),t,(1-smooth((ventTime-.65)/.75))*(.8+.4*smooth(ventTime/.3)));
 }
 if(n===2){surface.visible=after>0;const path=ct?[[.765,.75,-.35],[.765,.7,-.16],[.765,.55,-.01]]:[[.765,.75,-.35],[.765,.65,.7],[.765,.52,1.98],[1.1,.50,2.055],[1.435,.52,1.98],[1.435,.60,1.45]];deformFlow(surface.userData.flow,path,smooth(after/2.6),t,endFade*(ct?1-smooth((after-1.5)/1):1));flare.visible=!ct&&after>2.25;deformFlow(flare.userData.flow,[[1.44,.55,1.45],[1.75,1.1,1.45],[2.05,1.85,1.45]],smooth((after-2.25)/.5),t,endFade);if(!ct&&after>2.6)defender.position.z+=.65*smooth((after-2.6)/.7);
 }
 if(n===3){shell.visible=after>0&&after<(ct?3.8:1.8);shell.scale.setScalar(smooth(after/.4)*(ct?1-smooth((after-2.8)/1):1-smooth((after-1.45)/.35)));shell.position.set(1.4,1.0,0);shellMesh.rotation.y=-Math.PI/2;ally.rotation.y=-Math.PI/2;
  if(after>1.05&&after<1.7){const u=clamp((after-1.05)/.65,0,1);incoming.visible=true;incoming.position.set(ct?mix(5,1.4,u):mix(-2.4,1.0,u),1.12,0);}else incoming.visible=false;
  vent.visible=!ct&&after>1.68&&after<3.15;deformFlow(vent.userData.flow,[[.99,1.12,0],[-.1,1.1,0],[-1.65,.9,0]],smooth((after-1.68)/.36),t,1-smooth((after-2.5)/.65));attacker.visible=true;attacker.position.set(ct?4.9:-2.8,0,0);attacker.rotation.y=ct?-Math.PI/2:Math.PI/2;attackerLabel.visible=true;attackerLabel.position.copy(attacker.position).add(new T.Vector3(0,2.15,0));if(ct&&after>1.7)ally.rotation.z=-.08*Math.sin(Math.PI*clamp((after-1.7)/.5,0,1));
 }else{incoming.visible=false;attacker.visible=false;attackerLabel.visible=false;}
 if(n===4){ash.visible=after>.1;const growth=smooth((after-.1)/1.7),fade=1-smooth((after-3.4)/1.4);ash.position.set(1.5+after*.48,1.1+after*.14,0);ash.scale.set(1.4*growth,.98*growth,1.0*growth);ashMaterial.opacity=.94*fade;
  const p=ashG.attributes.position,c=ashG.attributes.color;for(let i=0;i<p.count;i++){const x=ashRest[i*3],y=ashRest[i*3+1],z=ashRest[i*3+2];const fold=1+.10*Math.sin(x*8-y*3-t*2.7)+.07*Math.sin(z*10+y*7-t*1.7);p.setXYZ(i,x*fold,y*fold+.07*Math.sin(x*9+t*2),z*fold);const heat=Math.max(0,-y)*.34;c.setXYZ(i,.65+heat,.69-heat*.25,.76-heat*.7);}p.needsUpdate=true;c.needsUpdate=true;ashG.computeVertexNormals();ashG.computeBoundingSphere();if(ct){defender.position.z=-2.1*smooth((after-.3)/1);walk(defender,after>.3&&after<1.4?1:0,t);}ally.position.x=-2.7+4.7*smooth((after-.4)/3.1);ally.position.z=2.2;walk(ally,after>.4&&after<3.5?1:0,t);
 }
 impact.visible=state.index===0&&t>2.95&&t<3.45;const ix=n===2?.66:n===3?1.1:1.16;deformFlow(impact.userData.flow,[[ix-.4,1.1,0],[ix,1.15,0],[ix+.45,1.15,0]],1,t,Math.sin(Math.PI*clamp((t-2.95)/.5,0,1)));
 const x=mix(-6.3,n===2?-.45:-.06,clamp(t/3,0,1)),big=smooth((t-.75)/.80),gone=1-smooth((t-3.0)/.30),flyY=1.26+.17*Math.sin(Math.PI*clamp(t/3,0,1));
 base.visible=t<1.3;dragon.visible=t>.83&&t<3.3;base.position.set(x,flyY,0);dragon.position.set(x,flyY,0);base.scale.setScalar((1-.8*big)*.95);dragon.scale.setScalar((.15+1.32*big)*Math.max(.001,gone));base.rotation.set(0,-Math.PI/2+TAU*smooth((t-.30)/1.0),.08*Math.sin(t*5));dragon.rotation.set(.10*Math.sin(t*4),-Math.PI/2+TAU*smooth((t-.30)/1.0),.10*Math.sin(t*4));
 for(const b of dragonBones){b.node.quaternion.copy(b.q);if(/wing/i.test(b.name))b.node.rotateY(.14*Math.sin(t*9));if(/tail/i.test(b.name))b.node.rotateY(.045*Math.sin(t*6));}
 transformGlow.position.set(x,flyY,0);const glow=Math.sin(Math.PI*clamp((t-.6)/1.0,0,1));transformGlow.scale.set(1.1*glow,.85*glow,1.1*glow);transformGlow.material.opacity=.16*glow;
 flashLight.position.set(ix,1.2,0);flashLight.intensity=(t>2.95&&t<3.7?3*Math.sin(Math.PI*clamp((t-2.95)/.75,0,1)):0);
 const args={t,surface:state.surface,counter:ct,chain:state.chain,defender,ally,secondary,base,dragon};if(concepts[state.index].slug==='frost'){waterStudy.render({...args,index:0});webStudy.render({...args,index:0});frostStudy.render({...args,index:concepts[state.index].iceIndex});}else{frostStudy.render({...args,index:0});if(concepts[state.index].slug==='arachnet'){waterStudy.render({...args,index:0});webStudy.render({...args,index:concepts[state.index].webIndex});}else{webStudy.render({...args,index:0});waterStudy.render({...args,index:concepts[state.index].renderIndex??0});}}if(aquatic){base.visible=false;dragon.visible=false;}transformGlow.material.color.set(aquatic?0x81d2e6:0xffc17d);flashLight.color.set(aquatic?0x55b7d4:0xff862b);targetLabel.visible=defender.visible;allyLabel.visible=ally.visible&&concepts[state.index].slug!=='arachnet';secondaryLabel.visible=secondary.visible;
 targetLabel.position.copy(defender.position).add(new T.Vector3(0,2.16,0));allyLabel.position.copy(ally.position).add(new T.Vector3(0,2.16,0));secondaryLabel.position.copy(secondary.position).add(new T.Vector3(0,2.15,0));targetMarker.position.x=(n===3?ally:defender).position.x;targetMarker.position.z=(n===3?ally:defender).position.z;
 if(state.overhead)camera.position.set(0,17,.1);else{const distance=16.8*state.zoom;camera.position.set(Math.sin(state.yaw)*Math.cos(state.pitch)*distance,Math.sin(state.pitch)*distance,Math.cos(state.yaw)*Math.cos(state.pitch)*distance);}camera.lookAt(0,.7,0);
 const w=canvas.clientWidth,h=canvas.clientHeight;if(canvas.width!==Math.round(w*renderer.getPixelRatio())||canvas.height!==Math.round(h*renderer.getPixelRatio()))renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix();document.querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.mode===concepts[state.index].kind));$('#tactic').setAttribute('aria-pressed',!state.counter);$('#counter').setAttribute('aria-pressed',state.counter);renderer.render(scene,camera);$('#tactic').classList.toggle('selected',!state.counter);$('#counter').classList.toggle('selected',state.counter);phaseText(t);$('#timeline').value=t;$('#clock').textContent=`${t.toFixed(1)} / 8.0s`;$('#play').textContent=state.playing?'Ⅱ Pause':'▶ Play';$('#play').setAttribute('aria-label',state.playing?'Pause animation':'Play animation');
}
const incoming=mesh(new T.SphereGeometry(.10,12,10),new T.MeshBasicMaterial({color:0xa5d6eb}),scene);incoming.visible=false;
const attacker=person(mat(0x927884));attacker.visible=false;const attackerLabel=label('ATTACKER','#c4b1c1');scene.add(attackerLabel);
const waterStudy=createWaterStudy({scene,mesh,box,line,mat,label,flow,deformFlow,walk});
const webStudy=createWebStudy({scene,mesh,box,line,mat,label,walk});
const frostStudy=createFrostStudy({scene,mesh,box,line,mat,label,walk});
let currentSpecies=null;
function select(index){
 if(!Number.isInteger(index)||index<0||index>=concepts.length)return;
 state.index=index;state.time=0;const c=concepts[index],aquatic=c.slug==='aqua',species=c.slug+'-'+c.kind;
 if(currentSpecies!==species){currentSpecies=species;$('#concepts').replaceChildren();concepts.forEach((entry,i)=>{if(entry.slug!==c.slug||entry.kind!==c.kind)return;const b=document.createElement('button');b.dataset.index=i;b.setAttribute('aria-pressed',i===index);b.innerHTML=`<span>${entry.confirmed?'CONFIRMED':String($('#concepts').children.length+1).padStart(2,'0')+' / PROPOSAL'}</span><strong>${entry.name}</strong>`;b.onclick=()=>select(i);$('#concepts').appendChild(b);});}
 for(const id of ['name','role','tagline','impact','clever','answer','visual','pairing'])$('#'+id).textContent=c[id];
 $('#tactic').textContent=c.webIndex===7?'Direct pull':'Tactical use';$('#counter').textContent=c.webIndex===7?'Swing + release':'Counterplay';$('#choice-title').textContent=c.choice;$('#choice-copy').textContent=state.counter?c.counter:c.use;
 const names={aqua:'AQUABEEK',inferno:'INFERNO',arachnet:'ARACHNET',frost:'FROSTCRAWLER'};
 const web=c.slug==='arachnet',frost=c.slug==='frost',name=names[c.slug];
 $('#scene-label').textContent=name+' / '+c.name.toUpperCase();
 $('#hero-word').textContent=frost?'ice.':web?'silk.':aquatic?'water.':'fire.';$('#hero-word').style.color=frost?'#b7dfe6':web?'#d4c0df':aquatic?'#9ed0d6':'#ffb15b';
 $('#hero-eyebrow').textContent=name+' / '+(c.kind==='main'?'PLAYER-HIT ABILITY':'PASSIVE / SURFACE HIT');
 $('#hero-intro').innerHTML=frost?(c.kind==='main'?'Three new ice mains: bank, relay or strike overhead.<br>Each works alone; compare the response.':'Ice Wall is Frostcrawler’s confirmed passive.<br>Compare floor, wall and ceiling.') :web?(c.kind==='main'?'Snapbind is Arachnet’s confirmed main.<br>Impact damage and a brief, breakable leg bind.':'Silkline is Arachnet’s confirmed passive.<br>Compare a direct pull with a swing and release.'):(aquatic?(c.kind==='main'?'Crashwave is Aquabeek’s confirmed main ability.<br>Direct impact plus a wave through the line.':'Mistbank is Aquabeek’s confirmed passive.<br>A placed mist cloud obscures both teams.'):(c.kind==='main'?'Backdraft remains Inferno’s confirmed main ability.<br>Impact burn, warning, then a directional pressure burst.':'Inferno’s confirmed passive: fire on the surface you hit.<br>Compare floor, wall and ceiling exposure.'));
 $('#decision-status').textContent=name+(c.confirmed?' / CONFIRMED':' / PROPOSALS');
 $('#model-note').textContent=c.slug==='inferno'?'EXISTING INFERNO FORMS / TIMING ILLUSTRATIVE':'NEUTRAL MODEL PLACEHOLDERS / RELATIVE DAMAGE ONLY';
 $('#study-note').textContent='Health bars and timing illustrate the concept, not chosen balance values. '+(c.confirmed?'This ability core is confirmed. Final numbers, production effects and implementation remain open.':'Frostcrawler mains remain proposals. Ice Wall is confirmed; detailed balance and orientation rules remain open.');
 $('#species-frost').setAttribute('aria-pressed',frost);$('#species-water').setAttribute('aria-pressed',c.slug==='aqua');$('#species-fire').setAttribute('aria-pressed',c.slug==='inferno');$('#species-web').setAttribute('aria-pressed',web);
 document.querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.mode===c.kind));
 document.querySelectorAll('#concepts button').forEach(b=>b.setAttribute('aria-pressed',+b.dataset.index===index));
 $('#surface-controls').hidden=c.kind!=='passive';
 document.querySelector('.beat-buttons button:last-child').dataset.time=(c.iceIndex?(c.iceIndex===10?5.3:4.2):[4.08,4.5,4.2,4.5,4.2,4.2][index]);
 $('#chain').hidden=c.slug!=='aqua'||c.kind==='passive';if($('#chain').hidden){state.chain=false;$('#chain').textContent='Show possible follow-up';$('#chain').setAttribute('aria-pressed',false);}
 render();
}
function selectMode(mode){const slug=concepts[state.index].slug;select(concepts.findIndex(c=>c.slug===slug&&c.kind===mode));}
function selectSlug(slug){const kind=concepts[state.index].kind;select(concepts.findIndex(c=>c.slug===slug&&c.kind===kind));}
function selectSurface(surface){if(!['floor','wall','ceiling'].includes(surface))return;state.surface=surface;state.time=0;state.overhead=false;state.pitch=surface==='ceiling'?.12:.50;state.yaw=.20;$('#camera').textContent='↗ Overhead';document.querySelectorAll('[data-surface]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.surface===surface));render();}
$('#species-frost').onclick=()=>selectSlug('frost');$('#species-water').onclick=()=>selectSlug('aqua');$('#species-fire').onclick=()=>selectSlug('inferno');$('#species-web').onclick=()=>selectSlug('arachnet');
document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>selectMode(b.dataset.mode));
document.querySelectorAll('[data-surface]').forEach(b=>b.onclick=()=>selectSurface(b.dataset.surface));
$('#chain').onclick=()=>{state.chain=!state.chain;$('#chain').setAttribute('aria-pressed',state.chain);$('#chain').textContent=state.chain?'Possible follow-up: on':'Show possible follow-up';render();};

function counter(value){state.counter=value;state.time=2.85;$('#tactic').classList.toggle('selected',!value);$('#counter').classList.toggle('selected',value);$('#tactic').setAttribute('aria-pressed',!value);$('#counter').setAttribute('aria-pressed',value);$('#choice-copy').textContent=value?concepts[state.index].counter:concepts[state.index].use;render();}
$('#tactic').onclick=()=>counter(false);$('#counter').onclick=()=>counter(true);$('#play').onclick=()=>{state.playing=!state.playing;render();};$('#replay').onclick=()=>{state.time=0;state.playing=true;render();};$('#timeline').oninput=e=>{state.time=+e.target.value;state.playing=false;render();};$('#speed').onclick=()=>{state.speed=state.speed===1?.5:state.speed===.5?.25:1;$('#speed').textContent=state.speed+'×';};document.querySelectorAll('[data-time]').forEach(b=>b.onclick=()=>{state.time=+b.dataset.time;state.playing=false;render();});$('#camera').onclick=()=>{state.overhead=!state.overhead;$('#camera').textContent=state.overhead?'↘ Perspective':'↗ Overhead';render();};$('#reset').onclick=()=>{state.yaw=.20;state.pitch=.55;state.zoom=1;state.overhead=false;$('#camera').textContent='↗ Overhead';render();};
let drag=null;canvas.addEventListener('pointerdown',e=>{drag=[e.clientX,e.clientY];canvas.setPointerCapture(e.pointerId);});canvas.addEventListener('pointermove',e=>{if(!drag)return;state.overhead=false;state.yaw-=(e.clientX-drag[0])*.006;state.pitch=clamp(state.pitch+(e.clientY-drag[1])*.004,.12,1.42);drag=[e.clientX,e.clientY];render();});for(const event of ['pointerup','pointercancel'])canvas.addEventListener(event,()=>drag=null);canvas.addEventListener('wheel',e=>{e.preventDefault();state.zoom=clamp(state.zoom*Math.exp(e.deltaY*.001),.6,1.6);render();},{passive:false});
window.addEventListener('keydown',e=>{if(e.target instanceof HTMLInputElement)return;if(e.code==='Space'){e.preventDefault();state.playing=!state.playing;render();}if(/^[1-3]$/.test(e.key)){const button=$('#concepts').children[+e.key-1];if(button)button.click();}});window.addEventListener('resize',()=>render());
window.abilityPreview={ready:true,state,concepts,errors,select,selectMode,selectSlug,selectSurface,counter,sample(t,index=state.index,c=state.counter){state.playing=false;if(index!==state.index)select(index);if(c!==state.counter)counter(c);render(t);return this.metrics();},metrics(){let finite=true,triangles=0;scene.traverse(o=>{if(!o.isMesh||!o.visible)return;const a=o.geometry.attributes.position;if(a)for(let i=0;i<a.array.length;i++)if(!Number.isFinite(a.array[i]))finite=false;triangles+=o.geometry.index?o.geometry.index.count/3:(a?.count||0)/3;});return {index:state.index,time:state.time,counter:state.counter,finite,triangles,errors:[...errors],renderer:renderer.info.render.calls,models:{base:base.children[0].children.length,dragon:dragon.children[0].children.length,placeholder:concepts[state.index].slug!=='inferno'},study:state.index>0?(concepts[state.index].slug==='frost'?frostStudy.metrics():concepts[state.index].slug==='arachnet'?webStudy.metrics():waterStudy.metrics()):null,water:state.index>0?(concepts[state.index].slug==='frost'?frostStudy.metrics():concepts[state.index].slug==='arachnet'?webStudy.metrics():waterStudy.metrics()):null,visibleEffects:Object.entries(fx).filter(([k,g])=>g.visible).map(([k])=>k),target:defender.position.toArray()};},capture(){return canvas.toDataURL('image/png');},project(point){const p=new T.Vector3(...point).project(camera);return {x:(p.x+1)*canvas.clientWidth/2,y:(1-p.y)*canvas.clientHeight/2};}};
select(9);selectSurface('floor');let last=performance.now();function tick(now){const dt=Math.min(.05,(now-last)/1000);last=now;if(state.playing){state.time=(state.time+dt*state.speed)%8;render();}requestAnimationFrame(tick);}requestAnimationFrame(tick);
