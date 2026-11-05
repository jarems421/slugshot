import * as T from 'three';
const idea=(name,kind,impact,clever,answer,pairing)=>({name,slug:'frost',kind,role:'FROSTCRAWLER / '+(kind==='main'?'PLAYER HIT':'SURFACE PASSIVE'),short:name,tagline:impact.split('. ')[0]+'.',impact,clever,answer,pairing,visual:'Pale blue faceted ice, dark edges and a neutral small/transformed slug. Motion and health are illustrative.',choice:'Watch the play, then try the response.',use:'The target commits to the affected route. The effect has standalone utility.',counter:'The opponent responds to the visible ice before the full payoff.',beats:['Aim at a player for the main, or a surface for the passive.','The neutral slug spins and opens into a larger placeholder.','Contact activates the ice effect.','Watch the result, then compare counterplay.'],counterbeat:answer});
export const frostConcepts=[
 idea('Rimebite','main','Impact damage coats the legs in brittle ice, slowing movement briefly. The target can still move, aim and fire; shooting the visible coating breaks the slow early.','Catch a fast opponent without completely stopping their movement. The direct hit and slow are useful on their own.','Shoot off the brittle ice, get a teammate to clear it, or return fire while moving more slowly.','A slower target is easier to line up for Crashwave; this does not require Aquabeek to make Rimebite useful.'),
 idea('Shattermark','main','Impact damage leaves a visible ice crystal on the target. After a short warning it bursts in a small radius, damaging that target and nearby opponents.','Tag a tightly grouped team to force them to spread, or pressure a lone target with the delayed second hit.','Shoot the exposed crystal before it bursts to prevent the delayed damage. Nearby teammates can also spread outside its radius.','A Snapbind hit could hold a second opponent near the marked player; the delayed solo hit works without that setup.'),
 idea('Skidshock','main','Impact damage freezes traction for a brief forced glide along the incoming shot direction. The opponent keeps aim and firing but brakes less effectively until the glide ends.','Shoot from an angle to slide someone past cover or a preferred firing position. This is a low sideways glide rather than a root or upward knockback.','Steer sideways during the short slide, or use solid cover to stop it early. No forced slide through walls is proposed.','Slide someone toward existing Surface Fire; the displacement already changes their angle on its own.'),
 idea('Blackice','passive','Surface impact makes a visible slick patch. Contact preserves momentum and weakens braking briefly: a floor crossing slides, a wall contact drifts, and a ceiling brush carries a jumping player onward.','Lay a fast crossing for yourself or make an enemy overshoot their intended stop. Either team can exploit the same visible surface.','Avoid the patch or cross at lower speed. The passive adds no direct damage and does not grab players who never touch it.','Carry speed into a Silkline swing or make an opponent overshoot cover. These are proposed sequential uses.'),
 idea('Ice Shelf','passive','Surface impact grows one short-lived solid foothold. A floor hit makes a low step, a wall hit makes a ledge, and a ceiling hit hangs a supported ice step beneath it.','Create a temporary angle or landing point for either team. It supplies useful access by itself and does not seal a whole corridor.','Shoot the brittle foothold to break it or use another route. Standing on a destructible ledge is a risk, not permanent safe high ground.','A shelf could give a better angle for Backdraft or a new starting point for Silkline.'),
 idea('Frostmine','passive','Surface impact leaves a visible ice bud that triggers on nearby contact. It flashes a short warning, then cracks in a small chilling burst that damages and briefly slows opponents still close.','Protect a route with a readable delayed trap. Walls and ceilings can cover a close passage; it never affects the entire room.','Leave the warned radius before the burst, or shoot the bud before approaching. The preview compares staying with stepping out after the warning.','Backdraft could push an opponent toward an armed bud. The trap also triggers and damages on its own.')
].map((c,i)=>({...c,iceIndex:i+1}));

export function createFrostStudy({scene,mesh,box,line,mat,label,walk}){
 const root=new T.Group();scene.add(root);const clamp=T.MathUtils.clamp,mix=T.MathUtils.lerp,s=x=>{x=clamp(x,0,1);return x*x*(3-2*x);},up=new T.Vector3(0,1,0);
 const ice=new T.MeshStandardMaterial({color:0x9cdae3,roughness:.29,metalness:.12,transparent:true,opacity:.85,flatShading:true});
 const small=mesh(new T.SphereGeometry(.35,24,16),mat(0xb9c5c9),root);small.scale.set(1,1.25,1.25);
 const large=mesh(new T.SphereGeometry(.7,24,16),mat(0xb9c5c9),root);large.scale.set(.75,.75,1.5);
 const wall=box(root,1.4,1.5,-.55,4.8,3,.16,mat(0x354550));
 const ceiling=box(root,1.4,3.15,0,4.8,.12,3,new T.MeshStandardMaterial({color:0x506772,transparent:true,opacity:.18,side:T.DoubleSide,depthWrite:false}),false);
 const patch=new T.Group();root.add(patch);const disc=mesh(new T.CylinderGeometry(1.25,1.35,.075,48),ice,patch);for(let k=0;k<6;k++){const a=k*Math.PI/3;line(patch,[[0,.045,0],[Math.cos(a)*1.15,.045,Math.sin(a)*1.15]],0xd7edf0,.012);}
 const coat=new T.Group();root.add(coat);for(let k=0;k<7;k++){const a=k/7*Math.PI*2;const shard=mesh(new T.OctahedronGeometry(.28),ice,coat);shard.position.set(Math.cos(a)*.3,.45+(k%2)*.15,Math.sin(a)*.3);shard.scale.set(.6,1.5,.6);}
 const crystal=mesh(new T.OctahedronGeometry(.3),ice,root);crystal.scale.y=1.6;
 const burst=new T.Group();root.add(burst);for(let k=0;k<14;k++){const shard=mesh(new T.OctahedronGeometry(.08),ice,burst);shard.userData.angle=k/14*Math.PI*2;}
 const ring=mesh(new T.TorusGeometry(1.25,.018,6,64),new T.MeshBasicMaterial({color:0xaee6ee}),root);ring.rotation.x=Math.PI/2;
 const shelf=box(root,1.4,.35,0,1.7,.55,1.35,ice);
 const supports=[box(root,.85,2.1,0,.12,2.1,.12,ice),box(root,1.95,2.1,0,.12,2.1,.12,ice)];
 const blocker=box(root,2.8,.8,0,.22,1.6,1.6,mat(0x354550));
 const shot=mesh(new T.SphereGeometry(.06,12,8),mat(0xf2d39b),root);
 const hp=label('IMPACT + EFFECT','#aed5dc',2.2);root.add(hp);
 const bars=[box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false),box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false)];
 let last={};
 function render({index=0,t,surface='floor',counter=false,defender,ally,secondary}){
  root.visible=index>0;if(!index)return;
  for(const o of [wall,ceiling,patch,coat,crystal,burst,ring,shelf,blocker,shot,...supports])o.visible=false;
  const passive=index>3,after=Math.max(0,t-3),born=t>3,build=s(after/.25),grow=s((t-.75)/.8),fade=1-s((after-3.7)/.8);
  const point=new T.Vector3(1.4,surface==='wall'?1.15:surface==='ceiling'?3.04:.05,surface==='wall'?-.43:0),normal=surface==='wall'?new T.Vector3(0,0,1):surface==='ceiling'?new T.Vector3(0,-1,0):up;
  small.visible=t<1.3;large.visible=t>.83&&t<3.3;const flight=clamp(t/3,0,1),flightPoint=passive?point:new T.Vector3(1.4,1.1,0);
  for(const o of [small,large]){o.position.set(mix(-6.3,flightPoint.x,flight),mix(1.24,flightPoint.y,s((t-1.8)/1.2)),flightPoint.z*s((t-1.8)/1.2));o.rotation.set(0,-Math.PI/2+Math.PI*2*s((t-.3)),0);}
  small.scale.setScalar(Math.max(.01,1-.8*grow));large.scale.set(.75, .75,1.5).multiplyScalar((.15+grow)*(1-s(after/.3)));
  defender.visible=true;defender.position.set(1.4,0,0);defender.rotation.set(0,0,0);walk(defender,0,t);ally.visible=false;secondary.visible=false;
  let damage=passive?0:.2*build,secondaryDamage=0,slowed=false,broken=false,sliding=false,triggered=false,detonated=false,platform=false;
  if(index===1){broken=counter&&after>1;slowed=born&&after<(counter?1:2.6);coat.visible=slowed;const distance=counter?1.5*s((after-1)/1):.5*s(after/2);defender.position.x+=distance;walk(defender,slowed?.2:.6,t);}
  if(index===2){broken=counter&&after>1;crystal.visible=born&&after<1.8&&!broken;secondary.visible=true;secondary.position.set(2.2+ (counter?1.8*s((after-.4)/1):0),0,.35);detonated=after>1.8&&!counter;damage+=detonated?.25*s((after-1.8)/.2):0;secondaryDamage=detonated?.2:0;ring.visible=born&&after<1.8;ring.position.set(1.4,.055,0);ring.scale.setScalar(1.25);}
  if(index===3){blocker.visible=counter;sliding=born&&after<1.5;defender.position.x+= (counter?1.0:2.6)*s(after/1.5);defender.position.z=counter?1.2*s(after/1.1):0;walk(defender,sliding?.1:0,t);}
  if(passive){wall.visible=surface==='wall';ceiling.visible=surface==='ceiling';patch.visible=born;patch.position.copy(point);patch.quaternion.setFromUnitVectors(up,normal);patch.scale.setScalar(build);disc.material.opacity=.85*fade;defender.position.set(mix(-1.4,1.4,s((after-.1)/1)),surface==='ceiling'?.9*Math.sin(Math.PI*clamp(after/2,0,1)):0,surface==='wall'?.1:0);walk(defender,.6,t);
   if(index===4){sliding=after>.9&&!counter;const p=counter?.5:2.5;defender.position.x=mix(-1.4,1.4, s((after-.1)/1))+p*s((after-.9)/1.5);defender.position.z=counter?1.8*s(after):surface==='wall'?.1:0;}
   if(index===5){patch.visible=false;shelf.visible=born;platform=born&&!counter;shelf.position.set(1.4,surface==='floor'?.3:surface==='wall'?1:.8,surface==='wall'?.1:0);shelf.scale.set(1,build,1);broken=counter&&after>1.4;shelf.visible=born&&!broken;if(platform){defender.position.set(mix(-1.4,1.4,s(after/1.5)),(shelf.position.y+.275)*s((after-.3)/1),surface==='wall'?.1:0);}else defender.position.set(1.4,0,1.6);}
   if(index===6){patch.visible=false;crystal.visible=born&&after<1.9;crystal.position.copy(point).addScaledVector(normal,.2);triggered=after>1;ring.visible=after>1&&after<1.9;ring.position.copy(point);ring.quaternion.setFromUnitVectors(new T.Vector3(0,0,1),normal);ring.scale.setScalar(1.25);detonated=after>1.9;const escape=counter?2.1*s((after-1)/.7):0;defender.position.x=1.4+escape;damage=detonated&&!counter?.25:0;slowed=detonated&&!counter&&after<3.1;}
  }
  if(index===2)crystal.position.copy(defender.position).add(new T.Vector3(0,1.3,.42));
  coat.position.copy(defender.position);coat.scale.setScalar(build);
  if(counter&&(index===1||index===2||index===5)&&after>.5&&after<1.1){shot.visible=true;shot.position.copy(defender.position).add(new T.Vector3(0,mix(1.3,.45,s((after-.5)/.6)),.35));}
  burst.visible=detonated&&after<(index===2?2.7:2.8);if(burst.visible){burst.position.copy(index===2?defender.position.clone().add(new T.Vector3(0,1.2,0)):point);const q=clamp((after-(index===2?1.8:1.9))/.8,0,1);for(const o of burst.children){const a=o.userData.angle;o.position.set(Math.cos(a)*q*1.6,.3+Math.sin(q*Math.PI)*.5,Math.sin(a)*q*1.6);o.scale.setScalar(1-q);}}
  for(const o of supports)o.visible=index===5&&surface==='ceiling'&&shelf.visible;
  hp.position.copy(defender.position).add(new T.Vector3(0,2.5,0));hp.visible=born;bars[0].visible=born;bars[1].visible=secondary.visible&&born;
  [defender,secondary].forEach((actor,i)=>{bars[i].position.copy(actor.position).add(new T.Vector3(0,2.04,0));bars[i].scale.x=1-(i?secondaryDamage:damage);});
  last={index,surface,relativeDamage:damage,secondaryDamage,slowed,broken,sliding,triggered,detonated,platform,defender:defender.position.toArray()};
 }
 return {render,metrics:()=>last};
}
