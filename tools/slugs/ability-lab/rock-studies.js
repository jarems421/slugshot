import * as T from 'three';
const idea=(name,kind,impact,clever,answer,pairing)=>({name,slug:'rock',kind,role:'RAMMSTONE / '+(kind==='main'?'PLAYER HIT':'SURFACE PASSIVE'),short:name,tagline:impact.split('. ')[0]+'.',impact,clever,answer,pairing,visual:'Grey stone chunks, an amber warning ring and neutral slug forms. Timings, movement and health are illustrative.',choice:'Watch the effect, then compare the response.',use:'The opponent commits to the affected route. The effect works without another slug.',counter:'The opponent responds to the rock before it lands.',beats:['Aim at a player for the main or a surface for the passive.','The neutral slug spins and expands in flight.','Contact activates the rock effect.','Watch the payoff and compare the response.'],counterbeat:answer});
const priorRockChoices=[
 idea('Punch','main','The hit is a strong punch and nothing else. There is no extra effect to learn.',
 'Pure aim. Rammstone’s depth comes from what it does to the map, so on a player it just needs to feel heavy.',
 'Dodge it or use cover. Nothing lingers after the hit.',
 'Works with anything that sets up a clean shot, such as Snapbind, or a target falling behind a blocked route.'),
 idea('Shove Punch','main','The hit is a strong punch that also knocks the target back a short way.',
 'Still simple, but it makes the punch look and feel physical, and it can knock someone out of cover or into a dangerous spot.',
 'Dodge it or use cover. Watch what is behind you.',
 'Could shove someone under a falling spire. It sits closer to Backdraft than the plain punch does, though this push is instant and Backdraft’s is delayed.'),
 idea('Rockbreak','passive','Hitting the ground punches a rock wall up as cover. Hitting part of the map breaks it: an arch drops rock that blocks the pathway below, and a spire comes down on whoever is under it. A plain wall or ceiling drops a little rubble on anyone below, and knocks a wall-runner off.',
 'Reshape the fight. Make cover where there is none, seal a route you do not want to defend, or drop a spire on someone who stands in the wrong place. Maps will be built around these moments.',
 'Flank a rock wall, cross a threatened arch before it falls or take another route, and step out from under a spire when it starts to go.',
 'Hold someone under a spire with Snapbind, or seal an exit so Chain Lightning finds a tighter group. Unlike Ice Wall, this also changes routes and can hurt people.'),
].map((c,i)=>({...c,rockIndex:i+1}));
export const rockConcepts=priorRockChoices.filter(c=>c.rockIndex>1).map(c=>({...c,confirmed:true}));

export function createRockStudy({scene,mesh,box,line,mat,label,walk}){
 const root=new T.Group();scene.add(root);const clamp=T.MathUtils.clamp,mix=T.MathUtils.lerp,s=x=>{x=clamp(x,0,1);return x*x*(3-2*x);};
 const stone=mat(0x8d8578),dark=mat(0x5e584f),warn=new T.MeshBasicMaterial({color:0xe8b35c});
 const small=mesh(new T.SphereGeometry(.35,24,16),mat(0xa89c88),root),large=mesh(new T.DodecahedronGeometry(.65),stone,root);
 const coverWall=box(root,1.4,.85,0,.42,1.7,2.4,stone);
 const enemyShot=mesh(new T.SphereGeometry(.14,14,10),warn,root);
 const pillars=[box(root,.15,1.3,0,.5,2.6,.6,dark),box(root,2.65,1.3,0,.5,2.6,.6,dark)];
 const lintel=box(root,1.4,2.8,0,3,.5,.6,stone);
 const rubble=Array.from({length:7},(_,k)=>{const piece=mesh(new T.DodecahedronGeometry(.34+.1*(k%3)),k%2?stone:dark,root);piece.userData={x:(k-3)*.34,z:(k%3-1)*.22};return piece;});
 const spire=mesh(new T.ConeGeometry(.42,1.9,9),stone,root);
 const roof=box(root,1.4,3.75,0,4.8,.12,3,new T.MeshStandardMaterial({color:0x506772,transparent:true,opacity:.16,side:T.DoubleSide,depthWrite:false}),false);
 const ring=mesh(new T.TorusGeometry(.95,.022,6,48),warn,root);ring.rotation.x=Math.PI/2;
 const burst=mesh(new T.TorusGeometry(.45,.03,6,32),warn,root);
 const chunks=Array.from({length:8},(_,k)=>mesh(new T.DodecahedronGeometry(.08+.04*(k%3)),k%2?stone:dark,root));
 const bar=box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false);
 let last={};
 function render({index=0,t,surface='floor',counter=false,defender,ally,secondary}){
  root.visible=index>0;if(!index)return;
  for(const o of [coverWall,enemyShot,...pillars,lintel,...rubble,spire,roof,ring,burst,...chunks,bar])o.visible=false;
  const passive=index===3,after=Math.max(0,t-3),born=t>3;
  const point=!passive?new T.Vector3(1.4,1.1,0):surface==='wall'?new T.Vector3(1.4,2.8,0):surface==='ceiling'?new T.Vector3(1.4,2.75,0):new T.Vector3(1.4,.05,0);
  small.visible=t<1.3;large.visible=t>.83&&t<3.15;const grow=s((t-.75)/.8),flight=clamp(t/3,0,1);
  for(const o of [small,large]){o.position.set(mix(-6.3,point.x,flight),mix(1.24,point.y,s((t-1.8)/1.2)),0);o.rotation.set(t*3,-Math.PI/2+Math.PI*2*s(t-.3),0);}
  small.scale.setScalar(Math.max(.01,1-.8*grow));large.scale.setScalar((.15+grow)*(1-s(after/.15)));
  defender.visible=true;defender.position.set(1.4,0,0);defender.rotation.set(0,0,0);walk(defender,0,t);ally.visible=false;secondary.visible=false;
  let damage=0,knocked=false,coverUp=false,shotBlocked=false,flanked=false,pathBlocked=false,stoppedAtRubble=false,crossed=false,warning=false,spireFell=false;
  if(!passive){
   if(counter){defender.position.z=1.9*s((t-1.9)/.8);walk(defender,t>1.9&&t<2.7?1:0,t);large.visible=t>.83&&t<3.5;large.scale.setScalar(.15+grow);if(t>3)large.position.x=1.4+(t-3)*6;}
   else{damage=born?.3:0;burst.visible=born&&after<.3;burst.position.set(1.4,1.1,0);burst.rotation.y=Math.PI/2;burst.scale.setScalar(1+after*5);
    if(index===1)defender.rotation.z=-.16*Math.sin(Math.PI*clamp(after/.3,0,1));
    if(index===2){knocked=born;defender.position.x=mix(1.4,3,s(after/.35));defender.rotation.z=-.3*Math.sin(Math.PI*clamp(after/.5,0,1));}}
  }
  if(passive&&surface==='floor'){
   const rise=s(after/.18);coverWall.visible=born;coverWall.scale.y=Math.max(.02,rise);coverWall.position.y=.85*rise;coverUp=born;
   chunks.forEach((piece,k)=>{const shown=born&&after<.55;piece.visible=shown;if(shown)piece.position.set(1.4+(k-4)*.1,Math.max(.05,2.4*after-5*after*after+.05*k),(k%4-1.5)*.5*(1+after*2));});
   ally.visible=true;ally.position.set(.3,0,0);
   defender.position.set(3.4,0,counter?2.1*s((after-.3)/1):0);walk(defender,counter&&after>.3&&after<1.3?1:0,t);
   const shotTime=after-.6;
   if(!counter){enemyShot.visible=shotTime>0&&shotTime<.35;enemyShot.position.set(3.4-4.5*shotTime,1.1,0);shotBlocked=shotTime>.35;}
   else{flanked=after>1.3;enemyShot.visible=after>1.4&&after<1.9;enemyShot.position.set(mix(3.4,.3,(after-1.4)/.5),1.1,mix(2.1,0,(after-1.4)/.5));damage=after>1.9?.2:0;bar.visible=true;}
   if(damage>0){bar.position.copy(ally.position).add(new T.Vector3(0,2.03,0));bar.scale.x=1-damage;}
  }
  if(passive&&surface==='wall'){
   const fall=s((after-.8)/.42);warning=born&&after<1.2;
   pillars.forEach(o=>{o.visible=true;});lintel.visible=t<3.8+.42;lintel.position.y=2.8-2.4*fall;lintel.rotation.z=.2*fall;
   ring.visible=warning;ring.position.set(1.4,.03,0);ring.scale.set(1.35,.7,1);
   const down=after>1.2;pathBlocked=down;rubble.forEach((piece,k)=>{piece.visible=down;if(down){piece.position.set(1.4+piece.userData.x,.3+.3*(k%2),piece.userData.z);}});
   const speed=counter?4.6:1.7,z=-3+speed*after;
   defender.position.x=1.4;
   if(!counter){const stop=Math.min(z,-.95);defender.position.z=stop;stoppedAtRubble=down&&stop===-.95;walk(defender,z<-.95?1:0,t);}
   else{defender.position.z=Math.min(z,2.3);crossed=z>0&&after<1.2;walk(defender,z<2.3?1:0,t);}
  }
  if(passive&&surface==='ceiling'){
   roof.visible=true;const delay=.9,fall=clamp((after-delay)/.32,0,1);warning=born&&after<delay+.32;
   spire.visible=after<delay+.75;spire.rotation.x=Math.PI;spire.position.set(1.4,mix(2.78,.9,fall*fall),0);spire.rotation.z=born&&after<delay?.05*Math.sin(after*50):0;
   ring.visible=warning;ring.scale.set(1,1,1);ring.position.set(1.4,.03,0);
   defender.position.set(1.4+(counter?2.2*s((after-.35)/.5):0),0,0);walk(defender,counter&&after>.35&&after<.85?1:0,t);
   spireFell=after>delay+.32;damage=spireFell&&!counter?.4:0;
   chunks.forEach((piece,k)=>{const u=after-delay-.32,shown=u>0&&u<.6;piece.visible=shown;if(shown)piece.position.set(1.4+Math.cos(k*.8)*u*2.6,Math.max(.05,2.2*u-5*u*u+.1),Math.sin(k*.8)*u*2.6);});
  }
  if(!(passive&&surface==='floor')&&born){bar.visible=true;bar.position.copy(defender.position).add(new T.Vector3(0,2.03,0));bar.scale.x=Math.max(.02,1-damage);}
  last={index,surface,relativeDamage:damage,knocked,coverUp,shotBlocked,flanked,pathBlocked,stoppedAtRubble,crossed,warning,spireFell,defender:defender.position.toArray()};
 }
 return {render,metrics:()=>last};
}
