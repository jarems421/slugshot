import * as T from 'three';
const idea=(name,kind,impact,clever,answer,pairing)=>({name,slug:'tormato',kind,role:'TORMATO / '+(kind==='main'?'PLAYER HIT':'SURFACE PASSIVE'),short:name,tagline:impact.split('. ')[0].replace(/\.$/,'')+'.',impact,clever,answer,pairing,visual:'Pale wind rings, neutral slug forms and health bars. Timings, movement and health are illustrative.',choice:'Watch the effect, then compare the response.',use:'The effect works without another slug.',counter:'The opponent responds to the wind.',beats:['Aim at a player for the main or a surface for the passive.','The neutral slug spins and expands in flight.','Contact activates the wind effect.','Watch the payoff and compare the response.'],counterbeat:answer});

const priorTormatoChoices=[
 idea('Tornado','main','The hit leaves a tornado on the spot that drags nearby opponents in. They can still walk, aim and fire, but moving away is harder.',
 'A utility hit: pull people off an angle and bunch them together for your team. It sets up the group-hitters without doing their job.',
 'Move straight away at the edge, where the pull is weakest, or wait it out behind cover.',
 'Bunches people for Chain Lightning, Iceburst and Crashwave. Wind carries things, so it could also pick up fire, mist or sparks it passes through.'),
 idea('Windbreak','passive','Hitting a surface raises a spinning wall of wind. Enemy slugs flying through it slow right down and cannot transform. Players walk through it freely.',
 'Shoot it in front of you to shut down incoming shots. It is your answer to anything that needs its big form, and players can still walk through to fight.',
 'Shoot around it, come from another angle, or walk through and fight up close. It stops slugs, not people.',
 'A slowed slug that cannot transform lands weak, which directly answers Inferno’s dragon. It also makes a set-up safer, such as healing on a Healing Spring.'),
 idea('Updraft','passive','Hitting a surface starts a rising column of wind that lifts anyone who steps in, on either team.',
 'Reach high angles or escape upward. A player rising in a straight line is an easy target, so it is a risk as well as a route.',
 'Walk around it, use it yourself, or shoot whoever is riding it.',
 'A lifted target is easy for any slug to hit, and it gives movement away from Silkline’s anchors.'),
].map((c,i)=>({...c,tormatoIndex:i+1}));
export const tormatoConcepts=priorTormatoChoices.filter(c=>[1,3].includes(c.tormatoIndex)).map(c=>({...c,confirmed:true}));

export function createTormatoStudy({scene,mesh,box,mat,walk}){
 const root=new T.Group();scene.add(root);const clamp=T.MathUtils.clamp,mix=T.MathUtils.lerp,s=x=>{x=clamp(x,0,1);return x*x*(3-2*x);},up=new T.Vector3(0,1,0);
 const wind=new T.MeshBasicMaterial({color:0xcfe6ea,transparent:true,opacity:.6,depthWrite:false}),soft=new T.MeshBasicMaterial({color:0xcfe6ea,transparent:true,opacity:.2,side:T.DoubleSide,depthWrite:false});
 const small=mesh(new T.SphereGeometry(.35,24,16),mat(0xb5c9c0),root),large=mesh(new T.SphereGeometry(.65,24,16),mat(0xb5c9c0),root);
 const wall=box(root,1.4,1.5,-.55,4.8,3,.16,mat(0x354550));
 const ceiling=box(root,1.4,3.15,0,4.8,.12,3,new T.MeshStandardMaterial({color:0x506772,transparent:true,opacity:.16,side:T.DoubleSide,depthWrite:false}),false);
 const funnel=new T.Group();root.add(funnel);const rings=Array.from({length:9},(_,k)=>{const ring=mesh(new T.TorusGeometry(.22+k*.13,.022,6,32),wind,funnel);ring.rotation.x=Math.PI/2;ring.position.y=.1+k*.3;return ring;});
 const sheet=new T.Group();root.add(sheet);const streaks=Array.from({length:36},(_,k)=>{const streak=mesh(new T.BoxGeometry(.7,.035,.035),wind,sheet);streak.userData={k};return streak;});
 const pane=mesh(new T.PlaneGeometry(3.6,2.7),soft,sheet);pane.rotation.y=Math.PI/2;pane.position.y=1.35;
 const column=mesh(new T.CylinderGeometry(.75,.75,3.4,24,1,true),soft,root);
 const enemySlug=mesh(new T.SphereGeometry(.2,14,10),mat(0xc48a8a),root),enemyBig=mesh(new T.SphereGeometry(.42,16,12),mat(0xc48a8a),root);
 const bars=[0,1,2].map(()=>box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false));
 let last={};
 function render({index=0,t,surface='floor',counter=false,defender,ally,secondary}){
  root.visible=index>0;if(!index)return;
  for(const o of [wall,ceiling,funnel,sheet,column,enemySlug,enemyBig,...bars])o.visible=false;
  const passive=index>1,after=Math.max(0,t-3),born=t>3,flight=clamp(t/3,0,1),grow=s((t-.75)/.8);
  const point=!passive?new T.Vector3(1.4,1.1,0):surface==='wall'?new T.Vector3(1.4,1.1,-.43):surface==='ceiling'?new T.Vector3(1.4,3.04,0):new T.Vector3(1.4,.05,0);
  small.visible=t<1.3;large.visible=t>.83&&t<3.15;
  for(const o of [small,large])o.position.set(mix(-6.3,point.x,flight),mix(1.24,point.y,s((t-1.8)/1.2)),point.z*s((t-1.8)/1.2));
  small.scale.setScalar(Math.max(.01,1-.8*grow));large.scale.setScalar((.15+grow)*(1-s(after/.15)));
  defender.visible=true;defender.position.set(1.4,0,0);defender.rotation.set(0,0,0);walk(defender,0,t);ally.visible=false;secondary.visible=false;
  let damage=0,dragged=false,distance=0,escaped=false,slugSlowed=false,transformed=false,lifted=0;
  const spin=(rise=1)=>{funnel.visible=true;funnel.rotation.y=t*7;rings.forEach((r,k)=>{r.scale.setScalar(rise*(1+.06*Math.sin(t*9+k)));r.position.x=.06*Math.sin(t*5+k);});};
  if(index===1){
   damage=born?.15:0;const life=s(after/.3)*(1-s((after-3.6)/.5));
   if(born&&life>.02){funnel.position.set(1.4,0,0);spin(life);}
   const pull=s((after-.2)/1.8)*(1-s((after-3.4)/.6));
   secondary.visible=true;secondary.position.set(mix(3.9,2.25,pull),0,mix(-1.6,-.5,pull));walk(secondary,0,t);
   ally.visible=true;ally.rotation.set(0,0,0);
   if(counter){const away=s((after-.1)/1.2);ally.position.set(mix(3.3,5.1,away),0,mix(1.7,2.6,away));walk(ally,after>.1&&after<1.3?1:0,t);escaped=born;}
   else{ally.position.set(mix(3.3,2.2,pull),0,mix(1.7,.55,pull));walk(ally,0,t);}
   dragged=pull>.5;distance=Math.hypot(ally.position.x-1.4,ally.position.z);
  }
  if(passive){wall.visible=surface==='wall';ceiling.visible=surface==='ceiling';}
  if(index===2){
   // A wall of wind across the path of an enemy shot coming from the right.
   const life=s(after/.3)*(1-s((after-4.1)/.5));
   sheet.visible=born&&life>.02;sheet.position.set(1.4,0,surface==='wall'?-.2:0);
   streaks.forEach((o,k)=>{const col=k%6,row=Math.floor(k/6);o.position.set(.03*Math.sin(t*9+k),.2+row*.46+.07*Math.sin(t*6+k),(-1.8+((col*.6+t*1.9+row*.3)%3.6))*life);o.rotation.y=Math.PI/2;o.scale.x=life;});
   pane.scale.set(life,life,1);
   ally.visible=true;ally.position.set(-1.3,0,0);ally.rotation.set(0,Math.PI/2,0);
   defender.position.set(5.3,0,counter?2.1:0);
   const go=after-.8,fly=clamp(go/(counter?.65:.3),0,1);
   if(!counter){
    const beforeWall=go<.28,slowT=clamp((go-.28)/1.5,0,1),x=beforeWall?mix(5.2,1.5,clamp(go/.28,0,1)):mix(1.5,-.5,slowT),y=beforeWall?1.2:mix(1.2,.2,slowT*slowT);
    enemySlug.visible=go>0&&slowT<1;enemySlug.position.set(x,y,0);slugSlowed=go>.28;
   }else{
    const x=mix(5.2,-1.3,fly),z=mix(2.1,0,fly);transformed=fly>.3;enemySlug.visible=go>0&&!transformed;enemyBig.visible=transformed&&fly<1;enemySlug.position.set(x,1.2,z);enemyBig.position.set(x,1.2,z);
   }
  }
  if(index===3){
   const footing=new T.Vector3(1.4,0,surface==='wall'?.35:0);
   column.visible=born&&after<4.5;column.position.set(footing.x,1.7,footing.z);column.scale.set(s(after/.3),1,s(after/.3));
   funnel.visible=false;
   defender.position.set(mix(-1.2,1.4,s((after-.2)/.7)),0,footing.z+(counter?1.7*s(after/.7):0));walk(defender,after>.2&&after<.9?1:0,t);
   if(!counter&&after>.9){lifted=3*s((after-.9)/1.3);defender.position.y=lifted;}
  }
  [[defender,damage]].forEach(([actor,value],i)=>{bars[i].visible=actor.visible&&born;bars[i].position.copy(actor.position).add(new T.Vector3(0,2.03,0));bars[i].scale.x=Math.max(.02,1-value);});
  last={index,surface,relativeDamage:damage,dragged,distance,escaped,slugSlowed,transformed,lifted,defender:defender.position.toArray()};
 }
 return {render,metrics:()=>last};
}
