const translations={
  en:{title:'Alarm control',subtitle:'Monitoring dashboard',language:'Language',edit:'Edit',live:'Live',floorPlan:'Floor plan',upload:'Upload image',mapHint:'Click the floor plan to add a point.',dataPoints:'Data points',simulate:'Simulate alarm',connecting:'Connecting…',connected:'Connected',offline:'Offline',emptyMap:'Upload a floor plan to get started',rename:'Point name',address:'Register (0-based)',source:'Input type',host:'Device IP / host',port:'Modbus port',fc:'Function code',unit:'Unit ID',remove:'Remove',empty:'No data points yet',added:'Sensor'},
  de:{title:'Alarmsteuerung',subtitle:'Überwachungs-Dashboard',language:'Sprache',edit:'Bearbeiten',live:'Live',floorPlan:'Gebäudeplan',upload:'Bild hochladen',mapHint:'Klicken Sie auf den Gebäudeplan, um einen Datenpunkt hinzuzufügen.',dataPoints:'Datenpunkte',simulate:'Alarm simulieren',connecting:'Verbindung wird hergestellt…',connected:'Verbunden',offline:'Offline',emptyMap:'Laden Sie einen Gebäudeplan hoch',rename:'Punktname',address:'Register (ab 0)',source:'Eingangstyp',host:'Geräte-IP / Host',port:'Modbus-Port',fc:'Funktionscode',unit:'Unit-ID',remove:'Entfernen',empty:'Noch keine Datenpunkte',added:'Sensor'},
  es:{title:'Control de alarmas',subtitle:'Panel de supervisión',language:'Idioma',edit:'Edición',live:'En directo',floorPlan:'Plano de planta',upload:'Subir imagen',mapHint:'Haz clic en el plano para añadir un punto.',dataPoints:'Puntos de datos',simulate:'Simular alarma',connecting:'Conectando…',connected:'Conectado',offline:'Sin conexión',emptyMap:'Sube un plano para empezar',rename:'Nombre del punto',address:'Registro (desde 0)',source:'Tipo de entrada',host:'IP / host del equipo',port:'Puerto Modbus',fc:'Código de función',unit:'ID de unidad',remove:'Eliminar',empty:'Aún no hay puntos',added:'Sensor'}
};
const $=id=>document.getElementById(id);let lang=localStorage.getItem('ema-language')||'en',mode='edit',points=[],socket=null,mapData=localStorage.getItem('ema-floorplan')||'';
function t(key){return translations[lang][key]||translations.en[key]||key}
function applyLanguage(){document.documentElement.lang=lang;document.querySelectorAll('[data-i18n]').forEach(el=>el.textContent=t(el.dataset.i18n));$('language').value=lang;render()}
function api(path,options={}){return fetch(`/api${path}`,{headers:{'Content-Type':'application/json'},...options})}
async function loadPoints(){try{let r=await api('/points');if(r.ok){points=await r.json();render()}}catch{setConnection(false)}}
function setConnection(on){$('connectionDot').classList.toggle('online',on);$('connectionText').textContent=t(on?'connected':'offline')}
function connect(){const scheme=location.protocol==='https:'?'wss':'ws';socket=new WebSocket(`${scheme}://${location.host}/ws`);socket.onopen=()=>setConnection(true);socket.onclose=()=>{setConnection(false);setTimeout(connect,2500)};socket.onerror=()=>socket.close();socket.onmessage=e=>{const msg=JSON.parse(e.data);if(msg.type==='point.deleted')points=points.filter(p=>p.id!==msg.id);else if(msg.point){const i=points.findIndex(p=>p.id===msg.point.id);if(i<0)points.push(msg.point);else points[i]=msg.point}render()}}
function setMode(next){mode=next;$('editMode').classList.toggle('active',mode==='edit');$('liveMode').classList.toggle('active',mode==='live');$('editControls').hidden=mode!=='edit';render()}
function safeText(tag,value){const el=document.createElement(tag);el.textContent=value;return el}
function render(){const markers=$('markers'),list=$('pointsList');markers.replaceChildren();list.replaceChildren();$('pointCount').textContent=points.length;
 for(const p of points){const marker=document.createElement('div');marker.className=`marker ${p.state?'alarm':''}`;marker.style.left=`${p.x}%`;marker.style.top=`${p.y}%`;marker.title=p.name;markers.append(marker);
  const card=document.createElement('article');card.className=`point ${p.state?'alarm':''}`;const top=document.createElement('div');top.className='point-top';top.append(safeText('span',p.name));if(mode==='edit'){const del=safeText('button',`× ${t('remove')}`);del.className='small delete';del.onclick=()=>removePoint(p.id);top.append(del)}card.append(top);
  if(mode==='edit'){const name=document.createElement('input');name.value=p.name;name.setAttribute('aria-label',t('rename'));name.onchange=()=>updatePoint(p.id,{name:name.value});card.append(name);
   const source=document.createElement('select');source.setAttribute('aria-label',t('source'));for(const s of ['modbus','gpio','usb']){const o=safeText('option',s.toUpperCase());o.value=s;source.append(o)}source.value=p.source_type;source.onchange=()=>updatePoint(p.id,{source_type:source.value});card.append(source);
   if(p.source_type==='modbus'){
    const host=document.createElement('input');host.value=p.host||'';host.placeholder=t('host');host.setAttribute('aria-label',t('host'));host.onchange=()=>updatePoint(p.id,{host:host.value});
    const port=document.createElement('select');port.setAttribute('aria-label',t('port'));for(let n=502;n<=510;n++){const o=safeText('option',String(n));o.value=n;port.append(o)}port.value=p.port||502;port.onchange=()=>updatePoint(p.id,{port:Number(port.value)});
    const fc=document.createElement('select');fc.setAttribute('aria-label',t('fc'));for(const n of [1,2,3,4]){const o=safeText('option',`FC ${String(n).padStart(2,'0')}`);o.value=n;fc.append(o)}fc.value=p.function_code||1;fc.onchange=()=>updatePoint(p.id,{function_code:Number(fc.value)});
    const address=document.createElement('input');address.value=p.address;address.placeholder=t('address');address.setAttribute('aria-label',t('address'));address.inputMode='numeric';address.onchange=()=>updatePoint(p.id,{address:address.value});
    const unit=document.createElement('input');unit.value=p.unit_id??1;unit.placeholder=t('unit');unit.setAttribute('aria-label',t('unit'));unit.inputMode='numeric';unit.onchange=()=>updatePoint(p.id,{unit_id:Number(unit.value)});
    card.append(host,port,fc,address,unit)
   }
  }list.append(card)
 }
 if(points.length===0)list.append(safeText('p',t('empty')));
}
async function createPoint(x,y){const payload={name:`${t('added')} ${points.length+1}`,source_type:'modbus',address:String(points.length),host:'',port:502,function_code:1,unit_id:1,x,y,state:false};try{const r=await api('/points',{method:'POST',body:JSON.stringify(payload)});if(r.ok){points.push(await r.json());render()}}catch{setConnection(false)}}
async function updatePoint(id,patch){try{const r=await api(`/points/${id}`,{method:'PATCH',body:JSON.stringify(patch)});if(r.ok){const v=await r.json();points=points.map(p=>p.id===id?v:p);render()}}catch{setConnection(false)}}
async function removePoint(id){try{const r=await api(`/points/${id}`,{method:'DELETE'});if(r.ok){points=points.filter(p=>p.id!==id);render()}}catch{setConnection(false)}}
$('language').onchange=e=>{lang=e.target.value;localStorage.setItem('ema-language',lang);applyLanguage()};$('editMode').onclick=()=>setMode('edit');$('liveMode').onclick=()=>setMode('live');
$('mapUpload').onchange=e=>{const file=e.target.files[0];if(!file)return;const reader=new FileReader();reader.onload=()=>{mapData=reader.result;localStorage.setItem('ema-floorplan',mapData);showMap()};reader.readAsDataURL(file)};
function showMap(){if(!mapData)return;$('floorPlan').src=mapData;$('mapContainer').style.display='block';$('placeholder').hidden=true}
$('mapContainer').onclick=e=>{if(mode!=='edit'||e.target!==$('floorPlan'))return;const r=$('floorPlan').getBoundingClientRect();createPoint(Math.max(0,Math.min(100,(e.clientX-r.left)/r.width*100)),Math.max(0,Math.min(100,(e.clientY-r.top)/r.height*100)))};
$('simulate').onclick=async()=>{if(!points.length)return;const p=points[0];await updatePoint(p.id,{state:!p.state})};
applyLanguage();showMap();loadPoints();connect();
