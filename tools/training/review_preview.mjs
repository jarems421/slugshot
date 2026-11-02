// Local browser evidence for the generated 3D review. No account/session access.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {spawn} from 'node:child_process';
const out=path.resolve('build/training/browser-review');fs.mkdirSync(out,{recursive:true});
const profile=fs.mkdtempSync(path.join(os.tmpdir(),'slugshot-training-review-'));
const child=spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless','--remote-debugging-port=0','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-gpu-sandbox','--hide-scrollbars','--no-first-run',`--user-data-dir=${profile}`,'about:blank'],{windowsHide:true,stdio:'ignore'});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));let ws;
try{
 let port;for(let i=0;i<150;i++){try{port=fs.readFileSync(path.join(profile,'DevToolsActivePort'),'utf8').split('\n')[0];break;}catch{}await sleep(100);}if(!port)throw Error('Chrome debug port unavailable');
 const pages=await(await fetch(`http://127.0.0.1:${port}/json/list`)).json();
 ws=new WebSocket(pages.find(p=>p.type==='page').webSocketDebuggerUrl);await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j});
 let serial=0;const pending=new Map(),errors=[];
 ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(m.error):p.resolve(m.result)}else if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails.exception?.description||m.params.exceptionDetails.text);};
 const call=(method,params={})=>new Promise((resolve,reject)=>{let id=++serial;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}))});
 const ev=async expression=>(await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true})).result;
 await call('Page.enable');await call('Runtime.enable');await call('Emulation.setDeviceMetricsOverride',{width:1500,height:1100,deviceScaleFactor:1,mobile:false});
 await call('Page.navigate',{url:process.argv[2]||'http://127.0.0.1:8879/'});
 let ready=false;for(let i=0;i<240;i++){if((await ev('Boolean(window.trainingReview)')).value){ready=true;break;}await sleep(250);}if(!ready)throw Error('Preview failed to become ready');
 const stats=(await ev('({mode:trainingReview.mode,stats:trainingReview.stats})')).value;
 if(stats.mode!=='webgl')throw Error('Interactive WebGL preview unavailable; check fallbacks');
 for(const view of ['island','above','underside','inside','room']){
  await ev(`document.querySelector('[data-view="${view}"]').click()`);await sleep(800);
  const shot=await call('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(out,view+'.png'),Buffer.from(shot.data,'base64'));
  if((await ev('trainingReview.active')).value!==view)throw Error('View button failed: '+view);
  const n=(await ev('trainingReview.roomVisible')).value;if(view==='inside'&&n<1)throw Error('Inside view hides enclosure');if(view==='island'&&n!==0)throw Error('Island view obscured by room');
 }
 await ev(`document.getElementById('rotate').click()`);if(!(await ev('trainingReview.controls.autoRotate')).value)throw Error('Auto rotation failed');
 await ev(`document.getElementById('reset').click()`);if((await ev('trainingReview.active')).value!=='island'||(await ev('trainingReview.controls.autoRotate')).value)throw Error('Reset failed');
 await call('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});await sleep(400);
 if((await ev('document.documentElement.scrollWidth>document.documentElement.clientWidth')).value)throw Error('Mobile horizontal overflow');
 const shot=await call('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(out,'mobile.png'),Buffer.from(shot.data,'base64'));
 if(errors.length)throw Error(errors.join('\n'));
 fs.writeFileSync(path.join(out,'results.json'),JSON.stringify({pass:true,...stats,views:5,mobileWidth:390,rotation:true,reset:true,errors},null,2));console.log(JSON.stringify({pass:true,...stats,views:5,rotation:true,reset:true,mobileWidth:390,errors}));
}finally{ws?.close();child.kill();}
