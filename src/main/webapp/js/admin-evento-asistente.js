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
    const idValid = id => /^[0-9]{1,10}$/.test(String(id)) && Number(id) > 0 && Number(id) <= 2147483647;
    let participantPage=1,participantTotal=0,leaving=false,catalogRevision=0,suggestedName='';
    let recoveryPage=1,recoveryTotal=0,configurationConflict=false;
    let officialDetail=null,contextConflict=false;
    let quick=null;
    const participantTypes=new Set();
    const states=['BORRADOR','PROGRAMADO','EN_VIVO','SUSPENDIDO','PENDIENTE_RESULTADO','FINALIZADO','CANCELADO'];
    function stamp(value,precision=9){
        if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,9})?)?$/.test(value)||value.slice(0,4)==='0000'||(value.split('.')[1]||'').length>precision)return null;
        const [y,m,d,h,n,s]=value.match(/\d+/g).map(Number),date=new Date(0);date.setUTCFullYear(y,m-1,d);date.setUTCHours(h,n,s||0,0);
        if(date.getUTCFullYear()!==y||date.getUTCMonth()!==m-1||date.getUTCDate()!==d||h>23||n>59||(s||0)>59)return null;
        return value.length===16?value+':00':value.includes('.')?value.replace(/0+$/,'').replace(/\.$/,''):value;
    }
    const sameDate=(a,b)=>stamp(a)!==null&&stamp(a)===stamp(b);
    const namedRows=(rows,key)=>Array.isArray(rows)&&rows.every(p=>p&&Number.isInteger(p[key])&&idValid(p[key])&&typeof p.nombre==='string'&&p.nombre.trim())&&new Set(rows.map(p=>p[key])).size===rows.length;
    function validSnapshot(draft){
        const p=draft?.payload,people=draft?.participants;
        return p&&Object.keys(p).every(k=>['idLiga','nombre','fechaInicio','fechaFin','esSimulado','duracionSimulacionSegundos'].includes(k))&&idValid(draft.sportId)&&idValid(p.idLiga)&&typeof p.nombre==='string'&&p.nombre.trim().length>0&&p.nombre.length<=200&&stamp(p.fechaInicio,7)
            &&(!p.fechaFin||(stamp(p.fechaFin,7)&&stamp(p.fechaFin)>stamp(p.fechaInicio)))&&['true','false'].includes(p.esSimulado)
            &&(!p.duracionSimulacionSegundos||(p.esSimulado==='true'&&idValid(p.duracionSimulacionSegundos)))
            &&Array.isArray(people)&&people.length<=2&&people.every((p,index)=>Number.isInteger(p.id)&&idValid(p.id)&&typeof p.name==='string'&&p.name.trim()&&p.name.length<=150&&p.order===index+1&&['',String(index===0)].includes(p.local)&&['pending','confirmed','uncertain','conflict'].includes(p.status))
            &&new Set(people.map(p=>p.id)).size===people.length&&new Set(people.map(p=>p.order)).size===people.length;
    }
    function node(tag,text) {const el=document.createElement(tag);if(text!==undefined)el.textContent=text;return el;}
    function option(value,text) {const el=node('option',text);el.value=String(value);return el;}
    function message(text,error=false) {$('wizard-status').textContent=text;$('wizard-status').dataset.error=String(error);}
    function failure(error) {
        if(leaving||error.cancelledByNavigation)return;
        if (error.status === 401 || error.status === 403) onError(error);
        const text=error.status?'Servidor HTTP '+error.status+' en '+(error.endpoint||'la operación solicitada')+'. '
            :error.name==='AbortError'?'La solicitud se interrumpió o agotó su tiempo. ':error instanceof TypeError?'No fue posible conectar con el servidor. ':error.message+' ';
        message(text+(snapshot?'El proceso se conserva. Consulta su configuración oficial antes de enviar otra operación.':'Los campos se conservan para corregirlos o reintentar.'),true);
    }
    function save(required=false) {
        try {if(snapshot)sessionStorage.setItem(key,JSON.stringify({version:1,snapshot,eventId,createUncertain}));else sessionStorage.removeItem(key);}
        catch {if(required)throw new Error('No se pudo guardar el progreso en esta pestaña; no se envió la operación.');message('El progreso permanece en esta pantalla, pero no pudo guardarse para una recarga. Conserva la referencia del evento.',true);}
    }
    function complete() {return Boolean(eventId)&&!contextConflict&&!needsCheck&&!configurationConflict&&officialParticipantCount===2&&snapshot?.participants.length===2&&snapshot.participants.every(p=>p.status==='confirmed');}
    function sync(disabled=false) {
        const sharedDisabled=disabled;
        disabled=disabled||Boolean(quick&&quick.pending());
        blocked=disabled;
        root.querySelectorAll('button,input,select').forEach(el=>{el.disabled=disabled||!canWrite;});
        if(snapshot)root.querySelectorAll('[data-wizard-step="1"] input,[data-wizard-step="1"] select,[data-wizard-step="1"] button,[data-wizard-step="2"] input,[data-wizard-step="2"] select,[data-wizard-step="2"] button,[data-wizard-step="3"] input').forEach(el=>{el.disabled=true;});
        $('wizard-league').disabled=disabled||!canWrite||Boolean(snapshot)||!leagues.size;
        for(const id of ['wizard-first','wizard-second'])$(id).disabled=disabled||!canWrite||Boolean(snapshot)||!candidates.size||!leagues.has($('wizard-league').value);
        $('wizard-simulated').disabled=disabled||!canWrite||Boolean(snapshot)||sports.get($('wizard-sport').value)?.permiteSimulacion!==true;
        if(!snapshot&&sports.get($('wizard-sport').value)?.permiteSimulacion!==true)$('wizard-simulated').checked=false;
        $('wizard-duration').disabled=disabled||!canWrite||Boolean(snapshot)||!$('wizard-simulated').checked;
        if(!snapshot){
            const sport=sports.get($('wizard-sport').value);
            $('wizard-simulation-help').textContent=(sport?.permiteSimulacion===false?'Este deporte no permite simulación; no se enviará duración. '
                :'Si activas simulación, puedes indicar una duración o dejarla vacía para usar la configuración del backend. ')
                +'Las fechas se envían tal como las indicas, sin convertir zonas horarias.';
        }
        $('wizard-participant-prev').disabled=disabled||!canWrite||Boolean(snapshot)||participantPage<=1;
        $('wizard-participant-next').disabled=disabled||!canWrite||Boolean(snapshot)||participantPage*100>=participantTotal;
        $('wizard-prev').disabled=disabled||step===1||Boolean(snapshot);
        $('wizard-next').hidden=step>=4||Boolean(snapshot);
        $('wizard-create').disabled=disabled||!canWrite||Boolean(snapshot);
        $('wizard-recovery').hidden=!createUncertain||Boolean(eventId);
        $('wizard-reconcile').disabled=disabled||!canWrite||!eventId;
        $('wizard-resume').disabled=disabled||!canWrite||!eventId||needsCheck||configurationConflict||snapshot?.estadoEvento!=='BORRADOR'||!snapshot?.participants.some(p=>p.status==='pending')||snapshot?.participants.some(p=>p.status==='conflict');
        $('wizard-recovery-prev').disabled=disabled||!canWrite||recoveryPage<=1;
        $('wizard-recovery-next').disabled=disabled||!canWrite||recoveryPage*100>=recoveryTotal;
        $('wizard-new').disabled=disabled||!canWrite||!complete()||snapshot?.programming?.state==='uncertain';
        $('wizard-markets').hidden=!complete();
        $('wizard-program').disabled=disabled||!canWrite||!complete()||snapshot?.estadoEvento!=='BORRADOR'||Boolean(snapshot?.programming);
        if(complete())$('wizard-markets').href=base+'/administrador/mercados?idEvento='+encodeURIComponent(eventId)+'#market-one';
        if(contextConflict)root.querySelectorAll('button,input,select').forEach(el=>{el.disabled=true;});
        if(snapshot&&step===5)preparation();
        root.setAttribute('aria-busy',String(disabled));
        if(quick)quick.sync(sharedDisabled,Boolean(snapshot&&(!complete()||snapshot.programming?.state==='uncertain')));
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
        if(blocked||!canWrite||contextConflict)return;
        return run(async()=>{try{await work();}catch(error){failure(error);}finally{sync(true);}});
    }
    function validateStep(number) {
        const container=root.querySelector('[data-wizard-step="'+number+'"]');
        for(const control of container.querySelectorAll('input,select'))if(!control.disabled&&!control.checkValidity()){control.reportValidity();return false;}
        if(number===1&&(!sports.has($('wizard-sport').value)||!leagues.has($('wizard-league').value)||leagues.get($('wizard-league').value).idDeporte!==Number($('wizard-sport').value))){message('Selecciona un deporte y una liga consultados.',true);return false;}
        if(number===2){
            if(selected.length!==2){message('Selecciona dos participantes diferentes del deporte consultado.',true);return false;}
            const ids=new Set(),orders=new Set();
            for(const participant of selected){const candidate=candidates.get(String(participant.id));if(!idValid(participant.id)||!candidate||candidate.sport!==$('wizard-sport').value||candidate.league!==$('wizard-league').value||!Number.isInteger(participant.order)||participant.order<1||participant.order>255||ids.has(participant.id)||orders.has(participant.order)){message('Revisa los participantes y sus órdenes; no pueden repetirse ni pertenecer a otro contexto.',true);return false;}ids.add(participant.id);orders.add(participant.order);}
        }
        if(number===3&&!$('wizard-name').value.trim()){message('Escribe el nombre del evento.',true);$('wizard-name').focus();return false;}
        if(number===3){
            const draft=current();
            if(!validSnapshot(draft)||($('wizard-simulated').checked&&sports.get($('wizard-sport').value)?.permiteSimulacion!==true)){
                message('Revisa nombre (máximo 200), fechas, permiso de simulación y duración entera positiva. El fin debe ser posterior al inicio.',true);return false;
            }
        }
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
        const rows=[['Deporte',draft.sportName],['Liga',draft.leagueName],['Evento',draft.payload.nombre],['Participantes',draft.participants.length?draft.participants.map(p=>p.name+' · '+(p.local===''?'Participante '+p.order:p.local==='true'?'LOCAL':'VISITANTE')).join('; '):'Sin participantes: borrador pendiente de configuración'],['Inicio',draft.payload.fechaInicio],['Fin',draft.payload.fechaFin||'Sin especificar'],['Tipo',draft.payload.esSimulado==='true'?'Simulado':'No simulado'],['Duración',draft.payload.esSimulado==='true'?(draft.payload.duracionSimulacionSegundos?draft.payload.duracionSimulacionSegundos+' segundos':'Predeterminada por el backend'):'No corresponde'],['Estado inicial','BORRADOR']];
        rows.forEach(([label,value])=>dl.append(node('dt',label),node('dd',value||'No disponible')));$('wizard-summary').replaceChildren(dl);
    }
    function participantRows() {
        for(const [index,id] of ['wizard-first-label','wizard-second-label'].entries()){
            const chosen=selected.find(p=>p.order===index+1);
            const team=chosen?chosen.type==='EQUIPO':participantTypes.size===1&&participantTypes.has('EQUIPO');
            $(id).textContent=team?(index===0?'Equipo LOCAL':'Equipo VISITANTE'):'Participante '+(index+1);
        }
        $('wizard-participants').replaceChildren(node('p',selected.length?selected.map(p=>(p.local===''?'Participante '+p.order:p.local==='true'?'LOCAL':'VISITANTE')+': '+p.name).join(' · '):'Selecciona dos participantes diferentes.'));
        const suggestion=selected.length===2?selected.map(p=>p.name).join(' vs '):'';
        if(!$('wizard-name').value||$('wizard-name').value===suggestedName)$('wizard-name').value=suggestion.slice(0,200);
        suggestedName=suggestion.slice(0,200);
    }
    function clearParticipants() {
        candidates.clear();participantTypes.clear();selected=[];participantPage=1;participantTotal=0;participantRows();$('wizard-participant-page').textContent='';
        $('wizard-participant-search').value='';
        for(const id of ['wizard-first','wizard-second']){$(id).replaceChildren(option('','Primero selecciona una liga'));$(id).disabled=true;}
    }
    function chooseParticipants() {
        selected=[];
        for(const [index,id] of ['wizard-first','wizard-second'].entries()){
            const p=candidates.get($(id).value);if(p)selected.push({id:p.id,name:p.name,type:p.type,order:index+1,local:p.type==='EQUIPO'?String(index===0):''});
        }
        for(const [id,other] of [['wizard-first','wizard-second'],['wizard-second','wizard-first']])
            for(const item of $(id).options)item.disabled=Boolean(item.value)&&item.value===$(other).value;
        if(selected.length===2&&selected[0].id===selected[1].id){$('wizard-second').value='';selected.pop();}
        participantRows();
    }
    async function loadParticipants(reset=true) {
        if(blocked||snapshot||!canWrite)return;
        if(reset)clearParticipants();
        const league=leagues.get($('wizard-league').value);if(!league){sync(blocked);return;}
        const revision=++catalogRevision,sport=$('wizard-sport').value,page=participantPage;
        return task(async()=>{
            message('Cargando participantes…');
            const search=$('wizard-participant-search').value.trim();
            if(search.length>150)throw new Error('La búsqueda admite hasta 150 caracteres.');
            const data=await request('/administrador/participantes/listar?'+new URLSearchParams({idDeporte:sport,idLiga:league.idLiga,activo:'true',pagina:participantPage,tamanoPagina:100,...(search?{buscar:search}:{})}));
            if(leaving||snapshot||revision!==catalogRevision||sport!==$('wizard-sport').value||String(league.idLiga)!==$('wizard-league').value||search!==$('wizard-participant-search').value.trim())return;
            const rows=participantPageRows(data,sport,page);
            const oldValues=['wizard-first','wizard-second'].map(id=>$(id).value);
            for(const [key] of candidates)if(!selected.some(p=>String(p.id)===key))candidates.delete(key);
            rows.forEach(p=>{candidates.set(String(p.idParticipante),{id:p.idParticipante,name:p.nombre,type:p.tipoParticipante,sport,league:String(league.idLiga)});participantTypes.add(p.tipoParticipante);});
            participantTotal=data.total;$('wizard-participant-page').textContent='Página '+participantPage+' · '+data.total+' participantes';
            for(const id of ['wizard-first','wizard-second']){
                $(id).replaceChildren(option('','Selecciona un participante'));for(const [key,p] of candidates)$(id).append(option(key,p.name+' · '+p.type));
            }
            ['wizard-first','wizard-second'].forEach((id,index)=>{if(candidates.has(oldValues[index]))$(id).value=oldValues[index];});chooseParticipants();
            message(rows.length?'Participantes activos asociados a la liga y compatibles con su deporte.':'No hay participantes activos asociados a esta liga. Registra sus asociaciones en Ligas y participantes.');
        });
    }
    async function loadSports() {
        if (snapshot||blocked||!canWrite) return;
        const revision=++catalogRevision;
        return task(async()=>{
            sports.clear();leagues.clear();clearParticipants();$('wizard-sport').replaceChildren(option('','Selecciona un deporte'));$('wizard-league').replaceChildren(option('','Primero consulta las ligas'));
            const data=await request('/deportes/exploracion');
            if(leaving||snapshot||revision!==catalogRevision)return;
            if(!namedRows(data.deportes,'idDeporte')||data.deportes.some(p=>p.activo!==true||typeof p.permiteSimulacion!=='boolean'))throw new Error('Catálogo de deportes inválido.');
            leagues.clear();clearParticipants();$('wizard-league').replaceChildren(option('','Primero consulta las ligas'));
            sports.clear();data.deportes.forEach(p=>sports.set(String(p.idDeporte),p));
            for(const [id,p] of sports)$('wizard-sport').append(option(id,p.nombre));
            message(sports.size?'Selecciona un deporte para consultar sus ligas.':'No hay deportes activos disponibles.');
        });
    }
    async function loadLeagues() {
        if(snapshot||blocked||!canWrite)return;
        const sport=$('wizard-sport').value;if(!sports.has(sport)){message('Selecciona un deporte consultado.',true);return;}
        const revision=++catalogRevision;
        return task(async()=>{
            leagues.clear();clearParticipants();$('wizard-league').replaceChildren(option('','Selecciona una liga'));
            const data=await request('/ligas/exploracion?'+new URLSearchParams({idDeporte:sport}));
            if(leaving||snapshot||revision!==catalogRevision||sport!==$('wizard-sport').value)return;
            if(Number(data.idDeporte)!==Number(sport)||!namedRows(data.ligas,'idLiga')||data.ligas.some(p=>p.idDeporte!==Number(sport)||p.activo!==true))throw new Error('Las ligas recibidas no corresponden al deporte seleccionado.');
            clearParticipants();
            data.ligas.forEach(p=>leagues.set(String(p.idLiga),p));for(const [id,p] of leagues)$('wizard-league').append(option(id,p.nombre));
            message(leagues.size?'Ligas del deporte consultadas.':'No hay ligas disponibles para este deporte. Puedes registrarlas en Ligas y participantes.');
        });
    }
    function participantPageRows(data,sport,page){
        const rows=data.participantes;
        if(!namedRows(rows,'idParticipante')||data.pagina!==page||data.tamanoPagina!==100||!Number.isSafeInteger(data.total)||data.total<0
            ||rows.length!==Math.min(100,Math.max(0,data.total-(page-1)*100))
            ||rows.some(p=>p.idDeporte!==Number(sport)||p.activo!==true||p.nombre.length>150||!['EQUIPO','ATLETA'].includes(p.tipoParticipante)))throw new Error('Página de participantes inconsistente.');
        return rows;
    }
    async function eligibleParticipants(draft,people=draft.participants){
        // Buscar solo los nombres seleccionados, paginando coincidencias si hace falta.
        for(const person of people){
            let page=1,found=false,total;
            do{
                const data=await request('/administrador/participantes/listar?'+new URLSearchParams({idDeporte:draft.sportId,idLiga:draft.payload.idLiga,buscar:person.name,activo:'true',pagina:page,tamanoPagina:100}));
                const rows=participantPageRows(data,draft.sportId,page);
                if(total!==undefined&&data.total!==total)throw new Error('El catálogo cambió durante la comprobación. Consulta nuevamente los participantes.');
                total=data.total;
                const official=rows.find(p=>p.idParticipante===person.id);
                if(official){
                    if(official.nombre!==person.name||official.tipoParticipante!==(person.local===''?'ATLETA':'EQUIPO'))throw new Error('El participante cambió. Consulta su nombre y tipo antes de confirmar.');
                    found=true;break;
                }
                page++;
            }while((page-1)*100<total);
            if(!found)throw new Error('No se encontró '+person.name+' activo en la liga seleccionada. Revisa Ligas y participantes; no se enviará su asociación.');
        }
    }
    async function checkCatalogs(draft){
        const data=await request('/deportes/exploracion');
        if(!namedRows(data.deportes,'idDeporte')||data.deportes.some(p=>p.activo!==true||typeof p.permiteSimulacion!=='boolean'))throw new Error('Catálogo de deportes inválido.');
        const sport=data.deportes.find(p=>p.idDeporte===Number(draft.sportId));
        if(!sport||sport.nombre!==draft.sportName||(draft.payload.esSimulado==='true'&&!sport.permiteSimulacion))throw new Error('El deporte cambió o ya no permite esta configuración. Consulta de nuevo el catálogo.');
        const dataLeagues=await request('/ligas/exploracion?'+new URLSearchParams({idDeporte:draft.sportId}));
        if(Number(dataLeagues.idDeporte)!==Number(draft.sportId)||!namedRows(dataLeagues.ligas,'idLiga')||dataLeagues.ligas.some(p=>p.activo!==true||p.idDeporte!==Number(draft.sportId)))throw new Error('Catálogo de ligas incompatible.');
        if(!dataLeagues.ligas.some(p=>p.idLiga===Number(draft.payload.idLiga)&&p.nombre===draft.leagueName))throw new Error('La liga ya no está disponible con los datos revisados.');
        await eligibleParticipants(draft);
    }
    function publishEvent(){onSport(snapshot.sportId,snapshot.sportName);onEvent(eventId);}
    function preparation(){
        const e=!needsCheck?officialDetail:null,list=$('wizard-preparation');list.replaceChildren();
        const add=(label,state)=>list.append(node('li',label+' · '+state));
        const pending=blocked?'EN PROCESO':'PENDIENTE';
        add('Evento creado',e?'CONFIRMADO':'REQUIERE REVISIÓN');
        add('Participantes asociados',complete()?'CONFIRMADO':needsCheck||configurationConflict?'REQUIERE REVISIÓN':pending);
        add('Evento programado',!e?'REQUIERE REVISIÓN':e.estadoEvento==='PROGRAMADO'?'CONFIRMADO':e.estadoEvento==='BORRADOR'?pending:'NO APLICA');
        const people=e?.participantes||[],local=people.find(p=>p.esLocal===true),visitor=people.find(p=>p.esLocal===false);
        const compatible=people.length===2&&people.every(p=>p.tipoParticipante==='EQUIPO')&&people.some(p=>p.ordenParticipante===1)&&people.some(p=>p.ordenParticipante===2)&&local&&visitor&&local.idParticipante!==visitor.idParticipante;
        const candidates=compatible&&Array.isArray(e.mercados)?e.mercados.filter(m=>m.tipoMercado==='CONVENCIONAL'&&Array.isArray(m.selecciones)&&
            (m.mercado==='Resultado final — 1X2'||m.selecciones.length===3&&[local.idParticipante,null,visitor.idParticipante].every(id=>m.selecciones.filter(s=>s.idParticipante===id).length===1))):[];
        const m=candidates.length===1?candidates[0]:null;
        const selections=m?.selecciones.length===3&&[local?.idParticipante,null,visitor?.idParticipante].every(id=>m.selecciones.filter(s=>s.idParticipante===id&&s.seleccionActiva===true&&idValid(s.idSeleccion)).length===1);
        const quotes=selections&&new Set(m.selecciones.map(s=>s.idCuota)).size===3&&m.selecciones.every(s=>idValid(s.idCuota)&&s.cuotaActiva===true&&s.fechaFinCuota===null&&Number(s.valor)>1&&Number(s.valor)<=999999.9999);
        const unknown=!e||candidates.length>1?'REQUIERE REVISIÓN':!compatible?'NO APLICA':'PENDIENTE';
        add('Mercado 1X2 configurado',selections?'CONFIRMADO':unknown);
        add('Cuotas registradas',quotes?'CONFIRMADO':unknown);
        add('Mercado abierto',quotes&&m.estadoMercado==='ABIERTO'?'CONFIRMADO':unknown);
        $('wizard-next-action').textContent=!e?'Verificación oficial pendiente. Se conserva el progreso; consulta la configuración antes de continuar.':
            !compatible?'El asistente 1X2 requiere dos EQUIPOS con LOCAL y VISITANTE inequívocos. Revisa la administración avanzada.':
            e.estadoEvento==='BORRADOR'?(snapshot.programming?'La programación tiene una respuesta conservada o incierta. No se repetirá; consulta el detalle y solicita revisión si continúa BORRADOR.':'Programa el evento para permitir la apertura de mercados.'):
            e.estadoEvento!=='PROGRAMADO'?'El evento está '+e.estadoEvento+'; no corresponde una nueva programación.':
            candidates.length>1?'Hay mercados equivalentes ambiguos. Requiere revisión manual.':!selections?'Configura el mercado 1X2.':!quotes?'Registra y revisa las tres cuotas.':m.estadoMercado==='ABIERTO'?'Evento preparado para apuestas.':m.estadoMercado==='BORRADOR'?'Abre el mercado cuando el evento esté programado.':'El mercado está '+m.estadoMercado+'; revisa la administración manual.';
        if(contextConflict&&eventId){const back=node('a','Volver al evento del proceso conservado');back.href=base+'/administrador/eventos?idEvento='+encodeURIComponent(eventId)+'#event-wizard';$('wizard-next-action').append(document.createTextNode(' '),back);}
    }
    function outcome() {
        $('wizard-created-reference').textContent=eventId?'Evento confirmado: '+snapshot.payload.nombre+' · referencia #'+eventId+' · Deporte: '+(snapshot.sportName||'Consulta el detalle')+' · Liga: '+(snapshot.leagueName||'Consulta el detalle')+' · Estado: '+(needsCheck?'pendiente de reconsulta':snapshot.estadoEvento||'pendiente de reconsulta')+' · Inicio: '+snapshot.payload.fechaInicio+' · '+(snapshot.payload.esSimulado==='true'?'Simulado':'No simulado'):'La creación todavía no tiene un ID confirmado.';
        $('wizard-outcome-title').textContent=needsCheck?'Verificación oficial pendiente':complete()?'Preparación para apuestas':'Configuración pendiente o parcial';
        preparation();
        const list=node('ul');for(const p of snapshot?.participants||[]){
            const row=node('li',(p.local==='true'?'LOCAL · ':p.local==='false'?'VISITANTE · ':'')+(p.name||'Referencia manual #'+p.id)+' · '+(needsCheck?'pendiente de revalidación':({pending:'asociación pendiente',confirmed:'asociación confirmada',uncertain:'respuesta pendiente de comprobación',conflict:'la configuración oficial difiere de la solicitada'}[p.status]||'pendiente')));
            list.append(row);
        }
        if(configurationConflict)list.append(node('li','Hay participantes oficiales ajenos al plan conservado. Revisa el evento en administración avanzada; no se sobrescribirá su configuración.'));
        if(!snapshot?.participants.length)list.append(node('li',officialParticipantCount>0?'La consulta oficial confirma '+officialParticipantCount+' participante(s) asociados.':'El borrador aún no tiene participantes planificados. Completa sus asociaciones en la administración avanzada.'));
        $('wizard-associations').replaceChildren(list);showStep(eventId?5:4,false);sync(blocked);
    }
    async function post(path,payload,before) {
        const token=await request('/administrador/seguridad/csrf');if(typeof token.csrfToken!=='string'||!/^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$/.test(token.csrfToken))throw new Error('Token CSRF inválido.');
        before();
        try{return await request(path,{method:'POST',headers:{'X-CSRF-Token':token.csrfToken},body:new URLSearchParams(payload)});}
        catch(error){error.wizardSent=true;throw error;}
    }
    async function associate() {
        if(!validSnapshot(snapshot)||!eventId||snapshot.participants.length!==2||needsCheck||configurationConflict)throw new Error('Consulta el detalle oficial y revisa las dos asociaciones antes de continuar.');
        await reconcile(eventId);
        if(snapshot.estadoEvento!=='BORRADOR')throw new Error('El evento debe estar en BORRADOR para completar sus asociaciones. Consulta su estado oficial.');
        if(configurationConflict||snapshot.participants.some(p=>p.status==='conflict'))throw new Error('La configuración oficial está en conflicto con el plan. Requiere revisión manual.');
        for(const participant of snapshot.participants){
            if(participant.status==='confirmed')continue;
            if(participant.status!=='pending')throw new Error('La asociación requiere conciliación antes de otra escritura.');
            const payload={idEvento:String(eventId),idParticipante:String(participant.id),ordenParticipante:String(participant.order)};
            if(participant.local!=='')payload.esLocal=participant.local;
            try{
                await eligibleParticipants(snapshot,[participant]);
                const data=await post('/administrador/eventos/participantes/agregar',payload,()=>{participant.status='uncertain';save(true);});
                const result=data.resultado;
                if(!result||!Number.isInteger(result.idEventoParticipante)||!idValid(result.idEventoParticipante)||result.idEvento!==eventId||result.idParticipante!==participant.id||result.ordenParticipante!==participant.order||result.esLocal!==(participant.local===''?null:participant.local==='true')){const error=new Error('Asociación sin confirmación válida.');error.wizardSent=true;throw error;}
                participant.status='confirmed';participant.resultado={idEventoParticipante:result.idEventoParticipante,idEvento:result.idEvento,
                    idParticipante:result.idParticipante,ordenParticipante:result.ordenParticipante,esLocal:result.esLocal};save();
                await reconcile(eventId);
                if(configurationConflict||snapshot.estadoEvento!=='BORRADOR'||snapshot.participants.some(p=>p.status==='conflict'))throw new Error('El evento cambió durante las asociaciones. Revisa el detalle oficial.');
            }catch(error){needsCheck=true;save();outcome();failure(error);message('El evento '+snapshot.payload.nombre+' (#'+eventId+') ya existe, pero su configuración es parcial. '+$('wizard-status').textContent,true);return;}
        }
        save();publishEvent();outcome();message(complete()?'Evento y ambas asociaciones comprobados en el detalle oficial. Puedes continuar con mercados y cuotas.':'La configuración permanece parcial. Consulta su detalle oficial antes de continuar.');
    }
    async function reconcile(id,recovery=false,observed=null) {
        if(contextConflict)throw new Error('El enlace y el proceso conservado no corresponden al mismo evento. Revisa el proceso anterior; no se mezclará ni borrará.');
        if(!validSnapshot(snapshot))throw new Error('El progreso conservado no permite comprobar la identidad del evento. No se enviarán escrituras.');
        needsCheck=true;outcome();sync(blocked);
        const data=observed?{evento:observed}:await request('/administrador/eventos/detalle?'+new URLSearchParams({idEvento:String(id)}));
        const official=data.evento;
        if(!official||official.idEvento!==Number(id)||official.idLiga!==Number(snapshot.payload.idLiga)||official.idDeporte!==Number(snapshot.sportId)||(official.evento??official.nombre)!==snapshot.payload.nombre||!states.includes(official.estadoEvento)||!sameDate(official.fechaInicio,snapshot.payload.fechaInicio)||(snapshot.payload.fechaFin?!sameDate(official.fechaFin,snapshot.payload.fechaFin):official.fechaFin!==null)
            ||typeof official.simulacion?.esSimulado!=='boolean'||official.simulacion.esSimulado!==(snapshot.payload.esSimulado==='true')
            ||(official.simulacion.esSimulado?!Number.isInteger(official.simulacion.duracionSimulacionSegundos)||!idValid(official.simulacion.duracionSimulacionSegundos):official.simulacion.duracionSimulacionSegundos!==null)
            ||(snapshot.payload.duracionSimulacionSegundos&&official.simulacion.duracionSimulacionSegundos!==Number(snapshot.payload.duracionSimulacionSegundos))
            ||(snapshot.durationConfirmed!==undefined&&official.simulacion.duracionSimulacionSegundos!==snapshot.durationConfirmed)
            ||!Array.isArray(official.participantes)||official.cantidadParticipantes!==official.participantes.length||official.participantes.some(p=>!p||!Number.isInteger(p.idParticipante)||!idValid(p.idParticipante)||!Number.isInteger(p.ordenParticipante)||p.ordenParticipante<1||p.ordenParticipante>255||![true,false,null].includes(p.esLocal))||new Set(official.participantes.map(p=>p.idParticipante)).size!==official.participantes.length||new Set(official.participantes.map(p=>p.ordenParticipante)).size!==official.participantes.length)throw new Error('El evento consultado no coincide con la identidad, fechas o simulación de este proceso. No se vinculó ni se envió ninguna asociación.');
        if(!Array.isArray(official.mercados)||official.cantidadMercados!==official.mercados.length||official.mercados.some(m=>!idValid(m.idMercado)||!Array.isArray(m.selecciones)||m.selecciones.some(s=>!idValid(s.idSeleccion))))throw new Error('Mercados oficiales inconsistentes; preparación pendiente de revisión.');
        official.nombre=official.evento??official.nombre;
        if(recovery&&!window.confirm('El servidor devuelve '+official.nombre+' (#'+official.idEvento+'). ¿Vincular este evento real al proceso conservado, sin crearlo nuevamente?'))return;
        officialDetail=official;
        eventId=official.idEvento;createUncertain=false;officialParticipantCount=official.participantes.length;snapshot.estadoEvento=official.estadoEvento;
        snapshot.sportName=official.deporte;snapshot.leagueName=official.liga;
        snapshot.durationConfirmed=official.simulacion.duracionSimulacionSegundos;
        configurationConflict=official.participantes.some(p=>!snapshot.participants.some(planned=>planned.id===p.idParticipante));
        for(const participant of snapshot.participants){
            const found=official.participantes.find(p=>p.idParticipante===participant.id);
            if(found&&typeof found.participante==='string')participant.name=found.participante;
            participant.status=found?(found.ordenParticipante===participant.order&&found.esLocal===(participant.local===''?null:participant.local==='true')?'confirmed':'conflict'):
                participant.status==='confirmed'||official.participantes.some(p=>p.ordenParticipante===participant.order)?'conflict':'pending';
        }
        needsCheck=false;save();if(!observed)publishEvent();outcome();message((complete()?'Configuración confirmada en la consulta oficial. Puedes continuar con mercados y cuotas.':'Configuración oficial consultada. Revisa las asociaciones pendientes o diferentes; esta consulta no envió ningún POST.')+(recovery?' La consulta demuestra el estado observado, pero no identifica qué petición creó el evento.':''));
    }
    async function recoveryEvents(page=1){
        if(!snapshot||!createUncertain||eventId||blocked||!canWrite)return;
        return task(async()=>{
            if(!validSnapshot(snapshot))throw new Error('El progreso guardado es incompatible. Revisa manualmente el listado de administración avanzada antes de crear otro evento.');
            const data=await request('/administrador/eventos/listar?'+new URLSearchParams({idDeporte:snapshot.sportId,pagina:page,tamanoPagina:100}));
            if(!Array.isArray(data.eventos)||data.pagina!==page||data.tamanoPagina!==100||!Number.isSafeInteger(data.total)||data.total<0
                ||data.eventos.length!==Math.min(100,Math.max(0,data.total-(page-1)*100))||data.eventos.some(e=>!e||!Number.isInteger(e.idEvento)||!idValid(e.idEvento)||e.idDeporte!==Number(snapshot.sportId)||!idValid(e.idLiga)||typeof e.evento!=='string'||!e.evento.trim()||!stamp(e.fechaInicio)||!states.includes(e.estadoEvento))
                ||new Set(data.eventos.map(e=>e.idEvento)).size!==data.eventos.length)throw new Error('El listado de recuperación es inconsistente.');
            recoveryPage=page;recoveryTotal=data.total;
            $('wizard-recovery-id').replaceChildren(option('','Selecciona el evento que deseas comprobar'));
            data.eventos.forEach(e=>$('wizard-recovery-id').append(option(e.idEvento,e.evento+' · '+(e.liga||'Liga #'+e.idLiga)+' · '+e.fechaInicio+' · '+e.estadoEvento)));
            $('wizard-recovery-page').textContent='Página '+page+' · '+data.total+' eventos del deporte';
            message(data.eventos.length?'Selecciona un evento y consulta su detalle para comprobarlo. Coincidir por nombre no demuestra que sea el mismo evento.':'No hay eventos en esta página. No se repetirá la creación; revisa el listado o solicita revisión administrativa.');
        });
    }
    $('wizard-load-sports').addEventListener('click',loadSports);$('wizard-load-leagues').addEventListener('click',loadLeagues);
    $('wizard-sport').addEventListener('change',()=>{
        if(snapshot||blocked)return;
        ++catalogRevision;
        onSport($('wizard-sport').value,sports.get($('wizard-sport').value)?.nombre);leagues.clear();clearParticipants();
        $('wizard-league').replaceChildren(option('','Primero selecciona un deporte'));$('wizard-league').disabled=true;
        if(sports.has($('wizard-sport').value))loadLeagues();
    });
    $('wizard-league').addEventListener('change',()=>{if(!snapshot&&!blocked)loadParticipants();});
    $('wizard-participant-query').addEventListener('click',()=>{if(!snapshot&&!blocked){participantPage=1;loadParticipants(false);}});
    for(const [id,delta] of [['wizard-participant-prev',-1],['wizard-participant-next',1]])$(id).addEventListener('click',()=>{if(!snapshot&&!blocked&&!$(id).disabled){participantPage+=delta;loadParticipants(false);}});
    for(const id of ['wizard-first','wizard-second'])$(id).addEventListener('change',chooseParticipants);
    $('wizard-simulated').addEventListener('change',()=>{if(!$('wizard-simulated').checked)$('wizard-duration').value='';sync(blocked);});
    $('wizard-prev').addEventListener('click',()=>{if(!blocked&&!snapshot&&step>1)showStep(step-1);});
    $('wizard-next').addEventListener('click',()=>{if(!blocked&&!snapshot&&step<4&&validateStep(step))showStep(step+1);});
    $('wizard-form').addEventListener('submit',event=>{
        event.preventDefault();if(blocked||snapshot||step!==4||![1,2,3].every(validateStep))return;
        if(!window.confirm('¿Crear '+$('wizard-name').value.trim()+' y después asociar los participantes indicados? Cada solicitud es independiente.'))return;
        task(async()=>{
            try{
                const draft=current();
                message('Comprobando deporte, liga y elegibilidad actual de ambos participantes…');
                await checkCatalogs(draft);
                snapshot=draft;
                const data=await post('/administrador/eventos/crear',snapshot.payload,()=>{createUncertain=true;save(true);});
                const result=data.resultado;
                if(!result||!Number.isInteger(result.idEvento)||!idValid(result.idEvento)||result.idLiga!==Number(snapshot.payload.idLiga)||result.nombre!==snapshot.payload.nombre||result.estadoEvento!=='BORRADOR'||!Number.isInteger(result.idEstado)||!idValid(result.idEstado)||!sameDate(result.fechaInicio,snapshot.payload.fechaInicio)||(snapshot.payload.fechaFin?!sameDate(result.fechaFin,snapshot.payload.fechaFin):result.fechaFin!==null)){const error=new Error('La creación no confirmó BORRADOR, identidad y fechas solicitadas.');error.wizardSent=true;throw error;}
                eventId=result.idEvento;createUncertain=false;needsCheck=false;snapshot.estadoEvento=result.estadoEvento;
                snapshot.resultado={idEvento:result.idEvento,idLiga:result.idLiga,idEstado:result.idEstado,estadoEvento:result.estadoEvento,
                    nombre:result.nombre,fechaInicio:result.fechaInicio,fechaFin:result.fechaFin};save();publishEvent();outcome();
                await associate();
            }catch(error){
                if(!eventId&&(!error.wizardSent||[400,401,403,404,405,409].includes(error.status))){snapshot=null;createUncertain=false;save();showStep(4,false);}
                else{createUncertain=!eventId;needsCheck=true;save();outcome();}
                failure(error);
            }
        });
    });
    $('wizard-reconcile').addEventListener('click',()=>{if(eventId&&snapshot)task(async()=>{
        await reconcile(eventId);
        if(snapshot.programming?.state==='uncertain'&&snapshot.estadoEvento==='PROGRAMADO'&&window.confirm('El detalle muestra PROGRAMADO para '+snapshot.payload.nombre+'. No demuestra qué solicitud produjo el cambio. ¿Aceptar el estado observado para finalizar la revisión, conservando la referencia incierta y sin enviar POST?')){
            snapshot.programming.state='observed';snapshot.programming.uncertainRequest=true;save();outcome();
        }
    });});
    $('wizard-program').addEventListener('click',()=>task(async()=>{
        await reconcile(eventId);
        if(!complete()||snapshot.estadoEvento!=='BORRADOR'||snapshot.programming)throw new Error('No corresponde programar nuevamente. Revisa el estado oficial y cualquier operación conservada.');
        if(!window.confirm('Evento: '+snapshot.payload.nombre+'. Estado actual: BORRADOR. Estado solicitado: PROGRAMADO. Permitirá abrir mercados elegibles; no inicia la simulación. ¿Confirmar?'))return;
        try{
            const data=await post('/administrador/eventos/estado/cambiar',{idEvento:String(eventId),nuevoEstado:'PROGRAMADO'},()=>{
                snapshot.programming={state:'uncertain'};needsCheck=true;save(true);outcome();
            });
            const r=data.resultado;
            if(!r||r.idEvento!==eventId||!states.includes(r.estadoAnterior)||r.estadoActual!=='PROGRAMADO'||typeof r.sinCambios!=='boolean'||r.sinCambios!==(r.estadoAnterior===r.estadoActual))throw new Error('Respuesta de programación incompatible; requiere conciliación.');
            snapshot.programming={state:'confirmed',resultado:{idEvento:r.idEvento,estadoAnterior:r.estadoAnterior,estadoActual:r.estadoActual,sinCambios:r.sinCambios}};save();
        }catch(error){
            // Incluso sin respuesta válida conservamos la intención: un GET no prueba causalidad.
            if([400,401,403,404,405,409].includes(error.status))delete snapshot.programming;
            save();try{await reconcile(eventId);}catch{needsCheck=true;outcome();}
            throw error;
        }
        await reconcile(eventId);
        if(snapshot.estadoEvento!=='PROGRAMADO')throw new Error('La respuesta se conserva, pero el detalle no confirma PROGRAMADO. No se repetirá la solicitud.');
        message('PROGRAMADO confirmado por respuesta y detalle oficial. Continúa con el mercado 1X2.');
    }));
    $('wizard-resume').addEventListener('click',()=>{if(eventId&&snapshot&&!needsCheck&&!snapshot.participants.some(p=>p.status==='conflict')&&window.confirm('¿Asociar únicamente los participantes pendientes al evento ya creado #'+eventId+'? No se creará otro evento.'))task(associate);});
    $('wizard-recover').addEventListener('click',()=>{if(snapshot&&createUncertain&&idValid($('wizard-recovery-id').value))task(()=>reconcile(Number($('wizard-recovery-id').value),true));else message('Selecciona el evento localizado en el listado.',true);});
    $('wizard-recovery-query').addEventListener('click',()=>recoveryEvents(1));
    for(const [id,delta] of [['wizard-recovery-prev',-1],['wizard-recovery-next',1]])$(id).addEventListener('click',()=>{if(!$(id).disabled)recoveryEvents(recoveryPage+delta);});
    $('wizard-advanced').addEventListener('click',()=>{if(eventId)publishEvent();$('advanced-event-management').open=true;});
    $('wizard-recovery-advanced').addEventListener('click',()=>{$('advanced-event-management').open=true;});
    $('wizard-new').addEventListener('click',()=>{if(complete()&&!snapshot.programming?.state?.includes('uncertain')&&window.confirm('El evento #'+eventId+' está confirmado. ¿Preparar otro evento?')){snapshot=null;officialDetail=null;eventId=null;createUncertain=false;needsCheck=false;configurationConflict=false;officialParticipantCount=0;selected=[];recoveryPage=1;recoveryTotal=0;save();$('wizard-form').reset();leagues.clear();candidates.clear();$('wizard-league').replaceChildren(option('','Selecciona una liga'));clearParticipants();participantRows();showStep(1);message('Puedes preparar un nuevo evento.');}});
    try{
        const saved=JSON.parse(sessionStorage.getItem(key)||'null');
        if(saved){
            if(saved.version!==1||!validSnapshot(saved.snapshot)||typeof saved.createUncertain!=='boolean'||(saved.eventId!==null&&!idValid(saved.eventId)))throw new Error('Progreso guardado no válido. No se restauró.');
            snapshot=saved.snapshot;eventId=saved.eventId===null?null:Number(saved.eventId);createUncertain=!eventId;needsCheck=true;outcome();message('Hay un proceso conservado en esta pestaña. Consulta su configuración oficial antes de continuar.',true);
        }
    }catch(error){createUncertain=true;snapshot={payload:{nombre:'Proceso no recuperable'},participants:[]};outcome();message('No se pudo recuperar el progreso guardado. Se conserva el almacenamiento original y se bloquea otra creación. Revisa manualmente el evento en administración avanzada.',true);}
    if(!snapshot){showStep(1,false);participantRows();}sync(false);
    window.addEventListener('pagehide',()=>{leaving=true;});
    window.addEventListener('pageshow',event=>{if(event.persisted)location.reload();});
    if(!canWrite)message('La creación requiere ADMINISTRADOR u OPERADOR_EVENTOS. El backend conserva la autorización definitiva.',true);
    async function refresh(id=eventId){
        if(id===null&&!snapshot)return loadSports();
        if(!idValid(id))return;
        if(snapshot&&Number(eventId)!==Number(id)){
            contextConflict=true;needsCheck=true;sync(false);message('El enlace o la consulta corresponde a otro evento. Se conserva el proceso anterior y se bloquean escrituras del asistente. Revisa ese proceso desde su referencia original.',true);return;
        }
        return task(async()=>{
            if(!snapshot){
                // Una referencia contextual nunca debe terminar habilitando otra creación.
                contextConflict=true;
                const e=(await request('/administrador/eventos/detalle?'+new URLSearchParams({idEvento:String(id)}))).evento;
                if(e?.idEvento===Number(id)){options.onDetail(e);$('advanced-event-management').open=false;}
                if(e?.idEvento===Number(id)&&e.participantes?.length!==2)$('advanced-event-management').open=true;
                if(!e||e.idEvento!==Number(id)||!Array.isArray(e.participantes)||e.participantes.length!==2)throw new Error('El evento requiere revisión en administración avanzada: se necesitan dos asociaciones para recuperar el asistente.');
                const people=[...e.participantes].sort((a,b)=>a.ordenParticipante-b.ordenParticipante);
                const draft={sportId:String(e.idDeporte),sportName:e.deporte,leagueName:e.liga,payload:{idLiga:String(e.idLiga),nombre:e.evento,fechaInicio:e.fechaInicio,esSimulado:String(e.simulacion?.esSimulado),...(e.fechaFin?{fechaFin:e.fechaFin}:{})},participants:people.map(p=>({id:p.idParticipante,name:p.participante,type:p.tipoParticipante,order:p.ordenParticipante,local:p.esLocal===null?'':String(p.esLocal),status:'pending'}))};
                if(!validSnapshot(draft)){$('advanced-event-management').open=true;throw new Error('El detalle no es compatible con el asistente. Usa administración avanzada; no se modificó el proceso.');}
                snapshot=draft;eventId=Number(id);needsCheck=true;contextConflict=false;
            }
            await reconcile(Number(id));
        });
    }
    function observe(e){
        if(snapshot&&eventId===e.idEvento&&!contextConflict)reconcile(eventId,false,e).catch(error=>{needsCheck=true;outcome();failure(error);});
    }
    quick=window.BetZoneQuickEventWizard(options);
    sync(false);
    return {sync,loadSports,refresh,observe};
};

/* Flujo convencional independiente del almacenamiento v1 del asistente avanzado. */
window.BetZoneQuickEventWizard = function ({request,run,base,role,onError}) {
    'use strict';
    const $=id=>document.getElementById(id),root=$('quick-event');
    const canWrite=['ADMINISTRADOR','OPERADOR_EVENTOS'].includes(role),admin=role==='ADMINISTRADOR';
    const actor=document.body.dataset.adminUser;
    const key='betzone-event-1x2:v1:'+base+':'+actor;
    const id=v=>Number.isInteger(Number(v))&&Number(v)>0&&Number(v)<=2147483647;
    const uuidPattern=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const node=(tag,text)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=String(text);return e;};
    const option=(v,text)=>{const e=node('option',text);e.value=String(v);return e;};
    const sports=new Map(),leagues=new Map(),teams=new Map();
    let busy=false,sharedBlocked=false,legacyPending=false,storageBlocked=!id(actor),operation=null,template=null,page=1,total=0;
    const status=(text,error=false)=>{$('quick-status').textContent=text;$('quick-status').dataset.error=String(error);};
    const pending=()=>storageBlocked||operation?.status==='pending';
    const locked=()=>sharedBlocked||busy||!canWrite||storageBlocked||(legacyPending&&operation?.status!=='pending');
    const approved=()=>template?.valida===true&&template.habilitada===true&&template.aprobada===true;
    function date(v) {
        if(typeof v!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?$/.test(v))return null;
        const [y,m,d,h,n,s=0]=v.match(/\d+/g).map(Number),value=new Date(0);
        value.setUTCFullYear(y,m-1,d);value.setUTCHours(h,n,s,0);
        if(y<1||value.getUTCFullYear()!==y||value.getUTCMonth()!==m-1||value.getUTCDate()!==d||h>23||n>59||s>59)return null;
        return v.length===16?v+':00':v;
    }
    function sync(disabled=sharedBlocked,legacy=legacyPending) {
        if(legacy&&!legacyPending&&operation?.status!=='pending')status('Hay un proceso anterior pendiente en el asistente avanzado. Consérvalo y completa su revisión antes de iniciar otra creación.',true);
        sharedBlocked=disabled;legacyPending=legacy;
        const frozen=locked()||Boolean(operation&&operation.status!=='rejected');
        root.querySelectorAll('button,input,select').forEach(e=>{e.disabled=frozen;});
        $('quick-league').disabled=frozen||!leagues.size;
        for(const name of ['quick-local','quick-visitor'])$(name).disabled=frozen||!teams.size;
        $('quick-create').disabled=frozen||!approved();
        $('quick-retry').hidden=operation?.status!=='pending';$('quick-retry').disabled=locked();
        $('quick-new').hidden=operation?.status!=='confirmed';$('quick-new').disabled=locked();
        $('quick-prev').disabled=frozen||page<=1;$('quick-next').disabled=frozen||page*100>=total;
        $('quick-template-admin').hidden=!admin;$('quick-template-action').hidden=approved()||!admin;
        $('quick-template-form').querySelectorAll('button,input').forEach(e=>{e.disabled=frozen||!admin||!template;});
        // Consultar una plantilla tras una respuesta de guardado incierta es seguro.
        $('quick-template-query').disabled=locked()||Boolean(operation&&operation.status!=='rejected')||!sports.has($('quick-sport').value);
        root.setAttribute('aria-busy',String(busy||sharedBlocked));
    }
    async function work(action,form=null) {
        if(locked()||(form&&!form.reportValidity()))return;
        return run(async()=>{
            busy=true;sync();
            try{await action();}catch(e){if(e.status===401||e.status===403)onError(e);status(e.message||'No fue posible completar la operación.',true);}
            finally{busy=false;sync();}
        });
    }
    function remember() {
        const value=JSON.stringify(operation);
        try{sessionStorage.setItem(key,value);if(sessionStorage.getItem(key)!==value)throw new Error();}
        catch{throw new Error('No se pudo conservar y verificar la UUID. No se enviará una operación nueva.');}
    }
    function uuid() {
        if(!window.crypto?.randomUUID)throw new Error('No se puede generar una UUID segura en este navegador.');
        return window.crypto.randomUUID();
    }
    function rows(data,key) {
        return Array.isArray(data)&&data.every(r=>r&&id(r[key])&&typeof r.nombre==='string'&&r.nombre.trim())&&new Set(data.map(r=>r[key])).size===data.length;
    }
    function resetTeams() {
        teams.clear();page=1;total=0;$('quick-page').textContent='';
        for(const name of ['quick-local','quick-visitor'])$(name).replaceChildren(option('','Selecciona un equipo'));
    }
    function resetTemplate() {template=null;$('quick-template').textContent='Sin consultar.';$('quick-template-form').reset();}
    async function loadSports() {
        const d=await request('/deportes/exploracion');
        if(!rows(d.deportes,'idDeporte')||d.deportes.some(r=>r.activo!==true))throw new Error('Catálogo de deportes inválido.');
        sports.clear();leagues.clear();resetTeams();resetTemplate();$('quick-sport').replaceChildren(option('','Selecciona un deporte'));
        $('quick-league').replaceChildren(option('','Selecciona un deporte'));
        // El backend también restringe explícitamente la primera plantilla a fútbol.
        d.deportes.filter(r=>r.nombre.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase()==='futbol')
            .forEach(r=>{sports.set(String(r.idDeporte),r);$('quick-sport').append(option(r.idDeporte,r.nombre));});
        status('Selecciona fútbol y su liga. Otros deportes y simulaciones utilizan el asistente avanzado.');summary();
    }
    async function loadLeagues() {
        leagues.clear();resetTeams();resetTemplate();$('quick-league').replaceChildren(option('','Selecciona una liga'));
        const sport=$('quick-sport').value;if(!sports.has(sport))return;
        const d=await request('/ligas/exploracion?'+new URLSearchParams({idDeporte:sport}));
        if(Number(d.idDeporte)!==Number(sport)||!rows(d.ligas,'idLiga')||d.ligas.some(r=>r.idDeporte!==Number(sport)||r.activo!==true))throw new Error('Catálogo de ligas incompatible.');
        d.ligas.forEach(r=>{leagues.set(String(r.idLiga),r);$('quick-league').append(option(r.idLiga,r.nombre));});
        await queryTemplate();summary();
    }
    async function loadTeams(reset=false) {
        if(reset)resetTeams();
        const sport=$('quick-sport').value,league=$('quick-league').value;if(!leagues.has(league))return;
        const search=$('quick-search').value.trim();if(search.length>150)throw new Error('La búsqueda admite hasta 150 caracteres.');
        const d=await request('/administrador/participantes/listar?'+new URLSearchParams({idDeporte:sport,idLiga:league,activo:'true',pagina:page,tamanoPagina:100,...(search?{buscar:search}:{})}));
        if(!rows(d.participantes,'idParticipante')||d.pagina!==page||d.tamanoPagina!==100||!Number.isSafeInteger(d.total)||d.total<0
          ||d.participantes.length!==Math.min(100,Math.max(0,d.total-(page-1)*100))
          ||d.participantes.some(r=>r.idDeporte!==Number(sport)||r.activo!==true))throw new Error('Página de participantes incompatible.');
        const chosen=[$('quick-local').value,$('quick-visitor').value];
        for(const [k] of teams)if(!chosen.includes(k))teams.delete(k);
        d.participantes.filter(r=>r.tipoParticipante==='EQUIPO').forEach(r=>teams.set(String(r.idParticipante),r));
        for(const [i,name] of ['quick-local','quick-visitor'].entries()){
            $(name).replaceChildren(option('','Selecciona un equipo'));for(const [k,r] of teams)$(name).append(option(k,r.nombre));
            if(teams.has(chosen[i]))$(name).value=chosen[i];
        }
        total=d.total;$('quick-page').textContent='Página '+page+' · '+total+' participantes de liga';choose();
        status('Equipos activos de la liga consultados. La publicación vuelve a validar su elegibilidad.');
    }
    function choose() {
        if($('quick-local').value&&$('quick-local').value===$('quick-visitor').value)$('quick-visitor').value='';
        for(const [a,b] of [['quick-local','quick-visitor'],['quick-visitor','quick-local']])
            for(const o of $(a).options)o.disabled=Boolean(o.value)&&o.value===$(b).value;
        summary();
    }
    function validTemplate(r) {
        if(!r||r.idDeporte!==Number($('quick-sport').value)||r.identidadPlantilla!=='BETZONE_1X2:'+r.idDeporte
          ||['existe','valida','habilitada','aprobada'].some(k=>typeof r[k]!=='boolean'))throw new Error('Respuesta de plantilla incompatible.');
        if(r.valida&&(!r.existe||!uuidPattern.test(r.versionPlantilla)||['cuotaLocal','cuotaEmpate','cuotaVisitante'].some(k=>!odd(r[k]))))throw new Error('Cuotas de plantilla inválidas.');
        return r;
    }
    const odd=v=>typeof v==='number'&&Number.isFinite(v)&&v>1&&v<=999999.9999;
    function templateView() {
        $('quick-template').textContent=template.valida?template.identidadPlantilla+' · versión '+template.versionPlantilla
          +' · LOCAL '+template.cuotaLocal+' · EMPATE '+template.cuotaEmpate+' · VISITANTE '+template.cuotaVisitante
          +' · '+(approved()?'Habilitada y aprobada':'No habilitada para publicar'):'No existe una plantilla válida. Un ADMINISTRADOR debe configurarla y aprobarla.';
        if(template.valida){for(const [name,k] of [['quick-odd-local','cuotaLocal'],['quick-odd-draw','cuotaEmpate'],['quick-odd-visitor','cuotaVisitante']])$(name).value=String(template[k]);
          $('quick-template-enabled').checked=template.habilitada;$('quick-template-approved').checked=template.aprobada;}
        summary();
    }
    async function queryTemplate() {
        resetTemplate();
        const d=await request('/administrador/eventos/plantilla-1x2?'+new URLSearchParams({idDeporte:$('quick-sport').value}));
        template=validTemplate(d.resultado);templateView();
        if(!approved())status('La publicación requiere plantilla habilitada y aprobada. '+(admin?'Configúrala en el apartado de plantilla.':'Solicita su configuración a un ADMINISTRADOR.'),true);
    }
    function summary() {
        if(operation?.status==='pending'){
            const p=operation.payload,review=operation.review||{},dl=node('dl');
            const values=[['Operación pendiente',p.referenciaOperacion],['Deporte',review.sport||'Se verificará con el servidor'],
              ['Liga',review.league||'Se verificará con el servidor'],['LOCAL',review.local||'Conservado en la solicitud'],
              ['VISITANTE',review.visitor||'Conservado en la solicitud'],['Fecha programada',p.fechaInicio],['Versión de plantilla',p.versionPlantilla]];
            values.forEach(([k,v])=>dl.append(node('dt',k),node('dd',v)));$('quick-summary').replaceChildren(dl);return;
        }
        const dl=node('dl');
        const values=[['Deporte',sports.get($('quick-sport').value)?.nombre],['Liga',leagues.get($('quick-league').value)?.nombre],
          ['LOCAL',teams.get($('quick-local').value)?.nombre],['VISITANTE',teams.get($('quick-visitor').value)?.nombre],['Inicio',date($('quick-start').value)],
          ['Cuotas aprobadas',approved()?template.cuotaLocal+' / '+template.cuotaEmpate+' / '+template.cuotaVisitante:'Pendientes de aprobación'],['Estado solicitado','PROGRAMADO · Mercado CONVENCIONAL 1X2 ABIERTO']];
        values.forEach(([k,v])=>dl.append(node('dt',k),node('dd',v||'Por seleccionar')));$('quick-summary').replaceChildren(dl);
    }
    function payload() {
        const sport=$('quick-sport').value,league=$('quick-league').value,local=$('quick-local').value,visitor=$('quick-visitor').value;
        if(!sports.has(sport)||!leagues.has(league)||leagues.get(league).idDeporte!==Number(sport)||!teams.has(local)||!teams.has(visitor)||local===visitor||!date($('quick-start').value)||!approved())throw new Error('Revisa deporte, liga, equipos, fecha y plantilla aprobada.');
        return {idDeporte:sport,idLiga:league,idParticipanteLocal:local,idParticipanteVisitante:visitor,fechaInicio:date($('quick-start').value),versionPlantilla:template.versionPlantilla,referenciaOperacion:uuid()};
    }
    function validOperation(o) {
        const p=o?.payload;
        return o?.version===1&&['pending','confirmed','rejected'].includes(o.status)&&p
          &&Object.keys(p).sort().join(',')==='fechaInicio,idDeporte,idLiga,idParticipanteLocal,idParticipanteVisitante,referenciaOperacion,versionPlantilla'
          &&['idDeporte','idLiga','idParticipanteLocal','idParticipanteVisitante'].every(k=>typeof p[k]==='string'&&/^[1-9][0-9]*$/.test(p[k])&&id(p[k]))
          &&p.idParticipanteLocal!==p.idParticipanteVisitante&&typeof p.fechaInicio==='string'&&date(p.fechaInicio)===p.fechaInicio
          &&typeof p.versionPlantilla==='string'&&uuidPattern.test(p.versionPlantilla)
          &&typeof p.referenciaOperacion==='string'&&uuidPattern.test(p.referenciaOperacion);
    }
    function validateResult(r,p) {
        if(!r||!['idEvento','idMercado','idSeleccionLocal','idSeleccionEmpate','idSeleccionVisitante'].every(k=>Number.isInteger(r[k])&&id(r[k]))
          ||new Set([r.idSeleccionLocal,r.idSeleccionEmpate,r.idSeleccionVisitante]).size!==3
          ||['idDeporte','idLiga','idParticipanteLocal','idParticipanteVisitante'].some(k=>r[k]!==Number(p[k]))
          ||date(r.fechaInicio)!==p.fechaInicio||r.referenciaOperacion!==p.referenciaOperacion||r.versionPlantilla!==p.versionPlantilla
          ||r.identidadPlantilla!=='BETZONE_1X2:'+p.idDeporte||r.estadoEvento!=='PROGRAMADO'||r.estadoMercado!=='ABIERTO'||r.tipoMercado!=='CONVENCIONAL'
          ||typeof r.solicitudIdempotente!=='boolean'||typeof r.disponibleParaApuestas!=='boolean'
          ||!['BORRADOR','PROGRAMADO','EN_VIVO','SUSPENDIDO','PENDIENTE_RESULTADO','FINALIZADO','CANCELADO'].includes(r.estadoEventoActual)
          ||!['BORRADOR','ABIERTO','SUSPENDIDO','CERRADO','LIQUIDADO','ANULADO'].includes(r.estadoMercadoActual)
          ||['cuotaLocal','cuotaEmpate','cuotaVisitante'].some(k=>!odd(r[k]))
          ||['nombre','deporte','liga','local','visitante'].some(k=>typeof r[k]!=='string'||!r[k].trim()))throw new Error('La respuesta no confirma la identidad completa del evento. Conserva la UUID y reintenta los mismos datos.');
    }
    function resultView(r,cached=false) {
        const box=$('quick-result'),dl=node('dl');
        const values=[['Evento creado',r.nombre],['IdEvento',r.idEvento],['Deporte',r.deporte],['Liga',r.liga],['LOCAL',r.local],['VISITANTE',r.visitante],['Fecha programada',r.fechaInicio],
          ['Estado al crear',r.estadoEvento],['Mercado creado',r.tipoMercado+' 1X2 · '+r.estadoMercado],['1 LOCAL',r.idSeleccionLocal+' · cuota '+r.cuotaLocal],
          ['X EMPATE',r.idSeleccionEmpate+' · cuota '+r.cuotaEmpate],['2 VISITANTE',r.idSeleccionVisitante+' · cuota '+r.cuotaVisitante],
          ['Plantilla',r.identidadPlantilla+' · '+r.versionPlantilla],['Referencia',r.referenciaOperacion],['Estado actual informado',r.estadoEventoActual+' · '+r.estadoMercadoActual],
          ['Disponibilidad informada',cached?'Resultado guardado; consulta el evento oficial para su disponibilidad actual.':r.disponibleParaApuestas?'Disponible para apuestas según el servidor al confirmar.':'No disponible para apuestas al consultar el servidor.'],['Recuperación idempotente',r.solicitudIdempotente?'Sí':'No']];
        values.forEach(([k,v])=>dl.append(node('dt',k),node('dd',v)));box.replaceChildren(node('h3','Resultado oficial de creación'),dl);
        for(const [title,path] of [['Ver evento','/administrador/eventos?idEvento='],['Administrar mercado','/administrador/mercados?idEvento='],['Control en vivo','/administrador/en-vivo?idEvento=']]){
            const link=node('a',title);link.href=base+path+encodeURIComponent(r.idEvento);box.append(link,document.createTextNode(' · '));
        }
        box.hidden=false;
    }
    async function post(path,data) {
        const token=await window.BetZoneAdmin.csrf();
        const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),120000);
        try {
            const response=await fetch(base+path,{method:'POST',credentials:'same-origin',cache:'no-store',signal:controller.signal,
              headers:{Accept:'application/json','Content-Type':'application/x-www-form-urlencoded;charset=UTF-8','X-CSRF-Token':token},body:new URLSearchParams(data)});
            if(response.status===401)window.BetZoneAdmin.sessionExpired();
            if(response.redirected||!/^application\/json\b/i.test(response.headers.get('content-type')||''))throw new Error('Respuesta inesperada. Conserva la UUID para recuperar el resultado.');
            const d=await response.json();
            if(!response.ok){
                const known=d?.ok===false&&Number.isInteger(d.codigo)&&d.codigo>=76700&&d.codigo<=76710
                  &&[400,403,404,409].includes(response.status)&&typeof d.mensaje==='string';
                const e=new Error(known?d.mensaje:(window.BetZoneAdmin.messages[response.status]||'No se pudo verificar el resultado.'));
                e.status=response.status;
                e.definitive=(known&&d.codigo!==76704)||(response.status===400&&d?.ok===false&&d.mensaje==='Los parámetros no son válidos.');
                throw e;
            }
            if(response.status!==200||d?.ok!==true)throw new Error('No se recibió una confirmación oficial.');
            return d.resultado;
        }finally{clearTimeout(timer);}
    }
    async function create(retry=false) {
        if(!retry){
            if(operation?.status==='pending'||operation?.status==='confirmed')return;
            const p=payload();
            if(!window.confirm('¿Crear y publicar '+teams.get(p.idParticipanteLocal).nombre+' vs '+teams.get(p.idParticipanteVisitante).nombre+' el '+p.fechaInicio+' con las cuotas aprobadas '+template.cuotaLocal+' / '+template.cuotaEmpate+' / '+template.cuotaVisitante+'?'))return;
            operation={version:1,status:'pending',payload:p,review:{sport:sports.get(p.idDeporte).nombre,league:leagues.get(p.idLiga).nombre,
              local:teams.get(p.idParticipanteLocal).nombre,visitor:teams.get(p.idParticipanteVisitante).nombre}};
        }
        if(!validOperation(operation)||operation.status!=='pending')throw new Error('No se puede verificar la referencia pendiente. Conserva el almacenamiento para revisión.');
        remember();summary();status('Preparando evento convencional... UUID: '+operation.payload.referenciaOperacion);
        try {
            const r=await post('/administrador/eventos/crear-convencional',operation.payload);
            validateResult(r,operation.payload);operation.status='confirmed';operation.result=r;
            resultView(r);status('Evento completo confirmado. No se requiere completar mercados ni cuotas.');
            try{remember();}catch{status('Evento confirmado. Conserva IdEvento y UUID: no se pudo guardar la respuesta; el registro anterior permite recuperarla.',true);}
        }catch(e){
            if(operation.status==='confirmed'){
                try{remember();}catch{/* La UUID previa permanece disponible para recuperación. */}
                status('El servidor confirmó el evento #'+operation.result.idEvento+'. Conserva la UUID '+operation.payload.referenciaOperacion+'; hubo un problema al presentar el resultado.',true);
                return;
            }
            if(e.definitive===true)operation.status='rejected';
            summary();
            try{remember();}catch{/* El registro verificado previo al envío permanece disponible. */}
            status(e.message+(operation.status==='pending'?' Resultado incierto: conserva esta UUID y reintenta únicamente los mismos datos.':' Corrige los campos y revisa la plantilla antes de una nueva confirmación.'),true);
            if(e.status===401||e.status===403)onError(e);
        }
    }
    $('quick-catalogs').addEventListener('click',()=>work(loadSports));
    $('quick-sport').addEventListener('change',()=>work(loadLeagues));
    $('quick-league').addEventListener('change',()=>work(()=>loadTeams(true)));
    $('quick-search-button').addEventListener('click',()=>work(()=>{page=1;return loadTeams();}));
    for(const [name,delta] of [['quick-prev',-1],['quick-next',1]])$(name).addEventListener('click',()=>{if(!$(name).disabled)work(()=>{page+=delta;return loadTeams();});});
    for(const name of ['quick-local','quick-visitor'])$(name).addEventListener('change',choose);
    $('quick-start').addEventListener('input',summary);
    $('quick-template-query').addEventListener('click',()=>work(queryTemplate));
    $('quick-template-action').addEventListener('click',()=>{$('quick-template-admin').open=true;});
    $('quick-form').addEventListener('submit',e=>{e.preventDefault();work(()=>create(),$('quick-form'));});
    $('quick-retry').addEventListener('click',()=>work(()=>create(true)));
    $('quick-new').addEventListener('click',()=>work(async()=>{
        if(operation?.status!=='confirmed')return;
        operation=null;remember();$('quick-result').hidden=true;$('quick-form').reset();await loadSports();
    }));
    $('quick-template-form').addEventListener('submit',e=>{
        e.preventDefault();if(!admin)return;
        work(async()=>{
            if(!template)return;
            if(!window.confirm('¿Guardar estos valores oficiales y su estado de aprobación como nueva versión para futuras creaciones?'))return;
            const data={idDeporte:$('quick-sport').value,cuotaLocal:$('quick-odd-local').value,cuotaEmpate:$('quick-odd-draw').value,cuotaVisitante:$('quick-odd-visitor').value,
              habilitada:String($('quick-template-enabled').checked),aprobada:String($('quick-template-approved').checked),versionEsperada:template.versionPlantilla||'',referenciaOperacion:uuid()};
            // Ante pérdida de respuesta se exige consultar antes de otra modificación.
            resetTemplate();
            try{template=validTemplate(await post('/administrador/eventos/plantilla-1x2/guardar',data));templateView();status('Versión de plantilla guardada y auditada.');}
            catch(error){status(error.message+' Consulta la plantilla oficial antes de modificarla nuevamente.',true);if(error.status===401||error.status===403)onError(error);}
        },$('quick-template-form'));
    });
    try{
        const saved=sessionStorage.getItem(key);
        if(saved&&saved!=='null'){
            operation=JSON.parse(saved);if(!validOperation(operation))throw new Error();
            if(operation.status==='confirmed'){validateResult(operation.result,operation.payload);resultView(operation.result,true);status('Se conserva una creación confirmada anteriormente.');}
            else if(operation.status==='pending')status('Hay una creación pendiente. UUID: '+operation.payload.referenciaOperacion+'. Reintenta únicamente los mismos datos para recuperar el resultado.',true);
        }
    }catch{storageBlocked=true;status('El proceso guardado no puede recuperarse con seguridad. Se conserva sin sobrescribirlo; solicita revisión.',true);}
    sync();summary();
    return {sync,pending};
};
