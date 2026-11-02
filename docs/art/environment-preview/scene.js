'use strict';
// Original Slugshot volcano study. Three.js is vendored under THREE-LICENSE.txt.
const stage = document.getElementById('stage');
const Q = new URLSearchParams(location.search);
const CAPTURE = Q.has('frame');
const FERN_MODE = Q.get('asset')==='fern';
const SHOP_MODE = Q.get('asset')==='shop';
const ERUPTION={period:7.5,flight:1.9,emit:.85,count:7};
function jetState(t,k){const phase=t%ERUPTION.period-k*.065,head=clamp(phase/ERUPTION.flight,0,1),tail=clamp((phase-ERUPTION.emit)/ERUPTION.flight,0,1);return {head,tail,visible:head-tail>.00001,alpha:clamp((head-tail)*18,0,1)*(.9-.15*head)};}
function interpolatePath(path,u){const x=clamp(u,0,1)*(path.length-1),i=Math.min(path.length-2,Math.floor(x)),f=x-i;return path[i].map((v,j)=>mix(v,path[i+1][j],f));}
const TAU = Math.PI * 2;
const clamp = (x,a,b)=>Math.max(a,Math.min(b,x));
const mix = (a,b,t)=>a+(b-a)*t;
const fract = x=>x-Math.floor(x);
const hash = x=>fract(Math.sin(x*127.1+3.7)*43758.5453);

document.getElementById(SHOP_MODE?'tab-shop':FERN_MODE?'tab-fern':'tab-volcano')?.setAttribute('aria-current','page');
if(FERN_MODE){document.getElementById('motion').hidden=true;document.title='Slugshot ? Curled Cave Fern';document.querySelector('h1').textContent='Curled Cave Fern';document.querySelector('header p').textContent='A reusable cavern plant. Drag to turn and scroll to inspect the curled tips.';document.getElementById('design-note').textContent='Six curled fronds, paired sculpted leaves, soft mint veins and dark ink edges. The same authored fern grows around the volcano.';document.getElementById('scale-note').textContent='About 10 studs tall, with its origin at the roots. Scale and rotate it when placing it.';document.getElementById('review-note').textContent='Reusable concept asset. The GLB contains portable vertex-colour paint and ink geometry; the source keeps the fern editable.';stage.setAttribute('aria-label','Interactive curled cave fern asset');}

if(SHOP_MODE){document.title='Slugshot ? The Burrow Exchange';document.querySelector('small').textContent='Slugshot ? Shop study 02';document.querySelector('h1').textContent='The Burrow Exchange';document.querySelector('header p').textContent='A pod-grown cavern shop. Drag to turn, lift the canopy or step inside.';document.getElementById('design-note').textContent='Rounded mineral-shell rooms grow around a cave tree beneath blue fungal canopies. A guarded bridge crosses the misty chasm, with exotic flowers and fungi on the rim. The name is a proposal.';document.getElementById('scale-note').textContent='The shop is about 60 studs wide and 42 tall. A 12-stud-clear bridge crosses a 70-stud-wide chasm. The figure on the bridge shows player scale.';document.getElementById('review-note').textContent='Second shape study based on your pod-house references. The interior reserves a counter for the future shopkeeper and room for future shopping interactions.';document.getElementById('fern-reuse').hidden=true;const research=document.createElement('p');research.className='note';research.innerHTML='References: <a href="https://slugterra.fandom.com/wiki/Barton_and_Spinks" target="_blank" rel="noopener">Barton and Spinks</a> and <a href="https://www.youtube.com/watch?v=mY9KVNmy11w" target="_blank" rel="noopener">The Trade</a>. Original Slugshot design.';document.getElementById('design-note').after(research);stage.setAttribute('aria-label','Interactive 3D general shop concept');const interior=document.createElement('button');interior.id='shop-interior';interior.textContent='Step inside';const roof=document.createElement('button');roof.id='shop-roof';roof.textContent='Lift roof';document.getElementById('motion').after(interior,roof);const flora=document.createElement('section');flora.innerHTML='<h2>Reusable cave flowers</h2><p class=note>The same original flowers planted along the chasm rim. Each downloads separately.</p><a class=download href=cave-flower-fan.glb download>Tidefan Bloom (GLB)</a><a class=download href=cave-flower-bell.glb download>Mistbell (GLB)</a><a class=download href=cave-flower-orchid.glb download>Coil Orchid (GLB)</a><a class=download href=cave-flowers.js download>Editable flower source</a><a class=download href=cave-flowers-readme.txt download>Reuse notes</a>';document.querySelector('aside').append(flora);for(const variant of ['fan','bell','orchid']){const link=document.createElement('a');link.className='download';link.href='?asset=shop&flower='+variant;link.textContent='View '+SlugshotFlowers.names[variant];flora.append(link);}if(Q.has('flower')){const variant=Q.get('flower'),name=SlugshotFlowers.names[variant]||'Cave flower';document.querySelector('h1').textContent=name;document.querySelector('header p').textContent='Reusable exotic cave flower. Drag to turn and scroll to inspect.';document.getElementById('design-note').textContent='An original cavern flower with curled petals, cool painted colours, luminous centres and charcoal ink geometry.';document.getElementById('scale-note').textContent='Shown enlarged for inspection. Exported plant is roughly 4 to 5 studs tall, with its origin at the roots.';document.getElementById('review-note').textContent='Reusable browser concept asset. Download the GLB below. Production optimization and Studio appearance remain to be checked.';}}

function fallback() {
  if(SHOP_MODE){SlugshotShopPreview.fallback({stage,Q});return;}

  stage.innerHTML = '<div class="rendered-view"><img alt="Rotatable rendered view of the volcano"><canvas aria-hidden="true"></canvas></div>';
  const box=stage.firstElementChild, img=box.querySelector('img'), canvas=box.querySelector('canvas'), ctx=canvas.getContext('2d');
  let f=0, down=false, last=0, above=false, motion=true, rotating=false, rotationAcc=0;
  const folder=FERN_MODE?'fern-frames/':'frames/';const draw=()=>{img.src=above?folder+'above.jpg':folder+String((f%36+36)%36).padStart(2,'0')+'.jpg';};draw();
  stage.onpointerdown=e=>{down=true;above=false;last=e.clientX;stage.setPointerCapture(e.pointerId);};
  stage.onpointerup=stage.onpointercancel=()=>down=false;
  stage.onpointermove=e=>{if(down&&Math.abs(e.clientX-last)>10){f+=e.clientX>last?-1:1;last=e.clientX;draw();}};
  document.getElementById('front').onclick=()=>{f=4;above=false;draw();};
  document.getElementById('above').onclick=()=>{above=true;draw();};
  document.getElementById('reset').onclick=()=>{f=0;above=false;draw();};
  document.getElementById('rotate').textContent='Auto rotate';
  document.getElementById('rotate').onclick=e=>{rotating=!rotating;e.target.textContent=rotating?'Stop rotation':'Auto rotate';};
  document.getElementById('motion').onclick=e=>{motion=!motion;e.target.textContent=motion?'Pause effects':'Resume effects';};
  document.querySelector('header p').textContent=FERN_MODE?'Drag to turn the reusable fern. Download its model or editable source below.':'Drag to turn. Choose a view, then tell me what you would change.';
  let elapsed=2,lastTime=0;
  function animate(ms){const w=Math.round(box.clientWidth),h=Math.round(box.clientHeight);if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;}ctx.clearRect(0,0,w,h);let dt=Math.min((ms-lastTime)/1000,.05);if(motion)elapsed+=dt;if(rotating&&!down&&!above){rotationAcc+=dt*5;if(rotationAcc>=1){f++;rotationAcc-=1;draw();}}lastTime=ms;
    const view=FERN_MODE?null:VOLCANO_FLOW_VIEWS[above?'above':String((f%36+36)%36)],t=elapsed;
    if(view){
      // Same projected lava ribbons as the live scene, with bright liquid travelling downhill.
      ctx.save();ctx.lineCap='round';ctx.lineJoin='round';
      for(let k=0;k<view.ribbons.length;k++){let run=view.ribbons[k];for(let i=1;i<run.length;i++){let p=run[i-1],q=run[i],v=(p[3]+q[3])*.5,power=0;for(let lane=0;lane<3;lane++){let head=(t*.095+lane/3+k*.067)%1,d=(head-v+1)%1;power+=Math.pow(Math.max(0,1-d/.14),2)*.7;}if(power<.025)continue;ctx.strokeStyle=`rgba(255,207,114,${power})`;ctx.shadowColor='rgba(255,137,51,.6)';ctx.shadowBlur=0;ctx.lineWidth=Math.max(.7,((p[2]+q[2])*.5)*w*.65);ctx.beginPath();ctx.moveTo(p[0]*w,p[1]*h);ctx.lineTo(q[0]*w,q[1]*h);ctx.stroke();}}
      for(let k=0;k<view.arcs.length;k++){const state=jetState(t,k);if(!state.visible)continue;const arc=view.arcs[k],samples=40,pts=Array.from({length:samples+1},(_,j)=>interpolatePath(arc,mix(state.tail,state.head,j/samples)));
        function ribbon(mult,colour,blur){ctx.beginPath();for(const sign of [-1,1]){for(let q=0;q<=samples;q++){let j=sign===1?q:samples-q,p=pts[j],a=pts[Math.max(0,j-1)],b=pts[Math.min(samples,j+1)],dx=(b[0]-a[0])*w,dy=(b[1]-a[1])*h,len=Math.max(.0001,Math.hypot(dx,dy)),width=w*.0026*Math.pow(Math.max(0,Math.sin(Math.PI*j/samples)),.35)*mult,x=p[0]*w-sign*dy/len*width,y=p[1]*h+sign*dx/len*width;if(sign===1&&q===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);}}ctx.closePath();ctx.fillStyle=colour;ctx.shadowColor='rgba(255,142,46,.8)';ctx.shadowBlur=blur;ctx.fill();}
        ribbon(1,`rgba(255,158,57,${state.alpha})`,w*.009);ribbon(.43,`rgba(255,222,137,${state.alpha})`,0);
        const tip=interpolatePath(arc,state.head);ctx.fillStyle=`rgba(255,204,108,${state.alpha})`;ctx.beginPath();ctx.ellipse(tip[0]*w,tip[1]*h,w*.0017,w*.0025,Math.sin(k),0,TAU);ctx.fill();
      }
      ctx.restore();
    }
    if(!above&&!FERN_MODE){const cx=view?view.crater[0]*w:w*.505,cy=view?view.crater[1]*h:h*.25;
      for(let i=0;i<11;i++){let u=(t*.08+i/11)%1,x=cx+Math.sin(i*2.3+t*.3)*w*.012+u*w*.025,y=cy-u*h*.19,r=w*(.014+u*.048);let g=ctx.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,`rgba(168,160,179,${.09*(1-u)})`);g.addColorStop(.5,`rgba(138,132,155,${.025*(1-u)})`);g.addColorStop(1,'rgba(138,132,155,0)');ctx.fillStyle=g;ctx.fillRect(x-r,y-r,2*r,2*r);}
      const phase=t%ERUPTION.period;for(let i=0;i<24;i++){let u=(phase-(i%6)*.065)/1.9;if(u<0||u>1)continue;let x=cx+Math.sin(i*2.399)*w*.035*u,y=cy-h*(.43*u-.43*u*u);ctx.fillStyle=`rgba(255,${178+i*3},100,${1-u})`;ctx.beginPath();ctx.ellipse(x,y,2.2*(1-u)+.5,3.2*(1-u)+.5,Math.sin(i),0,TAU);ctx.fill();}
    }requestAnimationFrame(animate);
  }requestAnimationFrame(animate);window.volcanoReview={mode:'rendered',eruptionState:t=>Array.from({length:ERUPTION.count},(_,i)=>jetState(t,i)),setTime:t=>elapsed=t,setView:(i)=>{f=i;above=false;draw();}};
}

let renderer;
if(Q.has('fallback')){fallback();}else{try{renderer=new THREE.WebGLRenderer({antialias:true,preserveDrawingBuffer:CAPTURE});}catch(e){fallback();}}
if(renderer){if(SHOP_MODE)SlugshotShopPreview.start({THREE,renderer,stage,Q});else build();}
function build(){
  renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.outputColorSpace=THREE.SRGBColorSpace;
  stage.appendChild(renderer.domElement);
  const scene=new THREE.Scene();scene.background=new THREE.Color(0x202333);
  const camera=new THREE.PerspectiveCamera(39,1,.1,1200);
  const time={value:2}, materials=[];
  const common=`
    uniform float uTime;
    varying vec3 vP; varying vec3 vN; varying vec2 vUv;
    float h3(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
    float noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(h3(i),h3(i+vec3(1,0,0)),f.x),mix(h3(i+vec3(0,1,0)),h3(i+vec3(1,1,0)),f.x),f.y),mix(mix(h3(i+vec3(0,0,1)),h3(i+vec3(1,0,1)),f.x),mix(h3(i+vec3(0,1,1)),h3(i+vec3(1,1,1)),f.x),f.y),f.z);}
    float fbm(vec3 p){return noise3(p)*.57+noise3(p*2.07)*.28+noise3(p*4.11)*.15;}
    float voronoiEdge(vec2 p){vec2 ip=floor(p),fp=fract(p);float a=100.,b=100.;for(int j=-1;j<=1;j++)for(int i=-1;i<=1;i++){vec2 q=vec2(float(i),float(j));vec2 o=vec2(h3(vec3(ip+q,3.)),h3(vec3(ip+q,8.)));float d=dot(q+o-fp,q+o-fp);if(d<a){b=a;a=d;}else if(d<b)b=d;}return sqrt(b)-sqrt(a);}
    float cell(vec2 p){vec2 i=floor(p),f=fract(p);float d=10.;for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){vec2 q=vec2(float(x),float(y));vec2 o=vec2(h3(vec3(i+q,3.)),h3(vec3(i+q,8.)));d=min(d,length(q+o-f));}return d;}
  `;
  const vertex=`varying vec3 vP;varying vec3 vN;varying vec2 vUv;void main(){vP=(modelMatrix*vec4(position,1.)).xyz;vN=normalize(mat3(modelMatrix)*normal);vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}`;
  function shader(body,side=THREE.FrontSide){const mat=new THREE.ShaderMaterial({uniforms:{uTime:time},vertexShader:vertex,fragmentShader:common+'\nvoid main(){'+body+'}',side});materials.push(mat);return mat;}
  const rock=shader(`
    vec3 n=normalize(vN),p=vP;float broad=fbm(p*.055),paint=fbm(p*.2),grain=noise3(p*2.5);
    vec3 base=mix(vec3(.033,.039,.059),vec3(.12,.13,.18),smoothstep(.2,.8,broad));
    base=mix(base,base*vec3(1.24,1.05,.83),smoothstep(.45,.75,noise3(p*.032+vec3(4.,1.,2.)))*.55);
    float angle=atan(p.z,p.x);float slab=floor((angle+3.14159)/6.28318*12.);float row=floor((p.y+sin(slab*3.)*8.)/26.);float tint=h3(vec3(slab,row,7.));base*=.80+.35*tint;base=mix(base,base*vec3(.92,.95,1.22),smoothstep(.7,.9,tint)*.45);
    base*=.9+.2*paint;float fleck=smoothstep(.78,.9,noise3(p*.9));base*=1.-fleck*.12;
    float scratch=1.-smoothstep(.018,.055,abs(sin(p.x*2.1+p.y*1.1+p.z*.7+paint*2.)));scratch*=smoothstep(.64,.79,noise3(p*.4));base*=1.-scratch*.09;
    float m=smoothstep(.52,.71,noise3(p*.14+vec3(8.,0.,4.)))*smoothstep(.05,.65,n.y)*(1.-smoothstep(12.,36.,p.y));base=mix(base,vec3(.065,.14,.10)*( .8+.5*paint),m*.45);
    float a=atan(p.z,p.x),t=clamp(p.y/132.,0.,1.),heat=0.;
    for(int i=0;i<7;i++){float fi=float(i),channel=-1.18+fi*.897598+.08*sin(t*5.+fi*2.);float da=abs(atan(sin(a-channel),cos(a-channel)));heat+=exp(-da*da*190.)*.55;}
    heat*=smoothstep(4.,30.,p.y);float key=max(dot(n,normalize(vec3(-.55,.9,.65))),0.);float shadow=mix(.38,1.,smoothstep(.02,.24,key));
    vec3 lit=base*(vec3(.40,.43,.59)+vec3(1.3,1.18,1.02)*key*shadow);
    lit+=base*vec3(1.8,.53,.13)*heat+vec3(.16,.045,.012)*heat;
    for(int c=0;c<4;c++){float ca=-1.85+float(c)*1.56;vec3 site=vec3(cos(ca)*88.,4.,sin(ca)*88.);float d=length(p-site);vec3 hue=c==0||c==2?vec3(.15,.65,.52):vec3(.43,.24,.61);lit+=hue*base*2.5/(1.+d*d*.035);}
    lit+=base*vec3(.26,.37,.52)*pow(1.-max(dot(n,normalize(cameraPosition-p)),0.),2.);
    gl_FragColor=vec4(lit,1.);
  `);
  const ink=new THREE.ShaderMaterial({vertexShader:`uniform float width;void main(){vec3 p=position+normal*width;gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.);}`,fragmentShader:'void main(){gl_FragColor=vec4(.003,.004,.007,1.);}',uniforms:{width:{value:.38}},side:THREE.BackSide});
  function add(g,mat,x=0,y=0,z=0,outline=0){const o=new THREE.Mesh(g,mat);o.position.set(x,y,z);scene.add(o);if(outline){const line=new THREE.Mesh(g,ink.clone());line.material.uniforms.width.value=outline;line.position.copy(o.position);scene.add(line);o.userData.ink=line;}return o;}
  function sync(o){let q=o.userData.ink;if(q){q.position.copy(o.position);q.rotation.copy(o.rotation);q.scale.copy(o.scale);}}
  function geometry(vertices,indices,uvs){const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));g.setAttribute('uv',new THREE.Float32BufferAttribute(uvs||vertices.map((_,i)=>i%3===0?0:0).slice(0,vertices.length/3*2),2));g.setIndex(indices);g.computeVertexNormals();return g;}
  const H=130;
  function centre(y){let t=y/H;return [4*Math.sin(t*2.4)-2*t,-4*t+2*Math.sin(t*3.)];}
  // Unequal ribs and stepped fracture ledges form one continuous wall.
  function radius(a,y){let t=clamp(y/H,0,1),base=84-54*Math.pow(t,.72);let phase=a*12+.22*Math.sin(a*3)+.13*Math.sin(t*9+a*2);let ridge=1-Math.abs(Math.sin(phase*.5));ridge=Math.pow(ridge,1.6);let tiers=1.15*Math.sin(t*TAU*3+a*2)+2.5*Math.sin(Math.floor(a*12/TAU)*17.3+Math.floor(t*6)*9.7);return base+(ridge-.36)*(15-5*t)+tiers+2*Math.sin(a*3+.5)*(1-t);}
  const N=72,R=14,verts=[],uv=[],idx=[];
  for(let j=0;j<=R;j++)for(let i=0;i<=N;i++){let a=i/N*TAU,y=j/R*H,c=centre(y),r=radius(a,y);if(j===R)y+=3.6*Math.sin(a*5+.7)+2*Math.sin(a*9);verts.push(c[0]+Math.cos(a)*r,y,c[1]+Math.sin(a)*r);uv.push(i/N,j/R);}
  for(let j=0;j<R;j++)for(let i=0;i<N;i++){let a=j*(N+1)+i,c=a+N+1;idx.push(a,c,a+1,a+1,c,c+1);}
  const mountainGeometry=geometry(verts,idx,uv).toNonIndexed();mountainGeometry.computeVertexNormals();
  const mountain=add(mountainGeometry,rock,0,0,0,.32);
  function onWall(a,y,offset=.3){a=((a%TAU)+TAU)%TAU;let u=a/TAU*N,v=clamp(y/H*R,0,R-.0001),i=Math.floor(u),j=Math.floor(v),fu=u-i,fv=v-j;
    const at=(ii,jj)=>new THREE.Vector3(...verts.slice((jj*(N+1)+ii)*3,(jj*(N+1)+ii)*3+3));let A=at(i,j),B=at(i+1,j),C=at(i,j+1),D=at(i+1,j+1),p;
    if(fu+fv<=1)p=A.multiplyScalar(1-fu-fv).addScaledVector(B,fu).addScaledVector(C,fv);else p=B.multiplyScalar(1-fv).addScaledVector(C,1-fu).addScaledVector(D,fu+fv-1);
    p.x+=Math.cos(a)*offset;p.z+=Math.sin(a)*offset;return p;
  }
  // The inside is a real bowl, set low enough to show a glowing lip and exposed cliff wall.
  let cv=[],cu=[],ci=[];for(let j=0;j<6;j++)for(let i=0;i<=N;i++){let a=i/N*TAU,f=j/5,c=centre(H),r=mix(radius(a,H),19,f),y=mix(H+3.6*Math.sin(a*5+.7)+2*Math.sin(a*9),122,f);cv.push(c[0]+Math.cos(a)*r,y,c[1]+Math.sin(a)*r);cu.push(i/N,f);}
  for(let j=0;j<5;j++)for(let i=0;i<N;i++){let a=j*(N+1)+i,c=a+N+1;ci.push(a,c,a+1,a+1,c,c+1);}const innerRock=shader(`vec3 n=normalize(vN);float h=clamp((vP.y-122.)/12.,0.,1.);vec3 c=mix(vec3(.7,.20,.055),vec3(.075,.06,.08),h);float paint=fbm(vP*.3);c*=.7+.5*paint;gl_FragColor=vec4(c,1.);`);add(geometry(cv,ci,cu),innerRock,0,0,0,.18);
  const lavaMat=shader(`
    vec3 p=vP;float flow=uTime*.92;vec2 uv=vUv;float molten=fbm(vec3(uv.x*2.2,uv.y*7.-flow,5.));
    float crust=voronoiEdge(vec2(uv.x*3.+sin(uv.y*5.)*.3,uv.y*9.-flow*.35));
    float plate=smoothstep(.18,.34,crust)*smoothstep(.40,.66,molten);
    vec3 hot=mix(vec3(1.1,.105,.045),vec3(2.4,1.05,.27),smoothstep(.18,.85,molten));
    hot=mix(hot,vec3(2.8,1.9,.68),pow(1.-smoothstep(.01,.16,crust),2.)*.35);
    vec3 skin=vec3(.075,.065,.095)*( .7+.6*molten);
    float ripple=.5+.5*sin((uv.y*6.-uTime*.68+noise3(vec3(uv*3.,2.))*.35)*6.28318);hot*=.92+.20*ripple;vec3 col=mix(hot,skin,plate*.9);float edge=smoothstep(0.,.1,uv.x)*smoothstep(1.,.9,uv.x);col=mix(vec3(.12,.04,.025),col,edge);
    gl_FragColor=vec4(col,1.);
  `,THREE.DoubleSide);
  // Broad descending rivers taper into seepage and follow the actual irregular wall.
  const streams=[];
  for(let k=0;k<7;k++){
    let a0=-1.18+k*TAU/7,phase=k*2,lo=[5,25,13,9,38,8,21][k],width=[4.8,3.6,4.2,5.2,3.4,4.5,3.8][k];
    let vv=[],uu=[],ii=[];const seg=120,across=8;
    for(let j=0;j<=seg;j++){let t=j/seg,y=mix(129,lo,t),a=a0+.08*Math.sin((y/H)*5+k*2),w=width*(.72+.23*Math.sin(t*15+phase))*(.55+.45*Math.sin(Math.PI*t*.7+.35));
      for(let s=0;s<=across;s++){let f=s/across,aa=a+(f-.5)*w*2/radius(a,y),r=radius(aa,y)+.28,c=centre(y);const wallPoint=onWall(aa,y,1.65);vv.push(wallPoint.x,wallPoint.y+.08,wallPoint.z);uu.push(f,t*1.7);}}
    for(let j=0;j<seg;j++)for(let s=0;s<across;s++){let a=j*(across+1)+s,b=a+across+1;ii.push(a,b,a+1,a+1,b,b+1);}add(geometry(vv,ii,uu),lavaMat);
    streams.push({a:a0,lo,width,positions:vv,segments:seg,across});
  }
  // A molten pool with drifting crust in the same palette, rather than a flat glowing disc.
  const poolMat=shader(`vec2 q=vP.xz*.16;float n=fbm(vec3(q,uTime*.12));float c=voronoiEdge(q+vec2(uTime*.025,0.));float crust=smoothstep(.13,.35,c);vec3 hot=mix(vec3(1.3,.19,.055),vec3(2.7,1.65,.45),smoothstep(.25,.75,n));hot=mix(hot,vec3(.085,.07,.10),crust*.86);gl_FragColor=vec4(hot,1.);`,THREE.DoubleSide);
  let cp=centre(H),pg=new THREE.CircleGeometry(19.2,72);pg.rotateX(-Math.PI/2);add(pg,poolMat,cp[0],122.4,cp[1]);
  // Sculpted bedrock footprint with broken rim; no manufactured circular plinth.
  const bv=[],bu=[],bi=[],BN=96;for(let j=0;j<4;j++)for(let i=0;i<=BN;i++){let a=i/BN*TAU,r=[0,94,96,89][j]*(1+.035*Math.sin(a*7)+.018*Math.sin(a*13)),y=[.2,.2,-3,-8][j];bv.push(Math.cos(a)*r,y,Math.sin(a)*r);bu.push(i/BN,j/3);}for(let j=0;j<3;j++)for(let i=0;i<BN;i++){let a=j*(BN+1)+i,b=a+BN+1;bi.push(a,a+1,b,a+1,b+1,b);}add(geometry(bv,bi,bu),rock,0,0,0,.35);
  // Ink cracks with short straight branches, anchored into the rock.
  const crackMat=new THREE.MeshBasicMaterial({color:0x10121c});
  function tube(points,r,mat){return add(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(points),points.length*3,r,4,false),mat);}
  for(let k=0;k<30;k++){let a0=k*2.399+.25,y0=13+hash(k+3)*92,pts=[];for(let j=0;j<5;j++){let y=y0+j*2.4,a=a0+((j%2)*.018)+j*.007,r=radius(a,y)+.42,c=centre(y);pts.push(onWall(a,y,.30));}tube(pts,.21,crackMat);}
  // Large bevelled fracture plates make up the wall rather than decorating it with boulders.
  function tierY(row,a){if(row===0)return .3;if(row===4)return H+2.6*Math.sin(a*5+.7);return row*32.5+Math.sin(a*3+row)*4;}
  for(let row=0;row<4;row++)for(let sector=0;sector<12;sector++){
    let shift=(row%2)*.22,a0=sector*TAU/12+shift+.012,a1=(sector+1)*TAU/12+shift-.012,vv=[],uu=[],ii=[],S=5;
    for(let j=0;j<=S;j++)for(let i=0;i<=S;i++){let u=i/S,v=j/S,a=mix(a0,a1,u),y=mix(tierY(row,a),tierY(row+1,a),v);let edge=Math.min(u,1-u,v,1-v);let front=Math.min(1,edge/.16);let p=onWall(a,Math.min(y,H-.01),-1.5+front*2.6);if(row===3&&j===S)p.y=y;
      vv.push(p.x,p.y,p.z);uu.push(u,v);}
    for(let j=0;j<S;j++)for(let i=0;i<S;i++){let a=j*(S+1)+i,b=a+S+1;ii.push(a,b,a+1,a+1,b,b+1);}
    let panel=geometry(vv,ii,uu).toNonIndexed();panel.computeVertexNormals();add(panel,rock);
    const border=[];for(let q=0;q<=10;q++){let u=.12+q/10*.7,a=mix(a0,a1,u),y=tierY(row,a)+.25;border.push(onWall(a,Math.min(y,H-.1),1.35));}if(hash(sector+row*12)>.32)tube(border,.25,crackMat);
    if((sector+row)%3===0){let side=[];for(let q=0;q<8;q++){let a=a0+.012,y=mix(tierY(row,a),tierY(row+1,a),q/8);side.push(onWall(a,Math.min(y,H-.1),1.35));}tube(side,.22,crackMat);}

  }
  // Moss and luminous fungi form clusters in sheltered lower creases.
  const moss=shader(`float n=fbm(vP*.55);vec3 c=mix(vec3(.045,.11,.07),vec3(.15,.29,.14),n);float l=max(dot(normalize(vN),normalize(vec3(-.4,1.,.4))),0.);gl_FragColor=vec4(c*(.65+l*.8),1.);`);
  const stemMat=shader(`float f=fbm(vP*.7);vec3 c=mix(vec3(.14,.20,.18),vec3(.40,.48,.34),f);float l=max(dot(normalize(vN),normalize(vec3(-.6,.9,.4))),0.);gl_FragColor=vec4(c*(.7+l*.7),1.);`);
  function capMat(deep,glow){return new THREE.ShaderMaterial({uniforms:{uTime:time,deep:{value:new THREE.Color(deep)},glow:{value:new THREE.Color(glow)}},vertexShader:vertex,fragmentShader:common+`uniform vec3 deep,glow;void main(){float s=fbm(vP*1.3);float spot=smoothstep(.68,.78,noise3(vP*1.1));float gill=(.5+.5*sin(atan(vP.z,vP.x)*48.));float under=smoothstep(.1,-.3,normalize(vN).y);vec3 col=deep*(.8+.5*s)+glow*(spot*1.1+under*(.65+.3*gill)+.18);float light=max(dot(normalize(vN),normalize(vec3(-.5,.8,.4))),0.);col+=deep*light*.6;gl_FragColor=vec4(col,1.);}`,side:THREE.DoubleSide});}
  const capMats=[capMat(0x2e6370,0x74e4d2),capMat(0x63507c,0xc394ed),capMat(0x6c4e75,0xf6b5d4)];
  const groups=[{a:-1.85,r:88,s:1.85},{a:-.4,r:89,s:1.5},{a:1.35,r:88,s:1.65},{a:2.8,r:88,s:1.6}];
  function mushroom(x,y,z,s,variant){let stem=new THREE.CylinderGeometry(.55*s,.94*s,5.5*s,9,3);let o=add(stem,stemMat,x,y+2.75*s,z,.12*s);o.rotation.z=-.12;sync(o);
    let cap=new THREE.SphereGeometry(3.7*s,20,10,0,TAU,0,Math.PI*.56);let arr=cap.attributes.position;for(let i=0;i<arr.count;i++){let xx=arr.getX(i),yy=arr.getY(i),zz=arr.getZ(i);arr.setXYZ(i,xx,yy*.38+.14*s*Math.sin(xx+zz),zz);}cap.computeVertexNormals();let top=add(cap,capMats[variant%3],x-.45*s,y+5.4*s,z,.14*s);top.rotation.z=-.07;sync(top);
    const under=new THREE.CircleGeometry(3.55*s,20);under.rotateX(Math.PI/2);add(under,capMats[variant%3],x-.45*s,y+5.32*s,z);
  }
  for(let k=0;k<groups.length;k++){let z=groups[k],x=Math.cos(z.a)*z.r,pz=Math.sin(z.a)*z.r;for(let j=0;j<8;j++){let a=hash(k*30+j)*TAU,r=hash(j*7+k)*6;let sx=x+Math.cos(a)*r,sz=pz+Math.sin(a)*r;let sc=(j===0?z.s:.32+hash(j+k*8)*.45);mushroom(sx,.4,sz,sc,k+j%2);}
    for(let j=0;j<5;j++){let a=z.a+(j-2)*.06,r=83+hash(k*12+j)*8;let o=add(new THREE.IcosahedronGeometry(1,1),moss,Math.cos(a)*r,1.4,Math.sin(a)*r,.1);o.scale.set(3+hash(j)*3,1.2,2.5+hash(j+4)*2);sync(o);}}
  const fernLeaf=shader(`float u=vUv.x,v=vUv.y;float vein=1.-smoothstep(.015,.075,abs(v-.5));vec3 c=mix(vec3(.025,.095,.070),vec3(.13,.34,.23),u);float light=max(dot(normalize(vN),normalize(vec3(-.5,.9,.4))),0.);c*=.65+.65*light;c+=vec3(.09,.20,.13)*vein*.45;gl_FragColor=vec4(c,1.);`,THREE.DoubleSide);
  const fernStem=shader(`float light=max(dot(normalize(vN),normalize(vec3(-.5,.9,.4))),0.);gl_FragColor=vec4(vec3(.07,.18,.12)*(.6+light*.6),1.);`);
  const fernInk=new THREE.MeshBasicMaterial({color:0x10151a});
  const fernMaterials={leaf:fernLeaf,stem:fernStem,ink:fernInk};
  for(let i=0;i<6;i++){let a=[-1.5,-.65,.55,1.8,2.55,3.6][i],fern=SlugshotFern.create(THREE,{seed:19,materials:fernMaterials});fern.position.set(Math.cos(a)*91,.45,Math.sin(a)*91);fern.rotation.y=hash(i+870)*TAU;fern.scale.setScalar(.9+hash(i+881)*.30);scene.add(fern);}
  // Reuse the approved library's layout parameters and hexagonal crystal primitive.
  // Library pedestal rocks are omitted: these clusters grow directly from the volcano bedrock.
  const libraryScatter=[];
  const warmPalettes=[SLUGSHOT_CRYSTAL_DESIGNS[6],SLUGSHOT_CRYSTAL_DESIGNS[10],SLUGSHOT_CRYSTAL_DESIGNS[11]];
  function libraryCrystalMaterial(palette){return new THREE.ShaderMaterial({uniforms:{uTime:time,deep:{value:new THREE.Vector3(...palette.deep)},bright:{value:new THREE.Vector3(...palette.bright)}},vertexShader:vertex,fragmentShader:common+`uniform vec3 deep,bright;void main(){vec3 n=normalize(vN);float h=clamp(vUv.y,0.,1.);float paint=.92+.08*noise3(vP*.9);float light=max(dot(n,normalize(vec3(-.6,.9,.4))),0.);float facet=.72+.28*light;vec3 c=mix(deep,bright,smoothstep(.05,1.,h))*(.50+.50*light);c+=bright*(.08+.32*pow(h,2.))*facet;c*=paint;float edge=pow(1.-max(dot(n,normalize(cameraPosition-vP)),0.),3.);c+=bright*.1*edge;if(deep.g<.01)c.gb*=.68;gl_FragColor=vec4(c,1.);}`});}
  const crystalMaterials=warmPalettes.map(libraryCrystalMaterial);
  function hexCrystalGeometry(h,r){const q=[],uv=[],ii=[];const yb=-.6,yt=(h-1.35*r)/(1-.108*r/h);for(const y of [yb,yt]){let rr=r*(1-.08*y/h)/.8660254;for(let i=0;i<6;i++){let a=i*TAU/6;q.push(Math.cos(a)*rr,y,Math.sin(a)*rr);uv.push(i/6,clamp(y/h,0,1));}}q.push(0,h,0,0,yb,0);uv.push(.5,1,.5,0);for(let i=0;i<6;i++){let j=(i+1)%6;ii.push(i,i+6,j,j,i+6,j+6,i+6,12,j+6,13,i,j);}const g=geometry(q,ii,uv).toNonIndexed();g.computeVertexNormals();return g;}
  function crystalShard(cluster,base,yaw,tilt,h,r,dir){let g=hexCrystalGeometry(h,r);if(dir){g.applyQuaternion(new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0,1,0),new THREE.Vector3(...dir).normalize()));}else{g.rotateZ(tilt);g.rotateY(-yaw);}g.translate(...base);g.scale(cluster.scale,cluster.scale,cluster.scale);g.rotateY(cluster.yaw);g.translate(cluster.x,.4,cluster.z);add(g,crystalMaterials[cluster.palette],0,0,0,.13);}
  function buildLibraryCluster(cluster){const d=SLUGSHOT_CRYSTAL_DESIGNS[cluster.design];
    if(d.special===4){ // Gold spiral: the library's central spire and nine rising staircase crystals.
      crystalShard(cluster,[0,.2,0],0,0,5.6,.55,[0,1,0]);for(let i=0;i<9;i++){let a=i*.78,rr=1.55-.06*i;crystalShard(cluster,[Math.cos(a)*rr,.15,Math.sin(a)*rr],0,0,.7+.42*i,.26+.012*i,[Math.cos(a)*.35,1,Math.sin(a)*.35]);}
    }else if(d.authored){const originals=[[[0,.3,0],0,.05,4.7,.72],[[.35,.3,.15],.8,.48,3.3,.55],[[-.3,.3,.3],2.6,.5,2.6,.5],[[-.2,.3,-.35],4,.36,3.6,.58],[[.6,.2,-.3],1.7,.72,1.8,.4],[[-.6,.2,-.1],5.2,.66,2.1,.42],[[.1,.2,.7],3.3,.82,1.3,.3]];for(const v of originals)crystalShard(cluster,...v);
    }else{ // Exact authored variant layout formulas and seeds from crystalVariant.
      for(let i=0;i<d.a[0];i++){let k=(i+.5)/d.a[0],th=i*2.39996+d.c[3],rad=d.b[3]>.5?d.a[1]:(i===0?0:d.a[1]*Math.sqrt(k)),h=mix(d.a[2],d.a[3],k)*(.85+.3*hash(i+d.c[3])),tilt=mix(d.b[0],d.b[1],d.b[3]>.5?hash(i*3.1+d.c[3]):rad/Math.max(d.a[1],.01)),yaw=th+Math.PI,base=[rad*Math.cos(th),d.c[2]+d.c[1]*hash(i*7.3+d.c[3]),rad*Math.sin(th)];crystalShard(cluster,base,yaw,tilt,h,d.b[2]*(.7+.5*(1-k)));}
    }
  }
  const designOrder=[6,10,2,1,3,0,10,2,6,3,1,0];
  for(let k=0;k<12;k++){let a=k*TAU/12+.10+(hash(k+620)-.5)*.18,rr=88+(hash(k+631)-.5)*3.5;
    const cluster={design:designOrder[k],palette:k%3,scale:1.55+hash(k+644)*.35,yaw:hash(k+659)*TAU,x:Math.cos(a)*rr,z:Math.sin(a)*rr};buildLibraryCluster(cluster);libraryScatter.push({name:SLUGSHOT_CRYSTAL_DESIGNS[cluster.design].name,colour:['Crimson','Gold','Molten orange'][cluster.palette],...cluster});
    if(k%2===0)mushroom(Math.cos(a+.075)*(rr+.8),.4,Math.sin(a+.075)*(rr+.8),.45+hash(k+670)*.3,k%3);
  }
  // Fine ember and diffuse smoke textures. No smoke spheres or cubes.
  const smokeCanvas=document.createElement('canvas');smokeCanvas.width=smokeCanvas.height=128;let sx=smokeCanvas.getContext('2d');let grad=sx.createRadialGradient(64,64,0,64,64,64);grad.addColorStop(0,'rgba(255,255,255,.35)');grad.addColorStop(.35,'rgba(255,255,255,.18)');grad.addColorStop(1,'rgba(255,255,255,0)');sx.fillStyle=grad;sx.fillRect(0,0,128,128);const smokeTex=new THREE.CanvasTexture(smokeCanvas);
  const smoke=[];for(let i=0;i<18;i++){const mat=new THREE.SpriteMaterial({map:smokeTex,color:0xb6aec6,transparent:true,opacity:.15,depthWrite:false});const o=new THREE.Sprite(mat);scene.add(o);smoke.push(o);}
  const emberMat=new THREE.MeshBasicMaterial({color:0xffbd69});const droplets=[];for(let i=0;i<30;i++){let o=add(new THREE.IcosahedronGeometry(.55+hash(i)*.8,1),emberMat);droplets.push(o);}
  const fountains=[];
  function fountainPoint(k,u){const a=k*TAU/ERUPTION.count+.35,height=35+hash(k+92)*13,spread=15+hash(k+105)*12;return new THREE.Vector3(cp[0]+Math.cos(a)*(1.8+spread*u),126+4*height*u*(1-u),cp[1]+Math.sin(a)*(1.8+spread*u));}
  // A continuously evaluated tube; neither the head nor tail jumps between stored mesh segments.
  function jetGeometry(){const vs=[],uv=[],ix=[],S=64,W=8;for(let j=0;j<=S;j++)for(let i=0;i<=W;i++){let a=i/W*TAU;vs.push(Math.cos(a),j/S,Math.sin(a));uv.push(i/W,j/S);}for(let j=0;j<S;j++)for(let i=0;i<W;i++){let a=j*(W+1)+i,b=a+W+1;ix.push(a,b,a+1,a+1,b,b+1);}return geometry(vs,ix,uv);}
  const jetGeo=jetGeometry();
  for(let k=0;k<ERUPTION.count;k++){let a=k*TAU/ERUPTION.count+.35,height=35+hash(k+92)*13,spread=15+hash(k+105)*12;
    const material=new THREE.ShaderMaterial({transparent:true,depthWrite:false,uniforms:{uTime:time,angle:{value:a},height:{value:height},spread:{value:spread},delay:{value:k*.065},origin:{value:new THREE.Vector3(cp[0],126,cp[1])}},vertexShader:`uniform float uTime,angle,height,spread,delay;uniform vec3 origin;varying float alpha,along,side;void main(){float phase=mod(uTime,7.5)-delay,head=clamp(phase/1.9,0.,1.),tail=clamp((phase-.85)/1.9,0.,1.),s=position.y,u=mix(tail,head,s);vec3 tangent=normalize(vec3(cos(angle)*spread,4.*height*(1.-2.*u),sin(angle)*spread)),axis=vec3(-sin(angle),0.,cos(angle)),other=normalize(cross(tangent,axis));float width=1.15*pow(max(0.,sin(3.141593*s)),.35)*(.85+.15*sin(u*24.-uTime*3.));vec3 p=origin+vec3(cos(angle)*(1.8+spread*u),4.*height*u*(1.-u),sin(angle)*(1.8+spread*u))+(axis*position.x+other*position.z)*width;alpha=clamp((head-tail)*18.,0.,1.)*(.9-.15*head);along=u;side=position.x;gl_Position=projectionMatrix*viewMatrix*vec4(p,1.);}`,fragmentShader:`varying float alpha,along,side;void main(){if(alpha<.002)discard;vec3 c=mix(vec3(1.5,.38,.07),vec3(2.2,1.35,.36),pow(1.-abs(side),.65));gl_FragColor=vec4(c,alpha);}`});
    const o=add(jetGeo,material);o.frustumCulled=false;fountains.push(o);
  }
  const motes=[];const moteMat=new THREE.SpriteMaterial({map:smokeTex,color:0x89e0ce,blending:THREE.AdditiveBlending,transparent:true,depthWrite:false});for(let i=0;i<22;i++){const o=new THREE.Sprite(moteMat);o.scale.setScalar(.9+hash(i)*.8);scene.add(o);motes.push(o);}
  // Simple R6-sized reference stays near the base.
  const human=new THREE.MeshBasicMaterial({color:0xe9dfba});add(new THREE.BoxGeometry(2,2,1),human,14,3,91,.08);add(new THREE.BoxGeometry(.8,2,.8),human,13.5,1,91,.06);add(new THREE.BoxGeometry(.8,2,.8),human,14.5,1,91,.06);add(new THREE.BoxGeometry(1.1,1.1,1),human,14,4.6,91,.05);
  // Lightweight bloom from the rendered scene, keeping the paint and ink crisp.
  const rt=new THREE.WebGLRenderTarget(1,1,{type:THREE.HalfFloatType});const bloomA=new THREE.WebGLRenderTarget(1,1),bloomB=new THREE.WebGLRenderTarget(1,1);
  const postScene=new THREE.Scene(),postCam=new THREE.OrthographicCamera(-1,1,1,-1,0,1),quad=new THREE.Mesh(new THREE.PlaneGeometry(2,2));postScene.add(quad);
  const postV='varying vec2 uv0;void main(){uv0=uv;gl_Position=vec4(position.xy,0.,1.);}';
  const blur=new THREE.ShaderMaterial({uniforms:{tex:{value:rt.texture},dir:{value:new THREE.Vector2()},first:{value:1}},vertexShader:postV,fragmentShader:`varying vec2 uv0;uniform sampler2D tex;uniform vec2 dir;uniform float first;vec3 sampleAt(vec2 p){vec3 c=texture2D(tex,p).rgb;return first>.5?max(c-vec3(.5),vec3(0.)):c;}void main(){vec3 c=sampleAt(uv0)*.227027;c+=sampleAt(uv0+dir*1.384615)*.316216;c+=sampleAt(uv0-dir*1.384615)*.316216;c+=sampleAt(uv0+dir*3.230769)*.070270;c+=sampleAt(uv0-dir*3.230769)*.070270;gl_FragColor=vec4(c,1.);}`});
  const composite=new THREE.ShaderMaterial({uniforms:{tex:{value:rt.texture},bloom:{value:bloomB.texture}},vertexShader:postV,fragmentShader:`varying vec2 uv0;uniform sampler2D tex,bloom;void main(){vec3 c=texture2D(tex,uv0).rgb+texture2D(bloom,uv0).rgb*.65;c=c/(vec3(1.)+c*.65);c=pow(c,vec3(1./2.2));float v=1.-.18*dot(uv0-.5,uv0-.5);gl_FragColor=vec4(c*v,1.);}`});
  let soloFern=null;
  if(FERN_MODE){for(const o of scene.children)o.visible=false;soloFern=SlugshotFern.create(THREE,{seed:19,materials:fernMaterials});scene.add(soloFern);}
  let yaw=CAPTURE?Number(Q.get('frame')):-.75,pitch=Q.has('above')?1.03:.35,distance=FERN_MODE?25:335,auto=false,motion=true,drag=false,lx=0,ly=0;
  function setView(y,p){yaw=y;pitch=p;}
  document.getElementById('front').onclick=()=>setView(0,.28);document.getElementById('above').onclick=()=>setView(-.35,1.03);document.getElementById('reset').onclick=()=>{distance=FERN_MODE?25:335;setView(-.75,.35);};
  document.getElementById('rotate').textContent='Auto rotate';document.getElementById('rotate').onclick=e=>{auto=!auto;e.target.textContent=auto?'Stop rotation':'Auto rotate';};
  const motionButton=document.getElementById('motion');if(motionButton)motionButton.onclick=e=>{motion=!motion;e.target.textContent=motion?'Pause effects':'Resume effects';};
  stage.onpointerdown=e=>{drag=true;lx=e.clientX;ly=e.clientY;stage.setPointerCapture(e.pointerId);};stage.onpointerup=stage.onpointercancel=()=>drag=false;stage.onpointermove=e=>{if(!drag)return;yaw-=(e.clientX-lx)*.008;pitch=clamp(pitch+(e.clientY-ly)*.006,-.05,1.25);lx=e.clientX;ly=e.clientY;};stage.onwheel=e=>{e.preventDefault();distance=clamp(distance*Math.exp(e.deltaY*.001),FERN_MODE?12:190,FERN_MODE?45:480);};
  let last=0,elapsed=3.8,lastW=0,lastH=0;
  function draw(ms){let dt=last?Math.min((ms-last)/1000,.05):0;last=ms;if(motion&&!CAPTURE)elapsed+=dt;time.value=elapsed;if(auto&&!drag)yaw+=dt*.11;let t=elapsed;
    let cp0=Math.cos(pitch);camera.position.set(Math.sin(yaw)*cp0*distance,(FERN_MODE?4.3:67)+Math.sin(pitch)*distance,Math.cos(yaw)*cp0*distance);camera.lookAt(0,FERN_MODE?4.3:67,0);
    for(let i=0;i<smoke.length;i++){let u=(t*.055+i/smoke.length)%1,s=smoke[i],size=10+u*42;s.position.set(cp[0]+Math.sin(i*2.7+t*.2)*2+u*10,129+u*58,cp[1]+Math.cos(i+t*.15)*3);s.scale.set(size,size,1);s.material.opacity=.24*(1-u)*Math.min(1,u*7);}
    for(let i=0;i<droplets.length;i++){let u=((t%ERUPTION.period)-(i%6)*.048)/1.9,d=droplets[i],a=i*2.399,v=103+hash(i+32)*18,g=103+hash(i+45)*14,spread=10+hash(i+58)*13;let y=127+v*u-g*u*u;d.visible=u>=0&&y>=122&&u<1.25;d.position.set(cp[0]+Math.cos(a)*spread*u,y,cp[1]+Math.sin(a)*spread*u);const velocity=new THREE.Vector3(Math.cos(a)*spread,v-2*g*u,Math.sin(a)*spread).normalize();d.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0),velocity);let sc=Math.max(.15,1-u*.45);d.scale.set(sc*.75,sc*(1.15+Math.abs(v-2*g*u)*.008),sc*.75);}
    if(!FERN_MODE)for(let i=0;i<fountains.length;i++)fountains[i].visible=jetState(t,i).visible;
    for(let i=0;i<motes.length;i++){let a=i*2.399,r=81+hash(i)*14,y=3+((t*.7+i*1.3)%14);motes[i].position.set(Math.cos(a)*r,y,Math.sin(a)*r);}
    const w=stage.clientWidth,h=stage.clientHeight;if(w!==lastW||h!==lastH){lastW=w;lastH=h;renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix();const ratio=renderer.getPixelRatio();rt.setSize(Math.round(w*ratio),Math.round(h*ratio));bloomA.setSize(Math.round(w/3),Math.round(h/3));bloomB.setSize(Math.round(w/3),Math.round(h/3));}
    renderer.setRenderTarget(rt);renderer.render(scene,camera);quad.material=blur;blur.uniforms.tex.value=rt.texture;blur.uniforms.first.value=1;blur.uniforms.dir.value.set(4/w,0);renderer.setRenderTarget(bloomA);renderer.render(postScene,postCam);blur.uniforms.tex.value=bloomA.texture;blur.uniforms.first.value=0;blur.uniforms.dir.value.set(0,4/h);renderer.setRenderTarget(bloomB);renderer.render(postScene,postCam);quad.material=composite;renderer.setRenderTarget(null);renderer.render(postScene,postCam);
    requestAnimationFrame(draw);
  }
  const wallMeshes=scene.children.filter(o=>o.isMesh&&o.material===rock);
  function projectedEffects(){if(FERN_MODE)return {ribbons:[],arcs:[],crater:[.5,.5]};camera.updateMatrixWorld();const project=p=>{let v=p.clone().project(camera);return [(v.x*.5+.5),(-v.y*.5+.5)];},ray=new THREE.Raycaster(),ribbons=[];
    for(const stream of streams){let run=[];for(let j=0;j<=stream.segments;j+=2){let at=s=>new THREE.Vector3(...stream.positions.slice((j*(stream.across+1)+s)*3,(j*(stream.across+1)+s)*3+3)),p=at(stream.across/2),delta=p.clone().sub(camera.position),dist=delta.length();ray.set(camera.position,delta.normalize());let hit=ray.intersectObjects(wallMeshes,false)[0];let visible=!hit||hit.distance>=dist-.7;if(visible){let xy=project(p),l=project(at(0)),r=project(at(stream.across));run.push([...xy,Math.max(.001,Math.hypot(l[0]-r[0],l[1]-r[1])*.20),j/stream.segments]);}else{if(run.length>2)ribbons.push(run);run=[];}}if(run.length>2)ribbons.push(run);}
    return {ribbons,arcs:fountains.map((o,k)=>Array.from({length:129},(_,i)=>project(fountainPoint(k,i/128)))),crater:project(new THREE.Vector3(cp[0],129,cp[1]))};
  }
  window.volcanoReview={mode:'live',eruptionState:t=>Array.from({length:ERUPTION.count},(_,i)=>jetState(t,i)),asset:FERN_MODE?'fern':'volcano',fernGLB:()=>{let fern=soloFern||SlugshotFern.create(THREE,{seed:19});let bytes=new Uint8Array(SlugshotFern.toGLB(THREE,fern)),text='';for(let i=0;i<bytes.length;i+=8192)text+=String.fromCharCode(...bytes.subarray(i,i+8192));return btoa(text);},projectedEffects,libraryScatter:()=>libraryScatter,setView:(y,p=.35)=>{yaw=y;pitch=p;auto=false;},setTime:t=>{elapsed=t;motion=false;},stats:()=>({meshes:scene.children.filter(x=>x.isMesh).length,triangles:renderer.info.render.triangles})};requestAnimationFrame(draw);
}
