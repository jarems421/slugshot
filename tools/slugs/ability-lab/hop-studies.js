import * as T from 'three';
const idea=(name,kind,impact,clever,answer,pairing)=>({name,slug:'hop',kind,role:'HOP ROCK / '+(kind==='main'?'PLAYER HIT':'SURFACE PASSIVE'),short:name,tagline:impact.split('. ')[0].replace(/\.$/,'')+'.',impact,clever,answer,pairing,visual:'Orange sparks and blasts, neutral slug forms and health bars. Timings, movement and health are illustrative.',choice:'Watch the effect, then compare the response.',use:'The effect works without another slug.',counter:'The opponent responds to the explosive.',beats:['Aim at a player for the main or a surface for the passive.','The neutral slug spins and expands in flight.','Contact activates the explosive.','Watch the payoff and compare the response.'],counterbeat:answer});

const priorHopChoices=[
 idea('Fuse','main','The hit lights a fuse on the target. Hit them again before it burns out and it explodes for big damage.',
 'Rewards landing two shots in a row: the first is a threat, the second is the payoff. Nobody else rewards a follow-up hit.',
 'Break line of sight or dodge until the fuse burns out.',
 'Snapbind, Tangle or Bramble make the second hit much easier. A teammate’s hit does not set it off, only yours.'),
 idea('Sticky Bomb','main','The slug sticks to the target and explodes a moment later, hurting anyone close to them.',
 'A familiar sticky grenade: the target becomes a danger to their own team.',
 'Run away from your teammates before it goes off.',
 'A group-hitter, which the owner chose knowingly alongside Crashwave, Iceburst and Chain Lightning. Tornado gathers the group it punishes.'),
 idea('Mine','passive','Hitting a surface leaves a mine that explodes when an enemy comes close.',
 'Trap a route, a doorway or a healing spot. A familiar hero-shooter tool, and nobody else lays traps.',
 'Spot it and walk around it, or shoot it to set it off safely.',
 'Mines under Updraft or past a Bramble patch catch people where they have to go.'),
 idea('Blast Hop','passive','Hitting a surface makes a small blast that launches anyone standing close to it.',
 'Shoot at your feet to blast-jump onto a ledge or out of a fight.',
 'Shoot the player in the air, because a blast-jump is easy to predict.',
 'The movement option. Close to Gas Jet, which the owner did not pick.'),
].map((c,i)=>({...c,hopIndex:i+1}));
export const hopConcepts=priorHopChoices.filter(c=>[2,3].includes(c.hopIndex)).map(c=>({...c,confirmed:true}));

export function createHopStudy({scene,mesh,box,mat,walk}){
 const root=new T.Group();scene.add(root);const clamp=T.MathUtils.clamp,mix=T.MathUtils.lerp,s=x=>{x=clamp(x,0,1);return x*x*(3-2*x);};
 const fire=new T.MeshBasicMaterial({color:0xffa04a,transparent:true,opacity:.6,depthWrite:false}),spark=new T.MeshBasicMaterial({color:0xffd27a});
 const small=mesh(new T.SphereGeometry(.35,24,16),mat(0xb59a7a),root),large=mesh(new T.SphereGeometry(.65,24,16),mat(0xb59a7a),root);
 const wall=box(root,1.4,1.5,-.55,4.8,3,.16,mat(0x354550));
 const ceiling=box(root,1.4,3.15,0,4.8,.12,3,new T.MeshStandardMaterial({color:0x506772,transparent:true,opacity:.16,side:T.DoubleSide,depthWrite:false}),false);
 const fuse=mesh(new T.TorusGeometry(.42,.04,8,32),spark,root);fuse.rotation.x=Math.PI/2;
 const blast=mesh(new T.SphereGeometry(1,24,16),fire,root);
 const bomb=mesh(new T.SphereGeometry(.16,12,10),mat(0x3a3330),root),blink=mesh(new T.SphereGeometry(.06,8,6),new T.MeshBasicMaterial({color:0xff5040}),root);
 const mine=new T.Group();root.add(mine);mesh(new T.CylinderGeometry(.28,.32,.1,16),mat(0x3a3330),mine);const mineLight=mesh(new T.SphereGeometry(.07,8,6),new T.MeshBasicMaterial({color:0xff5040}),mine);mineLight.position.y=.08;
 const shot2=mesh(new T.SphereGeometry(.2,14,10),mat(0xb59a7a),root),enemyShot=mesh(new T.SphereGeometry(.2,14,10),mat(0xc48a8a),root);
 const bars=[0,1].map(()=>box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false));
 let last={};
 function render({index=0,t,surface='floor',counter=false,defender,ally,secondary}){
  root.visible=index>0;if(!index)return;
  for(const o of [wall,ceiling,fuse,blast,bomb,blink,mine,shot2,enemyShot,...bars])o.visible=false;
  const passive=index>2,after=Math.max(0,t-3),born=t>3,flight=clamp(t/3,0,1),grow=s((t-.75)/.8);
  const point=!passive?new T.Vector3(1.4,1.1,0):surface==='wall'?new T.Vector3(1.4,1.1,-.43):surface==='ceiling'?new T.Vector3(1.4,3.04,0):new T.Vector3(1.4,.05,0);
  small.visible=t<1.3;large.visible=t>.83&&t<3.15;
  for(const o of [small,large])o.position.set(mix(-6.3,point.x,flight),mix(1.24,point.y,s((t-1.8)/1.2)),point.z*s((t-1.8)/1.2));
  small.scale.setScalar(Math.max(.01,1-.8*grow));large.scale.setScalar((.15+grow)*(1-s(after/.15)));
  defender.visible=true;defender.position.set(1.4,0,0);defender.rotation.set(0,0,0);walk(defender,0,t);ally.visible=false;secondary.visible=false;
  const boom=(at,u,size=1.5)=>{if(u<=0||u>=1)return;blast.visible=true;blast.position.copy(at);blast.scale.setScalar(.3+size*u);fire.opacity=.7*(1-u);};
  let damage=born&&!passive?.1:0,fused=false,detonated=false,fizzled=false,exploded=false,teammateHit=false,triggered=false,launched=0,caught=false;
  if(!passive){ally.visible=true;ally.position.set(-5.5,0,0);ally.rotation.set(0,Math.PI/2,0);}
  if(index===1&&born){
   // A second shot from Hop Rock's player sets the fuse off, unless the target gets out of line.
   if(counter){defender.position.z=2.2*s((after-.3)/.6);walk(defender,after>.3&&after<.9?1:0,t);}
   const burn=clamp(after/3,0,1),go=clamp((after-1)/.6,0,1);detonated=!counter&&after>1.6;fizzled=counter&&burn>=1;fused=!detonated&&!fizzled;
   if(fused){fuse.visible=true;fuse.position.copy(defender.position).add(new T.Vector3(0,1.1,0));fuse.scale.setScalar(1-.75*burn);fuse.rotation.z=t*6;}
   shot2.visible=after>1&&go<1;shot2.position.set(mix(-5.2,1.4,go),1.2,0);
   boom(defender.position.clone().add(new T.Vector3(0,1,0)),(after-1.6)/.5,1.2);if(detonated)damage=.55;
  }
  if(index===2&&born){
   secondary.visible=true;secondary.position.set(1.4,0,.9);walk(secondary,0,t);
   if(counter){defender.position.x=mix(1.4,4.2,s((after-.1)/1));walk(defender,after>.1&&after<1.1?1:0,t);}
   exploded=after>1.5;if(!exploded){bomb.visible=true;bomb.position.copy(defender.position).add(new T.Vector3(.25,1.2,0));blink.visible=Math.sin(after*18)>0;blink.position.copy(bomb.position).add(new T.Vector3(0,.15,0));}
   boom(defender.position.clone().add(new T.Vector3(0,1,0)),(after-1.5)/.5,1.6);
   teammateHit=exploded&&Math.hypot(secondary.position.x-defender.position.x,secondary.position.z-defender.position.z)<1.6;if(exploded)damage=.4;
  }
  if(passive){wall.visible=surface==='wall';ceiling.visible=surface==='ceiling';}
  if(index===3){
   const at=point.clone();mine.visible=born;mine.position.copy(at);mine.rotation.set(surface==='wall'?Math.PI/2:surface==='ceiling'?Math.PI:0,0,0);mineLight.visible=Math.sin(t*6)>0;
   defender.rotation.set(0,-Math.PI/2,0);const xAt=a=>mix(4.6,-1.4,s((a-.2)/2.6));
   // The mine goes off when the walker first comes within range; they stop there.
   let tTrig=99;for(let a=0;a<8;a+=.02)if(Math.hypot(xAt(a)-at.x,at.z)<1.1){tTrig=a;break;}
   triggered=!counter&&born&&after>tTrig;
   defender.position.set(triggered?xAt(tTrig):xAt(after),0,counter?2.2:0);walk(defender,!triggered&&after>.2&&after<2.8?1:0,t);
   if(triggered){mine.visible=false;boom(at,(after-tTrig)/.5,1.4);damage=.3;}
  }
  if(index===4){
   ally.visible=true;ally.rotation.set(0,Math.PI/2,0);const spot=new T.Vector3(1.4,0,surface==='wall'?.3:0);
   boom(surface==='floor'?point:spot,after/.4,1);
   const air=clamp(after/1.2,0,1);ally.position.set(born?mix(1.1,3.6,air):1.1,born?3.2*Math.sin(Math.PI*air):0,spot.z);launched=ally.position.y;
   defender.position.set(5,0,1.8);defender.rotation.set(0,-2.4,0);
   if(counter){const go=clamp((after-.2)/.4,0,1);enemyShot.visible=born&&go<1;enemyShot.position.set(mix(4.8,mix(1.1,3.6,.5),go),mix(1.2,3.4,go),mix(1.7,spot.z,go));caught=after>.6;damage=caught?.15:0;}
  }
  const shown=index===2?[defender,secondary]:index===4?(counter?[ally]:[]):[defender];
  shown.forEach((a,i)=>{bars[i].visible=born;bars[i].position.copy(a.position).add(new T.Vector3(0,2.03,0));bars[i].scale.x=Math.max(.02,1-(i?(teammateHit?.4:0):damage));});
  last={index,surface,relativeDamage:damage,fused,detonated,fizzled,exploded,teammateHit,triggered,launched,caught,defender:defender.position.toArray()};
 }
 return {render,metrics:()=>last};
}
