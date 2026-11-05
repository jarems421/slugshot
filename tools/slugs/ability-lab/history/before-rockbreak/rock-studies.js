import * as T from 'three';
const idea=(name,kind,impact,clever,answer,pairing)=>({name,slug:'rock',kind,role:'RAMMSTONE / '+(kind==='main'?'PLAYER HIT':'SURFACE PASSIVE'),short:name,tagline:impact.split('. ')[0]+'.',impact,clever,answer,pairing,visual:'Grey stone chunks, an amber warning ring and neutral slug forms. Timings, movement and health are illustrative.',choice:'Watch the effect, then compare the response.',use:'The opponent commits to the affected route. The effect works without another slug.',counter:'The opponent responds to the visible electrical effect.',beats:['Aim at a player for the main or a surface for the passive.','The neutral slug spins and expands in flight.','Contact activates the electrical effect.','Watch the payoff and compare the response.'],counterbeat:answer});
export const rockConcepts=[
 idea('Battering Ram','main','The hit deals damage and knocks the target straight back. If they hit a wall or other solid surface, they take bonus slam damage.',
 'Aim with what is behind your target in mind. Catch someone with their back to a wall for the big hit, or knock them off a ledge or out of position.',
 'Stay away from walls when under fire, or stand where the shot’s angle would knock you somewhere safe. In the open it is only a shove.',
 'Differs from Backdraft: this shove is instant and rewards the wall behind the target. Backdraft is delayed and rewards the shot angle.'),
 idea('Momentum','main','The further the shot travels before it hits, the more damage it deals. A long shot hits very hard; a close shot is weak.',
 'A pure skill shot: reward for landing long-range hits. It has no extra effect to learn, just heavy damage for good aim at range.',
 'Close the distance, because up close it barely hurts. Move unpredictably at range, since a long shot takes time to arrive.',
 'Pairs with anything that holds someone at range. Snapbind makes a long shot easier to land, and Mistbank can cover the approach that beats it.'),
 idea('Breakthrough','main','The shot smashes through the first placed barrier in its path, destroying it, and still hits whoever is behind it.',
 'The answer to set-up play. Break Ice Wall or other placed cover and punish the player relying on it, all in one shot.',
 'Do not stand directly behind your cover: step to the side so the shot breaks the barrier but misses you. Natural map walls still stop it.',
 'A direct counter to Ice Wall, and to future placed cover. This makes the two slugs interact without either needing special rules.'),
 idea('Rockfall','passive','Hitting a surface cracks it. After a short warning, rocks fall below the impact: from a ceiling or wall they drop, and from a floor they burst up and come down.',
 'Hit the ceiling above a doorway to threaten it, or time the warning so someone has to leave cover. One burst, then it is gone.',
 'Watch for the crack and warning circle, then step out. The delay gives plenty of time unless something else is holding you there.',
 'Snapbind holds a target under the rocks, and Battering Ram can shove someone into the zone. A single burst rather than a lasting patch like Livewire.'),
 idea('Upheaval','passive','The hit leaves a stone slab. Anyone stepping on it gets thrown away from the surface: up from a floor, outward from a wall, down from a ceiling.',
 'Launch yourself to high ground, or place it where an opponent will run. A player in the air is an easy target for your next shot.',
 'Walk around the slab. It does no damage and works on anyone, so you can also use an enemy’s slab yourself.',
 'Throw someone up, then land Chain Lightning or Momentum on them. Whether Silkline can carry the launch speed is still open.'),
 idea('Stonestep','passive','The hit grows a lasting rock ledge: a ramp on a floor, a platform on a wall and a hanging pillar from a ceiling. Anyone can use it until it is shot down.',
 'Build your own route to a high angle, or a new way around a defended corner. It changes the map for a while.',
 'Shoot it down, or use it yourself. Either team can stand on it, so a careless ledge can help the enemy.',
 'A wall platform gives a new anchor point near Silkline routes. Unlike Ice Wall, it is built to stand on rather than to hide behind.'),
].map((c,i)=>({...c,rockIndex:i+1}));

export function createRockStudy({scene,mesh,box,line,mat,label,walk}){
 const root=new T.Group();scene.add(root);const clamp=T.MathUtils.clamp,mix=T.MathUtils.lerp,s=x=>{x=clamp(x,0,1);return x*x*(3-2*x);},up=new T.Vector3(0,1,0);
 const stone=mat(0x8d8578),dark=mat(0x5e584f),warn=new T.MeshBasicMaterial({color:0xe8b35c}),barrierMat=new T.MeshStandardMaterial({color:0xa9d3dc,roughness:.35,transparent:true,opacity:.85});
 const small=mesh(new T.SphereGeometry(.35,24,16),mat(0xa89c88),root),large=mesh(new T.DodecahedronGeometry(.65),stone,root);
 const backWall=box(root,3.65,1.5,0,.24,3,3,mat(0x354550));
 const wall=box(root,1.4,1.5,-.55,4.8,3,.16,mat(0x354550));
 const ceiling=box(root,1.4,3.15,0,4.8,.12,3,new T.MeshStandardMaterial({color:0x506772,transparent:true,opacity:.16,side:T.DoubleSide,depthWrite:false}),false);
 const barrier=box(root,.4,.8,0,.2,1.6,1.8,barrierMat);
 const ring=mesh(new T.TorusGeometry(1,.022,6,48),warn,root);ring.rotation.x=Math.PI/2;
 const crack=new T.Group();root.add(crack);for(let k=0;k<5;k++){const a=k/5*Math.PI*2;line(crack,[[0,.02,0],[Math.cos(a)*.3,.02,Math.sin(a)*.3],[Math.cos(a+.4)*.6,.02,Math.sin(a+.4)*.6]],0x2d2822,.02);}
 const chunks=Array.from({length:9},(_,k)=>{const piece=mesh(new T.DodecahedronGeometry(.12+.05*(k%3)),k%2?stone:dark,root);piece.userData={a:k*2.4,r:.15+.1*(k%5),d:k*.03};return piece;});
 const slab=box(root,0,0,0,1.5,.2,1.5,stone);
 const ramp=box(root,0,0,0,2,.16,1.3,stone),ledge=box(root,0,0,0,1.7,.2,.95,stone),pillar=mesh(new T.CylinderGeometry(.34,.18,1.9,9),stone,root);
 const bars=[box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false),box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false)];
 const streak=[0,1,2].map(()=>mesh(new T.CylinderGeometry(.018,.018,1,6),warn,root));
 let last={};
 function render({index=0,t,surface='floor',counter=false,defender,ally,secondary}){
  root.visible=index>0;if(!index)return;
  for(const o of [backWall,wall,ceiling,barrier,ring,crack,slab,ramp,ledge,pillar,...chunks,...bars,...streak])o.visible=false;
  const passive=index>3,after=Math.max(0,t-3),born=t>3;
  const normal=surface==='wall'?new T.Vector3(0,0,1):surface==='ceiling'?new T.Vector3(0,-1,0):up;
  const point=new T.Vector3(1.4,surface==='wall'?1.1:surface==='ceiling'?3.04:.05,surface==='wall'?-.43:0);
  let targetX=1.4;if(index===2&&counter)targetX=-3.2;
  const destination=passive?point:new T.Vector3(targetX,1.1,index===3&&counter?0:0);
  small.visible=t<1.3;large.visible=t>.83&&t<3.2;const grow=s((t-.75)/.8),flight=clamp(t/3,0,1);
  for(const o of [small,large]){o.position.set(mix(-6.3,destination.x,flight),mix(1.24,destination.y,s((t-1.8)/1.2)),destination.z*s((t-1.8)/1.2));o.rotation.set(t*3,-Math.PI/2+Math.PI*2*s(t-.3),0);}
  small.scale.setScalar(Math.max(.01,1-.8*grow));large.scale.setScalar((.15+grow)*(1-s(after/.2)));
  defender.visible=true;defender.position.set(1.4,0,0);defender.rotation.set(0,0,0);walk(defender,0,t);ally.visible=false;secondary.visible=false;
  let damage=0,knocked=false,slammed=false,barrierBroken=false,warning=false,fell=false,inZone=false,launched=false,ledgeUp=false,height=0;
  if(index===1){
   damage=born?.2:0;
   if(!counter)backWall.visible=true;
   const reach=counter?3.9:3.25,shove=s(after/.32);
   defender.position.x=mix(1.4,reach,shove);knocked=born;defender.rotation.z=-.35*Math.sin(Math.PI*clamp(after/.5,0,1));
   slammed=!counter&&after>.3;if(slammed)damage=.46;
  }
  if(index===2){
   ally.visible=true;ally.position.set(-6.3,0,0);defender.position.x=targetX;walk(defender,counter?.3:0,t);
   damage=born?(counter?.1:.46):0;
   streak.forEach((o,k)=>{o.visible=t>1.6&&t<3.05&&!counter;o.position.set(mix(-6.3,destination.x,flight)-1.1-k*.45,large.position.y+(k-1)*.2,(k-1)*.2);o.rotation.z=Math.PI/2;o.scale.y=.9;});
  }
  if(index===3){
   barrierBroken=t>=2.62;barrier.visible=!barrierBroken;
   defender.position.set(1.4,0,counter?1.7*s((t-1.7)/.8):0);walk(defender,counter&&t<2.5?1:0,t);
   damage=born&&!counter?.28:0;
   const since=t-2.62;chunks.forEach((piece,k)=>{const shown=barrierBroken&&since<1.1;piece.visible=shown;if(shown)piece.position.set(.4+since*(1+k*.25),Math.max(.1,.2+k*.16+1.3*since-3.4*since*since),(k-4)*.1*(1+since*2));});
  }
  if(passive){
   wall.visible=surface==='wall';ceiling.visible=surface==='ceiling';
   crack.visible=born;crack.position.copy(point);crack.quaternion.setFromUnitVectors(up,normal);
  }
  if(index===4){
   const zone=new T.Vector3(1.4,.03,surface==='wall'?.35:0),delay=.95;warning=born&&after<delay+.45;ring.visible=warning;ring.position.copy(zone);
   defender.position.set(mix(-1.2,1.4,s(after/.7)),0,zone.z);if(counter)defender.position.x+=2.2*s((after-.7)/.5);
   walk(defender,after<.7||(counter&&after<1.2)?1:0,t);
   const since=after-delay;fell=born&&since>.3;inZone=defender.position.distanceTo(new T.Vector3(zone.x,0,zone.z))<1.1;
   chunks.forEach((piece,k)=>{const u=since-piece.userData.d,shown=u>0&&u<.85;piece.visible=shown;if(!shown)return;const a=piece.userData.a,r=piece.userData.r*2;let y;if(surface==='floor')y=Math.max(.1,4.6*u-6.2*u*u);else y=Math.max(.1,point.y-6*u*u);piece.position.set(zone.x+Math.cos(a)*r,y,zone.z+Math.sin(a)*r);});
   damage=fell&&inZone?.34:0;
  }
  if(index===5){
   const pop=s((after-.95)/.14),approach=s((after-.2)/.75);
   slab.visible=born;slab.quaternion.setFromUnitVectors(up,normal);slab.position.copy(point).addScaledVector(normal,.08+.22*pop*(1-s((after-1.3)/.5)));
   defender.position.set(mix(-1.2,1.4,approach),0,surface==='wall'?.15:0);
   if(counter)defender.position.z+=1.9*s(after/.7);
   walk(defender,after<.95?1:0,t);
   launched=!counter&&after>.95;
   if(launched){const u=clamp((after-.95)/1.25,0,1),arc=Math.sin(Math.PI*u);defender.rotation.x=-.5*arc;
    if(surface==='floor')defender.position.y=2.6*arc;
    if(surface==='wall'){defender.position.z=.15+2.1*u;defender.position.y=1.1*arc;}
    if(surface==='ceiling'){defender.position.y=.5*arc;defender.position.x=1.4+.9*u;}
    height=defender.position.y;}
  }
  if(index===6){
   const raise=s((after-.05)/.45),gone=counter&&after>1.5;ledgeUp=born&&!gone;
   if(surface==='floor'){ramp.visible=ledgeUp;ramp.position.set(1.4,.5*raise,0);ramp.rotation.set(0,0,.55*raise);}
   if(surface==='wall'){ledge.visible=ledgeUp;ledge.position.set(1.4,1.1,-.43+.45*raise);}
   if(surface==='ceiling'){pillar.visible=ledgeUp;pillar.position.set(1.4,3.08-.95*raise,0);pillar.scale.setScalar(Math.max(.02,raise));}
   const walkOn=s((after-.45)/.85);
   const zSpot=surface==='wall'?.1:surface==='ceiling'?1.1:0;
   defender.position.set(mix(-1.2,surface==='floor'?2.05:1.4,walkOn),0,zSpot);walk(defender,after>.45&&after<1.3?1:0,t);
   const ontop=surface==='floor'?1.05*clamp((defender.position.x-.6)/1.45,0,1):surface==='wall'?(walkOn>.8?1.25*s((after-1.1)/.25):0):0;
   defender.position.y=ledgeUp?ontop:Math.max(0,ontop-(after-1.5)*6);height=defender.position.y;
   if(gone)chunks.forEach((piece,k)=>{const u=after-1.5,shown=u<.9;piece.visible=shown;if(shown)piece.position.set(1.4+(k-4)*.13*(1+u),Math.max(.1,point.y*.45-3*u*u+k*.05),(k%3-1)*.2*(1+u)+(surface==='wall'?.2:0));});
  }
  [defender].forEach((actor,i)=>{bars[i].visible=actor.visible&&(born||index===2);bars[i].position.copy(actor.position).add(new T.Vector3(0,2.03,0));bars[i].scale.x=Math.max(.02,1-damage);bars[i].material.color.set(damage>.4?0xd77a5c:damage>0?0xd9b45c:0xa7c98f);});
  last={index,surface,relativeDamage:damage,knocked,slammed,barrierBroken,warning,fell,inZone,launched,ledgeUp,height,defender:defender.position.toArray()};
 }
 return {render,metrics:()=>last};
}
