import * as T from 'three';
const idea=(name,kind,impact,clever,answer,pairing)=>({name,slug:'inferno',kind,role:'INFERNO / '+(kind==='main'?'PLAYER HIT':'SURFACE PASSIVE'),short:name,tagline:impact.split('. ')[0].replace(/\.$/,'')+'.',impact,clever,answer,pairing,visual:'Inferno’s real forms, simple orange fire shapes and neutral players. Timings, movement and health are illustrative.',choice:'Watch the effect, then compare the response.',use:'The opponent commits to the affected route. The effect works without another slug.',counter:'The opponent responds to what Inferno is doing.',beats:['Aim at a player for the main or a surface for the passive.','Inferno spins and transforms in flight.','Contact activates the fire effect.','Watch the payoff and compare the response.'],counterbeat:answer});

const priorInfernoChoices=[
 idea('Victory Lap','main','The hit burns the target, but the dragon does not stop there. It banks round in a wide loop and dives back for a second hit.',
 'Pure showing off. Land the first hit, then force them to deal with a dragon coming back at them while you line up your next shot.',
 'Move or get behind cover as it comes round. The return pass goes where you were when it turned, so reading the loop beats it.',
 'A target bound by Snapbind cannot dodge the return. Fleeing the loop can push someone into Rockbreak rubble or Livewire.'),
 idea('Dragon’s Breath','main','The hit burns the target, then the dragon hovers and breathes a stream of fire that follows them for a moment.',
 'Uses his signature fire breath. The stream makes them run or hide right away, which lets you choose where they go.',
 'Break line of sight. Any solid cover stops the stream, and the dragon leaves shortly after.',
 'Ice Wall or Rockbreak cover can block it, and Mistbank can hide you from it. Running from it can lead someone into a set-up.'),
 idea('Flashpoint','main','The hit sets the target alight. The next hit they take from anyone, with any slug, sets off a burst of fire.',
 'A real team combo that works with every slug. Burn someone, then you or a teammate finish it with anything that connects.',
 'Get behind cover until the fire goes out. Taking no further hit means no burst.',
 'Rewards following up with an easy hit: a Chain Lightning arc or Crashwave could count as the trigger. Which hits count is still open.'),
 idea('Perch','passive','Hitting a surface leaves Inferno clinging there in his dragon form, spitting fireballs at any enemy he can see until he leaves or is shot off.',
 'Cocky and full of character. Guard a route, cover your flank or pressure a corner while you move somewhere else.',
 'Shoot him off, stay out of his sight or come from behind cover. He is exposed and easy to see.',
 'Mistbank blinds him as well as you. Perching on a wall above Rockbreak cover gives him an angle over it.'),
 idea('Thermal','passive','Hitting a surface starts a column of rising hot air. Anyone who steps in gets carried upward, whichever team they are on.',
 'Build a lift to a high angle, get out of a bad fight, or catch someone who rides it with your next shot. The fire does the moving, not the damage.',
 'Walk around it, or take the lift yourself. A player rising in a straight line is easy to hit.',
 'Different from Silkline: anyone can use it, and it only goes up. A rising target is an easy mark for Dragon’s Breath or Shove Punch.'),
 idea('Flamejet','passive','Hitting a surface opens a vent that blasts a jet of flame straight out, on and off in a steady rhythm.',
 'Blocks a corridor at the moments you choose. Timing your push with its rhythm is the skill, for both sides.',
 'Time your crossing for the gap, or find another route. It is loud and easy to read.',
 'Closest to Livewire, because it also hurts people passing through. It reaches further and pulses instead of sitting flat.'),
 idea('Fire Curtain','passive','As he flies, a curtain of fire rises along his path and stays for a while. Anyone can walk through it, but it burns them.',
 'Cut the room in two with one shot. Choose the line it takes to wall off a route, shield your approach or force people to cross where you are aiming.',
 'Go around the end of the curtain, wait for it to burn out, or take the burn and cross.',
 'Rammstone’s rock can block one route while the curtain burns the other. Shove Punch can knock someone into it, and Snapbind can hold them there. Water puts it out, so Crashwave and Mistbank answer it, and Mending Shot clears the burn.'),
].map((c,i)=>({...c,infernoIndex:i+1}));
export const infernoConcepts=priorInfernoChoices.filter(c=>[2,7].includes(c.infernoIndex)).map(c=>({...c,confirmed:true}));

export function createInfernoStudy({scene,mesh,box,mat,walk}){
 const root=new T.Group();scene.add(root);const clamp=T.MathUtils.clamp,mix=T.MathUtils.lerp,s=x=>{x=clamp(x,0,1);return x*x*(3-2*x);},up=new T.Vector3(0,1,0);
 const fire=new T.MeshBasicMaterial({color:0xff8a2c,transparent:true,opacity:.82,depthWrite:false}),hot=new T.MeshBasicMaterial({color:0xffd36b}),air=new T.MeshBasicMaterial({color:0xffb46a,transparent:true,opacity:.2,side:T.DoubleSide,depthWrite:false});
 const burst=mesh(new T.SphereGeometry(.5,20,14),fire,root);
 const stream=mesh(new T.ConeGeometry(.42,1,16,1,true),fire,root);
 const burn=[0,1,2].map(()=>mesh(new T.ConeGeometry(.13,.5,8),fire,root));
 const balls=[0,1,2].map(()=>mesh(new T.SphereGeometry(.14,12,10),hot,root));
 const cover=box(root,.75,.9,0,.3,1.8,2,mat(0x354550));
 const wall=box(root,1.4,1.5,-.55,4.8,3,.16,mat(0x354550));
 const ceiling=box(root,1.4,3.15,0,4.8,.12,3,new T.MeshStandardMaterial({color:0x506772,transparent:true,opacity:.16,side:T.DoubleSide,depthWrite:false}),false);
 const column=mesh(new T.CylinderGeometry(.75,.75,3.4,24,1,true),air,root);
 const vent=mesh(new T.CylinderGeometry(.3,.38,.1,16),mat(0x3a2a22),root);
 const shot=mesh(new T.SphereGeometry(.12,12,10),new T.MeshBasicMaterial({color:0xcfe3ea}),root);
 const curtain=Array.from({length:26},(_,k)=>{const cone=mesh(new T.ConeGeometry(.27,1,7),k%3?fire:hot,root);cone.userData.x=-5.4+k*.27;return cone;});
 const bar=box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false);
 let last={};
 const aimAt=(obj,from,to)=>{const d=to.clone().sub(from),len=Math.max(d.length(),.01);obj.position.copy(from).addScaledVector(d,.5);obj.quaternion.setFromUnitVectors(up,d.clone().normalize().negate());obj.scale.set(1,len,1);};
 function render({index=0,t,surface='floor',counter=false,defender,ally,base,dragon}){
  root.visible=index>0;if(!index)return;
  for(const o of [burst,stream,...burn,...balls,cover,wall,ceiling,column,vent,shot,bar,...curtain])o.visible=false;
  const passive=index>3,after=Math.max(0,t-3),born=t>3,flight=clamp(t/3,0,1),big=s((t-.75)/.8);
  const normal=surface==='wall'?new T.Vector3(0,0,1):surface==='ceiling'?new T.Vector3(0,-1,0):up.clone();
  const point=new T.Vector3(1.4,surface==='wall'?1.1:surface==='ceiling'?3.04:.05,surface==='wall'?-.43:0);
  const dest=index===7?new T.Vector3(1.4,point.y,surface==='wall'?-.43:0):passive?point:new T.Vector3(1.4,1.2,0);
  const fx=mix(-6.3,dest.x,flight),fy=mix(1.26,dest.y,s((t-1.8)/1.2));
  for(const form of [base,dragon])form.position.set(fx,fy,dest.z*s((t-1.8)/1.2));
  dragon.visible=t>.83;dragon.scale.setScalar((.15+1.0*big));
  defender.visible=true;defender.position.set(1.4,0,0);defender.rotation.set(0,0,0);
  let damage=0,secondPass=false,breathing=false,blocked=false,burning=false,detonated=false,shots=0,knockedOff=false,lifted=0,jetOn=false,hurtByJet=false,curtainUp=false,crossedThrough=false;
  const showBurst=(at,size,life)=>{if(life>0&&life<1){burst.visible=true;burst.position.copy(at);burst.scale.setScalar(size*(.4+life));fire.opacity=.82*(1-life);}else fire.opacity=.82;};
  if(!passive&&born&&after<.3)showBurst(new T.Vector3(1.4,1.2,0),1.3,after/.3);
  if(index===1){
   damage=born?.2:0;
   const u=clamp(after/1.5,0,1),ang=u*Math.PI*2;
   if(born){dragon.position.set(1.4+2.5*Math.sin(ang),1.25+.9*Math.sin(u*Math.PI),2.2*(1-Math.cos(ang))*.5);dragon.rotation.set(0,-Math.PI/2-ang,.5*Math.sin(ang));dragon.visible=after<1.75;if(after>1.5)dragon.scale.setScalar(1.15*(1-s((after-1.5)/.25)));}
   if(counter){defender.position.z=-1.9*s((after-.5)/.7);}
   secondPass=after>=1.5;
   if(secondPass&&!counter){damage=.4;showBurst(new T.Vector3(1.4,1.2,0),1.3,(after-1.5)/.3);}
  }
  if(index===2){
   damage=born?.2:0;const on=after>.25&&after<2.3;
   if(born){dragon.position.set(mix(1.4,-.9,s(after/.3)),1.9,0);dragon.rotation.set(0,-Math.PI/2,0);dragon.visible=after<2.7;if(after>2.3)dragon.scale.setScalar(1.15*(1-s((after-2.3)/.4)));}
   if(counter){cover.visible=true;defender.position.set(mix(1.4,1.6,s((after-.2)/.5)),0,0);}else{defender.position.z=1.4*Math.sin(clamp((after-.3)/2,0,1)*Math.PI);}
   const mouth=new T.Vector3(-.2,1.85,0),target=defender.position.clone().add(new T.Vector3(0,1.1,0));
   breathing=on;blocked=counter&&on;
   if(on){stream.visible=true;aimAt(stream,mouth,counter?new T.Vector3(.75,1.3,0):target);if(!counter)damage=.2+.3*clamp((after-.25)/2,0,1);}
  }
  if(index===3){
   const arrive=1.3;burning=born&&(!counter?after<arrive:after<2.8);
   burn.forEach((o,k)=>{o.visible=burning;o.position.set(defender.position.x+(k-1)*.22,1.2+.28*Math.sin(t*9+k*2)+.2*k,defender.position.z);o.scale.setScalar(.9+.2*Math.sin(t*14+k));});
   if(counter){cover.visible=true;cover.position.x=-.2;defender.position.set(mix(1.4,.25,s((after-.1)/.8)),0,0);}else cover.position.x=.75;
   ally.visible=true;ally.position.set(-3.4,0,0);ally.rotation.set(0,Math.PI/2,0);
   damage=born?.15:0;
   const fly=clamp((after-.7)/.6,0,1);shot.visible=after>.7&&fly<1;const end=counter?-.35:defender.position.x;shot.position.set(mix(-3.1,end,fly),1.15,0);
   detonated=!counter&&after>=arrive;
   if(detonated){damage=.55;showBurst(defender.position.clone().add(new T.Vector3(0,1.1,0)),2,(after-arrive)/.5);}
  }
  if(passive){wall.visible=surface==='wall';ceiling.visible=surface==='ceiling';}
  if(index===4){
   const off=counter&&after>1.5;knockedOff=off;
   const perch=point.clone().addScaledVector(normal,.35);
   if(born){dragon.visible=!off&&after<4.6;dragon.position.copy(perch);dragon.scale.setScalar(.8);dragon.rotation.set(surface==='wall'?-.5:surface==='ceiling'?Math.PI:0,Math.PI/2,0);}
   const walker=new T.Vector3(mix(4,-.6,clamp(after/4,0,1)),0,1.2);defender.position.copy(walker);
   balls.forEach((o,k)=>{const u=(after-.5-k*.85)/.45;const live=u>0&&u<1&&!off;o.visible=live;if(live){o.position.copy(perch.clone().lerp(walker.clone().add(new T.Vector3(0,1.1,0)),u));}if(u>=1&&!off)shots++;});
   damage=.12*shots;
   if(counter){const u=(after-1)/.5;shot.visible=u>0&&u<1;shot.position.copy(walker.clone().add(new T.Vector3(0,1.1,0)).lerp(perch,clamp(u,0,1)));if(off&&after<1.8)showBurst(perch,1,(after-1.5)/.3);}
  }
  if(index===5){
   const footing=new T.Vector3(1.4,0,surface==='wall'?.35:0);
   column.visible=born&&after<4.5;column.position.set(footing.x,1.7,footing.z);column.scale.set(s(after/.3),1,s(after/.3));
   const approach=s((after-.2)/.7);defender.position.set(mix(-1.2,1.4,approach),0,footing.z+(counter?1.7*s(after/.7):0));
   if(!counter&&after>.9){lifted=3*s((after-.9)/1.3);defender.position.y=lifted;}
   dragon.visible=t<3.25;
  }
  if(index===6){
   vent.visible=born;vent.position.copy(point);vent.quaternion.setFromUnitVectors(up,normal);
   const cycle=(after%1.5)/1.5;jetOn=born&&cycle<.5;
   const length=surface==='wall'?2.2:surface==='ceiling'?2.6:2.5;
   if(jetOn){stream.visible=true;aimAt(stream,point.clone().addScaledVector(normal,length),point);stream.scale.x=stream.scale.z=.8+.15*Math.sin(t*22);}
   // Crossing: mistimed walks into the jet, the answer waits for the gap.
   const startMove=counter?1.5:1.1,u=s((after-startMove)/.55);defender.position.set(mix(-.2,3,u),0,surface==='wall'?.4:0);
   const nearJet=Math.abs(defender.position.x-1.4)<.45;hurtByJet=nearJet&&jetOn;
   damage=!counter&&after>startMove+.25?.3:0;
   dragon.visible=t<3.25;
  }
  if(index===7){
   // Rises under him as he passes, runs the length of the shot, then burns out.
   const fade=1-s((after-3.4)/.7);dragon.visible=t<3.25;
   curtain.forEach((cone,k)=>{const x=cone.userData.x,passed=t-(x+6.3)/7.7*3,rise=s(passed/.28)*fade;cone.visible=rise>.02;if(!cone.visible)return;const flick=1+.14*Math.sin(t*11+k*1.7)+.08*Math.sin(t*19+k*2.9),height=2.1*rise*flick*(.82+.18*Math.sin(k*2.3));cone.position.set(x,height/2,.05*Math.sin(k*1.9));cone.scale.set(1,height,1);});
   curtainUp=t>1&&fade>.02;
   if(counter){const u=s((after-.2)/1.3),v=s((after-1.4)/1);defender.position.set(mix(-1,2.45,u),0,mix(-2.1,1.9,v));walk(defender,after<2.4?1:0,t);}
   else{const v=s((after-.3)/1.3);defender.position.set(-1,0,mix(-2.1,1.9,v));walk(defender,after>.3&&after<1.6?1:0,t);crossedThrough=defender.position.z>0;burning=crossedThrough&&after<3;damage=crossedThrough?.3:0;
    burn.forEach((o,k)=>{o.visible=burning;o.position.set(defender.position.x+(k-1)*.22,1.2+.28*Math.sin(t*9+k*2)+.2*k,defender.position.z);o.scale.setScalar(.9);});}
  }
  if(born){bar.visible=true;bar.position.copy(defender.position).add(new T.Vector3(0,2.03,0));bar.scale.x=Math.max(.02,1-damage);}
  last={index,surface,relativeDamage:damage,secondPass,breathing,blocked,burning,detonated,shots,knockedOff,lifted,jetOn,hurtByJet,curtainUp,crossedThrough,defender:defender.position.toArray()};
 }
 return {render,metrics:()=>last};
}
