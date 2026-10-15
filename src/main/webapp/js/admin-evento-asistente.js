/* Asistente de eventos: consume los contratos administrativos a través del cliente existente. */
window.BetZoneEventWizard = function (options) {
    'use strict';
    const {request, run, base, role, onEvent, onError, onSport} = options;
    const $ = id => document.getElementById(id);
    const root = $('event-wizard');
    const canWrite = role === 'ADMINISTRADOR' || role === 'OPERADOR_EVENTOS';
    const key = 'betzone-event-wizard:' + base;
    const sports = new Map(), leagues = new Map(), candidates = new Map();
    let selected = [], step = 1, blocked = false, snapshot = null, eventId = null, createUncertain = false, needsCheck = false, officialParticipantCount = 0;
    const idValid = id => Number.isInteger(Number(id)) && Number(id) > 0 && Number(id) <= 2147483647;
    function node(tag,text) {const el=document.createElement(tag);if(text!==undefined)el.textContent=text;return el;}
    function option(value,text) {const el=node('option',text);el.value=String(value);return el;}
    function message(text,error=false) {$('wizard-status').textContent=text;$('wizard-status').dataset.error=String(error);}
    function failure(error) {
        if (error.status === 401 || error.status === 403) onError(error);
        const text=error.status?'Servidor HTTP '+error.status+' en '+(error.endpoint||'la operación solicitada')+'. '
            :error.name==='AbortError'?'La solicitud se interrumpió o agotó su tiempo. ':error instanceof TypeError?'No fue posible conectar con el servidor. ':error.message+' ';
        message(text+(snapshot?'El proceso se conserva. Consulta su configuración oficial antes de enviar otra operación.':'Los campos se conservan para corregirlos o reintentar.'),true);
    }
    function save(required=false) {
        try {if(snapshot)sessionStorage.setItem(key,JSON.stringify({version:1,snapshot,eventId,createUncertain}));else sessionStorage.removeItem(key);}
        catch {if(required)throw new Error('No se pudo guardar el progreso en esta pestaña; no se envió la operación.');message('El progreso permanece en esta pantalla, pero no pudo guardarse para una recarga. Conserva la referencia del evento.',true);}
    }
    function complete() {return Boolean(eventId)&&!needsCheck&&(snapshot?.participants.length>0?snapshot.participants.every(p=>p.status==='confirmed'):officialParticipantCount>0);}
    function sync(disabled=false) {
        blocked=disabled;
        root.querySelectorAll('button,input,select').forEach(el=>{el.disabled=disabled||!canWrite;});
        if(snapshot)root.querySelectorAll('[data-wizard-step="1"] input,[data-wizard-step="1"] select,[data-wizard-step="1"] button,[data-wizard-step="2"] input,[data-wizard-step="2"] select,[data-wizard-step="2"] button,[data-wizard-step="3"] input').forEach(el=>{el.disabled=true;});
        $('wizard-league').disabled=disabled||!canWrite||Boolean(snapshot)||!leagues.size;
        for(const id of ['wizard-first','wizard-second'])$(id).disabled=disabled||!canWrite||Boolean(snapshot)||!candidates.size||!leagues.has($('wizard-league').value);
        $('wizard-duration').disabled=disabled||!canWrite||Boolean(snapshot)||!$('wizard-simulated').checked;
        $('wizard-prev').disabled=disabled||step===1||Boolean(snapshot);
        $('wizard-next').hidden=step>=4||Boolean(snapshot);
        $('wizard-create').disabled=disabled||!canWrite||Boolean(snapshot);
        $('wizard-recovery').hidden=!createUncertain||Boolean(eventId);
        $('wizard-reconcile').disabled=disabled||!canWrite||!eventId;
        $('wizard-resume').disabled=disabled||!canWrite||!eventId||needsCheck||snapshot?.participants.every(p=>p.status==='confirmed')||snapshot?.participants.some(p=>p.status==='conflict');
        $('wizard-new').disabled=disabled||!canWrite||!complete();
        $('wizard-markets').hidden=!complete();
        if(complete())$('wizard-markets').href=base+'/administrador/mercados?idEvento='+encodeURIComponent(eventId);
        root.setAttribute('aria-busy',String(disabled));
    }
    function showStep(next,focus=true) {
        step=next;
        root.querySelectorAll('[data-wizard-step]').forEach(el=>{el.hidden=Number(el.dataset.wizardStep)!==step;});
        root.querySelectorAll('[data-step-marker]').forEach(el=>{if(Number(el.dataset.stepMarker)===step)el.setAttribute('aria-current','step');else el.removeAttribute('aria-current');});
        if(step===4)summary();
        sync(blocked);
        if(focus)$('wizard-title').focus();
    }
    async function task(work) {
        if(blocked||!canWrite)return;
        return run(async()=>{try{await work();}catch(error){failure(error);}finally{sync(true);}});
    }
    function validateStep(number) {
        const container=root.querySelector('[data-wizard-step="'+number+'"]');
        for(const control of container.querySelectorAll('input,select'))if(!control.disabled&&!control.checkValidity()){control.reportValidity();return false;}
        if(number===1&&(!sports.has($('wizard-sport').value)||!leagues.has($('wizard-league').value))){message('Selecciona un deporte y una liga consultados.',true);return false;}
        if(number===2){
            if(selected.length!==2){message("Selecciona dos participantes diferentes de la liga y deporte consultados.",true);return false;}
            const ids=new Set(),orders=new Set();
            for(const participant of selected){if(!idValid(participant.id)||!Number.isInteger(participant.order)||participant.order<1||participant.order>255||ids.has(participant.id)||orders.has(participant.order)){message('Revisa los participantes y sus órdenes; no pueden repetirse.',true);return false;}ids.add(participant.id);orders.add(participant.order);}
        }
        if(number===3&&!$('wizard-name').value.trim()){message('Escribe el nombre del evento.',true);$('wizard-name').focus();return false;}
        return true;
    }
    function current() {
        const stamp=value=>/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)?value+':00':value;
        const payload={idLiga:$('wizard-league').value,nombre:$('wizard-name').value.trim(),fechaInicio:stamp($('wizard-start').value),esSimulado:String($('wizard-simulated').checked)};
        if($('wizard-end').value)payload.fechaFin=stamp($('wizard-end').value);
        if($('wizard-simulated').checked&&$('wizard-duration').value)payload.duracionSimulacionSegundos=$('wizard-duration').value;
        return {sportId:$('wizard-sport').value,sportName:sports.get($('wizard-sport').value)?.nombre,leagueName:leagues.get($('wizard-league').value)?.nombre,payload,participants:selected.map(p=>({...p,status:'pending'}))};
    }
    function summary() {
        const draft=snapshot||current();const dl=node('dl');
        const rows=[['Deporte',draft.sportName],['Liga',draft.leagueName],['Evento',draft.payload.nombre],['Participantes',draft.participants.length?draft.participants.map(p=>(p.name||'Referencia manual #'+p.id)+' · orden '+p.order+' · '+(p.local===''?'sin condición local':p.local==='true'?'local':'visitante')).join('; '):'Sin participantes: borrador pendiente de configuración'],['Inicio',draft.payload.fechaInicio],['Fin',draft.payload.fechaFin||'Sin especificar'],['Tipo',draft.payload.esSimulado==='true'?'Simulado':'No simulado'],['Duración',draft.payload.esSimulado==='true'?(draft.payload.duracionSimulacionSegundos?draft.payload.duracionSimulacionSegundos+' segundos':'Predeterminada por el backend'):'No corresponde']];
        rows.forEach(([label,value])=>dl.append(node('dt',label),node('dd',value||'No disponible')));$('wizard-summary').replaceChildren(dl);
    }
    function participantRows() {
        $('wizard-participants').replaceChildren(node('p',selected.length?selected.map(p=>p.name).join(' · '):'Selecciona dos participantes diferentes.'));
    }
    function clearParticipants() {
        candidates.clear();selected=[];participantRows();
        for(const id of ['wizard-first','wizard-second']){$(id).replaceChildren(option('','Primero selecciona una liga'));$(id).disabled=true;}
    }
    function chooseParticipants() {
        selected=[];
        for(const [index,id] of ['wizard-first','wizard-second'].entries()){
            const p=candidates.get($(id).value);if(p)selected.push({id:p.id,name:p.name,order:index+1,local:p.type==='EQUIPO'?String(index===0):''});
        }
        for(const [id,other] of [['wizard-first','wizard-second'],['wizard-second','wizard-first']])
            for(const item of $(id).options)item.disabled=Boolean(item.value)&&item.value===$(other).value;
        if(selected.length===2&&selected[0].id===selected[1].id){$('wizard-second').value='';selected.pop();}
        participantRows();
    }
    async function loadParticipants() {
        clearParticipants();
        const league=leagues.get($('wizard-league').value);if(!league){sync(blocked);return;}
        return task(async()=>{
            message('Cargando participantes…');
            const rows=await window.BetZoneAdmin.participants($('wizard-sport').value);
            rows.forEach(p=>candidates.set(String(p.idParticipante),{id:p.idParticipante,name:p.nombre,type:p.tipoParticipante}));
            const teams=rows.length>0&&rows.every(p=>p.tipoParticipante==='EQUIPO');
            $('wizard-first-label').textContent=teams?'Equipo local':'Participante 1';$('wizard-second-label').textContent=teams?'Equipo visitante':'Participante 2';
            for(const id of ['wizard-first','wizard-second']){
                $(id).replaceChildren(option('','Selecciona un participante'));for(const [key,p] of candidates)$(id).append(option(key,p.name+' · '+p.type));
            }
            message(rows.length?'Participantes activos compatibles con el deporte de la liga.':'No hay participantes disponibles para esta liga.');
        });
    }
    async function loadSports() {
        if (snapshot) return;
        return task(async()=>{
            const data=await request('/deportes/exploracion');
            if(!Array.isArray(data.deportes)||data.deportes.some(p=>!idValid(p.idDeporte)||typeof p.nombre!=='string'))throw new Error('Catálogo de deportes inválido.');
            sports.clear();data.deportes.forEach(p=>sports.set(String(p.idDeporte),p));
            const old=$('wizard-sport').value;$('wizard-sport').replaceChildren(option('','Selecciona un deporte'));for(const [id,p] of sports)$('wizard-sport').append(option(id,p.nombre));
            if(sports.has(old))$('wizard-sport').value=old;
            message(sports.size?'Selecciona un deporte para consultar sus ligas.':'No hay deportes activos disponibles.');
        });
    }
    async function loadLeagues() {
        const sport=$('wizard-sport').value;if(!sports.has(sport)){message('Selecciona un deporte consultado.',true);return;}
        return task(async()=>{
            const data=await request('/ligas/exploracion?'+new URLSearchParams({idDeporte:sport}));
            if(Number(data.idDeporte)!==Number(sport)||!Array.isArray(data.ligas)||data.ligas.some(p=>Number(p.idDeporte)!==Number(sport)||!idValid(p.idLiga)||typeof p.nombre!=='string'))throw new Error('Las ligas recibidas no corresponden al deporte seleccionado.');
            const old=$('wizard-league').value;leagues.clear();data.ligas.forEach(p=>leagues.set(String(p.idLiga),p));$('wizard-league').replaceChildren(option('','Selecciona una liga'));for(const [id,p] of leagues)$('wizard-league').append(option(id,p.nombre));if(leagues.has(old))$('wizard-league').value=old;
            message(leagues.size?'Ligas del deporte consultadas.':'No hay ligas disponibles para este deporte. Puedes registrarlas en Ligas y participantes.');
        });
    }
    function outcome() {
        $('wizard-created-reference').textContent=eventId?'Evento confirmado: '+snapshot.payload.nombre+' · referencia #'+eventId:'La creación todavía no tiene un ID confirmado.';
        $('wizard-outcome-title').textContent=complete()?'Evento configurado':'Configuración pendiente o parcial';
        const list=node('ul');for(const p of snapshot?.participants||[]){
            const row=node('li',(p.name||'Referencia manual #'+p.id)+' · '+({pending:'asociación pendiente',confirmed:'asociación confirmada',uncertain:'respuesta pendiente de comprobación',conflict:'la configuración oficial difiere de la solicitada'}[p.status]||'pendiente'));
            if(p.status==='pending'&&!needsCheck){
                const remove=node('button','Retirar del plan pendiente');remove.type='button';
                remove.addEventListener('click',()=>{if(!blocked&&window.confirm('¿Retirar esta asociación pendiente del plan? No se eliminará ningún registro del backend.')){snapshot.participants=snapshot.participants.filter(item=>item!==p);save();outcome();message('Plan pendiente actualizado. Para agregar otros participantes usa la administración avanzada del mismo evento y consulta su configuración oficial.');}});
                row.append(document.createTextNode(' '),remove);
            }
            list.append(row);
        }
        if(!snapshot?.participants.length)list.append(node('li',officialParticipantCount>0?'La consulta oficial confirma '+officialParticipantCount+' participante(s) asociados.':'El borrador aún no tiene participantes planificados. Completa sus asociaciones en la administración avanzada.'));
        $('wizard-associations').replaceChildren(list);showStep(eventId?5:4,false);sync(blocked);
    }
    async function post(path,payload,before) {
        const token=await request('/administrador/seguridad/csrf');if(typeof token.csrfToken!=='string'||!token.csrfToken)throw new Error('Token CSRF inválido.');
        before();
        try{return await request(path,{method:'POST',headers:{'X-CSRF-Token':token.csrfToken},body:new URLSearchParams(payload)});}
        catch(error){error.wizardSent=true;throw error;}
    }
    async function associate() {
        for(const participant of snapshot.participants){
            if(participant.status==='confirmed')continue;
            const payload={idEvento:String(eventId),idParticipante:String(participant.id),ordenParticipante:String(participant.order)};
            if(participant.local!=='')payload.esLocal=participant.local;
            try{
                const data=await post('/administrador/eventos/participantes/agregar',payload,()=>{participant.status='uncertain';save(true);});
                const result=data.resultado;
                if(!result||result.idEvento!==eventId||result.idParticipante!==participant.id||result.ordenParticipante!==participant.order||result.esLocal!==(participant.local===''?null:participant.local==='true')){const error=new Error('Asociación sin confirmación válida.');error.wizardSent=true;throw error;}
                participant.status='confirmed';save();
            }catch(error){needsCheck=true;save();outcome();failure(error);message('El evento '+snapshot.payload.nombre+' (#'+eventId+') ya existe, pero su configuración es parcial. '+$('wizard-status').textContent,true);return;}
        }
        needsCheck=false;save();onEvent(eventId);outcome();message(snapshot.participants.length?'Evento y asociaciones confirmados por el servidor. Puedes continuar con mercados y cuotas.':'Evento creado como borrador sin participantes. Completa su configuración en la administración avanzada.');
    }
    async function reconcile(id,recovery=false) {
        const data=await request('/eventos/exploracion/detalle?'+new URLSearchParams({idEvento:String(id)}));
        const official=data.evento;
        if(!official||official.idEvento!==Number(id)||official.idLiga!==Number(snapshot.payload.idLiga)||official.idDeporte!==Number(snapshot.sportId)||official.nombre!==snapshot.payload.nombre||!Array.isArray(official.participantes))throw new Error('El evento consultado no coincide con la referencia de este proceso. No se vinculó ni se envió ninguna asociación.');
        if(recovery&&!window.confirm('El servidor devuelve '+official.nombre+' (#'+official.idEvento+'). ¿Vincular este evento real al proceso conservado, sin crearlo nuevamente?'))return;
        eventId=official.idEvento;createUncertain=false;officialParticipantCount=official.participantes.length;
        for(const participant of snapshot.participants){
            const found=official.participantes.find(p=>p.idParticipante===participant.id);
            participant.status=found?(found.ordenParticipante===participant.order&&found.esLocal===(participant.local===''?null:participant.local==='true')?'confirmed':'conflict'):'pending';
        }
        needsCheck=false;save();onEvent(eventId);outcome();message(complete()?'Configuración confirmada en la consulta oficial. Puedes continuar con mercados y cuotas.':'Configuración oficial consultada. Revisa las asociaciones pendientes o diferentes; no se envió ningún POST.');
    }
    $('wizard-load-sports').addEventListener('click',loadSports);$('wizard-load-leagues').addEventListener('click',loadLeagues);
    $('wizard-sport').addEventListener('change',()=>{
        if(snapshot||blocked)return;
        onSport($('wizard-sport').value);leagues.clear();clearParticipants();
        $('wizard-league').replaceChildren(option('','Primero selecciona un deporte'));$('wizard-league').disabled=true;
        if(sports.has($('wizard-sport').value))loadLeagues();
    });
    $('wizard-league').addEventListener('change',()=>{if(!snapshot&&!blocked)loadParticipants();});
    for(const id of ['wizard-first','wizard-second'])$(id).addEventListener('change',chooseParticipants);
    $('wizard-simulated').addEventListener('change',()=>sync(blocked));
    $('wizard-prev').addEventListener('click',()=>{if(!blocked&&!snapshot&&step>1)showStep(step-1);});
    $('wizard-next').addEventListener('click',()=>{if(!blocked&&!snapshot&&step<4&&validateStep(step))showStep(step+1);});
    $('wizard-form').addEventListener('submit',event=>{
        event.preventDefault();if(blocked||snapshot||step!==4||![1,2,3].every(validateStep))return;
        if(!window.confirm('¿Crear '+$('wizard-name').value.trim()+' y después asociar los participantes indicados? Cada solicitud es independiente.'))return;
        task(async()=>{
            snapshot=current();
            try{
                const data=await post('/administrador/eventos/crear',snapshot.payload,()=>{createUncertain=true;save(true);});
                const result=data.resultado;
                if(!result||!Number.isInteger(result.idEvento)||!idValid(result.idEvento)||result.idLiga!==Number(snapshot.payload.idLiga)||result.nombre!==snapshot.payload.nombre||typeof result.estadoEvento!=='string'){const error=new Error('La creación no devolvió una confirmación válida.');error.wizardSent=true;throw error;}
                eventId=result.idEvento;createUncertain=false;needsCheck=false;save();onEvent(eventId);outcome();
                await associate();
            }catch(error){
                if(!eventId&&(!error.wizardSent||(error.status&&error.status<500&&error.status!==408))){snapshot=null;createUncertain=false;save();showStep(4,false);}
                else{createUncertain=!eventId;needsCheck=true;save();outcome();}
                failure(error);
            }
        });
    });
    $('wizard-reconcile').addEventListener('click',()=>{if(eventId&&snapshot)task(()=>reconcile(eventId));});
    $('wizard-resume').addEventListener('click',()=>{if(eventId&&snapshot&&!needsCheck&&!snapshot.participants.some(p=>p.status==='conflict')&&window.confirm('¿Asociar únicamente los participantes pendientes al evento ya creado #'+eventId+'? No se creará otro evento.'))task(associate);});
    $('wizard-recover').addEventListener('click',()=>{if(snapshot&&createUncertain&&idValid($('wizard-recovery-id').value))task(()=>reconcile(Number($('wizard-recovery-id').value),true));else message('Selecciona el evento localizado en el listado.',true);});
    $('wizard-advanced').addEventListener('click',()=>{if(eventId)onEvent(eventId);if(snapshot?.sportId)onSport(snapshot.sportId);$('advanced-event-management').open=true;});
    $('wizard-new').addEventListener('click',()=>{if(complete()&&window.confirm('El evento #'+eventId+' está confirmado. ¿Preparar otro evento?')){snapshot=null;eventId=null;createUncertain=false;needsCheck=false;officialParticipantCount=0;selected=[];save();$('wizard-form').reset();leagues.clear();candidates.clear();$('wizard-league').replaceChildren(option('','Selecciona una liga'));clearParticipants();participantRows();showStep(1);message('Puedes preparar un nuevo evento.');}});
    try{
        const saved=JSON.parse(sessionStorage.getItem(key)||'null');
        if(saved){
            if(saved.version!==1||!saved.snapshot||!idValid(saved.snapshot.payload?.idLiga)||!idValid(saved.snapshot.sportId)||typeof saved.snapshot.payload.nombre!=='string'||!Array.isArray(saved.snapshot.participants)||saved.snapshot.participants.some(p=>!idValid(p.id)||!Number.isInteger(p.order)||p.order<1||p.order>255||!['','true','false'].includes(p.local))||(saved.eventId!==null&&!idValid(saved.eventId)))throw new Error('Progreso guardado no válido. No se restauró.');
            snapshot=saved.snapshot;eventId=saved.eventId===null?null:Number(saved.eventId);createUncertain=!eventId;needsCheck=true;outcome();message('Hay un proceso conservado en esta pestaña. Consulta su configuración oficial antes de continuar.',true);
        }
    }catch(error){message('No se pudo recuperar el progreso guardado. Comprueba si ya creaste un evento antes de iniciar otra creación.',true);createUncertain=true;snapshot={payload:{nombre:'Proceso no recuperable'},participants:[]};}
    if(!snapshot)showStep(1,false);participantRows();sync(false);
    if(!canWrite)message('La creación requiere ADMINISTRADOR u OPERADOR_EVENTOS. El backend conserva la autorización definitiva.',true);
    return {sync,loadSports};
};
