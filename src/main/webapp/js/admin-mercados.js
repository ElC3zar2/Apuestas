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
            return missing;
        }
        function available(route){
            const m=market(),s=selection();
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
        function clearContext(){event=null;marketId=null;selectionId=null;revision++;clearForms();$('detail-results').replaceChildren();$('market-context').replaceChildren(node('p','Consulta un evento para administrar sus mercados.'));$('market-selections').replaceChildren();$('selection-context').textContent='Selecciona una selección para consultar su cuota activa.';A.choices($('market-picker'),[],'idMercado','mercado');A.choices($('selection-picker'),[],'idSeleccion','seleccion');$('selected-live').hidden=true;$('selected-markets').hidden=true;}
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
            selectMarket(preferred.market,preferred.selection);
        }
        async function readDetail(eventId,preferred={},verify){
            const data=await request('/administrador/eventos/detalle?'+new URLSearchParams({idEvento:eventId})),e=checkDetail(data.evento,eventId);
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
        document.querySelector('[data-nav="mercados"]').setAttribute('aria-current','page');
        clearContext();sync();if(!canWrite)status('Las escrituras requieren ADMINISTRADOR u OPERADOR_EVENTOS. El backend conserva la autorización definitiva.',true);
        const initial=new URLSearchParams(location.search).get('idEvento');
        loadSports().then(()=>{if(initial!==null){if(inputId(initial))detail(initial);else status('La referencia de evento en la URL no es válida. Selecciona un evento del listado.',true);}});
    }
    return {init};
})();
