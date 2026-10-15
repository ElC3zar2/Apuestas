(() => {
 'use strict';
 const A=window.BetZoneAdmin,$=id=>document.getElementById(id),role=document.body.dataset.adminRole;
 const canOperate=['ADMINISTRADOR','CAJERO'].includes(role),canRead=canOperate||role==='AUDITOR';
 const events=new Map(),money=new Intl.NumberFormat('es-GT',{style:'currency',currency:'GTQ'});
 const key='betzone-lote-pendiente:'+document.body.dataset.contextPath;
 let busy=false,expired=false,pending=new Set(),storage=true;
 try{const saved=JSON.parse(sessionStorage.getItem(key)||'[]');if(!Array.isArray(saved))throw new Error();pending=new Set(saved.map(String));}catch{storage=false;}
 const status=(text,error=false)=>{$('settlement-status').textContent=text;$('settlement-status').dataset.error=String(error);};
 function sync(){
  document.querySelectorAll('#contenido button,#contenido input,#contenido select').forEach(el=>{el.disabled=busy||expired;});
  $('settlement-event').disabled=busy||expired||!events.size;
  $('settle-button').disabled=busy||expired||!canOperate||!storage||!events.has($('settlement-event').value)||pending.has($('settlement-event').value);
  $('settle-form').hidden=!canOperate;$('settlement-ack').hidden=!canOperate||!pending.has($('settlement-event').value);
  $('settlement-query').querySelectorAll('input,button').forEach(el=>{el.disabled=busy||expired||!canRead;});
  $('settlement-result').setAttribute('aria-busy',String(busy));A.syncPages(busy||expired);
 }
 function report(e){
  if(e.status===401){expired=true;$('settlement-login').hidden=false;}
  status(e.status===409?'El evento todavía no tiene un resultado listo para liquidación.':e.status===503?
   'El servicio de liquidación no está disponible temporalmente. Verifica el estado antes de intentar nuevamente.':
   e.status?A.messages[e.status]||'No fue posible completar la operación.':e.name==='AbortError'?
   'La solicitud agotó su tiempo. Su resultado puede ser parcial; verifica el estado antes de repetirla.':e instanceof TypeError?'No fue posible conectar con el servidor.':e.message,true);
 }
 async function task(work){if(busy||expired)return;busy=true;sync();try{await work();}catch(e){report(e);}finally{busy=false;sync();}}
 function persist(){try{sessionStorage.setItem(key,JSON.stringify([...pending]));}catch{storage=false;throw new Error('No se pudo conservar el estado del envío en esta pestaña.');}}
 async function loadEvents(){
  if(busy||expired)return;
  const sport=$('settlement-sport').value;events.clear();A.choices($('settlement-event'),[],'idEvento',A.eventLabel,'Cargando eventos…');$('settlement-event-info').replaceChildren();$('settlement-result').hidden=true;
  if(!sport){sync();return;}
  await task(async()=>{
   status('Cargando eventos…');const data=await A.request(A.eventsPath(sport));
   if(!Array.isArray(data.eventos)||data.eventos.some(e=>e.idDeporte!==Number(sport)))throw new Error('Respuesta de eventos inconsistente.');
   A.pageData(data);data.eventos.forEach(e=>events.set(String(e.idEvento),e));A.choices($('settlement-event'),data.eventos,'idEvento',A.eventLabel);
   status(data.eventos.length?'Selecciona un evento para liquidar.':'No hay eventos disponibles en esta consulta.');
  });
 }
 function selection(){
  $('settlement-result').hidden=true;const e=events.get($('settlement-event').value);
  $('settlement-event-info').replaceChildren(A.node('p',e?A.eventLabel(e):'Selecciona un evento.'));
  if(pending.has($('settlement-event').value))status('Hay un envío sin confirmación para este evento. Verifica el estado antes de repetirlo.',true);sync();
 }
 function render(r){
  if(!r||r.idEvento!==Number($('settlement-event').value)||!Array.isArray(r.detalles))throw new Error('El lote recibido no corresponde al evento seleccionado.');
  const fields=[['Boletos relacionados','boletosRelacionados'],['Elegibles','boletosElegibles'],['Liquidados ahora','boletosLiquidadosNuevos'],['Ya liquidados','boletosYaLiquidados'],['Omitidos','boletosOmitidos']];
  if(fields.some(([,k])=>!Number.isInteger(r[k])||r[k]<0)||!Number.isFinite(Number(r.montoTotalLiquidadoNuevo))||r.detalles.length!==r.boletosElegibles||r.detalles.some(d=>typeof d.solicitudIdempotente!=='boolean'))throw new Error('Respuesta de lote incompleta.');
  const dl=A.node('dl');dl.className='operation-values';fields.forEach(([label,k])=>dl.append(A.node('dt',label),A.node('dd',String(r[k]))));
  dl.append(A.node('dt','Monto liquidado nuevo'),A.node('dd',money.format(r.montoTotalLiquidadoNuevo)));$('settlement-values').replaceChildren(dl);
  const table=A.node('table'),head=A.node('thead'),tr=A.node('tr'),body=A.node('tbody');
  ['Código boleto','Resultado','Estado','Monto','Procesamiento'].forEach(t=>{const th=A.node('th',t);th.scope='col';tr.append(th);});head.append(tr);table.append(head);
  r.detalles.forEach(d=>{const row=A.node('tr');[d.codigoBoleto,d.resultadoBoleto,d.estadoBoleto,money.format(d.montoLiquidado),d.solicitudIdempotente?'Ya estaba liquidado':'Liquidado ahora'].forEach(v=>row.append(A.node('td',v)));body.append(row);});
  if(!r.detalles.length){const cell=A.node('td','No hay boletos elegibles para procesar.');cell.colSpan=5;const row=A.node('tr');row.append(cell);body.append(row);}
  table.append(body);$('settlement-details').replaceChildren(table);$('settlement-result').hidden=false;A.choices($('batch-ticket'),r.detalles,'idBoleto','codigoBoleto');
  status(r.boletosLiquidadosNuevos>0?'Liquidación confirmada por el servidor.':r.boletosYaLiquidados>0?'El evento ya había sido liquidado. No se generaron liquidaciones nuevas.':'No hay liquidaciones nuevas. Los boletos pendientes permanecen omitidos.');
 }
 $('event-filter').addEventListener('submit',e=>{e.preventDefault();loadEvents();});$('settlement-sport').addEventListener('change',()=>{A.resetEvents();loadEvents();});$('settlement-event').addEventListener('change',selection);
 $('settle-form').addEventListener('submit',e=>{
  e.preventDefault();const id=$('settlement-event').value;if(busy||!canOperate||!storage||!events.has(id)||pending.has(id))return;
  if(!window.confirm('¿Liquidar los boletos elegibles de '+A.eventLabel(events.get(id))+'?'))return;
  task(async()=>{let sent=false;status('Procesando liquidación…');$('settlement-result').hidden=true;
   try{const token=await A.csrf();pending.add(id);persist();sent=true;
    const data=await A.request('/administrador/liquidaciones/liquidar-evento',{method:'POST',headers:{'X-CSRF-Token':token},body:new URLSearchParams({idEvento:id})});
    render(data.resultado);pending.delete(id);persist();
   }catch(error){if(!sent||(error.status&&error.status<500&&error.status!==408)){pending.delete(id);persist();}throw error;}
  });
 });
 $('settlement-ack').addEventListener('click',()=>{if(!busy&&window.confirm('¿Verificaste el estado? Esta acción solo habilita un envío manual; no ejecuta liquidaciones.')){pending.delete($('settlement-event').value);try{persist();}catch(e){report(e);}sync();}});
 $('batch-ticket').addEventListener('change',()=>{$('ticket-id').value=$('batch-ticket').value;});
 $('settlement-query').addEventListener('submit',e=>{e.preventDefault();if(!canRead||!$('settlement-query').reportValidity())return;
  task(async()=>{const data=await A.request('/administrador/liquidaciones/consultar?'+new URLSearchParams({idBoleto:$('ticket-id').value}));const r=data.resultado;if(!r)throw new Error('Consulta de liquidación inválida.');
   $('ticket-results').replaceChildren(A.node('p',[r.codigoBoleto,r.resultadoBoleto,r.estadoLiquidacion,money.format(r.montoLiquidado)].join(' · ')));status('Consulta oficial completada.');});
 });
 A.eventPagination($('event-filter'));sync();task(async()=>{
  status('Cargando deportes…');const data=await A.request('/deportes/exploracion');A.choices($('settlement-sport'),data.deportes,'idDeporte','nombre');
  const initial=new URLSearchParams(location.search).get('idEvento');
  if(initial&&/^[0-9]{1,10}$/.test(initial)&&Number(initial)>0&&Number(initial)<=2147483647){
   const detail=await A.request('/eventos/exploracion/detalle?'+new URLSearchParams({idEvento:initial}));
   if(detail.evento?.idEvento!==Number(initial))throw new Error('El evento consultado no coincide con el enlace.');
   events.set(initial,detail.evento);A.choices($('settlement-event'),[detail.evento],'idEvento',A.eventLabel);$('settlement-event').value=initial;$('settlement-sport').value=String(detail.evento.idDeporte);selection();
  }
  status(canOperate?'Selecciona un deporte y un evento.':canRead?'Tu rol permite consultar liquidaciones individuales.':'Tu rol no tiene permisos de liquidación.');
 });
})();
