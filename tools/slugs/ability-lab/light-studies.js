import * as T from 'three';
const idea=(name,kind,impact,clever,answer,pairing)=>({name,slug:'light',kind,role:'PHOSPHORO / '+(kind==='main'?'PLAYER HIT':'SURFACE PASSIVE'),short:name,tagline:impact.split('. ')[0].replace(/\.$/,'')+'.',impact,clever,answer,pairing,visual:'Warm light, neutral slug forms and health bars. Timings, movement and health are illustrative.',choice:'Watch the effect, then compare the response.',use:'The effect works without another slug.',counter:'The opponent responds to the light.',beats:['Aim at a player for the main or a surface for the passive.','The neutral slug spins and expands in flight.','Contact activates the light effect.','Watch the payoff and compare the response.'],counterbeat:answer});

const priorLightChoices=[
 idea('Flare Mark','main','The hit makes the target glow, so your whole team can see them through walls for a while.',
 'Nobody else reveals enemies. Tag someone, and they cannot hide behind cover or slip away to heal.',
 'Dodge the shot. Once lit, fight where being seen does not matter until it fades.',
 'A lit target cannot hide in Mistbank. Light also dispels Frightgeist’s illusions, if that rule is approved.'),
 idea('Flash','main','The hit bursts into a bright flash that blinds the target for a moment.',
 'A familiar flashbang, but you have to land it. The blinded player cannot answer, so your team can push.',
 'Dodge it, or turn away and back off until you can see again.',
 'Blinded players are easy for Shove Punch or Chain Lightning to catch.'),
 idea('Beacon','passive','Hitting a surface leaves a glowing light that reveals enemies near it through walls.',
 'Watch a route or a flank you cannot see. It is the area version of Flare Mark.',
 'Shoot it out, or stay out of its light.',
 'Placed on a ceiling it covers more ground but is easier to see and break.'),
 idea('Lightstep','passive','Hitting a surface flashes you to where the slug landed.',
 'Move at the speed of light: reach a ledge, cross a gap, or escape a fight with one shot. Where you land is visible, so it is a risk.',
 'Watch where the slug lands and aim there before they arrive.',
 'Different from Silkline’s pull, Updraft’s lift and Bloom Pad’s launch: it is instant.'),
 idea('Mirror','passive','Hitting a surface turns that spot into a mirror, and any slug that hits it bounces off.',
 'Trick shots: bounce a slug around cover to hit someone who thinks they are safe. Pure skill, and nobody else bends shots.',
 'Watch for mirrors and stay out of their angles. Enemies can bounce shots off them too.',
 'Bounce a Tangle or Chain Lightning around a corner. A mirror next to Ice Wall turns cover into a firing line.'),
 idea('Glare','passive','Hitting a surface leaves a bright light that blinds anyone who looks straight at it.',
 'The area version of Flash: light up a doorway or a route, so pushing through it means fighting half-blind.',
 'Look away and back in, take another route, or shoot it out.',
 'Pairs with Flash for a team that wants the enemy blind. Stops people chasing through a gap.'),
 idea('Tripwire','passive','Hitting a surface stretches a beam of light across it. The first enemy to cross gets flashed.',
 'A trap for a flank or a doorway: you know when someone comes through, and they arrive blind.',
 'Spot the beam and shoot its end, or go another way.',
 'Guards a Healing Spring or Bramble patch. Bramble slows them right where the wire is.'),
 idea('Lantern','passive','Hitting a surface leaves a light. Any enemy who looks at it gets their outline shown to your team, even through walls.',
 'The owner’s idea: a light that gives away whoever looks at it. Anyone hiding or holding an angle has to choose between watching and being seen.',
 'Look away from it, or shoot it out.',
 'Works with Flash: both punish looking at Phosphoro’s light. Placed on a ceiling, more people can see it.'),
].map((c,i)=>({...c,lightIndex:i+1}));
export const lightConcepts=priorLightChoices.filter(c=>[2,8].includes(c.lightIndex)).map(c=>({...c,confirmed:true}));

export function createLightStudy({scene,mesh,box,mat,walk}){
 const root=new T.Group();scene.add(root);const clamp=T.MathUtils.clamp,mix=T.MathUtils.lerp,s=x=>{x=clamp(x,0,1);return x*x*(3-2*x);};
 // Glow draws over walls to show what the reveal sees.
 const glow=new T.MeshBasicMaterial({color:0xfff1a8,transparent:true,opacity:.8,depthWrite:false,depthTest:false}),soft=new T.MeshBasicMaterial({color:0xfff1a8,transparent:true,opacity:.3,side:T.DoubleSide,depthWrite:false});
 const flashMat=new T.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.8,depthWrite:false}),blinkMat=new T.MeshBasicMaterial({color:0xfff6c8,transparent:true,opacity:.7,depthWrite:false});
 const small=mesh(new T.SphereGeometry(.35,24,16),mat(0xe8dca0),root),large=mesh(new T.SphereGeometry(.65,24,16),mat(0xe8dca0),root);
 const wall=box(root,1.4,1.5,-.55,4.8,3,.16,mat(0x354550));
 const ceiling=box(root,1.4,3.15,0,4.8,.12,3,new T.MeshStandardMaterial({color:0x506772,transparent:true,opacity:.16,side:T.DoubleSide,depthWrite:false}),false);
 const cover=box(root,3.1,.9,0,.3,1.8,2.4,mat(0x354550));
 const halo=mesh(new T.TorusGeometry(.45,.05,8,32),glow,root);halo.rotation.x=Math.PI/2;halo.renderOrder=5;
 const pillar=mesh(new T.CylinderGeometry(.07,.07,2.6,8),glow,root);pillar.renderOrder=5;
 const flash=mesh(new T.SphereGeometry(1,24,16),flashMat,root);
 const beacon=mesh(new T.IcosahedronGeometry(.22),glow,root);beacon.renderOrder=5;
 const range=mesh(new T.RingGeometry(2.2,2.32,48),soft,root);range.rotation.x=-Math.PI/2;
 const blinks=[0,1].map(()=>mesh(new T.SphereGeometry(.6,16,12),blinkMat,root));
 const enemyShot=mesh(new T.SphereGeometry(.2,14,10),mat(0xc48a8a),root);
 const bar=box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false);
 const mirror=mesh(new T.PlaneGeometry(1.4,1.4),new T.MeshStandardMaterial({color:0xcfe0ea,metalness:.9,roughness:.1,emissive:0x2a3a44,side:T.DoubleSide}),root);
 const sideCover=box(root,1.4,.9,2.5,.3,1.8,1.3,mat(0x354550));
 const glare=mesh(new T.SphereGeometry(.28,20,14),glow,root);glare.renderOrder=5;const glareRays=mesh(new T.RingGeometry(.4,1.1,32),soft,root);
 const headFlash=mesh(new T.SphereGeometry(.45,16,12),flashMat.clone(),root);
 const beam=mesh(new T.CylinderGeometry(.06,.06,3,8),glow,root);beam.rotation.x=Math.PI/2;beam.renderOrder=5;
 const emitter=mesh(new T.OctahedronGeometry(.16),glow,root);emitter.renderOrder=5;
 const ownShot=mesh(new T.SphereGeometry(.2,14,10),mat(0xe8dca0),root);
 let last={};
 function render({index=0,t,surface='floor',counter=false,defender,ally,secondary}){
  root.visible=index>0;if(!index)return;
  for(const o of [wall,ceiling,cover,halo,pillar,flash,beacon,range,enemyShot,bar,mirror,sideCover,glare,glareRays,headFlash,beam,emitter,ownShot,...blinks])o.visible=false;
  const passive=index>2,after=Math.max(0,t-3),born=t>3,flight=clamp(t/3,0,1),grow=s((t-.75)/.8);
  const point=!passive?new T.Vector3(1.4,1.1,0):surface==='wall'?new T.Vector3(1.4,1.1,-.43):surface==='ceiling'?new T.Vector3(1.4,3.04,0):new T.Vector3(1.4,.05,0);
  const dodge=!passive&&counter;
  small.visible=t<1.3;large.visible=t>.83&&t<(dodge?3.4:3.15);
  for(const o of [small,large])o.position.set(mix(-6.3,point.x,flight)+(dodge&&t>3?(t-3)*6:0),mix(1.24,point.y,s((t-1.8)/1.2)),point.z*s((t-1.8)/1.2));
  small.scale.setScalar(Math.max(.01,1-.8*grow));large.scale.setScalar(dodge?.15+grow:(.15+grow)*(1-s(after/.15)));
  defender.visible=true;defender.position.set(1.4,0,0);defender.rotation.set(0,0,0);walk(defender,0,t);ally.visible=false;secondary.visible=false;
  if(dodge){defender.position.z=1.8*s((t-1.9)/.8);walk(defender,t>1.9&&t<2.7?1:0,t);}
  const hit=!passive&&!counter&&born;let damage=hit?.15:0,bounced=false,hitAroundCover=false,tripped=false,marked=false,seenThroughCover=false,blinded=false,revealed=false,destroyed=false,teleported=false,caught=false;
  const lightUp=actor=>{halo.visible=true;halo.position.copy(actor.position).add(new T.Vector3(0,1+.15*Math.sin(t*4),0));pillar.visible=true;pillar.position.copy(actor.position).add(new T.Vector3(0,1.3,0));};
  if(!passive){ally.visible=true;ally.position.set(-5.5,0,0);ally.rotation.set(0,Math.PI/2,0);}
  if(index===1){
   cover.visible=true;cover.position.x=3.1;
   if(hit){defender.position.x=mix(1.4,3.9,s((after-.4)/.9));walk(defender,after>.4&&after<1.3?1:0,t);marked=after<4;if(marked)lightUp(defender);seenThroughCover=marked&&defender.position.x>3.3;}
  }
  if(index===2&&hit){
   flash.visible=after<.6;flash.scale.setScalar(.4+3*after);flashMat.opacity=.8*(1-after/.6);
   blinded=after<2.2;if(blinded)defender.rotation.y=1.3*Math.sin(after*3.5);
  }
  if(passive){wall.visible=surface==='wall';ceiling.visible=surface==='ceiling';}
  if(index===3){
   defender.visible=false;cover.visible=true;cover.position.x=2.5;
   secondary.visible=true;secondary.position.set(3.3,0,.5);secondary.rotation.set(0,-Math.PI/2,0);walk(secondary,0,t);
   // The enemy behind cover shoots the beacon out.
   const go=clamp((after-.6)/.6,0,1);destroyed=counter&&after>1.2;
   if(counter&&after>.6&&go<1){enemyShot.visible=true;enemyShot.position.set(mix(3.1,point.x,go),mix(1.2,point.y,go),mix(.5,point.z,go));}
   beacon.visible=born&&!destroyed;beacon.position.copy(point);beacon.rotation.y=t*2;beacon.scale.setScalar(s(after/.3));
   range.visible=born&&!destroyed;range.position.set(point.x,.03,point.z);
   revealed=beacon.visible&&Math.hypot(secondary.position.x-point.x,secondary.position.z-point.z)<2.3;if(revealed)lightUp(secondary);
  }
  if(index===4){
   const start=new T.Vector3(-5.5,0,0),landing=new T.Vector3(point.x,0,surface==='wall'?0:0);teleported=born;
   ally.visible=true;ally.rotation.set(0,Math.PI/2,0);ally.position.copy(teleported?landing:start);walk(ally,0,t);
   if(born&&after<.5){blinks.forEach((b,k)=>{b.visible=true;b.position.copy(k?landing:start).add(new T.Vector3(0,1,0));b.scale.setScalar(1+after*2);});blinkMat.opacity=.7*(1-after/.5);}
   defender.position.set(4.6,0,1.6);defender.rotation.set(0,-2.2,0);
   if(counter){const go=clamp((after-.1)/.4,0,1);enemyShot.visible=born&&go<1;enemyShot.position.set(mix(4.4,landing.x,go),1.2,mix(1.5,landing.z,go));caught=after>.5;damage=caught?.15:0;}
  }
  const blind=on=>{if(!on)return;headFlash.visible=true;headFlash.position.copy(defender.position).add(new T.Vector3(0,1.65,0));headFlash.material.opacity=.5+.3*Math.sin(t*12);};
  if(index===5){
   // Phosphoro's player bounces a slug off the mirror, around cover, into a hidden enemy.
   mirror.visible=born;mirror.scale.setScalar(s(after/.3));mirror.position.copy(point);
   if(surface==='wall')mirror.rotation.set(0,0,0);else mirror.rotation.set(-Math.PI/2,0,0);
   if(surface==='wall')mirror.position.z+=.01;else mirror.position.y+=surface==='ceiling'?-.07:.01;
   sideCover.visible=true;ally.visible=true;ally.position.set(-2,0,2.5);ally.rotation.set(0,Math.PI/2,0);
   defender.position.set(4.8,0,counter?mix(2.5,4.4,s((after-.4)/.8)):2.5);defender.rotation.set(0,-Math.PI/2,0);walk(defender,counter&&after>.4&&after<1.2?1:0,t);
   const a=clamp((after-.8)/.5,0,1),b=clamp((after-1.3)/.5,0,1),end=new T.Vector3(4.8,1.2,2.5);
   ownShot.visible=after>.8&&b<1;if(a<1)ownShot.position.lerpVectors(new T.Vector3(-1.8,1.2,2.5),point,a);else ownShot.position.lerpVectors(point,end,b);
   bounced=after>1.3;hitAroundCover=!counter&&after>1.8;damage=hitAroundCover?.15:0;
  }
  if(index===6){
   const spot=surface==='ceiling'?point.clone().add(new T.Vector3(0,-.15,0)):surface==='wall'?point.clone().add(new T.Vector3(0,0,.15)):point.clone().add(new T.Vector3(0,.25,0));
   glare.visible=born;glare.position.copy(spot);glare.scale.setScalar(s(after/.3)*(1+.1*Math.sin(t*8)));
   glareRays.visible=born;glareRays.position.copy(spot);glareRays.lookAt(4.2,1.6,0);glareRays.scale.setScalar(s(after/.3));
   defender.position.set(counter?mix(4.2,5.4,s((after-.3)/.8)):4.2,0,0);
   defender.rotation.set(0,counter?Math.PI/2:-Math.PI/2,0);walk(defender,counter&&after>.3&&after<1.1?1:0,t);
   blinded=born&&!counter&&after>.3;blind(blinded);
  }
  if(index===7){
   destroyed=counter&&after>1.4;
   emitter.visible=born&&!destroyed;emitter.position.copy(point);emitter.rotation.y=t*2;
   beam.visible=born&&!destroyed;beam.position.set(1.4,.45,surface==='wall'?1:0);beam.scale.set(1,s(after/.3),1);
   defender.rotation.set(0,-Math.PI/2,0);
   if(counter){defender.position.x=after<1.6?3.6:mix(3.6,-.8,s((after-1.6)/1.6));walk(defender,after>1.6&&after<3.2?1:0,t);const go=clamp((after-.8)/.6,0,1);enemyShot.visible=after>.8&&go<1;enemyShot.position.set(mix(3.4,point.x,go),mix(1.2,point.y,go),mix(0,point.z,go));}
   else{defender.position.x=mix(4.2,-.8,s((after-.3)/2.4));walk(defender,after>.3&&after<2.7?1:0,t);}
   tripped=beam.visible&&defender.position.x<1.5;blinded=tripped;blind(blinded);
  }
  if(index===8){
   // Only the enemy facing the light is revealed; Phosphoro's player is behind cover.
   const spot=surface==='ceiling'?point.clone().add(new T.Vector3(0,-.15,0)):surface==='wall'?point.clone().add(new T.Vector3(0,0,.15)):point.clone().add(new T.Vector3(0,.25,0));
   glare.visible=born;glare.position.copy(spot);glare.scale.setScalar(s(after/.3)*(1+.1*Math.sin(t*6)));
   sideCover.visible=true;ally.visible=true;ally.position.set(-2,0,2.5);ally.rotation.set(0,Math.PI/2,0);
   defender.position.set(4.4,0,2.4);const look=Math.atan2(spot.x-4.4,spot.z-2.4);
   defender.rotation.set(0,counter?mix(look,look+Math.PI,s((after-.3)/.5)):look,0);
   secondary.visible=true;secondary.position.set(3.8,0,-1.6);secondary.rotation.set(0,Math.PI/2,0);walk(secondary,0,t);
   revealed=born&&after>.5&&!counter;if(revealed)lightUp(defender);
  }
  const target=index===4?ally:defender;
  if(!passive||index===4&&counter||index===5){bar.visible=born;bar.position.copy(target.position).add(new T.Vector3(0,2.03,0));bar.scale.x=Math.max(.02,1-damage);}
  last={index,surface,relativeDamage:damage,bounced,hitAroundCover,tripped,hit,marked,seenThroughCover,blinded,revealed,destroyed,teleported,caught,defender:defender.position.toArray(),self:ally.position.toArray()};
 }
 return {render,metrics:()=>last};
}
