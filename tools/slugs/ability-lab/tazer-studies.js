import * as T from 'three';
const idea=(name,kind,impact,clever,answer,pairing)=>({name,slug:'tazer',kind,role:'TAZERLING / '+(kind==='main'?'PLAYER HIT':'SURFACE PASSIVE'),short:name,tagline:impact.split('. ')[0]+'.',impact,clever,answer,pairing,visual:'Thin yellow-white arcs, blue contact points and neutral slug forms. Timings, movement and health are illustrative.',choice:'Watch the effect, then compare the response.',use:'The opponent commits to the affected route. The effect works without another slug.',counter:'The opponent responds to the visible electrical effect.',beats:['Aim at a player for the main or a surface for the passive.','The neutral slug spins and expands in flight.','Contact activates the electrical effect.','Watch the payoff and compare the response.'],counterbeat:answer});
const priorTazerChoices=[
 idea('Chain Lightning','main','The hit deals damage, then arcs to nearby opponents for reduced damage. Each jump needs a nearby visible target; it never stuns or freezes anyone.',
 'Punish grouped opponents with one clear hit. Short jumps and falling damage reward choosing the right first target.',
 'Spread out before the shot or use solid cover between players. A direct hit still counts, but an isolated target gives the arc nowhere to jump.',
 'Crashwave could pressure a group before this shot. Wet-conductivity interactions remain possible inspiration, not selected rules.'),
 idea('Surge','main','Landing the hit deals damage and briefly boosts the shooter’s movement speed.',
 'Earn a short burst of mobility to chase, retreat or change angle. The target retains normal movement, aim and firing.',
 'Keep the faster shooter in sight or use cover to deny their new angle. The speed boost is short and grants no damage immunity.',
 'A later Silkline traversal could start with more momentum. Whether boosts carry into other movement systems remains open.'),
 idea('Static Mark','main','The hit deals damage and briefly reveals the struck opponent’s position through cover to your team.',
 'Track a retreat and choose a better next angle. It provides information rather than stopping the target or bending later shots.',
 'Keep repositioning while marked, use another exit or wait out the short reveal. Knowing a position does not let a projectile pass through solid cover.',
 'The information could guide a later Backdraft angle or a teammate’s rotation. It is useful even without an elemental partner.'),
 idea('Livewire','passive','Surface impact leaves a small electrified contact patch. An opponent touching it takes electrical damage; floors, walls and ceilings only affect players who actually contact the patch.',
 'Protect a route or a close wall traversal with a visible local hazard. It does not stun, pull or cover the whole room.',
 'Avoid the charged patch or take another route. The preview compares contact with a path around it.',
 'Electricity amplifies water: it can electrify water effects such as Crashwave and Mistbank. Exactly how is still to be decided.'),
 idea('Charge Pad','passive','Surface impact leaves a visible charged pad. Touching it grants one short movement-speed boost, then spends the pad.',
 'Place a boost on your route or a teammate’s crossing. A wall or ceiling pad only triggers on actual traversal contact. Either team could use it.',
 'Avoid giving the enemy a useful boost, or deliberately take it yourself. It adds no direct damage and does not launch or bind the toucher.',
 'A boosted approach could lead into Silkline. Team access, repeat rules and momentum carry remain proposals.'),
 idea('Arc Sensor','passive','Surface impact plants a short-lived electrical sensor. A nearby opponent entering its small radius is briefly revealed to your team.',
 'Watch a flank or an exit from behind cover. The visible sensor works on floors, walls or ceilings without slowing the detected player.',
 'Shoot the exposed sensor before entering its range or use another route. It provides a temporary ping rather than permanent tracking.',
 'A ping could warn you that someone is approaching Ice Wall’s open side. It does not automatically attack or select another slug.'),
].map((c,i)=>({...c,tazerIndex:i+1}));
export const tazerConcepts=priorTazerChoices.filter(c=>[1,4].includes(c.tazerIndex)).map(c=>({...c,confirmed:true}));

export function createTazerStudy({scene,mesh,box,line,mat,label,walk}){
 const root=new T.Group();scene.add(root);const clamp=T.MathUtils.clamp,mix=T.MathUtils.lerp,s=x=>{x=clamp(x,0,1);return x*x*(3-2*x);},up=new T.Vector3(0,1,0);
 const electric=new T.MeshBasicMaterial({color:0xf4e39c}),blue=new T.MeshStandardMaterial({color:0x78bbcc,emissive:0x234f63,roughness:.4});
 const small=mesh(new T.SphereGeometry(.35,24,16),mat(0xb9c5c9),root),large=mesh(new T.SphereGeometry(.65,24,16),mat(0xb9c5c9),root);
 const wall=box(root,1.4,1.5,-.55,4.8,3,.16,mat(0x354550));
 const ceiling=box(root,1.4,3.15,0,4.8,.12,3,new T.MeshStandardMaterial({color:0x506772,transparent:true,opacity:.16,side:T.DoubleSide,depthWrite:false}),false);
 const blocker=box(root,2.3,.9,0,.22,1.8,1.6,mat(0x354550));
 const patch=new T.Group();root.add(patch);mesh(new T.CylinderGeometry(.95,1.05,.06,32),blue,patch);for(let k=0;k<6;k++){const a=k/6*Math.PI*2;line(patch,[[0,.05,0],[Math.cos(a)*.4,.05,Math.sin(a)*.4],[Math.cos(a+.15)*.8,.05,Math.sin(a+.15)*.8]],0xf4e39c,.018);}
 const node=mesh(new T.OctahedronGeometry(.2),blue,root);
 const ring=mesh(new T.TorusGeometry(1.3,.014,6,64),electric,root);
 const mark=new T.Group();root.add(mark);const frame=mesh(new T.TorusGeometry(.4,.022,6,4),electric,mark);frame.rotation.z=Math.PI/4;frame.position.y=2.1;line(mark,[[-.42,.15,.3],[-.42,1.7,.3],[.42,1.7,.3],[.42,.15,.3]],0xf4e39c,.017);
 const speed=new T.Group();root.add(speed);for(const z of [-.25,.25])line(speed,[[-.6,.3,z],[-1.3,.3,z],[-1.55,.5,z]],0xf4e39c,.024);
 mark.traverse(o=>{if(o.isMesh){o.material.depthTest=false;o.material.depthWrite=false;o.renderOrder=4;}});
 const shooterLabel=label('SHOOTER','#bfd9dc',1.6);root.add(shooterLabel);
 const bars=[box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false),box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false),box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false)];
 function bolt(){const group=new T.Group();root.add(group);const segments=Array.from({length:9},()=>mesh(new T.CylinderGeometry(.014,.014,1,6),electric,group));return {group,segments};}
 const bolts=[bolt(),bolt(),bolt()];
 function arc(b,a,z,t){const points=[];for(let k=0;k<=9;k++){const u=k/9;points.push(a.clone().lerp(z,u).add(new T.Vector3(0,Math.sin(k*4+t*25)*.10*Math.sin(Math.PI*u),Math.cos(k*3+t*21)*.08*Math.sin(Math.PI*u))));}b.segments.forEach((o,i)=>{const delta=points[i+1].clone().sub(points[i]);o.position.copy(points[i]).addScaledVector(delta,.5);o.quaternion.setFromUnitVectors(up,delta.clone().normalize());o.scale.set(1,Math.max(.001,delta.length()),1);});}
 let last={};
 function render({index=0,t,surface='floor',counter=false,defender,ally,secondary}){
  root.visible=index>0;if(!index)return;
  for(const o of [wall,ceiling,blocker,patch,node,ring,mark,speed,shooterLabel,...bars,...bolts.map(b=>b.group)])o.visible=false;
  const passive=index>3,after=Math.max(0,t-3),born=t>3,build=s(after/.18),normal=surface==='wall'?new T.Vector3(0,0,1):surface==='ceiling'?new T.Vector3(0,-1,0):up;
  const point=new T.Vector3(1.4,surface==='wall'?1.1:surface==='ceiling'?3.04:.05,surface==='wall'?-.43:0);
  const destination=passive?point:new T.Vector3(1.4,1.1,0);small.visible=t<1.3;large.visible=t>.83&&t<3.3;const grow=s((t-.75)/.8),flight=clamp(t/3,0,1);
  for(const o of [small,large]){o.position.set(mix(-6.3,destination.x,flight),mix(1.24,destination.y,s((t-1.8)/1.2)),destination.z*s((t-1.8)/1.2));o.rotation.set(0,-Math.PI/2+Math.PI*2*s(t-.3),0);}
  small.scale.setScalar(Math.max(.01,1-.8*grow));large.scale.set(.75,.75,1.5).multiplyScalar((.15+grow)*(1-s(after/.3)));
  defender.visible=true;defender.position.set(1.4,0,0);defender.rotation.set(0,0,0);walk(defender,0,t);ally.visible=false;secondary.visible=false;
  let damage=passive?0:.2*build,secondDamage=0,thirdDamage=0,jumps=0,boosted=false,revealed=false,contact=false,consumed=false,broken=false,shooterX=-3.5;
  if(index===1){
   secondary.visible=true;ally.visible=true;secondary.position.set(counter?4.4:2.6,0,0);ally.position.set(counter?5.8:3.8,0,.6);
   jumps=born&&!counter?2:0;secondDamage=jumps?.12*build:0;thirdDamage=jumps?.07*build:0;
   for(let k=0;k<2;k++){bolts[k].group.visible=born&&after<.65&&!counter;arc(bolts[k],[defender,secondary][k].position.clone().add(new T.Vector3(0,1.1,0)),[secondary,ally][k].position.clone().add(new T.Vector3(0,1.1,0)),t);}
  }
  if(index===2){
   ally.visible=true;shooterX=-3.5+(counter?1:3.2)*s(after/2.2);ally.position.set(shooterX,0,counter?1.3*s(after):0);walk(ally,after<2.2?1:0,t);boosted=born&&after<2.2;speed.visible=boosted;speed.position.copy(ally.position);shooterLabel.visible=true;shooterLabel.position.copy(ally.position).add(new T.Vector3(0,2.35,0));blocker.visible=counter;
  }
  if(index===3){
   defender.position.set(1.4+1.6*s(after/2),0,-1.4*s(after/1.3));blocker.visible=born;revealed=born&&after<2.6;mark.visible=revealed;mark.position.copy(defender.position);mark.traverse(o=>{if(o.isMesh)o.renderOrder=4;});
   if(counter)defender.position.x+=1.4*s((after-1)/1.4);
  }
  if(passive){
   wall.visible=surface==='wall';ceiling.visible=surface==='ceiling';patch.visible=born&&after<3.8;patch.position.copy(point);patch.quaternion.setFromUnitVectors(up,normal);patch.scale.setScalar(build);
   const approach=s((after-.2)/1);defender.position.set(mix(-1.2,1.4,approach),surface==='ceiling'?.95*Math.sin(Math.PI*clamp((after-.2)/1.8,0,1)):0,surface==='wall'?.1:0);if(counter)defender.position.z=1.9*approach;
   contact=after>1&&!counter;
   if(index===4){damage=contact?.2*s((after-1)/.4):0;bolts[0].group.visible=contact&&after<2.5;arc(bolts[0],point,defender.position.clone().add(new T.Vector3(0,.6,0)),t);}
   if(index===5){consumed=contact;patch.visible=born&&!consumed&&after<3.8;boosted=contact&&after<2.8;if(contact){defender.position.x=1.4+3*s((after-1)/1.5);defender.position.y=0;}speed.visible=boosted;speed.position.copy(defender.position);}
   if(index===6){patch.visible=false;node.visible=born&&!(counter&&after>.8);node.position.copy(point).addScaledVector(normal,.2);node.rotation.y=t;broken=counter&&after>.8;revealed=after>1&&!broken&&after<2.8;mark.visible=revealed;mark.position.copy(defender.position);ring.visible=node.visible;ring.position.copy(point);ring.quaternion.setFromUnitVectors(new T.Vector3(0,0,1),normal);ring.scale.setScalar(.5+((after*.5)%1));}
  }
  [defender,secondary,ally].forEach((actor,i)=>{bars[i].visible=actor.visible&&born;bars[i].position.copy(actor.position).add(new T.Vector3(0,2.03,0));bars[i].scale.x=1-[damage,secondDamage,thirdDamage][i];});
  last={index,surface,relativeDamage:damage,secondaryDamage:secondDamage,thirdDamage,jumps,boosted,revealed,contact,consumed,broken,shooterX,defender:defender.position.toArray()};
 }
 return {render,metrics:()=>last};
}
