import * as T from 'three';
const idea=(name,kind,impact,clever,answer,pairing)=>({name,slug:'fright',kind,role:'FRIGHTGEIST / '+(kind==='main'?'PLAYER HIT':'SURFACE PASSIVE'),short:name,tagline:impact.split('. ')[0].replace(/\.$/,'')+'.',impact,clever,answer,pairing,visual:'Violet ghost shapes, neutral slug forms and health bars. Timings, movement and health are illustrative.',choice:'Watch the effect, then compare the response.',use:'The effect works without another slug.',counter:'The opponent responds to the haunting.',beats:['Aim at a player for the main or a surface for the passive.','The neutral slug spins and expands in flight.','Contact activates the fright effect.','Watch the payoff and compare the response.'],counterbeat:answer});

const priorFrightChoices=[
 idea('Jump Scare','main','The hit pops a ghostly face right in front of the target, scaring them for a moment, like a flash.',
 'The owner’s change: a scare instead of a run. The target is shaken for a moment, so your team can push.',
 'Dodge the shot. There is no element that counters it; you counter it by playing smart.',
 'Fright is immune to elements. It pairs with Decoy: scare them, then let the copy draw their fire.'),
 idea('Terrify','main','The hit terrifies the target, and they run away from you for a moment.',
 'The familiar fear effect: break up a push, or scare someone out of cover and into the open.',
 'Dodge the shot. Once scared, steer the run toward cover if you can.',
 'Replaced by Jump Scare.'),
 idea('Phantom Shot','main','The slug turns invisible halfway through its flight.',
 'Hard to dodge, so the skill is in leading the target. It suits a ghost and needs nothing else.',
 'Keep moving, because it still flies straight from where it was fired.',
 'Makes Frightgeist good at finishing hurt players who rely on dodging.'),
 idea('Haunt','main','The hit makes ghostly fake players appear around the target, seen only by them, for a while.',
 'The target wastes time and shots on fakes while your team closes in.',
 'The fakes never shoot. Watch for who shoots back.',
 'Lantern’s light shows which ones are fake, if light dispels illusions.'),
 idea('Decoy','passive','Hitting a surface makes a ghostly copy of you appear there, walking slowly to draw enemy fire.',
 'Fake a push or a flank, and make enemies give away where they are by shooting it. A familiar hero-shooter trick.',
 'Watch it: it never shoots. Shoot the real player instead.',
 'Light dispels illusions, so Lantern and Flash expose it.'),
 idea('Vanish','passive','Hitting a surface makes you invisible for a moment, until you shoot.',
 'Disappear to reposition or escape. The movement and stealth option.',
 'Shoot where they vanished, or use a reveal such as Lantern.',
 'Strong after Flash or Jump Scare, when nobody is watching you.'),
].map((c,i)=>({...c,frightIndex:i+1}));
export const frightConcepts=priorFrightChoices.filter(c=>[1,5].includes(c.frightIndex)).map(c=>({...c,confirmed:true}));

export function createFrightStudy({scene,mesh,box,mat,walk}){
 const root=new T.Group();scene.add(root);const clamp=T.MathUtils.clamp,mix=T.MathUtils.lerp,s=x=>{x=clamp(x,0,1);return x*x*(3-2*x);};
 const ghost=new T.MeshBasicMaterial({color:0xb7a2e8,transparent:true,opacity:.35,depthWrite:false}),wisp=new T.MeshBasicMaterial({color:0xc9b8f2,transparent:true,opacity:.6,depthWrite:false});
 const small=mesh(new T.SphereGeometry(.35,24,16),mat(0xb6aac8),root),large=mesh(new T.SphereGeometry(.65,24,16),mat(0xb6aac8),root);
 const wall=box(root,1.4,1.5,-.55,4.8,3,.16,mat(0x354550));
 const ceiling=box(root,1.4,3.15,0,4.8,.12,3,new T.MeshStandardMaterial({color:0x506772,transparent:true,opacity:.16,side:T.DoubleSide,depthWrite:false}),false);
 // Simple ghost figures stand in for fake players and the decoy.
 const figure=()=>{const g=new T.Group();root.add(g);mesh(new T.BoxGeometry(.5,.9,.3),ghost,g).position.y=.95;mesh(new T.SphereGeometry(.24,12,10),ghost,g).position.y=1.65;mesh(new T.BoxGeometry(.4,.55,.25),ghost,g).position.y=.28;return g;};
 const fakes=[0,1,2].map(figure),decoy=figure(),shade=figure();
 const wisps=Array.from({length:6},()=>mesh(new T.SphereGeometry(.07,8,6),wisp,root));
 const face=new T.Group();root.add(face);mesh(new T.SphereGeometry(.55,20,14),ghost,face);[-.18,.18].forEach(x=>{const eye=mesh(new T.SphereGeometry(.1,10,8),new T.MeshBasicMaterial({color:0x1a1424}),face);eye.position.set(x,.1,.45);});const mouth=mesh(new T.TorusGeometry(.14,.04,8,20),new T.MeshBasicMaterial({color:0x1a1424}),face);mouth.position.set(0,-.2,.47);
 const reply=mesh(new T.SphereGeometry(.2,14,10),mat(0xc48a8a),root);
 const bar=box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false);
 let last={};
 function render({index=0,t,surface='floor',counter=false,defender,ally,secondary}){
  root.visible=index>0;if(!index)return;
  for(const o of [wall,ceiling,face,reply,bar,decoy,shade,...fakes,...wisps])o.visible=false;
  const passive=index>4,after=Math.max(0,t-3),born=t>3,flight=clamp(t/3,0,1),grow=s((t-.75)/.8);
  const point=!passive?new T.Vector3(1.4,1.1,0):surface==='wall'?new T.Vector3(1.4,1.1,-.43):surface==='ceiling'?new T.Vector3(1.4,3.04,0):new T.Vector3(1.4,.05,0);
  const dodge=!passive&&counter&&index!==4;
  small.visible=t<1.3;large.visible=t>.83&&t<(dodge?3.4:3.15);
  for(const o of [small,large])o.position.set(mix(-6.3,point.x,flight)+(dodge&&t>3?(t-3)*6:0),mix(1.24,point.y,s((t-1.8)/1.2)),point.z*s((t-1.8)/1.2));
  small.scale.setScalar(Math.max(.01,1-.8*grow));large.scale.setScalar(dodge?.15+grow:(.15+grow)*(1-s(after/.15)));
  // Phantom Shot: gone from about halfway until just before impact.
  const hidden=index===3&&t>1.4&&t<2.85;if(hidden){small.visible=false;large.visible=false;}
  defender.visible=true;defender.position.set(1.4,0,0);defender.rotation.set(0,0,0);walk(defender,0,t);ally.visible=false;secondary.visible=false;
  if(dodge){defender.position.z=1.8*s((t-(index===3?1.2:1.9))/.8);walk(defender,t>1.2&&t<2.7?1:0,t);}
  const hit=!passive&&born&&!dodge;let damage=hit?.15:0,scared=false,feared=false,fled=0,haunted=false,shotAtFake=false,decoyUp=false,enemyFooled=false,invisible=false,found=false;
  const swirl=actor=>wisps.forEach((w,k)=>{w.visible=true;const a=k*1.05+t*2;w.position.set(actor.position.x+Math.cos(a)*.5,1.2+.5*Math.sin(t*3+k),actor.position.z+Math.sin(a)*.5);});
  if(!passive){ally.visible=true;ally.position.set(-5.5,0,0);ally.rotation.set(0,Math.PI/2,0);}
  if(index===1&&hit){
   // A face pops up in front of the target, who recoils and shakes.
   scared=after<1.8;const pop=s(after/.12)*(1-s((after-.7)/.3));
   face.visible=pop>.02;face.position.set(.5,1.6,0);face.rotation.y=Math.PI/2;face.scale.setScalar(.3+1.2*pop);
   defender.position.x=1.4+.5*s(after/.25);defender.rotation.set(scared?-.2*(1-after/1.8):0,0,scared?.12*Math.sin(after*20)*(1-after/1.8):0);
   if(scared)swirl(defender);
  }
  if(index===2&&hit){
   feared=after<1.6;const run=s((after-.1)/1.5);defender.position.x=mix(1.4,4.6,run);defender.rotation.y=Math.PI/2;walk(defender,feared?1:0,t);fled=defender.position.x-1.4;if(feared)swirl(defender);
  }
  if(index===4&&hit){
   haunted=after<4;const spots=[[3.2,1.6],[3.6,-1.4],[-.6,1.9]];
   fakes.forEach((f,k)=>{f.visible=haunted;f.position.set(spots[k][0]+.3*Math.sin(t+k),0,spots[k][1]);f.rotation.y=-Math.PI/2;});
   // The target shoots a fake, or ignores them and answers the real shooter.
   const go=clamp((after-.9)/.6,0,1),to=counter?new T.Vector3(-5.5,1.2,0):new T.Vector3(fakes[0].position.x,1.2,fakes[0].position.z);
   reply.visible=after>.9&&go<1;reply.position.lerpVectors(new T.Vector3(1.4,1.2,0),to,go);
   shotAtFake=!counter&&after>1.5;defender.rotation.y=Math.atan2(to.x-1.4,to.z);
  }
  if(passive){wall.visible=surface==='wall';ceiling.visible=surface==='ceiling';}
  const spot=new T.Vector3(1.4,0,surface==='wall'?.35:0);
  if(index===5){
   decoyUp=born&&after<4.5;decoy.visible=decoyUp;decoy.position.set(spot.x+.5*s(after/4),0,spot.z);decoy.rotation.y=Math.PI/2;
   ally.visible=true;ally.position.set(-3.4,0,2.4);ally.rotation.set(0,Math.PI/2,0);
   defender.position.set(5,0,.6);const to=counter?new T.Vector3(-3.4,1.2,2.4):decoy.position.clone().add(new T.Vector3(0,1.2,0));
   defender.rotation.set(0,Math.atan2(to.x-5,to.z-.6),0);
   const go=clamp((after-.8)/.6,0,1);reply.visible=born&&after>.8&&go<1;reply.position.lerpVectors(new T.Vector3(4.8,1.2,.6),to,go);
   enemyFooled=!counter&&after>1.4;
  }
  if(index===6){
   ally.visible=true;ally.rotation.set(0,Math.PI/2,0);const moveTo=s((after-.2)/1.8);ally.position.set(mix(-1.6,-.4,moveTo),0,mix(0,2.4,moveTo));walk(ally,born&&after>.2&&after<2?1:0,t);
   defender.position.set(4.6,0,.4);defender.rotation.set(0,-Math.PI/2,0);
   const go=clamp((after-.6)/.5,0,1);found=counter&&after>1.1;invisible=born&&after<3&&!found;
   if(invisible){ally.visible=false;shade.visible=true;shade.position.copy(ally.position);shade.rotation.y=Math.PI/2;}
   if(counter){reply.visible=born&&after>.6&&go<1;reply.position.lerpVectors(new T.Vector3(4.4,1.2,.4),new T.Vector3(mix(-1.6,-.4,s(.5)),1.2,mix(0,2.4,s(.5))),go);damage=found?.15:0;}
  }
  const target=index===6?ally:defender;
  if(!passive||index===6&&counter){bar.visible=born&&target.visible;bar.position.copy(target.position).add(new T.Vector3(0,2.03,0));bar.scale.x=Math.max(.02,1-damage);}
  last={index,surface,relativeDamage:damage,hit,scared,feared,fled,haunted,shotAtFake,decoyUp,enemyFooled,invisible,found,hiddenInFlight:hidden,defender:defender.position.toArray()};
 }
 return {render,metrics:()=>last};
}
