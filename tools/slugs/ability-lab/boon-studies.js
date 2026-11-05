import * as T from 'three';
const idea=(name,kind,impact,clever,answer,pairing)=>({name,slug:'boon',kind,role:'BOON DOC / '+(kind==='main'?'PLAYER HIT':'SURFACE PASSIVE'),short:name,tagline:impact.split('. ')[0]+'.',impact,clever,answer,pairing,visual:'Soft green healing shapes, neutral slug forms and health bars. Timings, movement and health are illustrative.',choice:'Watch the effect, then compare the response.',use:'The effect works without another slug.',counter:'The opponent responds to the healing.',beats:['Aim at a player for the main or a surface for the passive.','The neutral slug spins and expands in flight.','Contact activates the healing effect.','Watch the payoff and compare the response.'],counterbeat:answer});

const priorBoonChoices=[
 idea('Mending Shot','main','Hit a teammate and it heals them. Hit an enemy and it damages them and heals you.',
 'Every shot heals someone, so it always does something useful, alone or in a team. Choosing who to shoot in a fight is the skill.',
 'Break the line to their teammate, dodge the shot so it heals nobody, or go after the healer first.',
 'Clears burns and binds, so it frees a teammate from Snapbind and removes Dragon’s Breath and Fire Curtain burns.'),
 idea('Leech','main','The hit damages the enemy and heals the shooter.',
 'Works even when you are alone: stay in the fight by landing your shots. Simple, and useful in any match.',
 'Dodge it, because a miss heals nothing.',
 'A target held by Snapbind or slowed by a crossing is easier to leech from. Less team play than Mending Shot.'),
 idea('Healing Spring','passive','Hitting a surface starts a small pool of gentle healing that lasts a while. You and your teammates recover health standing in it; enemies get nothing. It heals less than a direct shot.',
 'Set up a safe spot before a fight, or heal behind Ice Wall or rock cover. From a wall or ceiling it drips to the floor below.',
 'Force them off it, or shoot them while they stand still. A healer is easy to predict when pinned to a pool.',
 'Pairs naturally with any cover. Mistbank hides the pool, and Fire Curtain can guard it.'),
 idea('Health Pod','passive','Hitting a surface grows a pod that anyone can touch once for a burst of health. Enemies can take it too.',
 'Leave health along a route you plan to use, but place it carefully, because a careless pod heals the enemy.',
 'Grab it first, or shoot it before they reach it.',
 'Silkline can reach pods on high walls quickly, and Shove Punch can knock someone away from one.'),
].map((c,i)=>({...c,boonIndex:i+1}));
export const boonConcepts=priorBoonChoices.filter(c=>[1,3].includes(c.boonIndex)).map(c=>({...c,confirmed:true}));

export function createBoonStudy({scene,mesh,box,mat,walk}){
 const root=new T.Group();scene.add(root);const clamp=T.MathUtils.clamp,mix=T.MathUtils.lerp,s=x=>{x=clamp(x,0,1);return x*x*(3-2*x);},up=new T.Vector3(0,1,0);
 const green=new T.MeshBasicMaterial({color:0x8fe0a0,transparent:true,opacity:.55,depthWrite:false}),solid=new T.MeshStandardMaterial({color:0x7fc98d,emissive:0x1f5a33,roughness:.5});
 const small=mesh(new T.SphereGeometry(.35,24,16),mat(0xc9d6b4),root),large=mesh(new T.SphereGeometry(.65,24,16),mat(0xc9d6b4),root);
 const wall=box(root,1.4,1.5,-.55,4.8,3,.16,mat(0x354550));
 const ceiling=box(root,1.4,3.15,0,4.8,.12,3,new T.MeshStandardMaterial({color:0x506772,transparent:true,opacity:.16,side:T.DoubleSide,depthWrite:false}),false);
 const cover=box(root,.5,.9,0,.3,1.8,2,mat(0x354550));
 const pool=mesh(new T.CylinderGeometry(1.05,1.15,.05,32),green,root);
 const halo=mesh(new T.TorusGeometry(.5,.03,6,32),green,root);halo.rotation.x=Math.PI/2;
 const pod=mesh(new T.IcosahedronGeometry(.26),solid,root);
 const motes=Array.from({length:8},()=>mesh(new T.SphereGeometry(.05,8,6),green,root));
 const bars=[box(root,0,0,0,.8,.065,.025,mat(0x8fe0a0),false),box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false),box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false)];
 const shot=mesh(new T.SphereGeometry(.2,14,10),mat(0xc9d6b4),root);
 let last={};
 function render({index=0,t,surface='floor',counter=false,defender,ally,secondary}){
  root.visible=index>0;if(!index)return;
  for(const o of [wall,ceiling,cover,pool,halo,pod,shot,...motes,...bars])o.visible=false;
  const passive=index>2,after=Math.max(0,t-3),born=t>3,flight=clamp(t/3,0,1),grow=s((t-.75)/.8);
  const point=!passive?new T.Vector3(1.4,1.1,0):surface==='wall'?new T.Vector3(1.4,1.1,-.43):surface==='ceiling'?new T.Vector3(1.4,3.04,0):new T.Vector3(1.4,.05,0);
  const endX=index===1&&counter?.35:point.x;
  small.visible=t<1.3;large.visible=t>.83&&t<3.15;
  for(const o of [small,large])o.position.set(mix(-6.3,endX,flight),mix(1.24,point.y,s((t-1.8)/1.2)),point.z*s((t-1.8)/1.2));
  small.scale.setScalar(Math.max(.01,1-.8*grow));large.scale.setScalar((.15+grow)*(1-s(after/.15)));
  defender.visible=true;defender.position.set(1.4,0,0);defender.rotation.set(0,0,0);walk(defender,0,t);ally.visible=false;secondary.visible=false;
  // Health shown is teammate's on Boon Doc's side and enemy's on the other.
  let friend=.35,enemy=1,healed=false,blocked=false,inPool=false,podTaken=false,stolen=false,shooterHealed=false;
  const glowOn=(actor,on)=>{halo.visible=on;if(on){halo.position.copy(actor.position).add(new T.Vector3(0,1+.5*Math.sin(t*3),0));motes.forEach((m,k)=>{m.visible=true;const a=k*.785+t*1.4;m.position.set(actor.position.x+Math.cos(a)*.45,actor.position.y+.3+((t*.8+k*.2)%1)*1.6,actor.position.z+Math.sin(a)*.45);});}};
  let selfHealth=.4;
  if(index===1){
   // Two shots: one at the teammate, then one at an enemy, which heals the shooter.
   ally.visible=true;ally.position.set(-4.4,0,0);ally.rotation.set(0,Math.PI/2,0);
   secondary.visible=true;secondary.position.set(3.4,0,-1.6);walk(secondary,0,t);
   if(counter){cover.visible=true;blocked=born;secondary.position.z=mix(-1.6,.6,s((after-.9)/.7));walk(secondary,after>.9&&after<1.6?1:0,t);}
   else{healed=born;friend=mix(.35,1,s(after/.6));glowOn(defender,born&&after<1);}
   const fly=clamp((after-1.1)/.8,0,1);shot.visible=after>1.1&&fly<1;shot.position.set(mix(-4.1,3.4,fly),1.2,mix(0,-1.6,fly));
   const landed=!counter&&after>=1.9;shooterHealed=landed;enemy=landed?.72:1;selfHealth=landed?mix(.4,.8,s((after-1.9)/.5)):.4;if(landed)glowOn(ally,after<3.4);
  }
  if(index===2){
   ally.visible=true;ally.position.set(-4.2,0,0);ally.rotation.set(0,Math.PI/2,0);friend=.35;
   if(counter){defender.position.z=1.8*s((t-1.9)/.8);walk(defender,t>1.9&&t<2.7?1:0,t);large.visible=t>.83&&t<3.4;large.scale.setScalar(.15+grow);if(t>3)large.position.x=1.4+(t-3)*6;}
   else{enemy=born?.72:1;shooterHealed=born;friend=mix(.35,.7,s(after/.6));glowOn(ally,born&&after<2.2);}
  }
  if(passive){wall.visible=surface==='wall';ceiling.visible=surface==='ceiling';}
  if(index===3){
   const spot=new T.Vector3(1.4,.04,surface==='wall'?.5:0);
   pool.visible=born&&after<4.4;pool.position.copy(spot);pool.scale.set(s(after/.3),1,s(after/.3));
   const walkIn=s((after-.2)/.8);defender.position.set(mix(-1.2,1.4,walkIn),0,spot.z);walk(defender,after>.2&&after<1?1:0,t);
   const stayUntil=counter?1.9:9;
   if(after>stayUntil){const u=s((after-stayUntil)/.7);defender.position.x=mix(1.4,3.5,u);walk(defender,u<1?1:0,t);}
   inPool=born&&Math.hypot(defender.position.x-spot.x,defender.position.z-spot.z)<1.05;
   const inTime=clamp(Math.min(after,stayUntil+.25)-.8,0,3);friend=Math.min(1,.35+.28*inTime);healed=inTime>0;glowOn(defender,inPool&&healed);
  }
  if(index===4){
   const at=surface==='ceiling'?new T.Vector3(1.4,2.7,0):surface==='wall'?new T.Vector3(1.4,1,-.2):new T.Vector3(1.4,.55,0);
   const racer=counter?defender:ally;const other=counter?ally:defender;
   ally.visible=true;ally.rotation.set(0,Math.PI/2,0);defender.rotation.set(0,0,0);
   const reach=s((after-.2)/.9);
   racer.position.set(mix(counter?4.2:-1.4,1.4,reach),0,surface==='wall'?.15:0);walk(racer,after>.2&&after<1.1?1:0,t);
   other.position.set(counter?-2.2:4.2,0,1.2);walk(other,0,t);
   podTaken=after>=1.05;stolen=podTaken&&counter;
   pod.visible=born&&!podTaken;pod.position.copy(at);pod.scale.setScalar(s(after/.3));pod.rotation.y=t;
   if(!counter){friend=podTaken?.95:.35;healed=podTaken;enemy=1;}else{friend=.35;enemy=podTaken?1:.5;}
   glowOn(racer,podTaken&&after<2.2);
  }
  const shown=index===1?[ally,defender,secondary]:index===2||index===4?[ally,defender]:[defender];
  const values=index===1?[selfHealth,friend,enemy]:index===2||index===4?[friend,enemy]:[friend];
  shown.forEach((actor,i)=>{bars[i].visible=actor.visible;bars[i].position.copy(actor.position).add(new T.Vector3(0,2.03,0));bars[i].scale.x=Math.max(.02,values[i]);});
  last={index,surface,friendHealth:friend,enemyHealth:enemy,healed,blocked,inPool,podTaken,stolen,shooterHealed,defender:defender.position.toArray()};
 }
 return {render,metrics:()=>last};
}
