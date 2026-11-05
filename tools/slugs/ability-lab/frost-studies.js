import * as T from 'three';
const idea=(name,kind,impact,clever,answer,pairing)=>({name,slug:'frost',kind,role:'FROSTCRAWLER / '+(kind==='main'?'PLAYER HIT':'SURFACE PASSIVE'),short:name,tagline:impact.split('. ')[0]+'.',impact,clever,answer,pairing,visual:'Pale blue faceted ice, dark edges and a neutral small/transformed slug. Motion and health are illustrative.',choice:'Watch the play, then try the response.',use:'The target commits to the affected route. The effect has standalone utility.',counter:'The opponent responds to the visible ice before the full payoff.',beats:['Aim at a player for the main, or a surface for the passive.','The neutral slug spins and opens into a larger placeholder.','Contact activates the ice effect.','Watch the result, then compare counterplay.'],counterbeat:answer});
const rejectedFrostConcepts=[
 idea('Rimebite','main','Impact damage coats the legs in brittle ice, slowing movement briefly. The target can still move, aim and fire; shooting the visible coating breaks the slow early.','Catch a fast opponent without completely stopping their movement. The direct hit and slow are useful on their own.','Shoot off the brittle ice, get a teammate to clear it, or return fire while moving more slowly.','A slower target is easier to line up for Crashwave; this does not require Aquabeek to make Rimebite useful.'),
 idea('Shattermark','main','Impact damage leaves a visible ice crystal on the target. After a short warning it bursts in a small radius, damaging that target and nearby opponents.','Tag a tightly grouped team to force them to spread, or pressure a lone target with the delayed second hit.','Shoot the exposed crystal before it bursts to prevent the delayed damage. Nearby teammates can also spread outside its radius.','A Snapbind hit could hold a second opponent near the marked player; the delayed solo hit works without that setup.'),
 idea('Skidshock','main','Impact damage freezes traction for a brief forced glide along the incoming shot direction. The opponent keeps aim and firing but brakes less effectively until the glide ends.','Shoot from an angle to slide someone past cover or a preferred firing position. This is a low sideways glide rather than a root or upward knockback.','Steer sideways during the short slide, or use solid cover to stop it early. No forced slide through walls is proposed.','Slide someone toward existing Surface Fire; the displacement already changes their angle on its own.'),
 idea('Blackice','passive','Surface impact makes a visible slick patch. Contact preserves momentum and weakens braking briefly: a floor crossing slides, a wall contact drifts, and a ceiling brush carries a jumping player onward.','Lay a fast crossing for yourself or make an enemy overshoot their intended stop. Either team can exploit the same visible surface.','Avoid the patch or cross at lower speed. The passive adds no direct damage and does not grab players who never touch it.','Carry speed into a Silkline swing or make an opponent overshoot cover. These are proposed sequential uses.'),
 idea('Ice Shelf','passive','Surface impact grows one short-lived solid foothold. A floor hit makes a low step, a wall hit makes a ledge, and a ceiling hit hangs a supported ice step beneath it.','Create a temporary angle or landing point for either team. It supplies useful access by itself and does not seal a whole corridor.','Shoot the brittle foothold to break it or use another route. Standing on a destructible ledge is a risk, not permanent safe high ground.','A shelf could give a better angle for Backdraft or a new starting point for Silkline.'),
 idea('Frostmine','passive','Surface impact leaves a visible ice bud that triggers on nearby contact. It flashes a short warning, then cracks in a small chilling burst that damages and briefly slows opponents still close.','Protect a route with a readable delayed trap. Walls and ceilings can cover a close passage; it never affects the entire room.','Leave the warned radius before the burst, or shoot the bud before approaching. The preview compares staying with stepping out after the warning.','Backdraft could push an opponent toward an armed bud. The trap also triggers and damages on its own.')
].map((c,i)=>({...c,iceIndex:i+1}));

const rejectedSecondMains=[
 {...idea('Prismfang','main','The direct hit leaves a single-use angled ice prism at the impact position. Shoot the prism to bank your next projectile around its fixed corner; the first hit already deals damage.',
 'Create a second firing lane beside cover. The bank is a visible fixed reflection, not homing: move yourself to use the prism angle. Any compatible shot, including another Frostcrawler, could use it.',
 'Move away from the reflected lane or shoot the brittle prism before the follow-up. The prism stays where the original hit occurred; it does not chase the target.',
 'A later Backdraft could arrive from a new angle. Projectile compatibility remains proposed, not an extra equipped ability.'),iceIndex:7},
 {...idea('Ice Echo','main','The hit deals damage and drops a breakable ice copy at the struck position as the opponent moves away. One later shot into that copy transfers reduced damage to its owner, then destroys it.',
 'Leave a briefly exposed second target when the opponent ducks behind cover. It is a physical damage relay, not a deceptive illusion; a visible thread shows its link.',
 'Destroy your own copy first, or get beyond its short link range. The preview shows the owner breaking it before a follow-up can transfer damage.',
 'A teammate could hit the copy while you track the moving opponent. Any ordinary direct follow-up can use the relay; no other species is required.'),iceIndex:8},
 {...idea('Hailbreak','main','The direct hit launches a visible ice shard upward. It arcs over nearby cover and falls once onto the original impact location after a warning.',
 'Punish someone who stays behind the same low cover after being hit. The second strike approaches from above instead of applying a freeze or slow.',
 'Move away from the marked landing point before the shard falls. It does not track after impact, and a solid roof blocks the falling strike.',
 'Snapbind could hold someone near the landing mark, but the direct hit and overhead pressure already work alone.'),iceIndex:9},
 {...idea('Ice Wall','passive','Surface impact grows a small jagged ice wall that provides physical cover. Floor hits raise it, ceiling hits hang it downward, and wall hits grow an anchored shield outward.',
 'Place cover where you need to reload, cross a firing lane or hold an angle. Either side can use the geometry; it covers one direction rather than enclosing a player.',
 'Flank its open sides or take a higher angle. Breakability, lifetime, size and exact orientation are still open; the preview demonstrates cover versus a flank.',
 'Cover could protect the start of a Silkline traversal or a reposition after Snapbind. Fire/water interactions and projectile exceptions remain unselected.'),iceIndex:10,confirmed:true,
 choice:'Compare covered fire with a flank.',use:'The incoming shot meets the jagged cover and stops. The player behind it takes no illustrated shot damage.',counter:'The attacker uses the open side to shoot around the small shield. Cover protects its own angle, not every direction.'}
];

const priorFrostChoices=[
 {...idea('Iceburst','main','On impact, Frostcrawler bursts into a short spray of ice shards. The struck opponent takes direct damage; opponents very close to the hit take smaller splash damage.',
 'A straightforward hit against a grouped team. Aim at the player nearest a cluster. This is an immediate close burst, unlike Crashwave’s travelling line of water.',
 'Spread out or use solid cover between players. The direct hit still counts; the preview compares a nearby opponent with one already outside the burst. No freeze, slow or knockback.',
 'Snapbind might hold one opponent beside another, but Iceburst needs only a direct hit to work.'),iceIndex:11,choice:'Compare grouped opponents with a spread team.',use:'A nearby second opponent is inside the brief splash radius.',counter:'The second opponent was already farther away when the hit landed, so only the directly struck player takes damage.'},
 {...idea('Brittle','main','The hit deals damage and briefly makes the target brittle. The next landed hit deals a small bonus and consumes the effect.',
 'A simple one-hit vulnerability: follow with your own next shot or let a teammate capitalize. No special target, ricochet, secondary trigger or immobilization is needed.',
 'Break line of sight until the short mark expires, or return fire. The visible torso cracks show the one-hit opportunity; repeated marks would not stack in this proposal.',
 'A later Crashwave or ordinary direct hit could consume the bonus. Per-target versus per-projectile rules remain open.'),iceIndex:12,choice:'Compare a landed follow-up with broken line of sight.',use:'The next ordinary shot lands, dealing its usual damage plus a small bonus. The brittle mark then disappears.',counter:'The opponent moves behind cover before the follow-up, which misses. The vulnerability expires without bonus damage.'},
 {...idea('Frostguard','main','Landing the hit deals damage and grants the shooter a small temporary layer of ice armour. It absorbs a limited amount of incoming damage, then breaks or expires.',
 'Reward landing an aggressive shot with a little protection for the return fire. This is mobile personal protection; Ice Wall remains stationary placed cover.',
 'Keep pressure until the small armour breaks, or wait for its short duration. It reduces damage; it does not make the shooter invulnerable or restrict anyone’s movement.',
 'Protect a brief reposition toward Ice Wall or a later Silkline shot. The armour is useful without another slug.'),iceIndex:13,choice:'Compare protection with waiting out the armour.',use:'The return shot lands while the ice armour is active. Part of its damage is absorbed before the thin shell breaks.',counter:'The opponent waits until the temporary armour expires, then returns fire for the full illustrated damage.'},
 rejectedSecondMains[3]
];

export const frostConcepts=priorFrostChoices.filter(c=>[11,10].includes(c.iceIndex)).map(c=>({...c,confirmed:true}));

export function createFrostStudy({scene,mesh,box,line,mat,label,walk}){
 const root=new T.Group();scene.add(root);const clamp=T.MathUtils.clamp,mix=T.MathUtils.lerp,s=x=>{x=clamp(x,0,1);return x*x*(3-2*x);},up=new T.Vector3(0,1,0);
 const ice=new T.MeshStandardMaterial({color:0x9cdae3,roughness:.29,metalness:.12,transparent:true,opacity:.85,flatShading:true});
 const small=mesh(new T.SphereGeometry(.35,24,16),mat(0xb9c5c9),root);small.scale.set(1,1.25,1.25);
 const large=mesh(new T.SphereGeometry(.7,24,16),mat(0xb9c5c9),root);large.scale.set(.75,.75,1.5);
 const wall=box(root,1.4,1.5,-.55,4.8,3,.16,mat(0x354550));
 const ceiling=box(root,1.4,3.15,0,4.8,.12,3,new T.MeshStandardMaterial({color:0x506772,transparent:true,opacity:.18,side:T.DoubleSide,depthWrite:false}),false);
 const patch=new T.Group();root.add(patch);const disc=mesh(new T.CylinderGeometry(1.25,1.35,.075,48),ice,patch);for(let k=0;k<6;k++){const a=k*Math.PI/3;line(patch,[[0,.045,0],[Math.cos(a)*1.15,.045,Math.sin(a)*1.15]],0xd7edf0,.012);}
 const coat=new T.Group();root.add(coat);for(let k=0;k<7;k++){const a=k/7*Math.PI*2;const shard=mesh(new T.OctahedronGeometry(.28),ice,coat);shard.position.set(Math.cos(a)*.3,.45+(k%2)*.15,Math.sin(a)*.3);shard.scale.set(.6,1.5,.6);}
 const crystal=mesh(new T.OctahedronGeometry(.3),ice,root);crystal.scale.y=1.6;
 const burst=new T.Group();root.add(burst);for(let k=0;k<14;k++){const shard=mesh(new T.OctahedronGeometry(.08),ice,burst);shard.userData.angle=k/14*Math.PI*2;}
 const ring=mesh(new T.TorusGeometry(1.25,.018,6,64),new T.MeshBasicMaterial({color:0xaee6ee}),root);ring.rotation.x=Math.PI/2;
 const shelf=box(root,1.4,.35,0,1.7,.55,1.35,ice);
 const supports=[box(root,.85,2.1,0,.12,2.1,.12,ice),box(root,1.95,2.1,0,.12,2.1,.12,ice)];
 const blocker=box(root,2.8,.8,0,.22,1.6,1.6,mat(0x354550));
 const shot=mesh(new T.SphereGeometry(.06,12,8),mat(0xf2d39b),root);
 const hp=label('IMPACT + EFFECT','#aed5dc',2.2);root.add(hp);
 const bars=[box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false),box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false)];
 const prism=mesh(new T.CylinderGeometry(.42,.42,1.5,3),ice,root);prism.rotation.z=.25;
 const echo=box(root,1.4,.85,0,.65,1.65,.42,ice);const echoHead=mesh(new T.OctahedronGeometry(.25),ice,root);
 const link=line(root,[[0,0,0],[1,0,0]],0xa9dce8,.014);
 const trajectory=line(root,[[-3,1.1,1.4],[1.4,1.1,1.4],[2.6,1.1,-1]],0xb8e5ee,.014);
 const hail=mesh(new T.OctahedronGeometry(.22),ice,root);hail.scale.y=1.8;
 const cover=new T.Group();root.add(cover);
 const contour=[[-1.65,0],[-1.65,1.15],[-1.30,1.5],[-.98,1.30],[-.65,1.95],[-.25,1.62],[.10,2.12],[.48,1.52],[.88,1.83],[1.12,1.25],[1.53,1.48],[1.65,0]];
 const shape=new T.Shape();shape.moveTo(...contour[0]);for(const pt of contour.slice(1))shape.lineTo(...pt);shape.closePath();
 const coverMat=new T.MeshStandardMaterial({color:0x8fcbd6,roughness:.32,metalness:.1,flatShading:true});
 mesh(new T.ExtrudeGeometry(shape,{depth:.35,bevelEnabled:true,bevelThickness:.06,bevelSize:.05,bevelSegments:1,steps:1}),coverMat,cover);
 for(const points of [[[-1.1,.15,.42],[-.4,.8,.42],[-.65,1.75,.42]],[[.2,.1,.42],[.55,.8,.42],[1.2,1.25,.42]]])line(cover,points,0xd7edf0,.018);
 const incoming=mesh(new T.SphereGeometry(.085,12,8),mat(0xf0c996),root);
 const v=new T.Vector3();
 const splash=new T.Group();root.add(splash);for(let k=0;k<16;k++){const o=mesh(new T.OctahedronGeometry(.085),ice,splash);o.userData.a=k/16*Math.PI*2;}
 const cracks=new T.Group();root.add(cracks);for(const x of [-.18,.18])line(cracks,[[x,.7,.27],[x-.09,.94,.28],[x+.06,1.12,.28],[x,1.42,.27]],0xc7f2f2,.023);
 const guard=new T.Group();root.add(guard);for(const x of [-.25,0,.25]){const o=mesh(new T.OctahedronGeometry(.35),ice,guard);o.position.set(x,1.02,.10);o.scale.set(.8,1.35,.65);}
 const shooterLabel=label('SHOOTER','#b7e1e3',1.7);root.add(shooterLabel);
 const shooterBar=box(root,0,0,0,.8,.065,.025,mat(0xa7c98f),false);
 let last={};
 function render({index=0,t,surface='floor',counter=false,defender,ally,secondary}){
  root.visible=index>0;if(!index)return;
  for(const o of [wall,ceiling,patch,coat,crystal,burst,ring,shelf,blocker,shot,...supports,prism,echo,echoHead,link,trajectory,hail,cover,incoming,splash,cracks,guard,shooterLabel,shooterBar])o.visible=false;
  const passive=index===10,after=Math.max(0,t-3),born=t>3,build=s(after/.25),grow=s((t-.75)/.8),fade=1-s((after-3.7)/.8);
  const point=new T.Vector3(1.4,surface==='wall'?1.15:surface==='ceiling'?3.04:.05,surface==='wall'?-.43:0),normal=surface==='wall'?new T.Vector3(0,0,1):surface==='ceiling'?new T.Vector3(0,-1,0):up;
  small.visible=t<1.3;large.visible=t>.83&&t<3.3;const flight=clamp(t/3,0,1),flightPoint=passive?point:new T.Vector3(1.4,1.1,0);
  for(const o of [small,large]){o.position.set(mix(-6.3,flightPoint.x,flight),mix(1.24,flightPoint.y,s((t-1.8)/1.2)),flightPoint.z*s((t-1.8)/1.2));o.rotation.set(0,-Math.PI/2+Math.PI*2*s((t-.3)),0);}
  small.scale.setScalar(Math.max(.01,1-.8*grow));large.scale.set(.75, .75,1.5).multiplyScalar((.15+grow)*(1-s(after/.3)));
  defender.visible=true;defender.position.set(1.4,0,0);defender.rotation.set(0,0,0);walk(defender,0,t);ally.visible=false;secondary.visible=false;
  let damage=passive?0:.2*build,secondaryDamage=0,slowed=false,broken=false,sliding=false,triggered=false,detonated=false,platform=false;
  if(index===1){broken=counter&&after>1;slowed=born&&after<(counter?1:2.6);coat.visible=slowed;const distance=counter?1.5*s((after-1)/1):.5*s(after/2);defender.position.x+=distance;walk(defender,slowed?.2:.6,t);}
  if(index===2){broken=counter&&after>1;crystal.visible=born&&after<1.8&&!broken;secondary.visible=true;secondary.position.set(2.2+ (counter?1.8*s((after-.4)/1):0),0,.35);detonated=after>1.8&&!counter;damage+=detonated?.25*s((after-1.8)/.2):0;secondaryDamage=detonated?.2:0;ring.visible=born&&after<1.8;ring.position.set(1.4,.055,0);ring.scale.setScalar(1.25);}
  if(index===3){blocker.visible=counter;sliding=born&&after<1.5;defender.position.x+= (counter?1.0:2.6)*s(after/1.5);defender.position.z=counter?1.2*s(after/1.1):0;walk(defender,sliding?.1:0,t);}
  if(passive){wall.visible=surface==='wall';ceiling.visible=surface==='ceiling';patch.visible=born;patch.position.copy(point);patch.quaternion.setFromUnitVectors(up,normal);patch.scale.setScalar(build);disc.material.opacity=.85*fade;defender.position.set(mix(-1.4,1.4,s((after-.1)/1)),surface==='ceiling'?.9*Math.sin(Math.PI*clamp(after/2,0,1)):0,surface==='wall'?.1:0);walk(defender,.6,t);
   if(index===4){sliding=after>.9&&!counter;const p=counter?.5:2.5;defender.position.x=mix(-1.4,1.4, s((after-.1)/1))+p*s((after-.9)/1.5);defender.position.z=counter?1.8*s(after):surface==='wall'?.1:0;}
   if(index===5){patch.visible=false;shelf.visible=born;platform=born&&!counter;shelf.position.set(1.4,surface==='floor'?.3:surface==='wall'?1:.8,surface==='wall'?.1:0);shelf.scale.set(1,build,1);broken=counter&&after>1.4;shelf.visible=born&&!broken;if(platform){defender.position.set(mix(-1.4,1.4,s(after/1.5)),(shelf.position.y+.275)*s((after-.3)/1),surface==='wall'?.1:0);}else defender.position.set(1.4,0,1.6);}
   if(index===6){patch.visible=false;crystal.visible=born&&after<1.9;crystal.position.copy(point).addScaledVector(normal,.2);triggered=after>1;ring.visible=after>1&&after<1.9;ring.position.copy(point);ring.quaternion.setFromUnitVectors(new T.Vector3(0,0,1),normal);ring.scale.setScalar(1.25);detonated=after>1.9;const escape=counter?2.1*s((after-1)/.7):0;defender.position.x=1.4+escape;damage=detonated&&!counter?.25:0;slowed=detonated&&!counter&&after<3.1;}
  }
  if(index===2)crystal.position.copy(defender.position).add(new T.Vector3(0,1.3,.42));
  coat.position.copy(defender.position);coat.scale.setScalar(build);
  if(counter&&(index===1||index===2||index===5)&&after>.5&&after<1.1){shot.visible=true;shot.position.copy(defender.position).add(new T.Vector3(0,mix(1.3,.45,s((after-.5)/.6)),.35));}
  burst.visible=detonated&&after<(index===2?2.7:2.8);if(burst.visible){burst.position.copy(index===2?defender.position.clone().add(new T.Vector3(0,1.2,0)):point);const q=clamp((after-(index===2?1.8:1.9))/.8,0,1);for(const o of burst.children){const a=o.userData.angle;o.position.set(Math.cos(a)*q*1.6,.3+Math.sin(q*Math.PI)*.5,Math.sin(a)*q*1.6);o.scale.setScalar(1-q);}}
  for(const o of supports)o.visible=index===5&&surface==='ceiling'&&shelf.visible;
  let ricochet=false,relayed=false,overhead=false,covered=false,flanked=false;
  if(index===7){
   prism.visible=born&&after<3.5;prism.position.set(1.4,.8,.8);defender.position.set(2.7,0,-.9-(counter?2*s((after-.4)/1.2):0));
   blocker.visible=born;blocker.position.set(.7,.85,-.6);blocker.scale.set(1,1,1.6);
   trajectory.visible=after>.3&&after<2.0;const u=clamp((after-.4)/1.4,0,1);incoming.visible=after>.4&&after<1.8;
   if(u<.6)incoming.position.set(mix(-3,1.4,u/.6),1.1,.8);else incoming.position.set(mix(1.4,2.7,(u-.6)/.4),1.1,mix(.8,-.9,(u-.6)/.4));
   ricochet=after>1.8&&!counter;damage=.2*build+(ricochet?.18:0);
   if(after>1.8)prism.visible=false;
  }
  if(index===8){
   const travel=s((after-.2)/1.2);defender.position.set(1.4+2*travel,0,-1.1*travel);echo.visible=born&&after<(counter?1:2.1);echoHead.visible=echo.visible;echo.position.set(1.4,.85,0);echoHead.position.set(1.4,1.95,0);
   link.visible=echo.visible;link.position.set(1.4,.9,0);const delta=defender.position.clone().sub(new T.Vector3(1.4,0,0));link.quaternion.setFromUnitVectors(new T.Vector3(1,0,0),delta.clone().normalize().lengthSq()?delta.clone().normalize():new T.Vector3(1,0,0));link.scale.x=Math.max(.001,delta.length());
   relayed=after>2.1&&!counter;broken=counter&&after>1;damage=.2*build+(relayed?.16:0);
   shot.visible=after>.5&&after<(counter?1:2.1);if(counter)shot.position.copy(defender.position).lerp(new T.Vector3(1.4,1.1,0),s((after-.5)/.5));else shot.position.set(mix(-3,1.4,s((after-.6)/1.5)),1.1,0);
  }
  if(index===9){
   const q=clamp(after/2,0,1);hail.visible=born&&after<2;hail.position.set(1.4+.65*Math.sin(Math.PI*q),1.2+3.4*Math.sin(Math.PI*q),0);ring.visible=born&&after<2;ring.position.set(1.4,.055,0);ring.rotation.x=Math.PI/2;ring.quaternion.setFromEuler(new T.Euler(-Math.PI/2,0,0));ring.scale.setScalar(.8);
   blocker.visible=born;blocker.position.set(-.1,.65,0);blocker.scale.set(1,.75,1.4);
   defender.position.x=1.4+(counter?2.0*s((after-.4)/1):0);overhead=after>2&&!counter;damage=.2*build+(overhead?.23:0);
  }
  if(index===10){
   patch.visible=false;cover.visible=born&&after<4.2;cover.position.copy(point);cover.quaternion.setFromUnitVectors(up,normal);cover.scale.set(1,build,1);if(surface==='wall'){cover.position.set(1.4,0,1.22);cover.quaternion.setFromAxisAngle(up,Math.PI/2);}
   const local=new T.Vector3(0,.8,1.1).applyQuaternion(cover.quaternion).add(cover.position);defender.position.set(local.x,Math.max(0,local.y-1.05),local.z);
   const u=clamp((after-.8)/1.3,0,1);incoming.visible=after>.8&&after<(counter?2.1:1.5);
   if(counter){const from=new T.Vector3(2.4,.9,-2).applyQuaternion(cover.quaternion).add(cover.position);const bend=new T.Vector3(2.4,.9,1.3).applyQuaternion(cover.quaternion).add(cover.position);const target=defender.position.clone().add(new T.Vector3(0,1.05,0));incoming.position.copy(u<.65?from.lerp(bend,u/.65):bend.lerp(target,(u-.65)/.35));}
   else incoming.position.copy(new T.Vector3(0,.9,mix(-3,-.1,clamp((after-.8)/.7,0,1))).applyQuaternion(cover.quaternion).add(cover.position));
   covered=after>1.5&&!counter;flanked=after>2.1&&counter;damage=flanked?.2:0;
  }
  let splashHit=false,brittle=false,bonus=0,armour=false,absorbed=0,shooterDamage=0;
  if(index===11){
   secondary.visible=true;secondary.position.set(counter?4.3:2.25,0,.35);secondaryDamage=born&&!counter?.13*build:0;splashHit=secondaryDamage>0;
   splash.visible=born&&after<.65;splash.position.set(1.4,1.05,0);const q=clamp(after/.65,0,1);for(const o of splash.children){const a=o.userData.a;o.position.set(Math.cos(a)*1.45*q,.4*Math.sin(a*3)*q,Math.sin(a)*1.45*q);o.scale.setScalar(1-q);}
   ring.visible=born&&after<.65;ring.position.set(1.4,.07,0);ring.quaternion.setFromEuler(new T.Euler(-Math.PI/2,0,0));ring.scale.setScalar(1.2*q);
  }
  if(index===12){
   brittle=born&&after<(counter?2.6:1.25);cracks.visible=brittle;cracks.position.copy(defender.position);
   shot.visible=after>.6&&after<1.25;shot.position.set(mix(-3,1.4,s((after-.6)/.65)),1.05,0);
   blocker.visible=counter&&after>.45;blocker.position.set(.3,.85,0);blocker.scale.set(1,1,1);
   if(counter){defender.position.z=-1.6*s((after-.25)/.7);cracks.position.copy(defender.position);}
   bonus=after>1.25&&!counter?.1:0;damage=.2*build+(after>1.25&&!counter?.2+bonus:0);
  }
  if(index===13){
   ally.visible=true;ally.position.set(-3.5,0,0);ally.rotation.set(0,Math.PI/2,0);armour=born&&after<(counter?1.8:1.25);guard.visible=armour;guard.position.copy(ally.position);
   shooterLabel.visible=true;shooterLabel.position.copy(ally.position).add(new T.Vector3(0,2.35,0));shooterBar.visible=true;shooterBar.position.copy(ally.position).add(new T.Vector3(0,2.05,0));
   const start=counter?2.0:.65,end=counter?2.6:1.25;incoming.visible=after>start&&after<end;incoming.position.set(mix(1.4,-3.5,s((after-start)/(end-start))),1.05,0);
   absorbed=after>end&&!counter?.14:0;shooterDamage=after>end?.2-absorbed:0;shooterBar.scale.x=1-shooterDamage;
  }
  hp.position.copy(defender.position).add(new T.Vector3(0,2.5,0));hp.visible=born;bars[0].visible=born;bars[1].visible=secondary.visible&&born;
  [defender,secondary].forEach((actor,i)=>{bars[i].position.copy(actor.position).add(new T.Vector3(0,2.04,0));bars[i].scale.x=1-(i?secondaryDamage:damage);});
  last={splashHit,brittle,bonus,armour,absorbed,shooterDamage,ricochet,relayed,overhead,covered,flanked,coverNormal:normal.toArray(),index,surface,relativeDamage:damage,secondaryDamage,slowed,broken,sliding,triggered,detonated,platform,defender:defender.position.toArray()};
 }
 return {render,metrics:()=>last};
}
