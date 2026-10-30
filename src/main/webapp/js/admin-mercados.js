/* ADMIN-05: controlador exclusivo de mercados. Transporte y autorización del servidor compartidos. */
window.BetZoneMarkets = (() => {
    'use strict';
    let initialized=false;
    const types=['CONVENCIONAL','MARCADOR_FINAL','PRIMERA_ANOTACION'];
    const marketStates=['BORRADOR','ABIERTO','SUSPENDIDO','CERRADO','LIQUIDADO','ANULADO'];
    const eventStates=['BORRADOR','PROGRAMADO','EN_VIVO','SUSPENDIDO','PENDIENTE_RESULTADO','FINALIZADO','CANCELADO'];
    const transitions={BORRADOR:['ABIERTO','ANULADO'],ABIERTO:['SUSPENDIDO','CERRADO','ANULADO'],SUSPENDIDO:['ABIERTO','CERRADO','ANULADO'],CERRADO:['ANULADO'],LIQUIDADO:[],ANULADO:[]};
    const id=v=>Number.isInteger(v)&&v>0&&v<=2147483647;
    const inputId=v=>/^[0-9]{1,10}$/.test(String(v))&&id(Number(v));
    const text=(v,max)=>typeof v==='string'&&v.trim().length>0&&v.length<=max;
    function decimal(value){
        if(typeof value!=='string'||value.length>32||!/^\d+(\.\d{1,4})?$/.test(value))throw new Error('Usa punto decimal, hasta cuatro posiciones y valores entre 1 y 999999.9999, mayores que 1.');
        const [whole,fraction='']=value.split('.'),units=BigInt(whole)*10000n+BigInt(fraction.padEnd(4,'0'));
        if(units<=10000n||units>9999999999n)throw new Error('El valor debe ser mayor que 1 y como máximo 999999.9999.');
        return units;
    }
    // Preserva el literal financiero antes de que JSON.parse lo convierta en Number.
    function parse(raw){
        const keys=new Set(['valor','cuota','valorResultado']);let result='',start=0,i=0;
        while(i<raw.length){
            if(raw[i]!=='"'){i++;continue;}
            const begin=i++;while(i<raw.length){if(raw[i]==='\\'){i+=2;continue;}if(raw[i++]==='"')break;}
            const token=raw.slice(begin,i);let cursor=i;while(/\s/.test(raw[cursor]||'')&&cursor<raw.length)cursor++;
            if(raw[cursor]!==':'||!keys.has(JSON.parse(token)))continue;
            cursor++;while(/\s/.test(raw[cursor]||'')&&cursor<raw.length)cursor++;
            const match=raw.slice(cursor).match(/^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?(?=\s*[,}])/);
            if(match){result+=raw.slice(start,cursor)+JSON.stringify(match[0]);i=cursor+match[0].length;start=i;}
        }
        return JSON.parse(result+raw.slice(start));
    }
    function date(value){
        if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,9})?)?$/.test(value))return false;
        const [y,m,d,h,n,s=0]=value.match(/\d+/g).map(Number),v=new Date(0);v.setUTCFullYear(y,m-1,d);
        return y>0&&v.getUTCFullYear()===y&&v.getUTCMonth()===m-1&&v.getUTCDate()===d&&h<24&&n<60&&s<60;
    }
    function checkDetail(e,expected){
        if(!e||e.idEvento!==Number(expected)||!id(e.idEvento)||!id(e.idLiga)||!id(e.idDeporte)||!text(e.evento,200)||!text(e.deporte,150)||!text(e.liga,150)||!eventStates.includes(e.estadoEvento)||!date(e.fechaInicio)||(e.fechaFin!==null&&!date(e.fechaFin))||typeof e.simulacion?.esSimulado!=='boolean'||!Array.isArray(e.participantes)||!Array.isArray(e.mercados)||e.cantidadParticipantes!==e.participantes.length||e.cantidadMercados!==e.mercados.length)throw new Error('Detalle administrativo inválido o de otro evento.');
        const people=new Set(),orders=new Set(),markets=new Set(),selections=new Set(),quotes=new Set();
        for(const p of e.participantes){if(!id(p.idParticipante)||people.has(p.idParticipante)||!text(p.participante,150)||!Number.isInteger(p.ordenParticipante)||p.ordenParticipante<1||p.ordenParticipante>255||orders.has(p.ordenParticipante))throw new Error('Participantes del evento inconsistentes.');people.add(p.idParticipante);orders.add(p.ordenParticipante);}
        for(const m of e.mercados){
            if(!id(m.idMercado)||markets.has(m.idMercado)||!text(m.mercado,150)||!(m.descripcionMercado===null||typeof m.descripcionMercado==='string'&&m.descripcionMercado.length<=250)||!types.includes(m.tipoMercado)||!marketStates.includes(m.estadoMercado)||!Array.isArray(m.selecciones))throw new Error('Mercados del evento inconsistentes.');markets.add(m.idMercado);
            for(const s of m.selecciones){
                if(!id(s.idSeleccion)||selections.has(s.idSeleccion)||!text(s.seleccion,150)||typeof s.seleccionActiva!=='boolean'||!(s.idParticipante===null||people.has(s.idParticipante)))throw new Error('Selecciones del evento inconsistentes.');selections.add(s.idSeleccion);
                if(s.idCuota===null){if([s.valor,s.cuota,s.valorResultado,s.cuotaActiva,s.fechaInicioCuota,s.fechaFinCuota].some(v=>v!==null))throw new Error('Selección sin cuota con datos contradictorios.');}
                else{
                    if(!id(s.idCuota)||quotes.has(s.idCuota)||s.cuotaActiva!==true||!date(s.fechaInicioCuota)||s.fechaFinCuota!==null)throw new Error('Cuota activa inconsistente.');quotes.add(s.idCuota);
                    if(decimal(s.valor)!==decimal(s.cuota))throw new Error('Valores de cuota contradictorios.');
                    if(s.valorResultado!==null&&(m.tipoMercado!=='MARCADOR_FINAL'||decimal(s.valorResultado)>=decimal(s.valor)))throw new Error('Valor de resultado incompatible.');
                    if(m.tipoMercado==='MARCADOR_FINAL'&&s.valorResultado===null)throw new Error('Falta valorResultado oficial de la modalidad.');
                }
            }
        }
        return e;
    }
    function init(){
        if(initialized||document.body.dataset.management!=='mercados')return;initialized=true;
        const $=value=>document.getElementById(value),A=window.BetZoneAdmin,base=document.body.dataset.contextPath||'',role=document.body.dataset.adminRole||'';
        const canWrite=['ADMINISTRADOR','OPERADOR_EVENTOS'].includes(role),forms=new Map(),buttons=new Map(),fingerprints=new Set();
        let busy=false,sessionBlocked=false,leaving=false,revision=0,event=null,marketId=null,selectionId=null,uncertain=null,verified=false,activeRoute='mercados/crear';
        const planKey='betzone-market-1x2:'+base;
        let plan=null,planNeedsCheck=false,planConflict='',planReview=false,planInvalid=false;
        let contextMismatch=false;
        const node=(tag,value,className)=>{const e=document.createElement(tag);if(value!==undefined)e.textContent=value;if(className)e.className=className;return e;};
        const show=v=>v===null||v===undefined?'Sin dato':typeof v==='boolean'?v?'Sí':'No':String(v);
        const market=()=>event?.mercados.find(m=>m.idMercado===marketId)||null;
        const selection=()=>market()?.selecciones.find(s=>s.idSeleccion===selectionId)||null;
        const status=(message,error=false)=>{if(leaving)return;$('management-status').textContent=message;$('management-status').dataset.error=String(error);};
        const operationNames={'mercados/crear':'Crear mercado','selecciones/crear':'Crear selección','cuotas/registrar':'Registrar cuota','mercados/estado/cambiar':'Cambiar estado del mercado'};
        const fail=message=>{throw new Error(message);};
        const sameName=(a,b)=>a.trim().toLocaleLowerCase('es')===b.trim().toLocaleLowerCase('es');
        function notice(message){$('market-uncertain').textContent=message;$('market-uncertain').hidden=!uncertain;}
        function resetVerification(){if(uncertain){verified=false;notice('Operación incierta: '+operationNames[uncertain.route]+' · '+uncertain.label+'. Conserva evento #'+uncertain.event+', mercado #'+(uncertain.market||'sin ID confirmado')+', selección #'+(uncertain.selection||'sin ID confirmado')+'. Consulta el contexto afectado. Sin identidad o evidencia suficiente, requiere conciliación manual; se mantiene el bloqueo. Ningún POST se reenviará automáticamente.');}}
        function report(error){
            if(leaving||error.cancelledByNavigation)return;
            if(uncertain)resetVerification();
            status(error.status?(A.messages[error.status]||'Error HTTP '+error.status):error.name==='AbortError'?'Solicitud interrumpida o demasiado lenta. Revisa el estado antes de reintentar.':error instanceof TypeError?'No fue posible conectar con el servidor.':error.message,true);
            if(error.status===401){sessionBlocked=true;$('management-login').hidden=false;}
        }
        async function request(path,options){
            if(leaving)throw new DOMException('Navegación','AbortError');
            const data=await A.request(path,options,parse);
            if(leaving)throw new DOMException('Navegación','AbortError');return data;
        }
        function specialReady(){return event?.simulacion.esSimulado&&event.participantes.length===2&&event.participantes.some(p=>p.ordenParticipante===1)&&event.participantes.some(p=>p.ordenParticipante===2);}
        function opening(m){
            const missing=[],rows=m.selecciones.filter(s=>s.seleccionActiva);
            if(event.estadoEvento!=='PROGRAMADO')missing.push('El evento no está PROGRAMADO');
            if(rows.length<(m.tipoMercado==='MARCADOR_FINAL'?1:2))missing.push('Faltan selecciones activas');
            if(rows.some(s=>s.idCuota===null||s.cuotaActiva!==true))missing.push('Hay selecciones sin cuota activa');
            if(m.tipoMercado==='MARCADOR_FINAL'&&(rows.length!==1||rows.some(s=>s.idParticipante!==null)))missing.push('Marcador final requiere una selección genérica única');
            if(m.tipoMercado==='PRIMERA_ANOTACION'&&(new Set(rows.map(s=>s.idParticipante).filter(id)).size!==2||rows.some(s=>!event.participantes.some(p=>p.idParticipante===s.idParticipante))))missing.push('La modalidad requiere dos participantes distintos del evento');
            if(m.tipoMercado==='CONVENCIONAL'&&(plan?.market.id===m.idMercado||sameName(m.mercado,'Resultado final — 1X2')
                ||m.selecciones.some(s=>s.seleccion==='X - Empate'&&s.idParticipante===null)&&m.selecciones.some(s=>/^[12] - /.test(s.seleccion)&&s.idParticipante!==null))){
                try{const teams=oneTeams(event);if(m.selecciones.length!==3||rows.length!==3||!oneEquivalent(m,teams))missing.push('1X2 requiere exactamente LOCAL, EMPATE y VISITANTE activos');}catch{missing.push('Participantes 1X2 incompatibles');}
            }
            return missing;
        }
        function available(route){
            const m=market(),s=selection();
            if(contextMismatch||plan&&event?.idEvento!==plan.event.idEvento)return false;
            if(!event)return false;
            if(route==='mercados/crear')return ['BORRADOR','PROGRAMADO'].includes(event.estadoEvento);
            if(route==='selecciones/crear')return m?.estadoMercado==='BORRADOR'&&(m.tipoMercado!=='MARCADOR_FINAL'||m.selecciones.length===0);
            if(route==='cuotas/registrar')return Boolean(m&&s?.seleccionActiva&&['BORRADOR','ABIERTO','SUSPENDIDO'].includes(m.estadoMercado)&&['BORRADOR','PROGRAMADO'].includes(event.estadoEvento));
            return Boolean(m&&transitions[m.estadoMercado].some(s=>s!=='ABIERTO'||!opening(m).length));
        }
        function sync(){
            for(const e of document.querySelectorAll('#contenido button,#contenido input,#contenido select,#contenido textarea'))e.disabled=busy||sessionBlocked;
            A.syncPages(busy||sessionBlocked);
            $('detail-id').disabled=busy||sessionBlocked||$('detail-id').options.length<2;
            $('market-picker').disabled=busy||sessionBlocked||!event?.mercados.length;
            $('selection-picker').disabled=busy||sessionBlocked||!market()?.selecciones.length;
            for(const [route,form]of forms){form.hidden=!canWrite||route!==activeRoute;form.parentElement.hidden=form.hidden;form.querySelector('fieldset').disabled=busy||sessionBlocked||!canWrite||Boolean(uncertain)||!available(route);buttons.get(route).disabled=busy||sessionBlocked||!canWrite||Boolean(uncertain)||!available(route);buttons.get(route).setAttribute('aria-pressed',String(activeRoute===route));}
            $('acknowledge-write').hidden=!uncertain;$('acknowledge-write').disabled=busy||sessionBlocked||!canWrite||!verified;
            const type=forms.get('mercados/crear').elements.tipoMercado;
            for(const option of type.options)option.disabled=option.value!=='CONVENCIONAL'&&(!specialReady()||event.mercados.some(m=>m.tipoMercado===option.value));
            if(type.selectedOptions[0]?.disabled)type.value='CONVENCIONAL';
            const p=forms.get('selecciones/crear').elements.idParticipante;
            p.disabled=p.disabled||forms.get('selecciones/crear').querySelector('fieldset').disabled||market()?.tipoMercado==='MARCADOR_FINAL';
            const vr=forms.get('cuotas/registrar').elements.valorResultado;vr.disabled=vr.disabled||forms.get('cuotas/registrar').querySelector('fieldset').disabled||market()?.tipoMercado!=='MARCADOR_FINAL';
            $('management-forms').setAttribute('aria-busy',String(busy));
            syncPlan();
        }
        function table(target,caption,headings,rows){
            const wrap=node('div',undefined,'table-scroll');wrap.tabIndex=0;wrap.setAttribute('role','region');wrap.setAttribute('aria-label',caption);
            const t=node('table'),thead=node('thead'),tr=node('tr'),tbody=node('tbody');t.append(node('caption',caption));
            headings.forEach(value=>{const th=node('th',value);th.scope='col';tr.append(th);});thead.append(tr);t.append(thead);
            if(!rows.length){const tr=node('tr'),td=node('td','No hay registros disponibles en esta consulta.');td.colSpan=headings.length;tr.append(td);tbody.append(tr);}
            for(const row of rows){const tr=node('tr');for(const v of row){const td=node('td');if(v instanceof Node)td.append(v);else td.textContent=show(v);tr.append(td);}tbody.append(tr);}t.append(tbody);wrap.append(t);target.append(wrap);
        }
        function action(label,fn){const b=node('button',label);b.type='button';b.addEventListener('click',()=>{if(!busy&&!sessionBlocked)fn();});return b;}
        function clearForms(){forms.forEach(f=>f.reset());}
        function clearContext(){event=null;marketId=null;selectionId=null;revision++;planReview=false;clearForms();$('detail-results').replaceChildren();$('market-context').replaceChildren(node('p','Consulta un evento para administrar sus mercados.'));$('market-selections').replaceChildren();$('selection-context').textContent='Selecciona una selección para consultar su cuota activa.';A.choices($('market-picker'),[],'idMercado','mercado');A.choices($('selection-picker'),[],'idSeleccion','seleccion');$('selected-live').hidden=true;$('selected-markets').hidden=true;}
        function selectMarket(value,selected=null){
            const m=event?.mercados.find(m=>m.idMercado===Number(value));marketId=m?.idMercado||null;selectionId=null;clearForms();
            $('market-picker').value=m?String(m.idMercado):'';$('market-context').replaceChildren();$('market-selections').replaceChildren();
            A.choices($('selection-picker'),m?.selecciones||[],'idSeleccion','seleccion');
            const participant=forms.get('selecciones/crear').elements.idParticipante;
            A.choices(participant,event?.participantes||[],'idParticipante','participante','Sin participante');participant.required=m?.tipoMercado==='PRIMERA_ANOTACION';
            for(const option of participant.options)option.disabled=Boolean(m?.tipoMercado==='PRIMERA_ANOTACION'&&option.value&&m.selecciones.some(s=>String(s.idParticipante)===option.value));
            const state=forms.get('mercados/estado/cambiar').elements.nuevoEstado;
            A.choices(state,(m?transitions[m.estadoMercado]:[]).filter(v=>v!=='ABIERTO'||!opening(m).length).map(v=>({value:v})), 'value','value','Selecciona destino permitido');
            if(m){
                $('market-context').append(node('h3',m.mercado),node('p','Modalidad: '+m.tipoMercado+' · Estado: '+m.estadoMercado+' · '+(m.descripcionMercado||'Sin descripción')));
                const requirements=opening(m);$('market-context').append(node('p',requirements.length?'Para abrir: '+requirements.join('. ')+'.':'Requisitos visibles para abrir completos; el backend realiza la validación definitiva.','muted'));
                $('market-context').append(node('p',m.tipoMercado==='CONVENCIONAL'?'Convencional: participante opcional y cuota explícita obligatoria.':m.tipoMercado==='MARCADOR_FINAL'?'Marcador final: selección genérica única; SQL resuelve los multiplicadores omitidos.':'Primera anotación: selecciones de los dos participantes distintos; valorResultado no corresponde.','muted'));
                table($('market-selections'),'Selecciones y cuotas activas',['Selección','Participante','Activa','Referencia','Cuota ID','Valor','Valor resultado','Acción'],m.selecciones.map(s=>[s.seleccion,event.participantes.find(p=>p.idParticipante===s.idParticipante)?.participante||'Sin participante',s.seleccionActiva,s.idSeleccion,s.idCuota,s.idCuota===null?'Sin cuota activa':s.valor,s.valorResultado,action('Administrar '+s.seleccion,()=>{selectSelection(s.idSeleccion);openOperation('cuotas/registrar');})]));
            }else $('market-context').append(node('p','Selecciona un mercado para administrar sus selecciones.'));
            selectSelection(selected);sync();
        }
        function selectSelection(value){
            const s=market()?.selecciones.find(s=>s.idSeleccion===Number(value));selectionId=s?.idSeleccion||null;
            $('selection-picker').value=s?String(s.idSeleccion):'';forms.get('cuotas/registrar').reset();
            $('selection-context').textContent=s?s.seleccion+' · '+(s.idCuota===null?'Esta selección todavía no tiene una cuota activa.':'Cuota activa #'+s.idCuota+' · valor '+s.valor+(s.valorResultado!==null?' · valorResultado '+s.valorResultado:'')):'Selecciona una selección para registrar una nueva cuota.';
            selectionMessage();sync();
        }
        function selectionMessage(){const m=market(),s=selection();$('management-selection').textContent=event?[event.evento,m?.mercado,s?.seleccion].filter(Boolean).join(' → '):'Consulta un evento y selecciona sus referencias reales antes de operar.';}
        function openOperation(route){activeRoute=route;selectionMessage();sync();}
        function render(e,preferred={}){
            event=e;const target=$('detail-results');target.replaceChildren(node('h3',e.evento),node('p',e.deporte+' · '+e.liga+' · '+e.estadoEvento+' · '+e.fechaInicio+' · '+(e.simulacion.esSimulado?'Simulado':'No simulado')+' · '+e.cantidadMercados+' mercados'));
            table(target,'Mercados del evento',['Mercado','Modalidad','Estado','Selecciones','Acción'],e.mercados.map(m=>[m.mercado,m.tipoMercado,m.estadoMercado,m.selecciones.length,action('Administrar '+m.mercado,()=>{selectMarket(m.idMercado);openOperation('selecciones/crear');})]));
            if(![...$('detail-id').options].some(o=>o.value===String(e.idEvento)))$('detail-id').append(A.option(e.idEvento,A.eventLabel(e)));
            $('detail-id').value=String(e.idEvento);A.choices($('market-picker'),e.mercados,'idMercado',m=>m.mercado+' · '+m.tipoMercado+' · '+m.estadoMercado);
            $('selected-live').href=base+'/administrador/en-vivo?idEvento='+e.idEvento;$('selected-live').hidden=false;$('selected-markets').hidden=true;
            let selected=preferred.market;
            if(!selected&&!plan){try{const matches=e.mercados.filter(m=>oneEquivalent(m,oneTeams(e))||sameName(m.mercado,'Resultado final — 1X2'));if(matches.length===1)selected=matches[0].idMercado;}catch{/* Otras modalidades conservan su selección manual. */}}
            selectMarket(selected,preferred.selection);
        }
        async function readDetail(eventId,preferred={},verify){
            const stamp=revision;
            const data=await request('/administrador/eventos/detalle?'+new URLSearchParams({idEvento:eventId})),e=checkDetail(data.evento,eventId);
            if(stamp!==revision||leaving)throw new DOMException('El contexto del evento cambió.','AbortError');
            if(verify)verify(e);render(e,preferred);
            if(uncertain){
                verified=uncertain.route==='mercados/estado/cambiar'&&preferred.market===uncertain.market&&(uncertain.selection===null||preferred.selection===uncertain.selection)&&e.idEvento===uncertain.event&&e.idLiga===uncertain.league&&e.idDeporte===uncertain.sport&&e.mercados.some(m=>m.idMercado===uncertain.market&&m.estadoMercado===uncertain.payload.nuevoEstado);
                notice(verified?'El detalle del evento y mercado afectados muestra el estado solicitado. Puedes revisar y habilitar manualmente. El GET muestra estado actual, no qué solicitud lo produjo. No se reenviará ningún POST.':'La consulta no acredita la operación incierta original. Consultar otros eventos, mercados, selecciones o encontrar nombres/valores iguales no demuestra causalidad. Requiere conciliación manual si no existe identidad confirmada suficiente; se mantiene el bloqueo.');
            }
        }
        async function query(work){
            if(busy||sessionBlocked||leaving)return;resetVerification();busy=true;sync();const stamp=revision;
            try{await work(stamp);if(stamp===revision)status('Consulta administrativa completada.');}catch(e){report(e);}finally{busy=false;sync();}
        }
        function detail(value){
            if(busy||sessionBlocked)return;
            if(!inputId(value)){status('Selecciona un evento válido del listado.',true);return;}
            if(plan&&plan.event.idEvento!==Number(value)&&!window.confirm('Hay un proceso 1X2 conservado para '+plan.event.evento+'. Consultar otro evento no lo reemplaza ni reenvía operaciones. ¿Continuar la consulta?'))return;
            if(event?.idEvento!==Number(value)&&!plan)for(const code of ['1','X','2'])$('one-odds-'+code).value='';
            const preferred=event?.idEvento===Number(value)?{market:marketId,selection:selectionId}:{};clearContext();query(()=>readDetail(value,preferred));
        }
        function readback(e,route,p,r){
            const m=e.mercados.find(m=>m.idMercado===(route==='mercados/crear'?r.idMercado:Number(p.idMercado)||marketId));
            if(route==='mercados/crear'&&(!m||m.mercado!==p.nombre||m.descripcionMercado!==(p.descripcion||null)||m.tipoMercado!==p.tipoMercado))fail('El detalle no confirma la modalidad y configuración del mercado creado.');
            if(route==='selecciones/crear'){const s=m?.selecciones.find(s=>s.idSeleccion===r.idSeleccion);if(!s||s.seleccion!==p.nombre||s.idParticipante!==(p.idParticipante?Number(p.idParticipante):null))fail('El detalle no confirma la selección o su participante.');}
            if(route==='cuotas/registrar'){const s=e.mercados.flatMap(m=>m.selecciones).find(s=>s.idSeleccion===Number(p.idSeleccion));if(!s||s.idCuota!==r.idCuota||decimal(s.valor)!==decimal(r.valor)||(p.valorResultado&&decimal(s.valorResultado)!==decimal(p.valorResultado)))fail('El detalle no confirma la cuota activa o su valorResultado.');}
            if(route==='mercados/estado/cambiar'&&(!m||m.estadoMercado!==p.nuevoEstado))fail('El detalle no confirma el estado actual solicitado.');
        }
        function payload(route,form){
            const fields=Object.fromEntries(new FormData(form)),allowed={ 'mercados/crear':['nombre','descripcion','tipoMercado'],'selecciones/crear':['nombre','idParticipante'],'cuotas/registrar':['valor','valorResultado'],'mercados/estado/cambiar':['nuevoEstado','motivo']}[route];
            for(const [key,v]of Object.entries(fields)){if(!allowed.includes(key)||typeof v!=='string')fail('El formulario contiene campos no autorizados.');fields[key]=v.trim();}
            if(!available(route))fail('La operación no está disponible en el contexto y estado actuales. Consulta el detalle.');
            const m=market(),s=selection();
            if(route==='mercados/crear'){
                if(!text(fields.nombre,150)||fields.descripcion.length>250||!types.includes(fields.tipoMercado))fail('Revisa nombre (máximo 150), descripción (máximo 250) y modalidad.');
                if(event.mercados.some(m=>sameName(m.mercado,fields.nombre)))fail('Ya existe un mercado visible con ese nombre.');
                if(fields.tipoMercado!=='CONVENCIONAL'&&(!specialReady()||event.mercados.some(m=>m.tipoMercado===fields.tipoMercado)))fail('Modalidad especial incompatible o ya existente. Requiere evento simulado y dos participantes con órdenes 1 y 2.');
                fields.idEvento=String(event.idEvento);
            }else if(route==='selecciones/crear'){
                if(!text(fields.nombre,150)||m.selecciones.some(s=>sameName(s.seleccion,fields.nombre)))fail('Nombre obligatorio, hasta 150 caracteres y sin duplicados visibles.');
                if(fields.idParticipante&&!event.participantes.some(p=>String(p.idParticipante)===fields.idParticipante))fail('El participante no pertenece al evento consultado.');
                if(m.tipoMercado==='MARCADOR_FINAL'&&(m.selecciones.length||fields.idParticipante))fail('Marcador final permite una selección genérica sin participante.');
                if(m.tipoMercado==='PRIMERA_ANOTACION'&&(!fields.idParticipante||m.selecciones.some(s=>String(s.idParticipante)===fields.idParticipante)))fail('Elige un participante del evento que no tenga una selección en este mercado.');
                fields.idMercado=String(m.idMercado);
            }else if(route==='cuotas/registrar'){
                if(m.tipoMercado==='CONVENCIONAL'&&!fields.valor)fail('La modalidad convencional requiere valor explícito.');
                if(m.tipoMercado!=='MARCADOR_FINAL'&&fields.valorResultado)fail('valorResultado no corresponde a esta modalidad.');
                const v=fields.valor?decimal(fields.valor):null,vr=fields.valorResultado?decimal(fields.valorResultado):null;
                if(v!==null&&vr!==null&&vr>=v)fail('valorResultado debe ser menor que valor.');
                fields.idSeleccion=String(s.idSeleccion);
            }else{
                if(!transitions[m.estadoMercado].includes(fields.nuevoEstado)||fields.motivo.length>250||(fields.nuevoEstado==='ABIERTO'&&opening(m).length))fail('Transición no disponible. Revisa las selecciones, cuotas y estado del evento.');
                fields.idMercado=String(m.idMercado);
            }
            return Object.fromEntries(Object.entries(fields).filter(([,v])=>v!==''));
        }
        function confirmResponse(route,r,p){
            if(!r||typeof r!=='object'||Array.isArray(r))fail('Respuesta sin resultado oficial.');let valid=false;
            if(route==='mercados/crear')valid=id(r.idMercado)&&r.idEvento===Number(p.idEvento)&&id(r.idEstado)&&r.nombre===p.nombre&&r.descripcion===(p.descripcion||null)&&r.estadoMercado==='BORRADOR';
            if(route==='selecciones/crear')valid=id(r.idSeleccion)&&r.idMercado===Number(p.idMercado)&&r.nombre===p.nombre&&r.activo===true;
            if(route==='cuotas/registrar')valid=id(r.idCuota)&&r.idSeleccion===Number(p.idSeleccion)&&r.activo===true&&date(r.fechaInicio)&&(r.idCuotaAnterior===null||id(r.idCuotaAnterior)&&r.idCuotaAnterior!==r.idCuota)&&decimal(r.valor)>10000n&&(!p.valor||decimal(r.valor)===decimal(p.valor));
            if(route==='mercados/estado/cambiar')valid=r.idMercado===Number(p.idMercado)&&marketStates.includes(r.estadoAnterior)&&r.estadoActual===p.nuevoEstado&&typeof r.sinCambios==='boolean'&&r.sinCambios===(r.estadoAnterior===r.estadoActual);
            if(!valid)fail('La respuesta oficial no coincide con la operación. Comprueba su estado antes de repetir.');
        }
        function showResult(result,route){
            const dl=node('dl',undefined,'operation-values');for(const [key,v]of Object.entries(result))dl.append(node('dt',key),node('dd',show(v)));$('operation-values').replaceChildren(node('p',operationNames[route]+': respuesta oficial confirmada.'),dl);
            if(route==='cuotas/registrar')$('operation-values').append(node('p','Cuota anterior informada: '+show(result.idCuotaAnterior)+'. El detalle solo muestra la cuota activa, no el histórico completo.'));
            $('operation-result').hidden=false;
        }
        async function write(route,form){
            if(busy||sessionBlocked||leaving||!canWrite||uncertain)return;let p;try{p=payload(route,form);}catch(e){report(e);return;}
            const fingerprint=route+'?'+new URLSearchParams(p)+(route==='cuotas/registrar'?'&cuotaConsultada='+selection().idCuota:'');if(route!=='mercados/estado/cambiar'&&fingerprints.has(fingerprint)){status('Estos datos ya recibieron confirmación. Consulta el resultado antes de repetir.',true);return;}
            const context={event:event.idEvento,sport:event.idDeporte,league:event.idLiga,market:route==='mercados/crear'?null:marketId,selection:['cuotas/registrar','mercados/estado/cambiar'].includes(route)?selectionId:null,label:[event.evento,route!=='mercados/crear'?market()?.mercado:null,['cuotas/registrar','mercados/estado/cambiar'].includes(route)?selection()?.seleccion:null,p.nombre].filter(Boolean).join(' → ')};
            if(!window.confirm(operationNames[route]+' · '+context.label+(p.nuevoEstado?' · '+market().estadoMercado+' → '+p.nuevoEstado:'')+(p.nuevoEstado==='CERRADO'||p.nuevoEstado==='ANULADO'?'. El backend puede desactivar cuotas activas; no liquida apuestas desde este formulario.':'')+'. ¿Confirmar?'))return;
            if(plan){if(!window.confirm('Esta operación manual puede cambiar el proceso 1X2 conservado. Deberás consultar nuevamente su detalle antes de continuarlo. ¿Confirmar?'))return;planNeedsCheck=true;}
            busy=true;sync();let sent=false;status('Enviando operación…');
            try{
                const token=await request('/administrador/seguridad/csrf');if(typeof token.csrfToken!=='string'||!/^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$/.test(token.csrfToken))fail('Token CSRF inválido; no se envió la operación.');
                sent=true;const data=await request('/administrador/'+route,{method:'POST',headers:{'X-CSRF-Token':token.csrfToken},body:new URLSearchParams(p)});
                confirmResponse(route,data.resultado,p);fingerprints.add(fingerprint);showResult(data.resultado,route);
                const preferred={market:route==='mercados/crear'?data.resultado.idMercado:context.market,selection:route==='selecciones/crear'?data.resultado.idSeleccion:context.selection};
                try{await readDetail(context.event,preferred,e=>readback(e,route,p,data.resultado));openOperation(route==='mercados/crear'?'selecciones/crear':route==='selecciones/crear'?'cuotas/registrar':route);status('Operación confirmada por el servidor. Detalle actualizado; consulta los campos adicionales en sus datos oficiales.');}
                catch(error){clearContext();report(error);status('Operación confirmada por el servidor. No fue posible actualizar o comprobar el detalle: '+(error.status?'HTTP '+error.status:error.message)+'. Conserva la respuesta oficial y consulta nuevamente; no repitas el POST.',true);}
            }catch(error){
                if(leaving||error.cancelledByNavigation)return;report(error);
                if(sent&&(!error.status||error.status>=500||error.status===408)){uncertain={...context,route,payload:{...p}};resetVerification();status('Esta operación podría haber sido procesada, pero no recibimos su confirmación. Consulta el contexto afectado; no repitas el POST.',true);}
            }finally{busy=false;sync();}
        }
        // Flujo 1X2 dentro del mismo controlador; todas las escrituras usan request/CSRF oficiales.
        function oneTeams(e){
            if(!e||e.participantes.length!==2||e.participantes.some(p=>p.tipoParticipante!=='EQUIPO')
                ||!e.participantes.some(p=>p.ordenParticipante===1)||!e.participantes.some(p=>p.ordenParticipante===2))fail('1X2 requiere dos EQUIPOS distintos con órdenes 1 y 2. Usa la administración manual para otras configuraciones.');
            const local=e.participantes.filter(p=>p.esLocal===true),visitor=e.participantes.filter(p=>p.esLocal===false);
            if(local.length!==1||visitor.length!==1)fail('LOCAL y VISITANTE no están identificados inequívocamente. Revisa las asociaciones del evento.');
            return {local:local[0],visitor:visitor[0]};
        }
        function oneIdentity(e){
            const t=oneTeams(e),person=p=>({id:p.idParticipante,name:p.participante,order:p.ordenParticipante});
            return {idEvento:e.idEvento,idDeporte:e.idDeporte,idLiga:e.idLiga,evento:e.evento,deporte:e.deporte,liga:e.liga,
                fechaInicio:e.fechaInicio,fechaFin:e.fechaFin,local:person(t.local),visitor:person(t.visitor)};
        }
        function oneEquivalent(m,t){
            return m.tipoMercado==='CONVENCIONAL'&&m.selecciones.length===3
                &&[t.local.idParticipante,null,t.visitor.idParticipante].every(person=>m.selecciones.filter(s=>s.idParticipante===person).length===1);
        }
        function oneRows(e){
            const t=oneTeams(e),label=(code,name,fallback)=>(code+' - '+name).length<=150?code+' - '+name:fallback;
            // Los nombres completos permanecen visibles aunque la etiqueta SQL deba ser corta.
            return [{code:'1',name:label('1',t.local.participante,'1 - LOCAL'),person:t.local.idParticipante,personName:t.local.participante},
                {code:'X',name:'X - Empate',person:null,personName:'Empate'},
                {code:'2',name:label('2',t.visitor.participante,'2 - VISITANTE'),person:t.visitor.idParticipante,personName:t.visitor.participante}];
        }
        function oneDraft(){
            const identity=oneIdentity(event),name=$('one-name').value.trim(),description=$('one-description').value.trim();
            if(!['BORRADOR','PROGRAMADO'].includes(event.estadoEvento))fail('El evento debe estar en BORRADOR o PROGRAMADO para configurar el mercado.');
            if(!text(name,150)||description.length>250)fail('Revisa el nombre del mercado (máximo 150) y su descripción (máximo 250).');
            const rows=oneRows(event).map(r=>{const odds=$('one-odds-'+r.code).value.trim();decimal(odds);return {...r,odds,id:null,state:'pending',quote:{id:null,state:'pending'}};});
            return {event:identity,market:{name,description,id:null,state:'pending'},rows,open:{state:'pending'},started:false,reviewRequired:'',last:'Plan revisado; todavía no se envió ninguna operación.'};
        }
        function validPlan(p){
            const state=v=>['pending','confirmed','uncertain'].includes(v),ref=v=>v===null||id(v);
            try{return p&&typeof p.started==='boolean'&&typeof p.reviewRequired==='string'&&p.reviewRequired.length<=250&&id(p.event.idEvento)&&id(p.event.idDeporte)&&id(p.event.idLiga)&&text(p.event.evento,200)&&date(p.event.fechaInicio)
                &&(p.event.fechaFin===null||date(p.event.fechaFin))&&id(p.event.local.id)&&id(p.event.visitor.id)&&p.event.local.id!==p.event.visitor.id
                &&[p.event.local,p.event.visitor].every(v=>text(v.name,150)&&[1,2].includes(v.order))&&p.event.local.order!==p.event.visitor.order
                &&text(p.market.name,150)&&typeof p.market.description==='string'&&p.market.description.length<=250&&ref(p.market.id)&&state(p.market.state)
                &&(p.market.state!=='confirmed'||id(p.market.id))&&Array.isArray(p.rows)&&p.rows.length===3&&p.rows.every((r,i)=>r.code===['1','X','2'][i]
                    &&text(r.name,150)&&r.personName===[p.event.local.name,'Empate',p.event.visitor.name][i]
                    &&r.name===(i===1?'X - Empate':(r.code+' - '+r.personName).length<=150?r.code+' - '+r.personName:i===0?'1 - LOCAL':'2 - VISITANTE')
                    &&r.person===[p.event.local.id,null,p.event.visitor.id][i]&&decimal(r.odds)>10000n&&ref(r.id)&&state(r.state)
                    &&(r.state!=='confirmed'||id(r.id))&&r.quote&&ref(r.quote.id)&&state(r.quote.state)&&(r.quote.state!=='confirmed'||id(r.quote.id)))
                &&new Set(p.rows.map(r=>r.name)).size===3&&new Set(p.rows.filter(r=>r.id!==null).map(r=>r.id)).size===p.rows.filter(r=>r.id!==null).length&&state(p.open.state);
            }catch{return false;}
        }
        function savePlan(required=false){
            try{if(plan)sessionStorage.setItem(planKey,JSON.stringify({version:1,plan}));else sessionStorage.removeItem(planKey);}
            catch{if(required)fail('No se pudo conservar el proceso en esta pestaña; no se envió el POST.');status('El proceso permanece en pantalla, pero no pudo guardarse. Conserva sus referencias antes de salir.',true);}
        }
        function planComplete(){return Boolean(plan&&event?.idEvento===plan.event.idEvento&&!planNeedsCheck&&!planConflict&&plan.market.state==='confirmed'
            &&plan.rows.every(r=>r.state==='confirmed'&&r.quote.state==='confirmed'));}
        function planUnknown(){return plan&&(plan.market.state==='uncertain'||plan.rows.some(r=>r.state==='uncertain'||r.quote.state==='uncertain')||plan.open.state==='uncertain');}
        function syncPlan(){
            const locked=busy||sessionBlocked||!canWrite||Boolean(uncertain)||planInvalid||contextMismatch||Boolean(plan&&event&&event.idEvento!==plan.event.idEvento);
            for(const name of ['one-event-back','one-event-program']){
                $(name).hidden=!event||name==='one-event-program'&&event.estadoEvento!=='BORRADOR';
                if(event)$(name).href=base+'/administrador/eventos?idEvento='+encodeURIComponent(event.idEvento)+'#event-wizard';
            }
            $('one-preparation').textContent=contextMismatch?'REQUIERE REVISIÓN: el enlace y el plan guardado pertenecen a eventos distintos. Se conserva el plan; vuelve a su evento antes de operar.':event?'Evento: '+event.evento+' · '+event.estadoEvento+'. Configura y verifica las tres selecciones y cuotas antes de abrir.':'Verificación oficial pendiente: consulta el evento.';
            $('one-edit').hidden=Boolean(plan)||planReview;$('one-review').hidden=Boolean(plan)||!planReview;$('one-progress').hidden=!plan;
            let compatible=false,reason='Consulta un evento para preparar su resultado final 1X2.';
            try{if(event){const teams=oneTeams(event);compatible=['BORRADOR','PROGRAMADO'].includes(event.estadoEvento);reason=compatible?'LOCAL y VISITANTE identificados mediante sus asociaciones oficiales.':'El estado del evento no admite crear mercados.';
                const existing=event.mercados.filter(m=>oneEquivalent(m,teams)||sameName(m.mercado,$('one-name').value.trim()));
                if(!plan&&existing.length){
                    compatible=false;reason=existing.length===1?'Ya existe '+existing[0].mercado+' · '+existing[0].estadoMercado+'. Revisa sus selecciones y cuotas en Mercado seleccionado; no se creará otro.':'Hay varios mercados coincidentes o equivalentes. Requiere revisión manual.';
                    if(existing.length===1){
                        const m=existing[0],missing=m.selecciones.filter(s=>!s.seleccionActiva||s.idCuota===null||s.cuotaActiva!==true).map(s=>s.seleccion);
                        $('one-preparation').textContent='Evento: '+event.evento+' · '+event.estadoEvento+' · Mercado: '+m.estadoMercado+'. '+(!oneEquivalent(m,teams)?'Configuración 1X2 parcial: revisa las selecciones en administración manual.':missing.length?'Selecciones o cuotas pendientes: '+missing.join(', ')+'.':m.estadoMercado==='ABIERTO'&&event.estadoEvento==='PROGRAMADO'?'Evento preparado para apuestas.':'Tres selecciones y cuotas verificadas. '+(event.estadoEvento==='BORRADOR'?'Programa el evento antes de abrir.':'Revisa la apertura en administración manual.'));
                    }
                }
                const rows=oneRows(event);for(const r of rows)$('one-person-'+r.code).textContent=r.personName;}}
            catch(e){reason=e.message;}
            $('one-context').textContent=planInvalid?'El progreso guardado es incompatible. Se conserva el almacenamiento original; requiere revisión manual antes de otro proceso.':plan?'Proceso conservado: '+plan.event.evento+' · '+plan.market.name:reason;
            for(const el of $('one-edit').querySelectorAll('input,textarea,select,button'))el.disabled=locked||Boolean(plan)||!compatible;
            $('one-confirm').disabled=locked||Boolean(plan)||!planReview||!compatible;$('one-back').disabled=locked;
            for(const name of ['check','adopt','resume','open','release','cancel'])$('one-'+name).disabled=locked||!plan;
            $('one-cancel').disabled||=plan?.started===true;
            $('one-resume').disabled||=planNeedsCheck||Boolean(planConflict)||Boolean(planUnknown())||planComplete()||event?.idEvento!==plan?.event.idEvento;
            const m=event?.mercados.find(m=>m.idMercado===plan?.market.id);
            $('one-open').disabled||=!planComplete()||m?.estadoMercado!=='BORRADOR'||event?.estadoEvento!=='PROGRAMADO'||plan?.open.state!=='pending'||Boolean(m&&opening(m).length);
            $('one-release').disabled||=!planComplete()||Boolean(planUnknown());
            if(plan){
                if(contextMismatch||event&&event.idEvento!==plan.event.idEvento){
                    const back=node('a','Volver al proceso conservado: '+plan.event.evento);
                    back.href=base+'/administrador/mercados?idEvento='+encodeURIComponent(plan.event.idEvento)+'#market-one';
                    $('one-preparation').append(document.createTextNode(' '),back);
                }
                const state=planConflict?'CONFLICTO':planUnknown()?'INCIERTO':planNeedsCheck?'PENDIENTE DE COMPROBACIÓN':planComplete()?(m?.estadoMercado==='ABIERTO'?'ABIERTO':'COMPLETO · mercado '+(m?.estadoMercado||'sin comprobar')):'INCOMPLETO';
                $('one-state').textContent=state+' · '+(planConflict||plan.last);
                if(planComplete()&&event.estadoEvento==='BORRADOR')$('one-state').textContent+=' Programa primero el evento mediante administración de eventos; el asistente no cambia su estado.';
                const stateName=v=>({pending:'PENDIENTE',confirmed:'CONFIRMADO',uncertain:'INCIERTO'}[v]);
                const evidence=target=>target.state==='confirmed'&&(planNeedsCheck||planConflict)
                    ?(target.observed?'REFERENCIA OBSERVADA':'RESPUESTA CONSERVADA')+' · comprobar detalle'
                    :target.observed?'OBSERVADO Y VINCULADO':stateName(target.state);
                $('one-market-state').textContent='Mercado: '+evidence(plan.market)+(plan.market.id?' · referencia #'+plan.market.id:' · sin ID oficial')+'. Estado de apertura: '+evidence(plan.open)+'.';
                if(event?.idEvento===plan.event.idEvento&&!planNeedsCheck&&!planConflict){
                    const missing=plan.rows.filter(r=>r.quote.state!=='confirmed').map(r=>r.code+' · '+r.personName);
                    $('one-preparation').textContent='Evento: '+event.evento+' · '+event.estadoEvento+' · Mercado: '+(m?.estadoMercado||'PENDIENTE')+'. '+(missing.length?'Cuotas pendientes: '+missing.join(', ')+'.':planComplete()?'Tres selecciones y tres cuotas verificadas. ':'Verificación de selecciones pendiente. ')+(planComplete()&&m?.estadoMercado==='ABIERTO'&&event.estadoEvento==='PROGRAMADO'?'Evento preparado para apuestas.':event.estadoEvento==='BORRADOR'?'Programa el evento antes de abrir.':'Revisa el siguiente paso del proceso.');
                }
                $('one-rows').replaceChildren();table($('one-rows'),'Progreso conservado del proceso 1X2',['Resultado','Selección','Cuota revisada','Selección oficial','Cuota oficial'],plan.rows.map(r=>[r.code+' · '+r.personName,r.name,r.odds,evidence(r)+(r.id?' · #'+r.id:''),evidence(r.quote)+(r.quote.id?' · #'+r.quote.id:'')]));
            }
        }
        function reviewPlan(){
            if(busy||sessionBlocked||!canWrite||uncertain||plan||planInvalid)return;
            try{const p=oneDraft(),dl=node('dl',undefined,'operation-values');
                for(const [label,value]of [['Evento',p.event.evento],['Deporte',p.event.deporte],['Liga',p.event.liga],['LOCAL',p.event.local.name],['VISITANTE',p.event.visitor.name],['Mercado',p.market.name],['Tipo','CONVENCIONAL'],['Estado inicial y final solicitado','BORRADOR'],...p.rows.map(r=>[r.name,r.odds])])dl.append(node('dt',label),node('dd',value));
                $('one-summary').replaceChildren(dl);planReview=true;sync();
            }catch(e){report(e);}
        }
        async function checkPlan(adopt=false){
            if(contextMismatch||event&&event.idEvento!==plan?.event.idEvento)fail('El evento consultado y el plan conservado no coinciden. Vuelve al evento del plan para conciliarlo; no se enviarán escrituras.');
            if(!validPlan(plan))fail('El proceso conservado no es válido; requiere revisión manual.');
            planNeedsCheck=true;planConflict=plan.reviewRequired;sync();
            const e=checkDetail((await request('/administrador/eventos/detalle?'+new URLSearchParams({idEvento:plan.event.idEvento}))).evento,plan.event.idEvento);
            if(JSON.stringify(oneIdentity(e))!==JSON.stringify(plan.event))fail('La identidad, fechas o participantes del evento difieren del plan. No se enviará ninguna escritura.');
            let m=plan.market.id===null?null:e.mercados.find(m=>m.idMercado===plan.market.id);
            const candidates=e.mercados.filter(m=>m.tipoMercado==='CONVENCIONAL'&&m.mercado===plan.market.name&&m.descripcionMercado===(plan.market.description||null));
            if(!m&&plan.market.id!==null)planConflict='El mercado con identidad confirmada no aparece en el detalle.';
            if(plan.market.id===null&&candidates.length){
                if(adopt&&candidates.length===1){m=candidates[0];plan.market.id=m.idMercado;plan.market.state='confirmed';plan.market.observed=true;}
                else planConflict='Hay un mercado coincidente sin identidad vinculada. Revisa y vincula explícitamente las referencias observadas; el nombre no demuestra qué POST lo creó.';
            }
            if(!m){
                if(plan.market.state==='uncertain')planConflict||='No hay identidad suficiente para conciliar la creación incierta. No se repetirá; requiere revisión manual.';
                if(e.mercados.some(m=>sameName(m.mercado,plan.market.name)||oneEquivalent(m,oneTeams(e))))planConflict||='Ya hay un nombre coincidente o una configuración convencional equivalente. Revisa el mercado existente; no se creará otro.';
            }else{
                if(m.tipoMercado!=='CONVENCIONAL'||m.mercado!==plan.market.name||m.descripcionMercado!==(plan.market.description||null))planConflict='El mercado oficial no coincide con la modalidad y descripción revisadas.';
                if(!['BORRADOR','ABIERTO','SUSPENDIDO'].includes(m.estadoMercado))planConflict='El mercado está '+m.estadoMercado+'; no admite continuar este proceso.';
                const used=new Set();
                for(const r of plan.rows){
                    let s=r.id===null?null:m.selecciones.find(s=>s.idSeleccion===r.id);
                    const matches=m.selecciones.filter(s=>s.seleccion===r.name&&s.idParticipante===r.person);
                    if(!s&&r.id!==null)planConflict||='Una selección con identidad confirmada ya no aparece. No se repetirá.';
                    if(r.id===null&&matches.length){
                        if(adopt&&matches.length===1){s=matches[0];r.id=s.idSeleccion;r.state='confirmed';r.observed=true;}
                        else planConflict||='Hay selecciones observadas pendientes de vinculación explícita. No se crearán duplicados.';
                    }
                    if(!s){if(r.state==='uncertain')planConflict||='Selección incierta sin referencia suficiente; requiere conciliación manual.';continue;}
                    used.add(s.idSeleccion);
                    if(s.seleccion!==r.name||s.idParticipante!==r.person||!s.seleccionActiva)planConflict||='Selección incompatible, inactiva o asociada a otro participante.';
                    if(s.idCuota===null){if(r.quote.state!=='pending'||r.quote.id!==null)planConflict||='Cuota confirmada o incierta sin una cuota activa comprobable. No se repetirá automáticamente.';}
                    else if(decimal(s.valor)!==decimal(r.odds))planConflict||='La cuota activa difiere de la revisada. Su sustitución requiere una decisión en administración manual.';
                    else if(r.quote.id!==null){if(r.quote.id!==s.idCuota)planConflict||='La identidad de la cuota activa cambió; revisa su histórico antes de operar.';}
                    else if(adopt){r.quote.id=s.idCuota;r.quote.state='confirmed';r.quote.observed=true;}
                    else planConflict||='Existe una cuota coincidente sin referencia vinculada. Revisa y vincula el estado observado; no se registrará otra cuota.';
                }
                if(m.selecciones.some(s=>!used.has(s.idSeleccion)))planConflict||='El mercado tiene selecciones adicionales o incompatibles con el plan 1X2.';
                if(m.estadoMercado==='ABIERTO'&&plan.open.state==='uncertain'){plan.open.state='confirmed';plan.open.observed=true;}
                if(plan.open.state==='confirmed'&&m.estadoMercado!=='ABIERTO')planConflict||='El mercado ya no refleja la apertura confirmada u observada. Revisa su estado en administración manual; no se repetirá la apertura.';
            }
            if(!['BORRADOR','PROGRAMADO'].includes(e.estadoEvento)&&m?.estadoMercado!=='ABIERTO')planConflict||='El estado del evento no admite continuar la configuración.';
            planNeedsCheck=false;plan.last='Detalle oficial consultado. Un GET muestra el estado observado; no demuestra qué solicitud lo produjo.';
            savePlan();render(e,{market:plan.market.id});sync();
            if(planConflict)fail(planConflict);
            return m;
        }
        async function planPost(route,p,target){
            const token=await request('/administrador/seguridad/csrf');
            if(typeof token.csrfToken!=='string'||!/^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$/.test(token.csrfToken))fail('Token CSRF inválido. No se envió el POST.');
            const previous=target.state,started=plan.started;target.state='uncertain';plan.started=true;planNeedsCheck=true;
            try{savePlan(true);}catch(e){target.state=previous;plan.started=started;throw e;}
            let data;
            try{data=await request('/administrador/'+route,{method:'POST',headers:{'X-CSRF-Token':token.csrfToken},body:new URLSearchParams(p)});}
            catch(e){if([400,401,403,404,405,409].includes(e.status)){target.state=previous;plan.last='Solicitud rechazada: HTTP '+e.status+'. Se conserva el progreso.';}savePlan();throw e;}
            const r=data.resultado;confirmResponse(route,r,p);
            if(route==='mercados/crear'){target.id=r.idMercado;target.result={idMercado:r.idMercado,idEvento:r.idEvento,idEstado:r.idEstado,estadoMercado:r.estadoMercado,nombre:r.nombre,descripcion:r.descripcion};}
            if(route==='selecciones/crear'){target.id=r.idSeleccion;target.result={idSeleccion:r.idSeleccion,idMercado:r.idMercado,nombre:r.nombre,activo:r.activo};}
            if(route==='cuotas/registrar'){target.id=r.idCuota;target.result={idCuota:r.idCuota,idSeleccion:r.idSeleccion,valor:r.valor,fechaInicio:r.fechaInicio,activo:r.activo,idCuotaAnterior:r.idCuotaAnterior};}
            if(route==='mercados/estado/cambiar')target.result={idMercado:r.idMercado,estadoAnterior:r.estadoAnterior,estadoActual:r.estadoActual,sinCambios:r.sinCambios};
            target.state='confirmed';plan.last=operationNames[route]+': respuesta oficial conservada; comprobación de detalle pendiente.';savePlan();showResult(target.result,route);
            if(route==='cuotas/registrar'&&r.idCuotaAnterior!==null){plan.reviewRequired='El backend informa una cuota anterior inesperada. Se conserva la respuesta; detén la recuperación y revisa el histórico.';savePlan();fail(plan.reviewRequired);}
            return r;
        }
        async function runPlan(work){
            if(busy||sessionBlocked||leaving||!canWrite||uncertain||planInvalid||contextMismatch||event&&event.idEvento!==plan?.event.idEvento)return;
            busy=true;sync();
            try{await work();}catch(e){if(plan){planNeedsCheck=true;savePlan();}report(e);}finally{busy=false;sync();}
        }
        async function configurePlan(){
            let m=await checkPlan(false);
            if(planUnknown())fail('Hay una operación incierta; comprueba y vincula las referencias observadas antes de continuar.');
            if(!m){await planPost('mercados/crear',{idEvento:String(plan.event.idEvento),nombre:plan.market.name,tipoMercado:'CONVENCIONAL',...(plan.market.description?{descripcion:plan.market.description}:{})},plan.market);m=await checkPlan(false);}
            if(m.estadoMercado!=='BORRADOR')fail('El mercado debe permanecer en BORRADOR para completar el asistente. Usa administración manual para otras transiciones.');
            for(const row of plan.rows){
                await checkPlan(false);if(row.state==='confirmed')continue;
                if(row.state!=='pending')fail('Selección incierta; no se reenviará.');
                await planPost('selecciones/crear',{idMercado:String(plan.market.id),nombre:row.name,...(row.person===null?{}:{idParticipante:String(row.person)})},row);
                await checkPlan(false);
            }
            if(plan.rows.some(r=>r.state!=='confirmed'))fail('Faltan selecciones confirmadas; no se registrarán cuotas.');
            for(const row of plan.rows){
                await checkPlan(false);if(row.quote.state==='confirmed')continue;
                if(row.quote.state!=='pending')fail('Cuota incierta; no se reenviará.');
                await planPost('cuotas/registrar',{idSeleccion:String(row.id),valor:row.odds},row.quote);await checkPlan(false);
            }
            plan.last='Mercado 1X2 COMPLETO y comprobado. Permanece en BORRADOR; la apertura es una operación independiente.';savePlan();sync();
        }
        function makeForm(route,schema,help){
            const panel=node('section',undefined,'panel'),form=node('form',undefined,'live-form management-form'),fieldset=node('fieldset'),title=operationNames[route];panel.append(node('h2',title));form.dataset.operation=route;form.action=base+'/administrador/'+route;form.method='post';form.noValidate=true;fieldset.append(node('legend','Referencias tomadas del evento, mercado y selección consultados.'));
            for(const [name,label,type,options,max]of schema){const control=node(type==='select'?'select':type==='textarea'?'textarea':'input');control.name=name;control.id='market-'+route.split('/')[0]+'-'+name;
                const labelNode=node('label',label);labelNode.htmlFor=control.id;if(type==='select')options.forEach(v=>control.append(A.option(v,v)));else if(type!=='textarea')control.type='text';if(max)control.maxLength=max;
                if(['valor','valorResultado'].includes(name)){control.inputMode='decimal';control.autocomplete='off';}
                if(name==='nombre')control.required=true;labelNode.append(control);fieldset.append(labelNode);
            }
            fieldset.append(node('p',help,'muted'));const submit=node('button',title,'primary');submit.type='submit';fieldset.append(submit);form.append(fieldset);panel.append(form);$('management-forms').append(panel);forms.set(route,form);form.addEventListener('submit',e=>{e.preventDefault();write(route,form);});
            const button=action(title,()=>openOperation(route));buttons.set(route,button);$('management-flow').append(button);
        }
        makeForm('mercados/crear',[['nombre','Nombre','text',null,150],['descripcion','Descripción (opcional)','textarea',null,250],['tipoMercado','Modalidad','select',types]],'Convencional: selecciones normales. Marcador final: una selección genérica. Primera anotación: participantes del evento. Las modalidades especiales requieren evento simulado y dos participantes con órdenes 1 y 2. Sus permisos específicos de deporte no se exponen en GET: SQL realiza la validación final.');
        makeForm('selecciones/crear',[['nombre','Nombre','text',null,150],['idParticipante','Participante del evento (según modalidad)','select',[]]],'Selecciona un mercado para administrar sus selecciones. El backend confirma la asociación al participante mediante el detalle, no mediante el DTO POST.');
        makeForm('cuotas/registrar',[['valor','Valor (obligatorio para convencional)','text',null,32],['valorResultado','Valor resultado (solo marcador final, opcional)','text',null,32]],'Punto decimal, hasta cuatro posiciones, mayor que 1 y máximo 999999.9999. No se redondea. En modalidades especiales, SQL resuelve los valores omitidos y los valida; no se conocen de antemano. Para marcador final: 1 < valorResultado < valor. Crear una cuota sustituye la activa; no se precargan sus valores.');
        makeForm('mercados/estado/cambiar',[['nuevoEstado','Estado solicitado','select',[]],['motivo','Motivo (opcional)','textarea',null,250]],'Revisa los requisitos de apertura en el contexto del mercado. CERRADO y ANULADO pueden desactivar cuotas activas. LIQUIDADO corresponde al proceso autorizado de oficialización y no es una acción de este formulario.');
        $('one-prepare').addEventListener('click',reviewPlan);
        $('one-back').addEventListener('click',()=>{if(!busy&&!plan){planReview=false;sync();}});
        $('one-confirm').addEventListener('click',()=>{
            if(busy||sessionBlocked||!canWrite||uncertain||plan||planInvalid||!planReview)return;
            let draft;try{draft=oneDraft();}catch(e){report(e);return;}
            if(!window.confirm('Crear '+draft.market.name+' para '+draft.event.evento+' con tres selecciones y cuotas '+draft.rows.map(r=>r.code+': '+r.odds).join(', ')+'. Son siete POST independientes; el mercado permanecerá en BORRADOR. ¿Confirmar?'))return;
            plan=draft;planNeedsCheck=true;planReview=false;runPlan(configurePlan);
        });
        $('one-check').addEventListener('click',()=>{if(plan)runPlan(()=>checkPlan(false));});
        $('one-adopt').addEventListener('click',()=>{if(plan&&!busy&&window.confirm('Se consultará el detalle y se vincularán únicamente referencias oficiales con identidad y valores compatibles con este plan. El GET acredita el estado observado, no qué POST lo produjo. No se enviará ninguna escritura. ¿Confirmar la conciliación administrativa?'))runPlan(()=>checkPlan(true));});
        $('one-resume').addEventListener('click',()=>{if(plan&&!busy&&!planNeedsCheck&&!planConflict&&!planUnknown()&&window.confirm('Continuar solo las operaciones PENDIENTES del mercado conservado. Se comprobará otra vez el detalle; no se sustituirán cuotas existentes. ¿Confirmar?'))runPlan(configurePlan);});
        $('one-open').addEventListener('click',()=>{if(plan&&planComplete()&&!planUnknown())runPlan(async()=>{
            const m=await checkPlan(false);
            if(!planComplete()||plan.open.state!=='pending'||m.estadoMercado!=='BORRADOR'||event.estadoEvento!=='PROGRAMADO'||opening(m).length)fail('No se puede abrir: se exige evento PROGRAMADO, mercado BORRADOR y las tres selecciones y cuotas comprobadas.');
            if(!window.confirm('Abrir '+m.mercado+' de '+event.evento+'. Esta operación es independiente de la configuración 1X2. ¿Confirmar ABIERTO?'))return;
            await planPost('mercados/estado/cambiar',{idMercado:String(m.idMercado),nuevoEstado:'ABIERTO'},plan.open);
            const opened=await checkPlan(false);if(opened.estadoMercado!=='ABIERTO')fail('El detalle no confirma ABIERTO. Conserva la respuesta oficial y concilia antes de otra operación.');
            plan.last='ABIERTO confirmado por respuesta y detalle oficial.';savePlan();status(plan.last);
        });});
        $('one-release').addEventListener('click',()=>{if(!busy&&canWrite&&planComplete()&&!planUnknown()&&window.confirm('¿Ya revisaste el mercado completo y sus resultados? Finalizar este proceso no cierra ni abre el mercado y no envía POST.')){plan=null;planConflict='';planNeedsCheck=false;planReview=false;savePlan();sync();}});
        $('one-cancel').addEventListener('click',()=>{if(!busy&&canWrite&&plan&&!plan.started&&window.confirm('No se envió ningún POST de este plan. ¿Volver a editar sus campos?')){plan=null;planNeedsCheck=false;planConflict='';savePlan();sync();}});
        try{
            const saved=JSON.parse(sessionStorage.getItem(planKey)||'null');
            if(saved){if(saved.version!==1||!validPlan(saved.plan))fail('Progreso 1X2 incompatible.');plan=saved.plan;planNeedsCheck=true;}
        }catch{planInvalid=true;status('No se pudo restaurar el proceso 1X2. Conservamos el almacenamiento original; revisa manualmente los mercados antes de iniciar otra configuración.',true);}
        const warning=node('p',undefined,'warning');warning.id='market-uncertain';warning.hidden=true;warning.setAttribute('role','status');warning.setAttribute('aria-live','polite');$('management-status').after(warning);
        $('market-picker').addEventListener('change',()=>{if(!busy&&!sessionBlocked){resetVerification();selectMarket($('market-picker').value);}});
        $('selection-picker').addEventListener('change',()=>{if(!busy&&!sessionBlocked){resetVerification();selectSelection($('selection-picker').value);}});
        forms.get('mercados/crear').elements.tipoMercado.addEventListener('change',sync);
        $('acknowledge-write').addEventListener('click',()=>{if(!busy&&!sessionBlocked&&canWrite&&uncertain&&verified&&window.confirm('El GET acredita el estado actual del evento y mercado afectados, no la causalidad de la solicitud. ¿Habilitar manualmente sin reenviar ninguna operación?')){uncertain=null;verified=false;notice('');sync();status('Formularios habilitados tras comprobar el contexto. No se envió ninguna escritura.');}});
        async function loadSports(){clearContext();A.resetEvents();A.choices($('detail-id'),[],'idEvento','evento');$('browse-results').replaceChildren();A.choices($('browse-sport'),[],'idDeporte','nombre');await query(async()=>{const data=await request('/deportes/exploracion');if(!Array.isArray(data.deportes)||data.deportes.some(s=>!id(s.idDeporte)||!text(s.nombre,150)||s.activo!==true||typeof s.permiteSimulacion!=='boolean')||new Set(data.deportes.map(s=>s.idDeporte)).size!==data.deportes.length)fail('Catálogo de deportes inválido.');A.choices($('browse-sport'),data.deportes,'idDeporte','nombre');if(!data.deportes.length)$('browse-results').append(node('p','No hay deportes disponibles.'));});}
        $('load-sports').addEventListener('click',()=>{if(!busy&&!sessionBlocked)loadSports();});
        $('browse-sport').addEventListener('change',()=>{if(!busy&&!sessionBlocked){clearContext();A.resetEvents();$('browse-form').requestSubmit();}});
        $('browse-form').addEventListener('submit',e=>{e.preventDefault();if(busy||sessionBlocked)return;const sport=$('browse-sport').value;if(!inputId(sport)){status('Selecciona un deporte consultado.',true);return;}clearContext();A.choices($('detail-id'),[],'idEvento','evento');$('browse-results').replaceChildren();const path=A.eventsPath(sport),page=Number(new URLSearchParams(path.split('?')[1]).get('pagina'));
            query(async()=>{const data=await request(path);if(data.pagina!==page||data.tamanoPagina!==100||!Number.isSafeInteger(data.total)||data.total<0||!Array.isArray(data.eventos)||data.eventos.length!==Math.min(100,Math.max(0,data.total-(page-1)*100))||data.eventos.some(e=>!id(e.idEvento)||e.idDeporte!==Number(sport)||!id(e.idLiga)||!text(e.evento,200)||!eventStates.includes(e.estadoEvento)||!date(e.fechaInicio))||new Set(data.eventos.map(e=>e.idEvento)).size!==data.eventos.length)fail('Página administrativa de eventos inconsistente.');A.pageData(data);A.choices($('detail-id'),data.eventos,'idEvento',A.eventLabel);table($('browse-results'),'Eventos administrativos',['Evento','Liga','Estado','Inicio','Acción'],data.eventos.map(e=>[e.evento,e.liga,e.estadoEvento,e.fechaInicio,action('Abrir '+e.evento,()=>detail(e.idEvento))]));});});
        $('detail-form').addEventListener('submit',e=>{e.preventDefault();detail($('detail-id').value);});$('detail-id').addEventListener('change',()=>detail($('detail-id').value));A.eventPagination($('browse-form'));
        window.addEventListener('pagehide',()=>{leaving=true;revision++;});
        window.addEventListener('pageshow',e=>{if(e.persisted)location.reload();});
        document.querySelector('[data-nav="mercados"]').setAttribute('aria-current','page');
        clearContext();sync();if(!canWrite)status('Las escrituras requieren ADMINISTRADOR u OPERADOR_EVENTOS. El backend conserva la autorización definitiva.',true);
        const initial=new URLSearchParams(location.search).get('idEvento');
        loadSports().then(async()=>{
            if(initial!==null&&!inputId(initial)){contextMismatch=true;sync();status('La referencia de evento en la URL no es válida. Se bloquean escrituras; vuelve al listado administrativo.',true);return;}
            contextMismatch=Boolean(plan&&initial!==null&&plan.event.idEvento!==Number(initial));
            if(contextMismatch){await query(()=>readDetail(initial));status('El enlace corresponde a otro evento. El plan de '+plan.event.evento+' se conserva y las escrituras permanecen bloqueadas. Regresa al evento del plan para revisarlo.',true);return;}
            if(plan)await query(()=>checkPlan(false));else if(initial!==null)await query(()=>readDetail(initial));
            if(event&&initial!==null){$('one-title').focus();$('market-one').scrollIntoView({block:'start'});}
        });
    }
    return {init};
})();
