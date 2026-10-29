/* ADMIN-07: resultados administrativos. SQL conserva reglas deportivas y transacciones. */
(() => {
    'use strict';
    if (document.body.dataset.resultsInitialized) return;
    document.body.dataset.resultsInitialized = 'true';
    const A = window.BetZoneAdmin, $ = id => document.getElementById(id);
    const base = document.body.dataset.contextPath || '', role = document.body.dataset.adminRole || '';
    const readable = ['ADMINISTRADOR','OPERADOR_EVENTOS','AUDITOR'].includes(role);
    const writable = ['ADMINISTRADOR','OPERADOR_EVENTOS'].includes(role);
    const eventStates = ['BORRADOR','PROGRAMADO','EN_VIVO','SUSPENDIDO','PENDIENTE_RESULTADO','FINALIZADO','CANCELADO'];
    const resultStates = ['PENDIENTE','CORREGIDO','OFICIAL','ANULADO'];
    const marketStates = ['BORRADOR','ABIERTO','SUSPENDIDO','CERRADO','LIQUIDADO','ANULADO'];
    const modalities = ['CONVENCIONAL','MARCADOR_FINAL','PRIMERA_ANOTACION'], resolutions = ['GANADA','PERDIDA','ANULADA'];
    const prefix = '/administrador/resultados/';
    const specs = {
        registrar: {name:'Registrar resultado preliminar',fields:[['resultadoTexto','Resultado preliminar',250,true],['observacion','Observación (opcional)',500,false]]},
        'selecciones/resolver': {name:'Resolver selección convencional',fields:[['observacion','Observación (opcional)',500,false]]},
        oficializar: {name:'Oficializar resultado',fields:[['observacion','Observación (opcional)',500,false]]},
        corregir: {name:'Corregir resultado oficial',admin:true,fields:[['nuevoResultadoTexto','Nuevo resultado',250,true],['motivo','Motivo de corrección',500,true]]},
        anular: {name:'Anular resultado',admin:true,fields:[['motivo','Motivo de anulación',500,true]]}
    };
    const forms = new Map(), buttons = new Map(), denied = new Set();
    let eventId = null, event = null, result = null, selectionId = null, fresh = false;
    let writing = false, reading = false, catalogBusy = false, leaving = false, sessionBlocked = false, revision = 0;
    let uncertain = null, active = 'registrar', correctionInvalidated = false, registerArmed = true, outcomeContext = null;
    let selectionOptionsStamp='',outcomeOptionsStamp='';
    const id = v => Number.isInteger(v) && v > 0 && v <= 2147483647;
    const inputId = v => typeof v === 'string' && /^[1-9][0-9]{0,9}$/.test(v) && id(Number(v));
    const object = v => v !== null && typeof v === 'object' && !Array.isArray(v);
    const text = (v,max,optional=false) => optional && v === null || typeof v === 'string' && v.length <= max && (optional || v.trim().length > 0);
    const nonnegative = v => Number.isInteger(v) && v >= 0 && v <= 2147483647;
    const fail = message => { throw new Error(message || 'Respuesta incompleta, inconsistente o de otro contexto. Actualiza mediante GET.'); };
    const node = (tag,value,cls) => { const n=document.createElement(tag); if(value!==undefined)n.textContent=value;if(cls)n.className=cls;return n; };
    const display = v => v === null || v === undefined ? 'Sin dato' : typeof v === 'boolean' ? v ? 'Sí' : 'No' : String(v);
    function bigint(v) {
        if (!['number','string'].includes(typeof v) || typeof v === 'number' && !Number.isSafeInteger(v)) return null;
        const value=String(v);
        return /^[1-9][0-9]{0,18}$/.test(value) && BigInt(value)<=9223372036854775807n ? value : null;
    }
    function parse(raw) {
        let key=null;
        return JSON.parse(raw.replace(/"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/g,(token,offset)=>{
            if(token[0]==='"'){key=/^\s*:/.test(raw.slice(offset+token.length))?JSON.parse(token):null;return token;}
            const field=key;key=null;
            if(['idIncidenciaPrimeraAnotacion','idPrimeraAnotacion','idIncidencia'].includes(field))return JSON.stringify(token);
            if(/^id[A-Z]/.test(field||'') && (!/^[1-9][0-9]*$/.test(token)||!id(Number(token))))fail();
            return token;
        }));
    }
    function date(v) {
        if(typeof v!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,9})?)?$/.test(v))return false;
        const [y,m,d,h,n,s=0]=v.match(/\d+/g).map(Number),check=new Date(0);check.setUTCFullYear(y,m-1,d);
        return y>0&&check.getUTCFullYear()===y&&check.getUTCMonth()===m-1&&check.getUTCDate()===d&&h<24&&n<60&&s<60;
    }
    const dateText = v => v===null ? 'Sin dato' : v.replace('T',' '); // LocalDateTime: no atribuir una zona horaria.
    const allowedRole = route => writable && (!specs[route].admin || role==='ADMINISTRADOR') && !denied.has(route);
    function status(message,error=false){if(leaving)return;$('management-status').textContent=message;$('management-status').dataset.error=String(error);}
    function errorText(error){return error.status===408?'HTTP 408: resultado de la solicitud no confirmado.':error.status?A.messages[error.status]||'Error HTTP '+error.status:error.name==='AbortError'?'Solicitud interrumpida o agotó el tiempo de espera.':error instanceof TypeError?'Error temporal de conexión.':error.message;}
    function report(error){
        if(leaving)return;status(errorText(error),true);
        if(error.status===401){sessionBlocked=true;$('management-login').hidden=false;}
    }
    async function request(path,options){
        if(leaving)throw new DOMException('Navegación','AbortError');
        const data=await A.request(path,options,parse);
        if(leaving)throw new DOMException('Navegación','AbortError');
        if(!object(data)||data.ok!==true)fail();return data;
    }
    function validateDetail(e,expected){
        if(!object(e)||e.idEvento!==Number(expected)||!id(e.idDeporte)||!id(e.idLiga)||!text(e.evento,200)||!text(e.deporte,150)||!text(e.liga,150)
            ||!eventStates.includes(e.estadoEvento)||!date(e.fechaInicio)||!(e.fechaFin===null||date(e.fechaFin))||typeof e.simulacion?.esSimulado!=='boolean'
            ||!Array.isArray(e.participantes)||!Array.isArray(e.mercados)||e.cantidadParticipantes!==e.participantes.length||e.cantidadMercados!==e.mercados.length)fail();
        const people=new Set(),orders=new Set(),markets=new Set(),selections=new Set();
        for(const p of e.participantes){if(!id(p.idParticipante)||people.has(p.idParticipante)||!id(p.ordenParticipante)||p.ordenParticipante>255||orders.has(p.ordenParticipante)||!text(p.participante,150))fail();people.add(p.idParticipante);orders.add(p.ordenParticipante);}
        for(const m of e.mercados){
            if(!id(m.idMercado)||markets.has(m.idMercado)||!text(m.mercado,150)||!modalities.includes(m.tipoMercado)||!marketStates.includes(m.estadoMercado)||!Array.isArray(m.selecciones))fail();markets.add(m.idMercado);
            for(const s of m.selecciones){
                if(!id(s.idSeleccion)||selections.has(s.idSeleccion)||!text(s.seleccion,150)||typeof s.seleccionActiva!=='boolean'
                    ||!(s.idParticipante===null||people.has(s.idParticipante))||!(s.idCuota===null||id(s.idCuota))
                    ||!(s.resultadoSeleccion===null||resolutions.includes(s.resultadoSeleccion))||!(s.fechaResolucion===null||date(s.fechaResolucion))
                    ||(s.resultadoSeleccion===null)!==(s.fechaResolucion===null))fail();selections.add(s.idSeleccion);
            }
        }
        return e;
    }
    function validateResult(data,e){
        if(data.idEvento!==e.idEvento||data.estadoEvento!==e.estadoEvento||typeof data.tieneResultado!=='boolean')fail();
        const r=data.resultado;
        if(!data.tieneResultado){if(r!==null||e.estadoResultado!==null||e.resultadoTexto!==null)fail();return null;}
        if(!object(r)||!id(r.idResultado)||r.idResultadoEvento!==r.idResultado||!resultStates.includes(r.estadoResultado)||!text(r.resultadoTexto,250)
            ||!text(r.observacion,500,true)||!date(r.fechaRegistro)||!(r.marcadorFinalA===null||nonnegative(r.marcadorFinalA))||!(r.marcadorFinalB===null||nonnegative(r.marcadorFinalB))
            ||(r.marcadorFinalA===null)!==(r.marcadorFinalB===null)||e.estadoResultado!==r.estadoResultado||e.resultadoTexto!==r.resultadoTexto)fail();
        if(r.idIncidenciaPrimeraAnotacion!==null){const exact=bigint(r.idIncidenciaPrimeraAnotacion);if(!exact)fail();r.idIncidenciaPrimeraAnotacion=exact;}
        return r;
    }
    const pair = () => {for(const m of event?.mercados||[]){const s=m.selecciones.find(s=>s.idSeleccion===selectionId);if(s)return {m,s};}return null;};
    function officialProblems(){
        const issues=[];
        for(const m of event?.mercados||[]){
            if(!['CERRADO','LIQUIDADO','ANULADO'].includes(m.estadoMercado))issues.push(m.mercado+': mercado todavía '+m.estadoMercado);
            if(m.tipoMercado==='CONVENCIONAL'&&m.estadoMercado!=='ANULADO'&&m.selecciones.some(s=>s.seleccionActiva&&s.resultadoSeleccion===null))issues.push(m.mercado+': faltan resoluciones convencionales activas');
        }
        return issues;
    }
    function eligible(route){
        if(!event)return false;
        const pending=result&&['PENDIENTE','CORREGIDO'].includes(result.estadoResultado);
        if(route==='registrar')return event.estadoEvento==='PENDIENTE_RESULTADO'&&(!result||pending)&&(!event.simulacion.esSimulado||Boolean(result));
        if(route==='selecciones/resolver'){const p=pair();return Boolean(pending&&p?.m.tipoMercado==='CONVENCIONAL'&&p.s.seleccionActiva);}
        if(route==='oficializar')return Boolean(pending&&event.estadoEvento==='PENDIENTE_RESULTADO'&&!officialProblems().length);
        if(route==='corregir')return result?.estadoResultado==='OFICIAL';
        return Boolean(result&&result.estadoResultado!=='ANULADO');
    }
    const ready = route => allowedRole(route)&&fresh&&!writing&&!reading&&!catalogBusy&&!leaving&&!sessionBlocked&&!uncertain&&eligible(route);
    function evidence(){
        if(!uncertain||!fresh||!event||!result||writing||reading||sessionBlocked||event.idEvento!==uncertain.event||event.idDeporte!==uncertain.sport||event.idLiga!==uncertain.league||result.idResultado!==uncertain.result)return false;
        if(uncertain.route==='oficializar')return result.estadoResultado==='OFICIAL'&&event.estadoEvento==='FINALIZADO';
        if(uncertain.route==='anular')return result.estadoResultado==='ANULADO'&&event.estadoEvento==='CANCELADO';
        return false;
    }
    function showUncertain(){
        $('uncertain-result').hidden=!uncertain;if(!uncertain)return;
        $('uncertain-values').textContent='Operación incierta: '+specs[uncertain.route].name+' · '+uncertain.path+' · Evento '+uncertain.event+' · Resultado '+display(uncertain.result)
            +' · Selección '+display(uncertain.selection)+' · Deporte '+uncertain.sport+' · Liga '+uncertain.league+' · Envío local '+uncertain.at+' · Payload original '+JSON.stringify(uncertain.payload)+' · Motivo: '+uncertain.reason+'. '
            +(evidence()?'El mismo evento y resultado muestran el estado solicitado. Esta evidencia no demuestra causalidad ni identifica al autor del POST. Requiere revisión y confirmación expresas, sin reenvío.'
                :'No hay evidencia suficiente para habilitar escrituras. Consulta el contexto original; si el GET no identifica la operación exacta, requiere conciliación del responsable técnico. Coincidir por texto o resolución no confirma el POST.');
    }
    function sync(){
        const blocked=!readable||sessionBlocked||leaving;
        for(const selector of ['#browse-form','#direct-event-form'])$(selector.slice(1)).querySelectorAll('input,select,button').forEach(n=>n.disabled=blocked||writing||catalogBusy);
        $('load-sports').disabled=blocked||writing||catalogBusy;
        $('refresh-result').disabled=blocked||writing||reading||catalogBusy||!eventId;
        $('detail-id').disabled=blocked||writing||catalogBusy||$('detail-id').options.length<=1;
        $('detail-form').querySelector('button').disabled=blocked||writing||!$('detail-id').value;
        A.syncPages(blocked||writing||catalogBusy);
        for(const [route,f]of forms){
            const access=allowedRole(route);f.parentElement.hidden=!access||route!==active;
            f.querySelector('fieldset').disabled=!ready(route);buttons.get(route).hidden=!access;
            f.querySelector('[type="submit"]').disabled=!ready(route)||route==='registrar'&&!registerArmed;
            buttons.get(route).disabled=writing||reading||catalogBusy||!fresh||Boolean(uncertain)||sessionBlocked;
            buttons.get(route).setAttribute('aria-pressed',String(active===route));
        }
        $('operations-panel').hidden=!writable;$('management-forms').hidden=!writable;
        $('management-forms').setAttribute('aria-busy',String(writing||reading));document.body.dataset.resultsBusy=String(writing||reading||catalogBusy);
        document.querySelectorAll('[data-result-pick]').forEach(b=>b.disabled=!fresh||writing||reading||Boolean(uncertain)||sessionBlocked||leaving);
        $('acknowledge-result').disabled=!evidence()||!allowedRole(uncertain?.route||active);
        $('operation-note').textContent=!writable?'Modo consulta: este rol no puede emitir POST.':!fresh?'Consulta vigente necesaria; los formularios permanecen protegidos.':uncertain?'Todas las nuevas escrituras están bloqueadas por el expediente incierto.':!eligible(active)?'La operación no está disponible en este contexto. '+(active==='oficializar'?officialProblems().join(' · '):active==='registrar'&&event?.simulacion.esSimulado&&!result?'La simulación no tiene texto de resultado registrado por el backend; requiere revisión técnica.':'Revisa estado, modalidad y selección activa.'):active==='registrar'&&!registerArmed?'El registro anterior está confirmado. Para una modificación nueva, edita el formulario y revisa nuevamente la confirmación; una consulta GET no repite ni prepara otro envío.':'El servidor valida las restricciones restantes, incluidas liquidaciones previas.';
        showUncertain();
        renderFlow();
    }
    function values(parent,entries){const dl=node('dl',undefined,'operation-values');for(const [key,value]of entries){dl.append(node('dt',key),node('dd',display(value)));}parent.append(dl);}
    function table(parent,caption,headers,rows){
        const scroll=node('div',undefined,'table-scroll');scroll.tabIndex=0;scroll.setAttribute('role','region');scroll.setAttribute('aria-label',caption);
        const t=node('table'),head=node('thead'),tr=node('tr'),body=node('tbody');t.append(node('caption',caption));for(const h of headers){const th=node('th',h);th.scope='col';tr.append(th);}head.append(tr);t.append(head,body);
        for(const cells of rows){const row=node('tr');for(const cell of cells){const td=node('td');if(cell instanceof Node)td.append(cell);else td.textContent=display(cell);row.append(td);}body.append(row);}scroll.append(t);parent.append(scroll);
    }
    function selectOptions(){
        const select=$('result-selection'),stamp=JSON.stringify((event?.mercados||[]).map(m=>[m.idMercado,m.mercado,m.tipoMercado,m.selecciones.map(s=>[s.idSeleccion,s.seleccion,s.seleccionActiva])]));
        if(document.activeElement!==select&&stamp!==selectionOptionsStamp){
            select.replaceChildren(A.option('','Selecciona una selección convencional activa'));
            for(const m of event?.mercados||[]){const group=node('optgroup');group.label=m.mercado+' · '+m.tipoMercado;for(const s of m.selecciones){const o=A.option(s.idSeleccion,s.seleccion+(s.seleccionActiva?'':' · Inactiva'));o.disabled=m.tipoMercado!=='CONVENCIONAL'||!s.seleccionActiva;group.append(o);}select.append(group);}
            selectionOptionsStamp=stamp;
        }
        if(!pair())selectionId=null;if(document.activeElement!==select)select.value=selectionId===null?'':String(selectionId);
        const outcome=$('selection-outcome'),context=pair()?event.idEvento+':'+result?.idResultado+':'+selectionId:null;
        if(context!==outcomeContext){outcome.value='';forms.get('selecciones/resolver').elements.namedItem('observacion').value='';}outcomeContext=context;
        const allowed=pair()?.m.estadoMercado==='ANULADO'?['ANULADA']:resolutions,nextStamp=allowed.join('|');
        if(document.activeElement!==outcome&&outcomeOptionsStamp!==nextStamp){const old=outcome.value;outcome.replaceChildren(A.option('','Selecciona la resolución'));for(const v of allowed)outcome.append(A.option(v,v));outcome.value=allowed.includes(old)?old:'';outcomeOptionsStamp=nextStamp;}
    }
    function pickSelection(value){
        const next=inputId(value)?Number(value):null,form=forms.get('selecciones/resolver');
        if(next!==selectionId&&(form.elements.namedItem('observacion').value.trim()||$('selection-outcome').value)
            &&!window.confirm('Cambiar de selección descartará la resolución y observación de su borrador actual. ¿Continuar?')){$('result-selection').value=selectionId===null?'':String(selectionId);return false;}
        selectionId=next;selectOptions();return true;
    }
    function renderFlow(){
        const box=$('official-requirements');box.replaceChildren();
        const settled=Boolean(fresh&&result&&(result.estadoResultado==='OFICIAL'&&event?.estadoEvento==='FINALIZADO'||result.estadoResultado==='ANULADO'&&event?.estadoEvento==='CANCELADO'));
        $('selected-settlements').hidden=!settled||role!=='ADMINISTRADOR';
        if(!$('selected-settlements').hidden)$('selected-settlements').href=base+'/administrador/liquidaciones?idEvento='+event.idEvento;
        let next='Selecciona un evento y consulta su resultado oficial.';
        if(event&&!fresh)next='La lectura anterior es histórica. Actualiza el evento antes de decidir otra operación.';
        else if(fresh&&event){
            const pending=[];for(const m of event.mercados)if(m.tipoMercado==='CONVENCIONAL'&&m.estadoMercado!=='ANULADO')for(const s of m.selecciones)if(s.seleccionActiva&&s.resultadoSeleccion===null)pending.push(m.mercado+' · '+s.seleccion);
            const issues=officialProblems();
            if(event.estadoEvento==='EN_VIVO')next='El evento sigue EN_VIVO. Su cierre se gestiona desde Control en vivo; este módulo no cambia ese estado.';
            else if(!result)next=event.simulacion.esSimulado?'No hay resultado preliminar de la simulación: requiere revisión técnica; no se registra uno automáticamente.':'Consulta y registra expresamente el resultado preliminar cuando el evento esté PENDIENTE_RESULTADO.';
            else if(settled)next='Resultado '+result.estadoResultado+' y evento '+event.estadoEvento+' comprobados. La liquidación financiera es independiente; los boletos compuestos pueden seguir pendientes.'+(role==='OPERADOR_EVENTOS'?' Solicita la liquidación a ADMINISTRADOR o CAJERO.':'');
            else if(['OFICIAL','ANULADO'].includes(result.estadoResultado))next='El resultado está '+result.estadoResultado+' y el evento '+event.estadoEvento+'. Revisa la coherencia del contexto oficial antes de continuar; no se habilita la navegación financiera como si la etapa estuviera confirmada.';
            else if(['PENDIENTE','CORREGIDO'].includes(result.estadoResultado))next=pending.length?'Revisa y resuelve individualmente las '+pending.length+' selecciones convencionales activas pendientes.':issues.length?'Revisa los requisitos deportivos antes de oficializar.':'Puedes revisar y confirmar la oficialización. La decisión definitiva pertenece al backend.';
            if(['PENDIENTE','CORREGIDO'].includes(result?.estadoResultado)){
                for(const issue of issues)box.append(node('li',issue));
                for(const name of pending)box.append(node('li','Resolución pendiente: '+name));
                if(!issues.length)box.append(node('li','Requisitos visibles de oficialización completos; no garantizan aceptación SQL.'));
                if(event.mercados.some(m=>m.tipoMercado!=='CONVENCIONAL'))box.append(node('li','MARCADOR_FINAL y PRIMERA_ANOTACION conservan la resolución especializada de SQL.'));
            }
        }
        $('result-next').textContent=next;
    }
    function render(){
        const box=$('detail-results');box.replaceChildren();if(!event)return;
        box.append(node('h3',event.evento));values(box,[['idEvento',event.idEvento],['Deporte',event.deporte],['Liga',event.liga],['Estado del evento',event.estadoEvento],['Simulado',event.simulacion.esSimulado],['Inicio (LocalDateTime del servidor)',dateText(event.fechaInicio)],['Fin (LocalDateTime del servidor)',dateText(event.fechaFin)]]);
        box.append(node('h3','Resultado consultado'));
        if(result)values(box,[['idResultado / idResultadoEvento',result.idResultado],['Estado del resultado',result.estadoResultado],['resultadoTexto',result.resultadoTexto],['observacion',result.observacion],['Fecha de registro (LocalDateTime del servidor)',dateText(result.fechaRegistro)],['Marcador final A',result.marcadorFinalA],['Marcador final B',result.marcadorFinalB],['idIncidenciaPrimeraAnotacion',result.idIncidenciaPrimeraAnotacion]]);
        else box.append(node('p','El evento existe y no tiene resultado registrado.'));
        if(event.simulacion.esSimulado)box.append(node('p','SQL conserva el marcador y puede recalcular el texto. Si ya existe resultado, se utiliza su texto oficial sin construir un marcador en el navegador. Una diferencia con el texto recalculado puede causar rechazo del contrato y requerir conciliación.','integration-note'));
        if(correctionInvalidated)box.append(node('p','Corrección confirmada: las resoluciones de la lectura anterior están invalidadas. Actualiza para consultar nuevas resoluciones oficiales.','warning'));
        for(const m of event.mercados){box.append(node('h3',m.mercado+' · '+m.tipoMercado+' · '+m.estadoMercado));
            const rows=m.selecciones.map(s=>{
                let action=m.tipoMercado==='CONVENCIONAL'?'Sin acción disponible':'Resolución automática por SQL';
                if(m.tipoMercado==='CONVENCIONAL'&&s.seleccionActiva&&writable){const b=node('button',s.resultadoSeleccion===null?'Resolver pendiente':'Revisar resolución');b.type='button';b.dataset.resultPick=String(s.idSeleccion);b.disabled=!fresh||writing||Boolean(uncertain);b.addEventListener('click',()=>{if(!fresh||writing||reading||uncertain||sessionBlocked||!pickSelection(String(s.idSeleccion)))return;active='selecciones/resolver';sync();$('result-selection').focus();});action=b;}
                return [s.idSeleccion,s.seleccion,s.seleccionActiva?'Activa':'Inactiva',correctionInvalidated?'Lectura anterior invalidada':s.resultadoSeleccion,correctionInvalidated?'Actualizar':dateText(s.fechaResolucion),action];
            });table(box,'Selecciones de '+m.mercado,['ID','Selección','Estado','Resolución oficial','Fecha de resolución','Acción'],rows);
        }
        $('result-context').textContent='Evento #'+event.idEvento+' · Deporte #'+event.idDeporte+' · Liga #'+event.idLiga+' · '+(result?'Resultado #'+result.idResultado+' · '+result.estadoResultado:'Sin resultado registrado');
        $('management-selection').textContent=$('result-context').textContent;
        for(const [link,page]of [['selected-event','eventos'],['selected-live','en-vivo'],['selected-markets','mercados']]){$(link).hidden=!writable;$(link).href=base+'/administrador/'+page+'?idEvento='+event.idEvento;}
        selectOptions();
        const registered=forms.get('registrar').elements.namedItem('resultadoTexto');registered.readOnly=event.simulacion.esSimulado;
        if(registered.readOnly)registered.value=result?.resultadoTexto||'';
    }
    function hasDraft(){return [...forms.values()].some(f=>[...f.querySelectorAll('textarea')].some(n=>!n.readOnly&&n.value.trim()));}
    async function load(idValue,expectedResult=null,expected=null){
        if(!readable||writing||sessionBlocked||leaving)return;
        if(!inputId(String(idValue))){status('El ID de evento debe ser un SQL INT positivo, sin exponentes ni decimales.',true);return;}
        const next=String(Number(idValue)),changed=eventId!==next;
        if(reading&&!changed)return;
        if(changed&&eventId&&hasDraft()&&!window.confirm('Cambiar de evento descartará los borradores. La escritura incierta se conservará separada. ¿Continuar?'))return;
        const version=++revision;eventId=next;fresh=false;reading=true;
        if(changed){event=null;result=null;selectionId=null;correctionInvalidated=false;registerArmed=true;selectionOptionsStamp='';outcomeOptionsStamp='';for(const f of forms.values())f.reset();$('detail-results').replaceChildren();$('result-context').textContent='Consultando evento #'+eventId;for(const link of ['selected-event','selected-live','selected-markets','selected-settlements'])$(link).hidden=true;}
        $('direct-event-id').value=eventId;$('reading-status').textContent='Consultando detalle y resultado por evento…';sync();
        try{
            const d=await request('/administrador/eventos/detalle?idEvento='+eventId);if(leaving||version!==revision)return;
            const e=validateDetail(d.evento,next),data=await request(prefix+'por-evento?idEvento='+next);if(leaving||version!==revision)return;
            const r=validateResult(data,e);if(expectedResult!==null&&r?.idResultado!==expectedResult)fail('La lectura posterior no corresponde al resultado confirmado.');
            if(expected&&(expected.state&&r?.estadoResultado!==expected.state||expected.eventState&&e.estadoEvento!==expected.eventState
                ||expected.selection&&!e.mercados.some(m=>m.selecciones.some(s=>s.idSeleccion===expected.selection.id&&s.resultadoSeleccion===expected.selection.value))))fail('El POST está confirmado, pero el detalle no acredita todavía sus estados o resolución. Conserva el DTO y actualiza mediante GET; no repitas el POST.');
            event=e;result=r;fresh=true;correctionInvalidated=false;
            if(changed)active=r&&['PENDIENTE','CORREGIDO'].includes(r.estadoResultado)?officialProblems().length?'selecciones/resolver':'oficializar':'registrar';
            render();$('reading-status').textContent='Lectura oficial actualizada (sin polling automático).';status('Detalle administrativo y resultado consultados.');
        }catch(error){if(leaving||version!==revision)return;fresh=false;if(error.status===403)sessionBlocked=true;report(error);$('reading-status').textContent='Lectura desactualizada; los datos anteriores son históricos. Escrituras bloqueadas.';}
        finally{if(version===revision){reading=false;sync();}}
    }
    function payloadFor(route){
        if(!ready(route))fail('La operación no está habilitada para este rol, estado o contexto vigente.');
        if(route==='registrar'&&!registerArmed)fail('El registro anterior está confirmado. No se repite sin una nueva edición expresa.');
        const p=route==='registrar'?{idEvento:String(event.idEvento)}:{idResultadoEvento:String(result.idResultado)};
        const f=forms.get(route);
        for(const [key,label,max,required]of specs[route].fields){const value=f.elements.namedItem(key).value.trim();if(value.length>max||required&&!value)fail(label+': '+(required?'obligatorio; ':'')+'máximo '+max+' caracteres.');if(value)p[key]=value;}
        if(route==='registrar'&&event.simulacion.esSimulado&&p.resultadoTexto!==result.resultadoTexto)fail('Usa el texto consultado del resultado simulado; no se construye un resultado deportivo local.');
        if(route==='selecciones/resolver'){
            const selected=$('result-selection').value,pairValue=pair(),value=$('selection-outcome').value;
            if(!inputId(selected)||Number(selected)!==selectionId||!pairValue||pairValue.m.tipoMercado!=='CONVENCIONAL'||!pairValue.s.seleccionActiva||!resolutions.includes(value)||pairValue.m.estadoMercado==='ANULADO'&&value!=='ANULADA')fail('Selecciona una resolución permitida para una selección convencional activa del mismo evento.');
            p.idSeleccion=selected;p.resultado=value;
        }
        return p;
    }
    function validateDTO(route,p,r,snapshot){
        const keys=route==='registrar'?['idResultado','idEvento','estadoResultado','resultadoTexto','observacion']:route==='selecciones/resolver'?['idResolucion','idResultadoEvento','idSeleccion','resultado','observacion']:['idResultado','idEvento','estadoResultado','estadoEvento',route==='corregir'?'requiereNuevaResolucion':'sinCambios'];
        if(!object(r)||Object.keys(r).length!==keys.length||keys.some(k=>!Object.hasOwn(r,k)))fail();
        if(route==='selecciones/resolver'){if(!id(r.idResolucion)||r.idResultadoEvento!==snapshot.result||r.idSeleccion!==snapshot.selection||r.resultado!==p.resultado||r.observacion!==(p.observacion||null))fail();return;}
        if(!id(r.idResultado)||r.idEvento!==snapshot.event||snapshot.result!==null&&r.idResultado!==snapshot.result)fail();
        if(route==='registrar'){if(!['PENDIENTE','CORREGIDO'].includes(r.estadoResultado)||r.resultadoTexto!==p.resultadoTexto||r.observacion!==(p.observacion||null))fail();return;}
        const expected={oficializar:['OFICIAL','FINALIZADO'],corregir:['CORREGIDO','PENDIENTE_RESULTADO'],anular:['ANULADO','CANCELADO']}[route];
        if(r.estadoResultado!==expected[0]||r.estadoEvento!==expected[1]||(route==='corregir'?r.requiereNuevaResolucion!==true:typeof r.sinCambios!=='boolean'))fail();
    }
    async function submit(route){
        let p;try{p=payloadFor(route);}catch(error){report(error);return;}
        const impact=route==='oficializar'?'Oficializar aplica reglas deportivas y resoluciones automáticas, propaga resoluciones y finaliza el evento. No paga premios ni liquida boletos.':route==='corregir'?'Corregir elimina resoluciones anteriores, devuelve el evento a PENDIENTE_RESULTADO y exige resolver nuevamente. SQL rechaza si existen boletos liquidados.':route==='anular'?'ANULAR cancela el evento, anula resoluciones y mercados y cierra cuotas; SQL rechaza si existen boletos liquidados. No confirma pagos.':'El servidor valida cada dato y sus condiciones.';
        if(!window.confirm(specs[route].name+' · Evento '+event.idEvento+' ('+event.evento+') · Resultado '+display(result?.idResultado)+' · '+JSON.stringify(p)+'\n'+impact+' ¿Confirmar?'))return;
        if(!ready(route))return;
        const operation={route,path:prefix+route,payload:Object.freeze({...p}),event:event.idEvento,result:result?.idResultado||null,selection:route==='selecciones/resolver'?selectionId:null,sport:event.idDeporte,league:event.idLiga,at:new Date().toLocaleString()};
        writing=true;fresh=false;++revision;$('reading-status').textContent='Lectura suspendida durante la escritura; datos anteriores históricos.';sync();status('Enviando una única solicitud desde JavaScript. Espera la respuesta.');let sent=false;
        try{
            const token=await request('/administrador/seguridad/csrf');if(leaving)return;
            if(typeof token.csrfToken!=='string'||!/^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$/.test(token.csrfToken))fail('No se obtuvo un token CSRF canónico. No se envió el POST.');
            sent=true;const response=await request(operation.path,{method:'POST',headers:{'X-CSRF-Token':token.csrfToken},body:new URLSearchParams(p)});
            validateDTO(route,p,response.resultado,operation);
            const article=node('article');article.append(node('h3',specs[route].name+' · POST confirmado · Evento '+operation.event));values(article,Object.entries(response.resultado));
            const dto=node('details');dto.append(node('summary','Ver DTO oficial recibido'),node('p',JSON.stringify(response.resultado),'live-status'));article.append(dto);
            if(route==='corregir')article.append(node('p','Requiere nueva resolución: las resoluciones anteriores fueron invalidadas por esta corrección. Consulta el estado oficial y vuelve a resolver las selecciones que correspondan.','warning'));
            $('operation-values').append(article);$('operation-result').hidden=false;
            forms.get(route).reset();
            if(route==='registrar')registerArmed=false;
            if(route==='corregir'){correctionInvalidated=true;forms.get('selecciones/resolver').reset();selectionId=null;render();}
            const dtoValue=response.resultado,expected=route==='selecciones/resolver'?{selection:{id:dtoValue.idSeleccion,value:dtoValue.resultado}}:{state:dtoValue.estadoResultado,eventState:dtoValue.estadoEvento};
            writing=false;await load(String(operation.event),route==='selecciones/resolver'?operation.result:dtoValue.idResultado,expected);
            if(!leaving&&eventId===String(operation.event))status(fresh?'POST confirmado. Lectura oficial actualizada.':'POST confirmado; no fue posible actualizar la lectura oficial.',!fresh);
        }catch(error){
            if(sent){uncertain=Object.freeze({...operation,reason:errorText(error)});fresh=false;}
            if(error.status===403){if(sent)denied.add(route);else sessionBlocked=true;}
            if(!sent&&!sessionBlocked)fresh=Boolean(event);
            if(leaving)return;report(error);if(sent)status('Escritura incierta: nuevas escrituras bloqueadas. '+errorText(error),true);
        }finally{writing=false;sync();}
    }
    function buildForms(){
        for(const [route,spec]of Object.entries(specs)){
            const section=node('section',undefined,'panel'),h=node('h2',spec.name),f=node('form',undefined,'management-form live-form'),fieldset=node('fieldset');
            f.dataset.operation=route;fieldset.append(node('legend',spec.name+' · Referencias obtenidas del contexto oficial'));
            if(route==='selecciones/resolver')for(const [key,label]of [['result-selection','Selección del evento'],['selection-outcome','Resolución']]){const l=node('label',label),select=node('select');l.htmlFor=key;select.id=key;select.name=key==='result-selection'?'idSeleccion':'resultado';select.required=true;select.append(A.option('','Selecciona una opción'));l.append(select);fieldset.append(l);}
            for(const [key,label,max,required]of spec.fields){const l=node('label',label),input=node('textarea');input.id='result-'+route.replace('/','-')+'-'+key;input.name=key;input.maxLength=max;input.required=required;input.rows=3;l.htmlFor=input.id;l.append(input);fieldset.append(l);}
            const submitButton=node('button',spec.name,route==='anular'?'critical':'primary');submitButton.type='submit';fieldset.append(submitButton);f.append(fieldset);section.append(h,f);$('management-forms').append(section);forms.set(route,f);
            f.addEventListener('submit',e=>{e.preventDefault();submit(route);});
            if(route==='registrar')for(const name of ['input','change'])f.addEventListener(name,()=>{if(!writing&&!reading){registerArmed=true;sync();}});
            const b=node('button',spec.name);b.type='button';b.addEventListener('click',()=>{if(writing||reading||uncertain||sessionBlocked||!allowedRole(route))return;active=route;sync();});$('management-flow').append(b);buttons.set(route,b);
        }
        $('result-selection').addEventListener('change',()=>{pickSelection($('result-selection').value);sync();});
        for(const key of ['result-selection','selection-outcome'])$(key).addEventListener('blur',()=>{selectOptions();sync();});
    }
    async function sports(){
        if(!readable||writing||catalogBusy||sessionBlocked||leaving)return;catalogBusy=true;sync();
        try{const data=await request('/deportes/exploracion');if(!Array.isArray(data.deportes)||data.cantidad!==data.deportes.length||new Set(data.deportes.map(s=>s.idDeporte)).size!==data.deportes.length||data.deportes.some(s=>!id(s.idDeporte)||!text(s.nombre,150)||typeof s.activo!=='boolean'||typeof s.permiteSimulacion!=='boolean'))fail();const previous=$('browse-sport').value;A.choices($('browse-sport'),data.deportes,'idDeporte','nombre');$('browse-sport').value=previous;status('Deportes consultados. Selecciona filtros o consulta directamente un ID real.');}
        catch(error){fresh=false;if(event)$('reading-status').textContent='Lectura desactualizada tras fallo de consulta. Actualiza el evento antes de escribir.';if(error.status===403)sessionBlocked=true;report(error);}finally{catalogBusy=false;sync();}
    }
    async function list(){
        if(!readable||writing||catalogBusy||sessionBlocked||leaving)return;
        const sport=$('browse-sport').value,filter=$('browse-state').value;if(!inputId(sport)||filter&&!eventStates.includes(filter)){status('Selecciona filtros válidos.',true);return;}
        catalogBusy=true;sync();
        try{const data=await request(A.eventsPath(sport)+(filter?'&estado='+encodeURIComponent(filter):''));if(!Array.isArray(data.eventos)||!Number.isSafeInteger(data.total)||data.total<0||data.eventos.length>data.tamanoPagina||new Set(data.eventos.map(e=>e.idEvento)).size!==data.eventos.length||data.eventos.some(e=>!id(e.idEvento)||e.idDeporte!==Number(sport)||!text(e.evento,200)||!eventStates.includes(e.estadoEvento)||filter&&e.estadoEvento!==filter))fail();A.pageData(data);A.choices($('detail-id'),data.eventos,'idEvento',A.eventLabel);$('browse-results').textContent=data.eventos.length+' eventos en esta página; total de la consulta: '+data.total+'.';}
        catch(error){fresh=false;if(event)$('reading-status').textContent='Lectura desactualizada tras fallo de consulta. Actualiza el evento antes de escribir.';$('detail-id').replaceChildren(A.option('','Consulta no disponible'));if(error.status===403)sessionBlocked=true;report(error);}finally{catalogBusy=false;sync();}
    }
    buildForms();A.eventPagination($('browse-form'));
    $('browse-form').addEventListener('submit',e=>{e.preventDefault();list();});
    for(const key of ['browse-sport','browse-state'])$(key).addEventListener('change',()=>{if(writing||catalogBusy)return;A.resetEvents();$('detail-id').replaceChildren(A.option('','Consulta los eventos con estos filtros'));$('browse-results').textContent='Filtros modificados; consulta nuevamente.';sync();});
    $('load-sports').addEventListener('click',sports);
    $('refresh-result').addEventListener('click',()=>{if(eventId&&!reading)load(eventId);});
    $('detail-form').addEventListener('submit',e=>{e.preventDefault();load($('detail-id').value);});
    $('detail-id').addEventListener('change',()=>{if($('detail-id').value)load($('detail-id').value);});
    $('direct-event-form').addEventListener('submit',e=>{e.preventDefault();load($('direct-event-id').value);});
    $('acknowledge-result').addEventListener('click',()=>{if(!evidence()||!allowedRole(uncertain.route)||leaving)return;if(!window.confirm('Revisé el evento y resultado originales y su estado actual. No demuestra causalidad del POST ni su autor. ¿Levantar el bloqueo sin reenviar?'))return;$('reconciliation-result').hidden=false;$('reconciliation-result').textContent='Revisión manual: '+uncertain.path+' · Evento '+uncertain.event+' · Resultado '+uncertain.result+' · '+JSON.stringify(uncertain.payload)+'. Estado coincidente; causalidad no demostrada.';uncertain=null;sync();});
    window.addEventListener('beforeunload',e=>{if(writing||uncertain){e.preventDefault();e.returnValue='';}});
    window.addEventListener('pagehide',()=>{leaving=true;fresh=false;++revision;});
    sync();if(!readable){status('Este rol no tiene acceso a la vista de resultados.',true);return;}
    const initial=new URLSearchParams(location.search).get('idEvento');
    if(initial!==null&&!inputId(initial))status('La referencia de evento no es válida.',true);
    else sports().then(()=>{if(initial!==null)load(initial);});
})();
