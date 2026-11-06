import * as T from 'three';
const idea=(name,kind,impact,clever,answer,pairing)=>({name,slug:'gas',kind,role:'FLATULORHINKUS / '+(kind==='main'?'PLAYER HIT':'SURFACE PASSIVE'),short:name,tagline:impact.split('. ')[0].replace(/\.$/,'')+'.',impact,clever,answer,pairing,visual:'Green stink clouds, neutral slug forms and health bars. Timings, movement and health are illustrative.',choice:'Watch the effect, then compare the response.',use:'The effect works without another slug.',counter:'The opponent responds to the gas.',beats:['Aim at a player for the main or a surface for the passive.','The neutral slug spins and expands in flight.','Contact activates the gas effect.','Watch the payoff and compare the response.'],counterbeat:answer});

const priorGasChoices=[
 idea('Reek','main','The hit leaves the target stinking, and their teammates near them cough and slow down.',
 'It punishes a team for grouping up: the hit player becomes a problem for their own side. The opposite of Tornado, which groups people.',
 'Spread out from the stinking player until it wears off.',
 'Tornado drags a reeking player into their own team. Wind blows gas away, so Tormato can also clear it.'),
 idea('Nauseate','main','The hit makes the target feel sick, so their aim sways for a moment.',
 'Shoot first and win the trade, because their reply goes wide. Simple, and it suits a disgusting slug.',
 'Wait a moment before shooting back, or close in where sway matters less.',
 'Close to Tangle: both weaken the reply. Only one of them should be picked.'),
 idea('Stink Cloud','passive','Hitting a surface leaves a stinking cloud where nobody can heal. From a wall or ceiling it sinks to the floor below.',
 'The answer to healing: cover Healing Spring or a hurt enemy’s retreat. Familiar from anti-heal abilities in hero shooters.',
 'Fight outside it, or heal somewhere else.',
 'Directly answers Boon Doc. Fire could ignite it into a burst, if that rule is approved.'),
 idea('Gas Jet','passive','Hitting a surface blasts out a burst of gas that pushes away anyone close to it.',
 'Shoot at your feet to blast-jump, or push enemies off a ledge or out of cover.',
 'Keep away from where it lands, or use the push yourself.',
 'Movement like Bloom Pad but instant and less controlled. Pushing someone into Fire Curtain or a Bramble patch is a tech.'),
 idea('Rebound','main','Landing a hit blasts you backwards on a burst of gas, away from the target.',
 'Hit and run: take a close fight, land the shot and you are already escaping. It suits a slug that cannot stand its own smell.',
 'Do not chase into the open, or dodge so they get no escape.',
 'Rebound out of a Bramble patch or away from Fire Curtain. A miss leaves you standing close.'),
 idea('Horn Charge','main','Landing a hit sends you charging straight at the target, like a rhino.',
 'Close the gap for a fight up close: land the hit from range and you arrive before they reset.',
 'Back off after being hit, or punish the charge, because a charging player runs straight at you.',
 'Charge into a group Tornado gathered, or a target Tangle has weakened.'),
 idea('Gross Out','main','The hit grosses the target out, so their next shots do nothing when they hit a surface for a while.',
 'Switch off their passive: no Ice Wall, no Updraft, no Healing Spring until it wears off.',
 'Wait it out, or fight with direct hits, which still work.',
 'Takes away cover and escape before a push. A different job from Tangle, which weakens their next hit on a player.'),
 idea('Nausea','main','The hit leaves the target sick, so their next slug cannot transform, flies slowly and does less damage.',
 'The owner’s idea: the target chooses between firing a weak shot now or waiting for the sickness to pass.',
 'Wait for the sickness to wear off before shooting back.',
 'The same effect as Vinedrill’s Tangle for now; the owner will make them different in the detailed pass.'),
].map((c,i)=>({...c,gasIndex:i+1}));
export const gasConcepts=priorGasChoices.filter(c=>[8,3].includes(c.gasIndex)).map(c=>({...c,confirmed:true}));

export function createGasStudy({scene,mesh,box,mat,walk}){
 const root=new T.Group();scene.add(root);const clamp=T.MathUtils.clamp,mix=T.MathUtils.lerp,s=x=>{x=clamp(x,0,1);return x*x*(3-2*x);};
 const fog=new T.MeshBasicMaterial({color:0xa9c46a,transparent:true,opacity:.32,depthWrite:false}),sick=new T.MeshBasicMaterial({color:0xb9d27a,transparent:true,opacity:.7,depthWrite:false}),heal=new T.MeshBasicMaterial({color:0x8fe0a0,transparent:true,opacity:.7,depthWrite:false});
 const small=mesh(new T.SphereGeometry(.35,24,16),mat(0xb3bf8a),root),large=mesh(new T.SphereGeometry(.65,24,16),mat(0xb3bf8a),root);
 const wall=box(root,1.4,1.5,-.55,4.8,3,.16,mat(0x354550));
 const ceiling=box(root,1.4,3.15,0,4.8,.12,3,new T.MeshStandardMaterial({color:0x506772,transparent:true,opacity:.16,side:T.DoubleSide,depthWrite:false}),false);
 const cloud=new T.Group();root.add(cloud);const puffs=Array.from({length:11},(_,k)=>{const p=mesh(new T.SphereGeometry(.42,14,10),fog,cloud);const a=k*2.4,r=.85*Math.sqrt((k+.5)/11);p.userData={x:Math.cos(a)*r,z:Math.sin(a)*r,y:.35+.3*(k%3)};return p;});
 const rings=[0,1].map(()=>mesh(new T.TorusGeometry(.25,.03,6,20),sick,root));
 const motes=Array.from({length:6},()=>mesh(new T.SphereGeometry(.05,8,6),heal,root));
 const reply=mesh(new T.SphereGeometry(.2,14,10),mat(0xc48a8a),root);
 const bars=[box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false)];
 const burst=mesh(new T.SphereGeometry(.5,14,10),fog,root),noRing=mesh(new T.TorusGeometry(.3,.04,8,24),sick,root),splat=mesh(new T.CylinderGeometry(.25,.25,.03,16),mat(0x6d7468),root),pop=mesh(new T.TorusGeometry(.5,.05,8,32),new T.MeshBasicMaterial({color:0x9fd0e8,transparent:true,opacity:.7,depthWrite:false}),root);pop.rotation.x=Math.PI/2;splat.position.set(3,.02,0);
 const replyBig=mesh(new T.SphereGeometry(.45,16,12),mat(0xc48a8a),root);
 let last={};
 function render({index=0,t,surface='floor',counter=false,defender,ally,secondary}){
  root.visible=index>0;if(!index)return;
  for(const o of [wall,ceiling,cloud,reply,replyBig,burst,noRing,splat,pop,...rings,...motes,...bars])o.visible=false;
  const passive=index===3||index===4,after=Math.max(0,t-3),born=t>3,flight=clamp(t/3,0,1),grow=s((t-.75)/.8);
  const point=!passive?new T.Vector3(1.4,1.1,0):surface==='wall'?new T.Vector3(1.4,1.1,-.43):surface==='ceiling'?new T.Vector3(1.4,3.04,0):new T.Vector3(1.4,.05,0);
  small.visible=t<1.3;large.visible=t>.83&&t<3.15;
  for(const o of [small,large])o.position.set(mix(-6.3,point.x,flight),mix(1.24,point.y,s((t-1.8)/1.2)),point.z*s((t-1.8)/1.2));
  small.scale.setScalar(Math.max(.01,1-.8*grow));large.scale.setScalar((.15+grow)*(1-s(after/.15)));
  defender.visible=true;defender.position.set(1.4,0,0);defender.rotation.set(0,0,0);walk(defender,0,t);ally.visible=false;secondary.visible=false;
  const puff=(at,size,lift=0)=>{cloud.visible=size>.02;cloud.position.copy(at);puffs.forEach((p,k)=>{p.position.set(p.userData.x*size+.06*Math.sin(t*2+k),p.userData.y*size+lift,p.userData.z*size+.06*Math.cos(t*2+k));p.scale.setScalar(size*(1+.08*Math.sin(t*3+k)));});};
  let damage=born&&!passive?.15:0,reeking=false,teammateSlowed=false,spread=0,nauseous=false,replyMissed=false,replyHit=false,healBlocked=false,health=1,pushed=0,rebounded=0,charged=0,passiveBlocked=false,passiveWorks=false,sick=false,replyWeak=false,replyTransformed=false;
  const dodge=!passive&&counter&&index>4;if(dodge){defender.position.z=1.8*s((t-1.9)/.8);walk(defender,t>1.9&&t<2.7?1:0,t);damage=0;large.visible=t>.83&&t<3.4;large.scale.setScalar(.15+grow);if(t>3)large.position.x=1.4+(t-3)*6;}
  if(!passive){ally.visible=true;ally.position.set(-5.5,0,0);ally.rotation.set(0,Math.PI/2,0);}
  if(index===1){
   // The stinking player walks on; their teammate either stays close and slows, or spreads out.
   const go=s((after-.3)/3);defender.position.x=born?mix(1.4,3.4,go):1.4;walk(defender,born&&after>.3&&after<3.3?1:0,t);
   secondary.visible=true;secondary.rotation.set(0,0,0);
   if(counter){const away=s((after-.2)/1);secondary.position.set(mix(1.4,2.6,away),0,mix(.9,-2.6,away));walk(secondary,after>.2&&after<1.2?1:0,t);}
   else{secondary.position.set(born?mix(1.4,2.2,go):1.4,0,.9);walk(secondary,born&&after>.3&&after<3.3?1:0,t);}
   reeking=born&&after<4.2;if(reeking)puff(defender.position,.9*s(after/.3));
   spread=Math.hypot(secondary.position.x-defender.position.x,secondary.position.z-defender.position.z);teammateSlowed=reeking&&spread<1.6;
  }
  if(index===2&&born){
   nauseous=after<2.4;if(nauseous){defender.rotation.z=.22*Math.sin(after*5);rings.forEach((r,k)=>{r.visible=true;r.rotation.x=Math.PI/2;r.position.copy(defender.position).add(new T.Vector3(.15*Math.sin(t*4+k*3),2.3+k*.12,.15*Math.cos(t*4+k*3)));});}
   // Their reply goes wide while sick, straight once it wears off.
   const fire=counter?2.6:.8,fly=clamp((after-fire)/.9,0,1);reply.visible=after>fire&&fly<1;
   reply.position.set(mix(1.2,-5.4,fly),1.2,counter?0:2.6*Math.sin(fly*Math.PI*.6));
   replyMissed=!counter&&after>fire+.9;replyHit=counter&&after>fire+.9;
  }
  if(index===5){
   ally.position.set(-3.6,0,0);
   if(!dodge&&born){const u=clamp(after/.8,0,1);ally.position.set(mix(-3.6,-6.4,s(u)),1.6*Math.sin(Math.PI*u),mix(0,1.2,s(u)));rebounded=-3.6-ally.position.x;if(after<.6){burst.visible=true;burst.position.set(-3.3,1,0);burst.scale.setScalar(1+after*3);}}
  }
  if(index===6){
   ally.position.set(-4.6,0,0);
   if(!dodge&&born){const u=s(after/.6);ally.position.x=mix(-4.6,.5,u);walk(ally,after<.6?1:0,t);charged=ally.position.x+4.6;}
  }
  if(index===7){
   // The target tries to use a surface: nothing while grossed out, a passive once it wears off.
   const fire=counter?2.6:.8,fly=clamp((after-fire)/.5,0,1),landed=born&&after>fire+.5;
   if(born){reply.visible=after>fire&&fly<1;reply.position.set(mix(1.6,3,fly),mix(1.2,.05,fly),0);}
   const gross=born&&after<2.4;if(gross){noRing.visible=true;noRing.position.copy(defender.position).add(new T.Vector3(0,2.35,0));noRing.rotation.y=t*2;}
   passiveBlocked=landed&&!counter;passiveWorks=landed&&counter;splat.visible=passiveBlocked;
   if(passiveWorks){pop.visible=true;pop.position.set(3,.05,0);pop.scale.setScalar(1+((after-fire-.5)%1)*1.2);}
  }
  if(index===8&&born){
   sick=after<2.4;if(sick){defender.rotation.z=.08*Math.sin(after*4);rings.forEach((r,k)=>{r.visible=true;r.rotation.x=Math.PI/2;r.position.copy(defender.position).add(new T.Vector3(.15*Math.sin(t*4+k*3),2.3+k*.12,.15*Math.cos(t*4+k*3)));});puff(defender.position,.5*s(after/.3)*(1-s((after-2.1)/.3)),.6);}
   // Weak and slow while sick; full size and fast once it passes.
   const fire=counter?2.6:.8,go=after-fire,fly=clamp(go/(counter?.7:1.8),0,1),shot=counter?replyBig:reply;
   shot.visible=go>0&&fly<1;shot.position.set(mix(1.2,-5.4,fly),counter?1.2:mix(1.2,.4,fly),0);
   replyWeak=!counter&&go>0;replyTransformed=counter&&go>0;
  }
  if(passive){wall.visible=surface==='wall';ceiling.visible=surface==='ceiling';}
  const spot=new T.Vector3(1.4,0,surface==='wall'?.3:0);
  if(index===3){
   const life=s(after/.4);if(born)puff(spot,1.2*life);
   if(counter){defender.position.x=mix(1.4,3.9,s((after-.6)/.8));walk(defender,after>.6&&after<1.4?1:0,t);}
   const inside=born&&Math.hypot(defender.position.x-spot.x,defender.position.z-spot.z)<1.2;healBlocked=inside;
   // Healing from elsewhere only counts outside the cloud.
   const outside=counter?clamp(after-1.4,0,2):0;health=Math.min(1,.4+.3*outside);
   motes.forEach((m,k)=>{m.visible=born&&!inside;const a=k*1.05+t*1.4;m.position.set(defender.position.x+Math.cos(a)*.45,.3+((t*.8+k*.2)%1)*1.6,defender.position.z+Math.sin(a)*.45);});
  }
  if(index===4){
   if(born&&after<1.2)puff(point,.4+1.4*s(after/.4),0);
   const near=!counter;defender.position.set(near?2.2:4.4,0,near?0:1.8);
   if(near&&born){const u=s(after/.9);defender.position.x=mix(2.2,5.3,u);defender.position.y=2.2*Math.sin(Math.PI*clamp(after/.9,0,1));pushed=defender.position.x-2.2;}
  }
  bars[0].visible=born&&index!==4;bars[0].position.copy(defender.position).add(new T.Vector3(0,2.03,0));bars[0].scale.x=Math.max(.02,index===3?health:1-damage);
  last={index,surface,relativeDamage:damage,sick,replyWeak,replyTransformed,rebounded,charged,passiveBlocked,passiveWorks,reeking,teammateSlowed,spread,nauseous,replyMissed,replyHit,healBlocked,health,pushed,defender:defender.position.toArray()};
 }
 return {render,metrics:()=>last};
}
