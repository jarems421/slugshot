import * as T from 'three';
const idea=(name,kind,impact,clever,answer,pairing)=>({name,slug:'vine',kind,role:'VINEDRILL / '+(kind==='main'?'PLAYER HIT':'SURFACE PASSIVE'),short:name,tagline:impact.split('. ')[0].replace(/\.$/,'')+'.',impact,clever,answer,pairing,visual:'Green vines, thorns and blooms, neutral slug forms and health bars. Timings, movement and health are illustrative.',choice:'Watch the effect, then compare the response.',use:'The effect works without another slug.',counter:'The opponent responds to the plant.',beats:['Aim at a player for the main or a surface for the passive.','The neutral slug spins and expands in flight.','Contact activates the plant effect.','Watch the payoff and compare the response.'],counterbeat:answer});

const priorVineChoices=[
 idea('Drill Through','main','The slug drills through one piece of cover and still hits the player behind it.',
 'Cover is the most crowded job in the roster, and this is the answer to it. Ice Wall, rock cover and a corner no longer make someone safe.',
 'Stand behind two layers of cover, or keep moving so there is nothing to aim at. It only goes through one.',
 'Breaks the stalemate when Ice Wall or rock cover holds a fight. Fire Curtain and Mistbank do not stop it either.'),
 idea('Tangle','main','The hit wraps vines around the target, so their next slug comes out small and slow and cannot transform.',
 'Win a trade by shooting first: their answer comes back weak. It weakens an enemy’s attack instead of moving or holding them.',
 'Wait for the vines to drop before shooting back, or let a teammate take the fight.',
 'A tangled Inferno cannot become the dragon on his next shot. Mending Shot clears it, like any bind.'),
 idea('Bloom Pad','passive','Hitting a surface grows a springy flower that launches anyone who steps on it forward. From a wall or ceiling it grows on the floor below.',
 'A ground boost: cross gaps, chase, or get out of a fight fast. It goes sideways where Updraft goes up and Silkline pulls to anchors.',
 'Use it yourself, or shoot the player in the air, because their flight is easy to predict.',
 'Launch into a Tornado’s group to finish it, or away from Fire Curtain.'),
 idea('Bramble','passive','Hitting a surface grows a thorny patch that slows anyone walking through it. From a wall or ceiling it falls to the floor below.',
 'Slow a route without hurting anyone: chasers lose ground and a slowed player is easier to hit.',
 'Walk around it, jump over it, or burn it away with fire.',
 'A slowed player is easy for Chain Lightning or Shove Punch to catch. Fire burns it, so Inferno clears it.'),
].map((c,i)=>({...c,vineIndex:i+1}));
export const vineConcepts=priorVineChoices.filter(c=>[2,4].includes(c.vineIndex)).map(c=>({...c,confirmed:true}));

export function createVineStudy({scene,mesh,box,mat,walk}){
 const root=new T.Group();scene.add(root);const clamp=T.MathUtils.clamp,mix=T.MathUtils.lerp,s=x=>{x=clamp(x,0,1);return x*x*(3-2*x);};
 const leaf=new T.MeshStandardMaterial({color:0x6fae5a,roughness:.7}),bark=new T.MeshStandardMaterial({color:0x5b6b3a,roughness:.8}),petal=new T.MeshStandardMaterial({color:0xd99ac0,roughness:.6});
 const small=mesh(new T.SphereGeometry(.35,24,16),mat(0xa8c290),root),large=mesh(new T.SphereGeometry(.65,24,16),mat(0xa8c290),root);
 const wall=box(root,1.4,1.5,-.55,4.8,3,.16,mat(0x354550));
 const ceiling=box(root,1.4,3.15,0,4.8,.12,3,new T.MeshStandardMaterial({color:0x506772,transparent:true,opacity:.16,side:T.DoubleSide,depthWrite:false}),false);
 const cover=box(root,0,.9,0,.3,1.8,2,mat(0x354550)),cover2=box(root,.75,.9,0,.3,1.8,2,mat(0x3d4f5b));
 const holes=[-.17,.17].map(x=>{const h=mesh(new T.TorusGeometry(.32,.07,8,24),bark,root);h.rotation.y=Math.PI/2;h.position.set(x,1.15,0);return h;});
 const vines=[0,1,2].map(()=>mesh(new T.TorusGeometry(.38,.05,6,24),leaf,root));
 const pad=new T.Group();root.add(pad);mesh(new T.CylinderGeometry(.5,.55,.12,24),leaf,pad);
 Array.from({length:6},(_,k)=>{const p=mesh(new T.SphereGeometry(.22,10,8),petal,pad);const a=k*Math.PI/3;p.position.set(Math.cos(a)*.5,.06,Math.sin(a)*.5);p.scale.set(1,.25,.6);p.rotation.y=-a;});
 const stalk=mesh(new T.CylinderGeometry(.05,.05,1,8),leaf,root);
 const thorns=new T.Group();root.add(thorns);Array.from({length:22},(_,k)=>{const c=mesh(new T.ConeGeometry(.08,.45,6),bark,thorns);const a=k*2.4,r=.25+.85*Math.sqrt((k+.5)/22);c.position.set(Math.cos(a)*r,.2,Math.sin(a)*r);c.rotation.z=.3*Math.sin(k*1.7);});
 const shotSmall=mesh(new T.SphereGeometry(.2,14,10),mat(0xc48a8a),root),shotBig=mesh(new T.SphereGeometry(.45,16,12),mat(0xc48a8a),root);
 const bar=box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false);
 let last={};
 function render({index=0,t,surface='floor',counter=false,defender,ally,secondary}){
  root.visible=index>0;if(!index)return;
  for(const o of [wall,ceiling,cover,cover2,...holes,pad,stalk,thorns,shotSmall,shotBig,bar,...vines])o.visible=false;
  const passive=index>2,after=Math.max(0,t-3),born=t>3,flight=clamp(t/3,0,1),grow=s((t-.75)/.8);
  const point=!passive?new T.Vector3(1.4,1.1,0):surface==='wall'?new T.Vector3(1.4,1.1,-.43):surface==='ceiling'?new T.Vector3(1.4,3.04,0):new T.Vector3(1.4,.05,0);
  // Two layers of cover stop Drill Through at the second one.
  const endX=index===1&&counter?.6:point.x;
  small.visible=t<1.3;large.visible=t>.83&&t<3.15;
  const shotX=mix(-6.3,endX,flight);
  for(const o of [small,large])o.position.set(shotX,mix(1.24,point.y,s((t-1.8)/1.2)),point.z*s((t-1.8)/1.2));
  small.scale.setScalar(Math.max(.01,1-.8*grow));large.scale.setScalar((.15+grow)*(1-s(after/.15)));
  defender.visible=true;defender.position.set(1.4,0,0);defender.rotation.set(0,0,0);walk(defender,0,t);ally.visible=false;secondary.visible=false;
  let damage=0,drilled=false,hit=false,tangled=false,returnWeak=false,returnTransformed=false,launched=false,distance=0,slowed=false;
  if(index===1){
   cover.visible=true;cover2.visible=counter;defender.position.x=counter?1.6:1.4;
   drilled=shotX>0;holes.forEach(h=>{h.visible=drilled;h.scale.setScalar(Math.max(.01,s(shotX/.4)));});
   hit=!counter&&born;damage=hit?.2:0;
  }
  if(index===2){
   hit=born;damage=born?.15:0;const life=born?s(after/.3)*(1-s((after-2.2)/.3)):0;tangled=life>.05;
   vines.forEach((v,k)=>{v.visible=tangled;v.position.set(1.4,.45+k*.5,0);v.rotation.set(Math.PI/2+.35*Math.sin(t*3+k),t*2+k,0);v.scale.setScalar(life);});
   // The target shoots back: weak while tangled, full size if they wait.
   const fire=counter?2.6:.8,go=after-fire,fly=clamp(go/(counter?.7:1.8),0,1);
   const shot=counter?shotBig:shotSmall;shot.visible=go>0&&fly<1;shot.position.set(mix(1.2,-5.8,fly),counter?1.2:mix(1.2,.4,fly),0);
   returnWeak=!counter&&go>0;returnTransformed=counter&&go>0;
   ally.visible=true;ally.position.set(-6,0,0);ally.rotation.set(0,Math.PI/2,0);
  }
  if(passive){wall.visible=surface==='wall';ceiling.visible=surface==='ceiling';}
  const spot=new T.Vector3(1.4,0,surface==='wall'?.25:0);
  if(passive&&born&&surface!=='floor'){stalk.visible=after<.8;stalk.position.set(spot.x,point.y/2,mix(point.z,spot.z,.5));stalk.scale.set(1,point.y*s(after/.3),1);}
  if(index===3){
   pad.visible=born;pad.position.copy(spot);const g=s(after/.4);
   const air=clamp((after-1.1)/1.2,0,1);pad.scale.set(g,g*(after>1&&after<1.25?.5:1),g);
   if(counter){defender.position.set(mix(-1.2,4,s((after-.2)/2.2)),0,1.7);walk(defender,after>.2&&after<2.4?1:0,t);}
   else{
    defender.position.set(mix(-1.2,spot.x,s((after-.2)/.9)),0,spot.z);walk(defender,after>.2&&after<1.1?1:0,t);
    if(after>1.1){defender.position.x=mix(spot.x,6,air);defender.position.y=4*1.8*air*(1-air);launched=true;}
    distance=defender.position.x-spot.x;
   }
  }
  if(index===4){
   thorns.visible=born;thorns.position.copy(spot);thorns.scale.setScalar(s(after/.4));
   // Normal pace outside the patch, slow inside.
   const d=Math.max(0,after-.2),pace=2.4,slow=.7,enter=.3-(-1.6),inside=2.5-.3;
   let x;if(counter)x=-1.6+pace*d;else if(d<enter/pace)x=-1.6+pace*d;else if(d<enter/pace+inside/slow)x=.3+slow*(d-enter/pace);else x=2.5+pace*(d-enter/pace-inside/slow);
   defender.position.set(Math.min(x,5.5),0,counter?1.9+spot.z:spot.z);walk(defender,after>.2&&x<5.5?1:0,t);
   slowed=!counter&&x>.3&&x<2.5;distance=defender.position.x;
  }
  if(!passive){bar.visible=born;bar.position.copy(defender.position).add(new T.Vector3(0,2.03,0));bar.scale.x=Math.max(.02,1-damage);}
  last={index,surface,relativeDamage:damage,drilled,hit,tangled,returnWeak,returnTransformed,launched,distance,slowed,defender:defender.position.toArray()};
 }
 return {render,metrics:()=>last};
}
