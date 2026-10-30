(() => {
    'use strict';
    const $ = id => document.getElementById(id);
    const page = document.body.dataset.management;
    if (!page) return;
    // ADMIN-05 dispone de un controlador propio; evita registrar dos flujos de mercados.
    if (page === 'mercados') {
        if (window.BetZoneMarkets) window.BetZoneMarkets.init();
        else { const status=document.getElementById('management-status');if(status)status.textContent='No se pudo cargar la administración de mercados. Recarga la página.'; }
        return;
    }
    const base = document.body.dataset.contextPath || '';
    const role = (document.body.dataset.adminRole || '').trim();
    const phase4 = page === 'catalogos' || page === 'eventos';
    const validId = value => /^[0-9]{1,10}$/.test(String(value)) && Number(value)>0 && Number(value)<=2147483647;
    const states = ['BORRADOR','PROGRAMADO','EN_VIVO','SUSPENDIDO','PENDIENTE_RESULTADO','FINALIZADO','CANCELADO'];
    function stamp(value) {
        if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,7})?)?$/.test(value)||value.slice(0,4)==='0000')return null;
        const [y,m,d,h,n,s]=value.match(/\d+/g).map(Number), date=new Date(0);
        date.setUTCFullYear(y,m-1,d);date.setUTCHours(h,n,s||0,0);
        if(date.getUTCFullYear()!==y||date.getUTCMonth()!==m-1||date.getUTCDate()!==d||h>23||n>59||(s||0)>59)return null;
        return value.length===16?value+':00':value.includes('.')?value.replace(/0+$/,'').replace(/\.$/,''):value;
    }
    const sameStamp = (a,b) => stamp(a)!==null && stamp(a)===stamp(b);
    const namedRows = (rows,key) => Array.isArray(rows)&&rows.every(r=>r&&Number.isInteger(r[key])&&validId(r[key])&&typeof r.nombre==='string'&&r.nombre.trim())&&new Set(rows.map(r=>r[key])).size===rows.length;
    let sports4=[], countries4=null, officialEvent4=null, leaving4=false;
    let participantPage4=1, participantTotal4=0, eventParticipantPage4=1, eventParticipantTotal4=0;
    let uncertainChecked4=false, uncertainWrite4=null;
    function verification4(message, checked=false) {
        if(!phase4||!uncertainWrite4)return;
        uncertainChecked4=checked;
        let notice=$('uncertain-verification');
        if(!notice){notice=node('p',undefined,'warning');notice.id='uncertain-verification';notice.setAttribute('role','status');notice.setAttribute('aria-live','polite');$('management-status').after(notice);}
        notice.hidden=false;
        const w=uncertainWrite4;
        notice.textContent='Operación incierta: '+w.route+' · '+w.label+'. '+message+' La lectura describe el estado actual; no demuestra qué solicitud lo produjo. No se reenviará ningún POST automáticamente.';
    }
    function pendingVerification4(){
        verification4(uncertainWrite4?.route.endsWith('/crear')?'La creación no devolvió una identidad confirmada. Coincidir por nombre en un listado no identifica unívocamente el registro creado. El backend no ofrece verificación exacta de esta solicitud: requiere conciliación manual con el responsable y mantiene el bloqueo.':'Resultado todavía sin verificar. Consulta el registro y contexto afectados. Si el contrato no permite comprobarlos exactamente, se requiere conciliación manual con el responsable; los formularios permanecen bloqueados.');
    }
    function captureUncertain4(route,payload){
        const p=Object.fromEntries(payload),participant=catalogParticipants.find(r=>String(r.idParticipante)===p.idParticipante),league=catalogLeagues.find(r=>String(r.idLiga)===p.idLiga);
        uncertainWrite4={route,payload:p,sport:p.idDeporte||String(officialEvent4?.idDeporte||participant?.idDeporte||league?.idDeporte||$('browse-sport').value),
            league:p.idLiga||String(officialEvent4?.idLiga||''),event:p.idEvento||null,
            label:[p.nombre||officialEvent4?.nombre,league?.nombre,participant?.nombre,p.idLiga?'liga #'+p.idLiga:'',p.idParticipante?'participante #'+p.idParticipante:'',p.idEvento?'evento #'+p.idEvento:''].filter(Boolean).join(' · ')};
        pendingVerification4();
    }
    function verifyParticipants4(data,sport,filters){
        const w=uncertainWrite4;if(!uncertain||!w||String(sport)!==w.sport)return;
        const p=w.payload,found=data.participantes.find(row=>String(row.idParticipante)===p.idParticipante);
        if(w.route.startsWith('ligas/participantes/')){
            if(String(filters.idLiga||'')!==w.league){verification4('La consulta no corresponde a la liga afectada. Una exploración de ligas o participantes sin el idLiga correcto no verifica esta relación. Se mantiene el bloqueo.');return;}
            const complete=data.pagina===1&&data.total===data.participantes.length&&!filters.buscar&&!filters.activo;
            if(!found&&!complete){verification4('Participante no visible en esta página o con estos filtros: no permite concluir ausencia de asociación. Consulta sin búsqueda ni filtro de activo; si el catálogo ocupa varias páginas, requiere conciliación manual.');return;}
            const associated=Boolean(found),requested=w.route.endsWith('/asociar');
            verification4((associated?'Asociación activa confirmada para esta liga y participante.':'Ausencia de asociación activa confirmada en la consulta completa de esta liga.')+(associated===requested?' El estado coincide con lo solicitado. Puedes revisar y habilitar manualmente.':' El estado NO coincide con lo solicitado; la operación no queda confirmada. Requiere conciliación manual y mantiene el bloqueo.'),associated===requested);
        }else if(w.route==='participantes/actualizar'){
            if(!found){verification4('El participante afectado no está en esta página. No se ha comprobado su actualización; requiere localizar ese ID o conciliación manual.');return;}
            const matches=found.nombre===p.nombre&&found.idPais===(p.idPais?Number(p.idPais):null)&&String(found.activo)===p.activo;
            verification4(matches?'El participante afectado coincide en nombre, país, activo y deporte con la actualización solicitada. Puedes revisar y habilitar manualmente.':'El participante afectado existe, pero sus campos no coinciden con la actualización solicitada. Requiere conciliación manual; se mantiene el bloqueo.',matches);
        }
    }
    function verifyLeague4(rows,sport){
        const w=uncertainWrite4;if(!uncertain||!w||w.route!=='ligas/actualizar'||String(sport)!==w.sport)return;
        const p=w.payload,found=rows.find(row=>String(row.idLiga)===w.league);
        const matches=found&&found.nombre===p.nombre&&found.idPais===(p.idPais?Number(p.idPais):null)&&String(found.activo)===p.activo;
        verification4(matches?'La liga afectada coincide en nombre, país, activo y deporte con lo solicitado. Puedes revisar y habilitar manualmente.':'No se pudo comprobar la actualización exacta de la liga. La exploración solo devuelve ligas activas y su ausencia no demuestra desactivación. Requiere conciliación manual.',Boolean(matches));
    }
    function verifyEvent4(event){
        const w=uncertainWrite4;if(!uncertain||!w)return;
        if(String(event.idEvento)!==w.event||String(event.idLiga)!==w.league||String(event.idDeporte)!==w.sport){verification4('La consulta corresponde a otro evento o contexto; no verifica la operación afectada. Se mantiene el bloqueo.');return;}
        const p=w.payload;let matches=false;
        if(w.route==='eventos/estado/cambiar')matches=event.estadoEvento===p.nuevoEstado;
        else if(w.route==='eventos/actualizar')matches=event.nombre===p.nombre&&sameStamp(event.fechaInicio,p.fechaInicio)&&(p.fechaFin?sameStamp(event.fechaFin,p.fechaFin):event.fechaFin===null);
        else if(w.route==='eventos/participantes/agregar')matches=event.participantes.some(row=>String(row.idParticipante)===p.idParticipante&&row.ordenParticipante===Number(p.ordenParticipante)&&row.esLocal===(p.esLocal===undefined?null:p.esLocal==='true'));
        verification4(matches?'El detalle administrativo del evento afectado confirma la configuración solicitada. Puedes revisar y habilitar manualmente.':'El detalle del evento afectado no confirma la configuración solicitada. Requiere conciliación manual; se mantiene el bloqueo.',matches);
    }
    const field = (name, label, type = 'text', required = true, extra = {}) => ({ name, label, type, required, ...extra });
    const id = (name, label, required = true) => field(name, label, 'number', required, { min: '1', max: '2147483647', step: '1' });
    const name = (max = 150) => field('nombre', 'Nombre', 'text', true, { maxLength: max });
    const choices = (name, label, options, required = true) => field(name, label, 'select', required, { options });
    const reason = () => field('motivo', 'Motivo (opcional)', 'textarea', false, { maxLength: 250 });
    const country = () => choices('idPais','País (opcional)',[],false);
    const active = () => choices('activo', 'Activo', [['true','Sí'],['false','No']]);
    const date = (name, label, required = true) => field(name, label, 'datetime-local', required, { step: '1', min: '0001-01-01T00:00:00', max: '9999-12-31T23:59:59' });
    const decimal = (name, label) => field(name, label, 'text', false, { maxLength: 32, pattern: '[0-9]+([.][0-9]{1,4})?', inputMode: 'decimal' });
    // Rutas, campos y enumeraciones cerradas del contrato OperacionAdministracionEventos.
    const operations = {
        resultados: [
            ['resultados/registrar', 'Registrar resultado', [id('idEvento','ID real del evento'), field('resultadoTexto','Resultado oficial (texto)','textarea',true,{maxLength:250}), field('observacion','Observación (opcional)','textarea',false,{maxLength:500})]],
            ['resultados/selecciones/resolver', 'Resolver selección', [id('idResultadoEvento','ID real del resultado del evento'), id('idSeleccion','ID real de la selección'), choices('resultado','Resolución oficial',[['','Selecciona la resolución'],'GANADA','PERDIDA','ANULADA']), field('observacion','Observación (opcional)','textarea',false,{maxLength:500})]],
            ['resultados/oficializar', 'Oficializar resultado', [id('idResultadoEvento','ID real del resultado del evento'), field('observacion','Observación (opcional)','textarea',false,{maxLength:500})]],
            ['resultados/corregir', 'Corregir resultado', [id('idResultadoEvento','ID real del resultado del evento'), field('nuevoResultadoTexto','Nuevo resultado oficial','textarea',true,{maxLength:250}), field('motivo','Motivo obligatorio','textarea',true,{maxLength:500})]],
            ['resultados/anular', 'Anular resultado', [id('idResultadoEvento','ID real del resultado del evento'), field('motivo','Motivo obligatorio','textarea',true,{maxLength:500})]]
        ],
        catalogos: [
            ['ligas/crear', 'Registrar liga', [id('idDeporte','ID real del deporte'), name(), country()]],
            ['ligas/actualizar', 'Modificar liga', [id('idLiga','ID real de liga'), name(), country(), active()]],
            ['participantes/crear', 'Registrar participante', [id('idDeporte','ID real del deporte'), name(), choices('tipoParticipante','Tipo de participante',[['EQUIPO','Equipo'],['ATLETA','Atleta']]), country()]],
            ['participantes/actualizar', 'Modificar participante', [id('idParticipante','ID real del participante'), name(), country(), active()]],
            ['ligas/participantes/asociar', 'Asociar participante a liga', [id('idLiga','Liga consultada'), id('idParticipante','Participante consultado')]],
            ['ligas/participantes/desasociar', 'Desasociar participante de liga', [id('idLiga','Liga consultada'), id('idParticipante','Participante asociado')]]
        ],
        eventos: [
            ['eventos/crear', 'Crear evento', [id('idLiga','ID real de liga'), name(200), date('fechaInicio','Inicio (hora del servidor)'), date('fechaFin','Fin (opcional, hora del servidor)',false), choices('esSimulado','Evento simulado',[['false','No'],['true','Sí']]), id('duracionSimulacionSegundos','Duración simulada en segundos (opcional)',false)]],
            ['eventos/actualizar', 'Configurar evento', [id('idEvento','ID real del evento'), name(200), date('fechaInicio','Inicio (hora del servidor)'), date('fechaFin','Fin (opcional; vacío elimina el fin)',false)]],
            ['eventos/participantes/agregar', 'Asociar participante', [id('idEvento','ID real del evento'), id('idParticipante','ID real del participante'), field('ordenParticipante','Orden del participante','number',true,{min:'1',max:'255',step:'1'}), choices('esLocal','Es local (opcional)',[['true','Sí'],['false','No']],false)]],
            ['eventos/estado/cambiar', 'Cambiar estado del evento', [id('idEvento','ID real del evento'), choices('nuevoEstado','Estado solicitado',['BORRADOR','PROGRAMADO','EN_VIVO','SUSPENDIDO','PENDIENTE_RESULTADO','FINALIZADO','CANCELADO']), reason()]]
        ],
        mercados: [
            ['mercados/crear', 'Crear mercado', [id('idEvento','ID real del evento'), name(), field('descripcion','Descripción (opcional)','textarea',false,{maxLength:250}), choices('tipoMercado','Modalidad oficial',['CONVENCIONAL','MARCADOR_FINAL','PRIMERA_ANOTACION'])]],
            ['selecciones/crear', 'Crear selección', [id('idMercado','ID real del mercado'), name(), id('idParticipante','ID real del participante (opcional)',false)]],
            ['cuotas/registrar', 'Registrar cuota', [id('idSeleccion','ID real de la selección'), decimal('valor','Valor (opcional según modalidad)'), decimal('valorResultado','Valor de resultado (opcional según modalidad)')]],
            ['mercados/estado/cambiar', 'Cambiar estado del mercado', [id('idMercado','ID real del mercado'), choices('nuevoEstado','Estado solicitado',['BORRADOR','ABIERTO','SUSPENDIDO','CERRADO','LIQUIDADO','ANULADO']), reason()]]
        ]
    };
    const errors = {400:'Datos no válidos. Revisa los campos; el backend valida la operación.',401:'La sesión expiró. Vuelve a iniciar sesión.',403:'Acceso denegado. Las operaciones requieren ADMINISTRADOR u OPERADOR_EVENTOS.',404:'Recurso no encontrado.',405:'Método no permitido por el servidor.',409:'La operación es incompatible con el estado actual. Consulta los datos antes de reintentar.',500:'El servidor no pudo procesar la operación.',503:'Servicio temporalmente no disponible.'};
    let busy = false, uncertain = false, sessionBlocked = false, resultEventContext = null;
    let resultReady = false, officialResultId = null;
    const eventSelectionIds = new Set();
    let eventWizard = null;
    const connected = page === 'mercados' || page === 'resultados';
    const operationPanels = new Map(), operationButtons = new Map();
    let catalogParticipants=[],catalogLeagues=[],listedEvents=[];
    let connectedEvent = null, selectedMarket = null, selectedSelection = null, manualReferences = false;
    const controllers = new Set();
    const display = value => value == null || value === '' ? '—' : typeof value === 'boolean' ? (value ? 'Sí' : 'No') : String(value);
    function node(tag, text, className) { const el = document.createElement(tag); if (text !== undefined) el.textContent = text; if (className) el.className = className; return el; }
    function status(text, error = false) { $('management-status').textContent = text; $('management-status').dataset.error = String(error); }
    function sync() {
        document.querySelectorAll('#contenido input, #contenido select, #contenido textarea, #contenido button').forEach(el => {
            el.disabled = busy || sessionBlocked || (uncertain && Boolean(el.closest('.management-form')))
                || (page === 'resultados' && Boolean(el.closest('.management-form')) && (!resultReady || !['ADMINISTRADOR','OPERADOR_EVENTOS'].includes(role)))
                || (Boolean(el.closest('.management-form'))&&!['ADMINISTRADOR','OPERADOR_EVENTOS'].includes(role))
                || (el.closest('[data-admin-only]') !== null && role !== 'ADMINISTRADOR');
        });
        document.querySelectorAll('.management-form').forEach(form=>{form.hidden=!['ADMINISTRADOR','OPERADOR_EVENTOS'].includes(role);});
        document.querySelectorAll('.management-form select[data-dependent]').forEach(select=>{select.disabled=select.disabled||select.options.length<2;});
        if($('detail-id'))$('detail-id').disabled=busy||sessionBlocked||$('detail-id').options.length<2;
        $('acknowledge-write').hidden = !uncertain;
        $('management-forms').setAttribute('aria-busy', String(busy));
        window.BetZoneAdmin.syncPages(busy||sessionBlocked);
        if (eventWizard) eventWizard.sync(busy || sessionBlocked || uncertain);
        if(phase4){
            $('acknowledge-write').disabled=busy||sessionBlocked||!uncertainChecked4;
            for(const form of document.querySelectorAll('.management-form')){
                const unavailable=page==='eventos'&&!officialEvent4 || form.dataset.countryBlocked==='true';
                if(unavailable)form.querySelectorAll('button,input,select,textarea').forEach(el=>el.disabled=true);
            }
            if(page==='catalogos'){
                $('participant-prev').disabled=busy||sessionBlocked||participantPage4<=1;
                $('participant-next').disabled=busy||sessionBlocked||participantPage4*Number($('participant-size').value)>=participantTotal4;
            }else{
                $('event-participant-prev').disabled=busy||sessionBlocked||!officialEvent4||eventParticipantPage4<=1;
                $('event-participant-next').disabled=busy||sessionBlocked||!officialEvent4||eventParticipantPage4*100>=eventParticipantTotal4;
            }
        }
    }
    function report(error) {
        if(phase4&&(leaving4||error.cancelledByNavigation))return;
        if(phase4&&uncertain)verification4('La consulta no pudo verificar la operación'+(error.status?' (HTTP '+error.status+')':'')+'. Resultado todavía incierto; se mantiene el bloqueo y requiere reconsulta pertinente o conciliación manual.');
        status(error.status ? errors[error.status] || 'Error al procesar la solicitud.' : error.name === 'AbortError' ? 'Solicitud interrumpida o demasiado lenta. Reintenta manualmente la consulta.' : error instanceof TypeError ? 'No fue posible conectar con el servidor.' : error.message, true);
        if (error.status === 401 || error.status === 403) status('Servidor HTTP '+error.status+' en '+(error.endpoint || 'la operación solicitada')+': '+(error.status===401?errors[401]:'Acceso denegado por el backend. No se modificaron sus permisos.'),true);
        if (error.status === 401) {
            sessionBlocked = true; $('management-login').hidden = false;
        }
    }
    async function api(path, options = {}) {
        if(phase4&&leaving4)throw new DOMException('Navegación','AbortError');
        const data=await window.BetZoneAdmin.request(path, options);
        if(phase4&&leaving4)throw new DOMException('Navegación','AbortError');
        return data;
    }
    async function query(path, consume) {
        if (busy || sessionBlocked) return;
        if(phase4&&uncertain)pendingVerification4();
        busy = true; sync(); status('Consultando información…');
        try { await consume(await api(path));
            status('Consulta completada. Se muestran únicamente los datos devueltos.'); }
        catch (error) { report(error); }
        finally { busy = false; sync(); }
    }
    function link(path, text) { const a = node('a',text); a.href = base + path; return a; }
    function action(text, callback) { const button = node('button',text); button.type = 'button'; button.addEventListener('click', () => { if (!busy && !sessionBlocked) callback(); }); return button; }
    function openOperation(route, focus = false) {
        if (!connected || !operationPanels.has(route)) return;
        for (const [key,panel] of operationPanels) panel.hidden = key !== route;
        for (const [key,button] of operationButtons) button.setAttribute('aria-pressed',String(key === route));
        if (focus) { operationPanels.get(route).scrollIntoView({behavior:'smooth',block:'center'}); operationPanels.get(route).focus(); }
    }
    function selectionMessage() {
        if (!connected) return;
        if(manualReferences){$('management-selection').textContent='Referencias manuales modificadas. Su relación con el evento requiere una nueva consulta; revisa la respuesta oficial de cada operación.';return;}
        const parts = [connectedEvent?.nombre,selectedMarket?.nombre,selectedSelection?.nombre].filter(Boolean);
        $('management-selection').textContent = parts.length ? parts.join(' → ') : 'Selecciona un evento de la tabla; las referencias por ID siguen disponibles en modo avanzado.';
    }
    function useMarket(market) {
        manualReferences=false;
        selectedMarket = {id:market.idMercado,nombre:market.mercado}; selectedSelection = null;
        populate('idSeleccion',market.selecciones||[],'idSeleccion','seleccion');
        document.querySelectorAll('.management-form [name="idMercado"]').forEach(input=>{input.value=String(market.idMercado);});
        const quota = document.querySelector('[data-operation="cuotas/registrar"] [name="idSeleccion"]'); if(quota)quota.value='';
        selectionMessage();
        sync();
    }
    function participantPicker(event) {
        const select=document.querySelector('[data-operation="selecciones/crear"] [name="idParticipante"]');
        if(!select)return;
        window.BetZoneAdmin.choices(select,event.participantes,'idParticipante','participante','Sin participante');
        select.required=false;
    }
    function table(target, caption, headings, rows) {
        const wrap = node('div',undefined,'table-scroll'); const table = node('table'); table.append(node('caption',caption));
        if(phase4){wrap.tabIndex=0;wrap.setAttribute('role','region');wrap.setAttribute('aria-label',caption);}
        const header = node('tr'); headings.forEach(text => { const th = node('th',text); th.scope = 'col'; header.append(th); });
        const thead = node('thead'); thead.append(header); table.append(thead);
        const body = node('tbody');
        if (!rows.length) { const row = node('tr'); const cell = node('td','No hay registros disponibles en esta consulta.'); cell.colSpan = headings.length; row.append(cell); body.append(row); }
        for (const values of rows) { const row = node('tr'); values.forEach(value => { const cell = node('td'); if (value instanceof Node) cell.append(value); else cell.textContent = display(value); row.append(cell); }); body.append(row); }
        table.append(body); wrap.append(table); target.append(wrap);
    }
    function fill(formRoute, values) {
        const form = document.querySelector('[data-operation="'+formRoute+'"]'); if (!form) return;
        openOperation(formRoute);
        if(phase4&&formRoute.endsWith('/actualizar')){
            form.reset();
            form.dataset.loadedId=String(values.idLiga??values.idParticipante??values.idEvento);
            form.dataset.countryBlocked=String(page==='catalogos'&&(!countries4||(values.idPais!=null&&!countries4.some(p=>p.idPais===values.idPais))));
            if(form.dataset.countryBlocked==='true')status('No se puede modificar: el país actual no está en el catálogo disponible. Se conserva el registro; solicita su consulta al backend.',true);
            const context=form.querySelector('[data-record-context]');
            if(context)context.textContent='Deporte: '+((page==='eventos'?officialEvent4?.deporte:$('browse-sport').selectedOptions[0]?.textContent)||'Consulta oficial')+(values.tipoParticipante?' · Tipo: '+values.tipoParticipante:'');
        }
        for (const [key,value] of Object.entries(values)) {
            const control = form.elements.namedItem(key); if (!control) continue;
            if(phase4&&key==='idPais'&&value!=null&&!countries4?.some(p=>p.idPais===value)){control.value='';continue;}
            if(control.tagName==='SELECT'&&value!=null&&![...control.options].some(o=>o.value===String(value)))control.append(window.BetZoneAdmin.option(value,values.nombre||values.nombreEvento||'Registro seleccionado'));
            control.value = value == null ? '' : String(value);
        }
        form.scrollIntoView({behavior:'smooth',block:'center'});
        if(form.dataset.countryBlocked!=='true')status('Datos copiados al formulario. Revisa todos los campos antes de enviar.');
        if(phase4)sync();
    }
    function selectEvent(eventId) {
        if (!Number.isInteger(Number(eventId)) || Number(eventId) < 1 || Number(eventId) > 2147483647) return;
        if(page==='eventos'&&officialEvent4?.idEvento!==Number(eventId)){
            officialEvent4=null;catalogParticipants=[];eventParticipantPage4=1;eventParticipantTotal4=0;
            document.querySelectorAll('.management-form').forEach(form=>{form.reset();delete form.dataset.loadedId;});
            populate('idParticipante',[],'idParticipante','nombre');
            if(!uncertain)$('operation-result').hidden=true;
        }
        if(page === 'mercados' && connectedEvent?.idEvento !== Number(eventId)) {
            document.querySelectorAll('.management-form').forEach(form=>form.reset());
            connectedEvent=null;selectedMarket=null;selectedSelection=null;
            manualReferences=false;
            for(const name of ['idMercado','idSeleccion','idParticipante'])populate(name,[],name,'nombre');
            selectionMessage();
            const picker=$('selection-participant-picker');if(picker)picker.replaceChildren();
        }
        if (page === 'resultados' && resultEventContext !== String(eventId)) {
            document.querySelectorAll('.management-form').forEach(form => form.reset());
            document.querySelectorAll('.management-form [name="idResultadoEvento"]').forEach(input => { input.value = ''; input.readOnly = false; });
            officialResultId = null; resultReady = false; eventSelectionIds.clear();
            $('operation-result').hidden = true; $('operation-values').replaceChildren();
            resultEventContext = String(eventId);
        }
        document.querySelectorAll('.management-form [name="idEvento"]').forEach(input => { input.value = String(eventId); });
        if ($('detail-id')) {if(![...$('detail-id').options].some(o=>o.value===String(eventId)))$('detail-id').append(window.BetZoneAdmin.option(eventId,'Evento seleccionado'));$('detail-id').value=String(eventId);}
        if ($('selected-live')) { $('selected-live').href = base+'/administrador/en-vivo?idEvento='+encodeURIComponent(eventId); $('selected-live').hidden = false; }
        if ($('selected-markets')) { $('selected-markets').href = base+'/administrador/mercados?idEvento='+encodeURIComponent(eventId); $('selected-markets').hidden = false; }
    }
    const labels = {idLiga:'ID de liga',idDeporte:'ID de deporte',idPais:'ID de país',nombre:'Nombre',activo:'Activo',idParticipante:'ID de participante',tipoParticipante:'Tipo de participante',idEvento:'ID de evento',idEstado:'ID de estado',estadoEvento:'Estado del evento',fechaInicio:'Fecha de inicio',fechaFin:'Fecha de fin',idEventoParticipante:'ID de asociación',ordenParticipante:'Orden',esLocal:'Es local',idMercado:'ID de mercado',descripcion:'Descripción',estadoMercado:'Estado del mercado',idSeleccion:'ID de selección',idCuota:'ID de cuota',idCuotaAnterior:'ID de cuota anterior',valor:'Valor oficial',estadoAnterior:'Estado anterior',estadoActual:'Estado actual',sinCambios:'Sin cambios',idResultado:'ID de resultado',estadoResultado:'Estado del resultado',resultadoTexto:'Resultado',observacion:'Observación'};
    function resultValues(target, value) {
        const dl = node('dl',undefined,'operation-values');
        for (const [key,item] of Object.entries(value)) {
            if (item && typeof item === 'object') { const block = node('div'); resultValues(block,item); target.append(block); continue; }
            dl.append(node('dt',labels[key] || key),node('dd',display(item)));
        }
        target.append(dl);
    }
    function resultContextMessage() {
        if (page !== 'resultados') return;
        $('result-context').textContent = !resultReady ? 'Consulta y confirma el detalle del evento antes de operar.'
            : officialResultId ? 'Evento #'+resultEventContext+' · resultado #'+officialResultId+' confirmado por el backend y cargado en los formularios.'
            : 'Evento consultado sin resultado registrado. Puedes registrar su resultado.';
    }
    function confirmResultResponse(route, result, payload) {
        if (!result || typeof result !== 'object' || Array.isArray(result)) throw new Error('Respuesta sin resultado oficial.');
        if (route === 'resultados/selecciones/resolver') {
            if (result.idResultadoEvento !== Number(payload.get('idResultadoEvento')) || result.idSeleccion !== Number(payload.get('idSeleccion')) || !Number.isInteger(result.idResolucion)) throw new Error('La resolución recibida no coincide con la solicitud.');
            // La selección consultada permite asociar la respuesta al evento; un ID manual no demuestra esa relación.
            return eventSelectionIds.has(result.idSeleccion) || String(result.idResultadoEvento) === officialResultId;
        }
        if (result.idEvento !== Number(resultEventContext) || !Number.isInteger(result.idResultado) || result.idResultado <= 0
            || (payload.has('idResultadoEvento') && result.idResultado !== Number(payload.get('idResultadoEvento')))) throw new Error('El resultado recibido no corresponde al evento o resultado solicitado.');
        return true;
    }
    function showResult(result, bindResult = true, route = '') {
        $('operation-values').replaceChildren(); resultValues($('operation-values'),result); $('operation-result').hidden = false;
        if (page === 'resultados') {
            if (result.idEvento) selectEvent(result.idEvento);
            const resultId = result.idResultado ?? result.idResultadoEvento;
            if (bindResult && Number.isInteger(resultId) && resultId > 0) {
                officialResultId = String(resultId);
                document.querySelectorAll('.management-form [name="idResultadoEvento"]').forEach(input => { input.value = officialResultId; input.readOnly = true; });
            }
            resultContextMessage();
            if (result.requiereNuevaResolucion === true) $('operation-values').append(node('p','El servidor indica que se requiere una nueva resolución de selecciones.','warning'));
            $('detail-results').replaceChildren(node('p','La operación cambió datos. Consulta de nuevo el evento para actualizar su estado.','muted'));
        }
        if (result.idEvento) {
            selectEvent(result.idEvento);
            if(role==='ADMINISTRADOR')$('operation-values').append(link('/administrador/liquidaciones?idEvento='+encodeURIComponent(result.idEvento),'Liquidar evento'),document.createTextNode(' · '));
            $('operation-values').append(link('/administrador/eventos?idEvento='+encodeURIComponent(result.idEvento),'Consultar evento'),document.createTextNode(' · '),link('/administrador/en-vivo?idEvento='+encodeURIComponent(result.idEvento),'Abrir control en vivo'));
        }
        if (result.idMercado) document.querySelectorAll('.management-form [name="idMercado"]').forEach(input => {if(![...input.options].some(o=>o.value===String(result.idMercado)))input.append(window.BetZoneAdmin.option(result.idMercado,result.nombre||'Mercado creado'));input.value = String(result.idMercado); });
        if (result.idSeleccion) document.querySelectorAll('.management-form [name="idSeleccion"]').forEach(input => {if(![...input.options].some(o=>o.value===String(result.idSeleccion)))input.append(window.BetZoneAdmin.option(result.idSeleccion,result.nombre||'Selección creada'));input.value = String(result.idSeleccion); });
        if(connected){
            if(route === 'mercados/crear'){populate('idSeleccion',[],'idSeleccion','seleccion');selectedMarket={id:result.idMercado,nombre:result.nombre};selectedSelection=null;openOperation('selecciones/crear');}
            if(route === 'selecciones/crear'){
                selectedSelection={id:result.idSeleccion,nombre:result.nombre};
                const quota=document.querySelector('[data-operation="cuotas/registrar"]');if(quota){quota.elements.valor.value='';quota.elements.valorResultado.value='';}
                openOperation('cuotas/registrar');
            }
            if(route === 'resultados/registrar' || result.requiereNuevaResolucion === true)openOperation('resultados/selecciones/resolver');
            selectionMessage();
        }
    }
    async function participantRows4(sport, pageNumber, size, filters={}) {
        if(!validId(sport)||!validId(pageNumber)||![20,50,100].includes(size))throw new Error('Selecciona un deporte y una página válidos.');
        const data=await api('/administrador/participantes/listar?'+new URLSearchParams({idDeporte:sport,pagina:pageNumber,tamanoPagina:size,...filters}));
        const rows=data.participantes;
        if(data.pagina!==pageNumber||data.tamanoPagina!==size||!Number.isSafeInteger(data.total)||data.total<0||!namedRows(rows,'idParticipante')
            ||rows.length!==Math.min(size,Math.max(0,data.total-(pageNumber-1)*size))
            ||rows.some(p=>p.idDeporte!==Number(sport)||typeof p.activo!=='boolean'||!['EQUIPO','ATLETA'].includes(p.tipoParticipante)||!Object.hasOwn(p,'idPais')||(p.idPais!==null&&(!Number.isInteger(p.idPais)||!validId(p.idPais)))||(filters.activo&&String(p.activo)!==filters.activo)))throw new Error('Página de participantes inconsistente; no se habilitaron referencias.');
        verifyParticipants4(data,sport,filters);
        return data;
    }
    async function catalogParticipants4() {
        catalogParticipants=[];populate('idParticipante',[],'idParticipante','nombre');$('participant-results').replaceChildren();
        const filters={},sport=$('browse-sport').value,search=$('participant-search').value.trim(),size=Number($('participant-size').value);
        if(search.length>150)throw new Error('La búsqueda admite hasta 150 caracteres.');
        if(search)filters.buscar=search;
        if($('participant-active').value)filters.activo=$('participant-active').value;
        if($('participant-league').value){if(!catalogLeagues.some(l=>String(l.idLiga)===$('participant-league').value))throw new Error('Consulta primero esa liga.');filters.idLiga=$('participant-league').value;}
        const data=await participantRows4(sport,participantPage4,size,filters);
        catalogParticipants=data.participantes;participantTotal4=data.total;populate('idParticipante',catalogParticipants,'idParticipante',p=>p.nombre+' · '+p.tipoParticipante);
        $('participant-page').textContent='Página '+participantPage4+' · '+data.total+' participantes · '+catalogParticipants.length+' visibles';
        table($('participant-results'),filters.idLiga?'Participantes asociados a la liga consultada':'Participantes del deporte',['Nombre','Tipo','Activo','Acción'],catalogParticipants.map(p=>[p.nombre,p.tipoParticipante,p.activo,action('Modificar participante',()=>fill('participantes/actualizar',p))]));
    }
    async function consumeLeagues4(data,sport){
        if(Number(data.idDeporte)!==Number(sport)||!namedRows(data.ligas,'idLiga')||data.ligas.some(l=>l.idDeporte!==Number(sport)||l.activo!==true||!Object.hasOwn(l,'idPais')||(l.idPais!==null&&(!Number.isInteger(l.idPais)||!validId(l.idPais)))))throw new Error('Catálogo de ligas inconsistente.');
        catalogLeagues=data.ligas;populate('idLiga',data.ligas,'idLiga','nombre');
        const old=$('participant-league').value;window.BetZoneAdmin.choices($('participant-league'),data.ligas,'idLiga','nombre','Todo el deporte');
        if(data.ligas.some(l=>String(l.idLiga)===old))$('participant-league').value=old;
        const target=$('browse-results');target.replaceChildren();
        table(target,'Ligas del deporte',['Nombre','Activa','Acción'],data.ligas.map(l=>[l.nombre,l.activo,action('Modificar liga',()=>fill('ligas/actualizar',l))]));
        await catalogParticipants4();
        verifyLeague4(data.ligas,sport);
    }
    async function eventParticipants4() {
        if(!officialEvent4)throw new Error('Consulta el detalle administrativo del evento.');
        const context=officialEvent4,search=$('event-participant-search').value.trim();
        if(search.length>150)throw new Error('La búsqueda admite hasta 150 caracteres.');
        catalogParticipants=[];populate('idParticipante',[],'idParticipante','nombre');
        const data=await participantRows4(context.idDeporte,eventParticipantPage4,100,{idLiga:context.idLiga,activo:'true',...(search?{buscar:search}:{})});
        if(officialEvent4!==context)return;
        catalogParticipants=data.participantes;eventParticipantTotal4=data.total;
        populate('idParticipante',catalogParticipants.filter(p=>!context.participantes.some(a=>a.idParticipante===p.idParticipante)),'idParticipante','nombre');
        $('event-participant-page').textContent='Página '+eventParticipantPage4+' · '+data.total+' candidatos activos de la liga';
    }
    function validateOperation4(route,payload,form) {
        if(payload.has('nombre')&&(!payload.get('nombre').trim()||payload.get('nombre').length>(page==='catalogos'?150:200)))throw new Error('Nombre fuera del límite permitido.');
        if(payload.has('motivo')&&payload.get('motivo').length>250)throw new Error('El motivo admite hasta 250 caracteres.');
        if(payload.has('activo')&&!['true','false'].includes(payload.get('activo')))throw new Error('Activo debe ser sí o no.');
        if(payload.has('esLocal')&&!['true','false'].includes(payload.get('esLocal')))throw new Error('Condición local inválida.');
        if(payload.has('tipoParticipante')&&!['EQUIPO','ATLETA'].includes(payload.get('tipoParticipante')))throw new Error('Tipo de participante inválido.');
        for(const [key,value] of payload){
            const input=form.elements.namedItem(key);
            if((key.startsWith('id')||['ordenParticipante','duracionSimulacionSegundos'].includes(key))&&!validId(value))throw new Error('Referencia o entero inválido: '+key);
            if(input?.maxLength>0&&value.length>input.maxLength)throw new Error('Texto demasiado largo: '+key);
            if(input?.tagName==='SELECT'&&![...input.options].some(o=>o.value===value&&!o.disabled))throw new Error('Selecciona una opción consultada: '+key);
            if(key.startsWith('fecha')&&!stamp(value))throw new Error('Fecha inválida.');
        }
        if(payload.has('fechaFin')&&stamp(payload.get('fechaFin'))<=stamp(payload.get('fechaInicio')))throw new Error('El fin debe ser posterior al inicio.');
        if(payload.has('idPais')&&!countries4?.some(p=>String(p.idPais)===payload.get('idPais')))throw new Error('País no consultado.');
        if(page==='catalogos'){
            if((form.elements.namedItem('idPais')&&countries4===null)||form.dataset.countryBlocked==='true')throw new Error('No se pudo comprobar el país; no se enviará la actualización.');
            if(payload.has('idDeporte')&&!sports4.some(s=>String(s.idDeporte)===payload.get('idDeporte')))throw new Error('Consulta el deporte.');
            if(payload.has('idLiga')&&!catalogLeagues.some(l=>String(l.idLiga)===payload.get('idLiga')))throw new Error('Consulta la liga.');
            if(payload.has('idParticipante')&&!catalogParticipants.some(p=>String(p.idParticipante)===payload.get('idParticipante')))throw new Error('Consulta el participante.');
            if(route.endsWith('/actualizar')&&form.dataset.loadedId!==payload.get(payload.has('idLiga')?'idLiga':'idParticipante'))throw new Error('Carga el registro desde su tabla antes de modificarlo.');
            if(route==='ligas/participantes/desasociar'&&$('participant-league').value!==payload.get('idLiga'))throw new Error('Consulta los participantes asociados a esa liga antes de desasociar.');
            if(route==='ligas/participantes/asociar'&&!catalogParticipants.find(p=>String(p.idParticipante)===payload.get('idParticipante'))?.activo)throw new Error('La asociación requiere un participante activo.');
        }else{
            if(!officialEvent4||payload.get('idEvento')!==String(officialEvent4.idEvento))throw new Error('Consulta el detalle de este evento antes de operar.');
            if(route==='eventos/actualizar'&&form.dataset.loadedId!==payload.get('idEvento'))throw new Error('Carga los datos oficiales antes de configurar el evento.');
            if(route==='eventos/actualizar'&&(!['BORRADOR','PROGRAMADO','SUSPENDIDO'].includes(officialEvent4.estadoEvento)||officialEvent4.simulacion?.fechaInicioRealUtc))throw new Error('El estado o inicio real del evento impide modificar su configuración.');
            if(route==='eventos/participantes/agregar'){
                if(officialEvent4.estadoEvento!=='BORRADOR')throw new Error('Solo se pueden asociar participantes a un evento en BORRADOR.');
                const participant=catalogParticipants.find(p=>String(p.idParticipante)===payload.get('idParticipante'));
                if(!participant||!participant.activo||participant.idDeporte!==officialEvent4.idDeporte||Number(payload.get('ordenParticipante'))>255||officialEvent4.participantes.some(p=>p.idParticipante===participant.idParticipante||p.ordenParticipante===Number(payload.get('ordenParticipante'))))throw new Error('Participante u orden inválido o ya asociado.');
            }
            if(route==='eventos/estado/cambiar'&&!states.includes(payload.get('nuevoEstado')))throw new Error('Estado no reconocido.');
        }
    }
    async function confirmOperation4(route,result,payload) {
        const equal=(key)=>result[key]===Number(payload.get(key));
        let valid=false;
        if(route.includes('ligas/participantes/'))valid=equal('idLiga')&&equal('idParticipante')&&result.activo===route.endsWith('/asociar');
        else if(route.startsWith('ligas/')||route.startsWith('participantes/')){
            const league=route.startsWith('ligas/'),key=league?'idLiga':'idParticipante',old=(league?catalogLeagues:catalogParticipants).find(p=>p[key]===Number(payload.get(key)));
            valid=validId(result[key])&&Number.isInteger(result[key])&&result.nombre===payload.get('nombre')&&result.idPais===(payload.has('idPais')?Number(payload.get('idPais')):null)
                &&result.idDeporte===(route.endsWith('/crear')?Number(payload.get('idDeporte')):old?.idDeporte)
                &&result.activo===(route.endsWith('/crear')?true:payload.get('activo')==='true')
                &&(!payload.has(key)||equal(key))&&(league||result.tipoParticipante===(route.endsWith('/crear')?payload.get('tipoParticipante'):old?.tipoParticipante));
        }else if(route==='eventos/actualizar')valid=equal('idEvento')&&result.idLiga===officialEvent4.idLiga&&result.nombre===payload.get('nombre')&&states.includes(result.estadoEvento)&&sameStamp(result.fechaInicio,payload.get('fechaInicio'))&&(payload.has('fechaFin')?sameStamp(result.fechaFin,payload.get('fechaFin')):result.fechaFin===null);
        else if(route==='eventos/participantes/agregar')valid=validId(result.idEventoParticipante)&&Number.isInteger(result.idEventoParticipante)&&equal('idEvento')&&equal('idParticipante')&&equal('ordenParticipante')&&result.esLocal===(payload.has('esLocal')?payload.get('esLocal')==='true':null);
        else if(route==='eventos/estado/cambiar'){
            valid=equal('idEvento')&&states.includes(result.estadoAnterior)&&result.estadoActual===payload.get('nuevoEstado')&&typeof result.sinCambios==='boolean'&&result.sinCambios===(result.estadoAnterior===result.estadoActual);
            // El DAO también expone DTO distintos para inicio/fin simulado y cancelación.
            // Se presentan tal como llegan; no se inventa un estadoAnterior ausente.
            if(!('estadoAnterior' in result)&&!('estadoActual' in result)){
                const requested=payload.get('nuevoEstado');
                const cancellation=requested==='CANCELADO'&&result.estadoEvento==='CANCELADO'&&result.estadoResultado==='ANULADO'&&Number.isInteger(result.idResultado)&&validId(result.idResultado);
                const simulation=Object.keys(result).every(k=>['idEvento','sinCambios','registrado'].includes(k))&&['EN_VIVO','PENDIENTE_RESULTADO'].includes(requested)&&officialEvent4.simulacion.esSimulado===true&&typeof result.sinCambios==='boolean'
                    &&(result.registrado==null||(requested==='PENDIENTE_RESULTADO'&&result.registrado.idEvento===officialEvent4.idEvento&&Number.isInteger(result.registrado.idResultado)&&validId(result.registrado.idResultado)&&['PENDIENTE','CORREGIDO'].includes(result.registrado.estadoResultado)&&typeof result.registrado.resultadoTexto==='string'&&result.registrado.resultadoTexto.trim()));
                if(equal('idEvento')&&typeof result.sinCambios==='boolean'&&(cancellation||simulation)){
                    const detailData=await api('/administrador/eventos/detalle?'+new URLSearchParams({idEvento:payload.get('idEvento')}));
                    if(detailData.evento?.idEvento!==Number(payload.get('idEvento'))||detailData.evento.estadoEvento!==requested)throw new Error('La consulta administrativa no confirma el estado solicitado.');
                    return detailData;
                }
            }
        }
        if(!valid)throw new Error('La respuesta oficial no corresponde a los datos solicitados. Consulta el registro antes de repetir.');
        return null;
    }
    function renderForms() {
        operations[page].forEach(([route,title,fields],index) => {
            if (page === 'eventos' && route === 'eventos/crear' && $('event-wizard')) return;
            const panel = node('section',undefined,'panel'); panel.append(node('h2',title));
            if(connected){
                panel.id='operation-panel-'+index;panel.tabIndex=-1;operationPanels.set(route,panel);
                const button=node('button',title);button.type='button';button.setAttribute('aria-controls',panel.id);button.setAttribute('aria-pressed','false');
                if(route==='resultados/corregir'||route==='resultados/anular')button.dataset.adminOnly='true';
                button.addEventListener('click',()=>{if(!busy&&!sessionBlocked)openOperation(route,true);});
                operationButtons.set(route,button);$('management-flow').append(button);
            }
            const form = node('form',undefined,'live-form management-form'); form.dataset.operation = route; form.action = base+'/administrador/'+route; form.method = 'post';
            if (route === 'resultados/corregir' || route === 'resultados/anular') {
                form.dataset.adminOnly = 'true'; panel.append(node('p','Acción exclusiva de ADMINISTRADOR.','warning'));
            }
            const fieldset = node('fieldset'); fieldset.append(node('legend','Los campos sin indicación de opcional son obligatorios.'));
            if(phase4&&route.endsWith('/actualizar')){const context=node('p','Carga un registro desde su tabla antes de modificarlo.','muted');context.dataset.recordContext='true';form.append(context);}
            let references;
            if(connected){references=node('details',undefined,'advanced-reference');references.append(node('summary','Referencias reales y modo avanzado'));}
            fields.forEach(schema => {
                const label = node('label',({idDeporte:'Deporte',idLiga:'Liga',idParticipante:'Participante',idMercado:'Mercado',idSeleccion:'Selección',idPais:'País (opcional)'}[schema.name]||schema.label)); const input = node(schema.type === 'textarea' ? 'textarea' : schema.type === 'select' ? 'select' : 'input');
                input.id = 'operation-'+index+'-'+schema.name; label.htmlFor = input.id; input.name = schema.name; input.required = schema.required;
                if (schema.type !== 'textarea' && schema.type !== 'select') input.type = schema.type;
                if (schema.type === 'select') {
                    if (!schema.required) { const empty = node('option','Sin especificar'); empty.value = ''; input.append(empty); }
                    schema.options.forEach(option => { const [value,text] = Array.isArray(option) ? option : [option,option]; const el = node('option',text); el.value = value; input.append(el); });
                }
                for (const key of ['min','max','step','maxLength','pattern','inputMode']) if (schema[key] !== undefined) input[key] = schema[key];
                if (schema.type === 'textarea') input.rows = 2;
                if(schema.name.startsWith('id')&&schema.name!=='idPais'){
                    if(schema.name==='idResultadoEvento'||schema.name==='idEvento'){
                        input.type='hidden';label.hidden=true;label.append(input);
                    }else{
                        const select=node('select');select.id=input.id;select.name=input.name;select.required=input.required;select.dataset.dependent='true';
                        select.append(window.BetZoneAdmin.option('','Selecciona primero el contexto'));label.append(select);
                    }
                }else label.append(input);

                if(references && label.hidden)references.append(label);else fieldset.append(label);
                if(connected && schema.name.startsWith('id'))input.addEventListener('input',()=>{manualReferences=true;selectionMessage();});
            });
            if(references)fieldset.append(references);
            if (route === 'cuotas/registrar') fieldset.append(node('small','Punto decimal y hasta cuatro decimales. El backend decide qué valor exige cada modalidad y valida el rango; no se calculan cuotas aquí.'));
            if (route.includes('estado/cambiar')) fieldset.append(node('small','El backend valida la transición. Cambiar estado no sustituye la oficialización de resultados ni la liquidación de apuestas.'));
            if(page==='eventos'&&route==='eventos/estado/cambiar')fieldset.append(node('small','Según el estado y tipo del evento, el backend puede iniciar o finalizar su simulación, o anular resultados al cancelar. Revisa las consecuencias antes de confirmar.'));
            if (route === 'eventos/crear') fieldset.append(node('small','La duración es opcional y la controla el backend. Las fechas se envían sin convertir la zona horaria.'));
            if(route==='ligas/participantes/desasociar')fieldset.append(node('small','Se desactiva la relación con la liga. El participante y sus asociaciones históricas a eventos se conservan.'));
            const submit = node('button',title,'primary'); submit.type = 'submit'; fieldset.append(submit);
            if(references)submit.addEventListener('click',()=>{for(const input of references.querySelectorAll('input'))if(!input.checkValidity()){references.open=true;break;}});
            form.append(fieldset); panel.append(form); $('management-forms').append(panel);
            form.addEventListener('submit', async event => {
                event.preventDefault(); if (busy || uncertain || sessionBlocked||!['ADMINISTRADOR','OPERADOR_EVENTOS'].includes(role)) return;
                if (page === 'resultados' && (!resultReady || !['ADMINISTRADOR','OPERADOR_EVENTOS'].includes(role))) return;
                if (form.dataset.adminOnly && role !== 'ADMINISTRADOR') return;
                const payload = new URLSearchParams();
                for (const schema of fields) {
                    let value = form.elements.namedItem(schema.name).value.trim();
                    if (schema.required && !value) { status('Completa el campo: '+schema.label,true); return; }
                    if (schema.type === 'datetime-local' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) value += ':00';
                    if (value) payload.set(schema.name,value);
                }
                if(phase4){try{validateOperation4(route,payload,form);}catch(error){report(error);return;}}
                const fingerprint = payload.toString();
                if (page === 'resultados' && payload.has('idEvento') && Number(payload.get('idEvento')) !== Number(resultEventContext)) { status('Consulta primero el detalle de ese evento para cambiar el contexto de resultados.',true); return; }
                if (page !== 'resultados' && form.dataset.lastSuccess === fingerprint) { status('Este formulario ya recibió confirmación con los mismos datos. Consulta el resultado antes de crear otra operación.',true); return; }
                const confirmation = page === 'resultados'
                    ? title+' · evento #'+resultEventContext+(payload.has('idResultadoEvento')?' · resultado #'+payload.get('idResultadoEvento'):'')
                        +(payload.has('idResultadoEvento') && !officialResultId ? '. El ID es manual: comprueba que pertenece al evento; no existe una consulta que permita verificarlo antes del envío.' : '')+' ¿Confirmar?'
                    : phase4 ? title+' · '+(payload.get('nombre')||officialEvent4?.nombre||catalogParticipants.find(p=>String(p.idParticipante)===payload.get('idParticipante'))?.nombre||'')+(route.includes('ligas/participantes/')?' · Liga: '+catalogLeagues.find(l=>String(l.idLiga)===payload.get('idLiga'))?.nombre:'')+(payload.has('nuevoEstado')?' · '+officialEvent4.estadoEvento+' → '+payload.get('nuevoEstado'):'')+'. ¿Confirmar?' : title+' con los datos indicados. ¿Confirmar?';
                if (!window.confirm(confirmation)) return;
                busy = true; sync(); status('Enviando operación…'); let sent = false;
                if(!phase4)$('operation-result').hidden = true;
                try {
                    const token = await api('/administrador/seguridad/csrf');
                    if (typeof token.csrfToken !== 'string' || !token.csrfToken || (phase4&&!/^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$/.test(token.csrfToken))) throw new Error('Token CSRF no válido.');
                    sent = true;
                    const data = await api('/administrador/'+route,{method:'POST',headers:{'X-CSRF-Token':token.csrfToken},body:payload});
                    if (!data.resultado || typeof data.resultado !== 'object' || Array.isArray(data.resultado) || !Object.keys(data.resultado).length) throw new Error('Respuesta sin resultado oficial.');
                    const verifiedDetail4=phase4?await confirmOperation4(route,data.resultado,payload):null;
                    const bindResult = page === 'resultados' ? confirmResultResponse(route,data.resultado,payload) : true;
                    form.dataset.lastSuccess = fingerprint;
                    showResult(data.resultado,bindResult,route); status(title+': operación confirmada por el servidor. Actualiza las consultas para ver los datos actuales.');
                    if(page==='eventos'){
                        officialEvent4=null;populate('idParticipante',[],'idParticipante','nombre');
                        try{
                            const detailData=verifiedDetail4||await api('/administrador/eventos/detalle?'+new URLSearchParams({idEvento:payload.get('idEvento')}));
                            if(detailData.evento?.idEvento!==Number(payload.get('idEvento')))throw new Error('El ID del detalle no coincide.');
                            renderDetail(detailData.evento);await eventParticipants4();
                        }catch(error){officialEvent4=null;report(error);status(title+': escritura confirmada; no se pudo actualizar el detalle. Consulta el evento antes de otra operación.',true);}
                    }
                    if(page==='catalogos'){
                        catalogParticipants=[];catalogLeagues=[];participantTotal4=0;
                        for(const key of ['idLiga','idParticipante'])populate(key,[],key,'nombre');
                        document.querySelectorAll('.management-form').forEach(f=>delete f.dataset.loadedId);
                        $('browse-results').replaceChildren(node('p','Operación confirmada. Vuelve a consultar ligas y participantes para actualizar las referencias.'));
                        $('participant-results').replaceChildren();$('participant-page').textContent='Consulta pendiente de actualización';
                        try{
                            const sport=payload.get('idDeporte')||$('browse-sport').value;
                            $('browse-sport').value=sport;participantPage4=1;
                            await consumeLeagues4(await api('/ligas/exploracion?'+new URLSearchParams({idDeporte:sport})),sport);
                        }catch(error){report(error);status(title+': escritura confirmada; no se pudo actualizar la consulta. No repitas la escritura. Vuelve a consultar los catálogos.',true);}
                    }
                } catch (error) {
                    if(phase4&&(leaving4||error.cancelledByNavigation))return;
                    report(error);
                    if (sent && (!error.status || error.status >= 500 || (phase4&&error.status===408))) {
                        uncertain = true;
                        if(phase4)captureUncertain4(route,payload);
                        status('El resultado de la escritura no está confirmado. Consulta los registros antes de repetir; estas operaciones no ofrecen una referencia de idempotencia.',true);
                    }
                } finally { busy = false; sync(); }
            });
        });
        if(connected)openOperation(operations[page][0][0]);
    }
    function renderDetail(event) {
        if(event)event.nombre=event.evento||event.nombre;
        if (!event || !Number.isInteger(event.idEvento) || !Array.isArray(event.participantes) || !Array.isArray(event.mercados)) throw new Error('El detalle no cumple el contrato esperado.');
        if(page==='eventos'&&(!validId(event.idEvento)||!validId(event.idLiga)||!validId(event.idDeporte)||typeof event.nombre!=='string'||!event.nombre.trim()||event.nombre.length>200||!states.includes(event.estadoEvento)||!stamp(event.fechaInicio)||(event.fechaFin!=null&&!stamp(event.fechaFin))||event.cantidadParticipantes!==event.participantes.length||event.cantidadMercados!==event.mercados.length||typeof event.simulacion?.esSimulado!=='boolean'
            ||event.participantes.some(p=>!Number.isInteger(p.idParticipante)||!validId(p.idParticipante)||typeof p.participante!=='string'||!['EQUIPO','ATLETA'].includes(p.tipoParticipante)||!Number.isInteger(p.ordenParticipante)||p.ordenParticipante<1||p.ordenParticipante>255||![true,false,null].includes(p.esLocal))
            ||new Set(event.participantes.map(p=>p.idParticipante)).size!==event.participantes.length||new Set(event.participantes.map(p=>p.ordenParticipante)).size!==event.participantes.length||event.mercados.some(m=>!Array.isArray(m.selecciones))))throw new Error('Detalle administrativo inconsistente. No se habilitaron operaciones.');
        const target = $('detail-results'); target.replaceChildren(); selectEvent(event.idEvento);
        if(page==='eventos'){officialEvent4=event;eventWizard?.observe(event);}
        if(connected){connectedEvent=event;manualReferences=false;selectionMessage();if(page==='mercados')participantPicker(event);}
        target.append(node('h3',display(event.nombre)));
        if($('detail-id')){const choice=[...$('detail-id').options].find(o=>o.value===String(event.idEvento));if(choice)choice.textContent=window.BetZoneAdmin.eventLabel(event);}
        bindEventFields(event);
        resultValues(target,{idEvento:event.idEvento,idLiga:event.idLiga,estadoEvento:event.estadoEvento,fechaInicio:event.fechaInicio,fechaFin:event.fechaFin});
        if (page === 'resultados') resultValues(target,{resultadoTexto:event.resultadoTexto,estadoResultado:event.estadoResultado});
        target.append(node('p','Deporte: '+display(event.deporte)+' · Liga: '+display(event.liga),'muted'));
        if (page !== 'resultados') target.append(link('/administrador/resultados?idEvento='+encodeURIComponent(event.idEvento),'Resultados de este evento'));
        if (page === 'eventos') target.append(action('Cargar datos para configurar este evento',() => fill('eventos/actualizar',{idEvento:event.idEvento,nombre:event.nombre,fechaInicio:event.fechaInicio,fechaFin:event.fechaFin})));
        table(target,'Participantes asociados',['ID','Participante','Tipo','Orden','Local','País'],event.participantes.map(p=>[p.idParticipante,p.participante,p.tipoParticipante,p.ordenParticipante,p.esLocal,p.idPais]));
        for (const market of event.mercados) {
            target.append(node('h3',display(market.mercado)));
            target.append(node('p','Modalidad: '+display(market.tipoMercado)+' · Estado: '+display(market.estadoMercado)+' · '+display(market.descripcionMercado),'muted'));
            if (page === 'mercados') {
                target.append(action('Crear selección en '+market.mercado,()=>{useMarket(market);fill('selecciones/crear',{idMercado:market.idMercado});}),document.createTextNode(' '),action('Cambiar estado de '+market.mercado,()=>{useMarket(market);fill('mercados/estado/cambiar',{idMercado:market.idMercado});}));
            }
            if (!Array.isArray(market.selecciones)) throw new Error('Respuesta de selecciones inválida.');
            table(target,'Selecciones y cuotas disponibles',['Selección','Referencia','Participante','Activa','Cuota ID','Cuota','Valor','Valor resultado','Cuota activa','Acción'],market.selecciones.map(selection=>[
                selection.seleccion,selection.idSeleccion,event.participantes.find(participant=>participant.idParticipante===selection.idParticipante)?.participante || selection.idParticipante,selection.seleccionActiva,selection.idCuota,selection.cuota,selection.valor,selection.valorResultado,selection.cuotaActiva,
                page === 'mercados' ? action('Registrar cuota',()=>{useMarket(market);selectedSelection={id:selection.idSeleccion,nombre:selection.seleccion};selectionMessage();fill('cuotas/registrar',{idSeleccion:selection.idSeleccion,valor:'',valorResultado:''});})
                    : page === 'resultados' ? action('Resolver selección',()=>{manualReferences=false;selectedSelection={id:selection.idSeleccion,nombre:selection.seleccion};selectionMessage();fill('resultados/selecciones/resolver',{idSeleccion:selection.idSeleccion,resultado:''});}) : '—'
            ]));
            if (page === 'resultados') table(target,'Resoluciones devueltas por el servidor',['ID selección','Selección','Resolución oficial','Fecha de resolución'],market.selecciones.map(selection=>[selection.idSeleccion,selection.seleccion,selection.resultadoSeleccion,selection.fechaResolucion]));
        }
        if (!event.mercados.length) target.append(node('p','No hay mercados disponibles en esta consulta.','muted'));
        if (page === 'resultados') {
            eventSelectionIds.clear();
            event.mercados.forEach(market => market.selecciones.forEach(selection => eventSelectionIds.add(selection.idSeleccion)));
            resultReady = true; resultContextMessage();
        }
    }
    function detail(eventId) {
        if (!$('detail-results') || busy || sessionBlocked) return;
        if(page==='eventos'){
            if(!validId(eventId)){status('Selecciona un evento válido.',true);return;}
            selectEvent(eventId);officialEvent4=null;catalogParticipants=[];populate('idParticipante',[],'idParticipante','nombre');
        }
        if(page==='mercados')selectEvent(eventId);
        if(connected && connectedEvent && connectedEvent.idEvento!==Number(eventId)){
            connectedEvent=null;selectedMarket=null;selectedSelection=null;selectionMessage();
            if(page==='mercados')selectEvent(eventId);
        }
        if (page === 'resultados') {
            if (resultEventContext !== null && resultEventContext !== String(eventId)
                && [...document.querySelectorAll('.management-form textarea')].some(input => input.value.trim())
                && !window.confirm('Cambiar de evento descartará los borradores e IDs anteriores. ¿Continuar?')) return;
            selectEvent(eventId); resultReady = false; resultContextMessage();
        }
        $('detail-results').replaceChildren();
        $('selected-live').hidden = true; $('selected-markets').hidden = true;
        query('/administrador/eventos/detalle?idEvento='+encodeURIComponent(eventId),async data=> {
            if (data.evento?.idEvento !== Number(eventId)) throw new Error('El ID devuelto no coincide con la consulta.');
            renderDetail(data.evento);
            if(page==='eventos')verifyEvent4(data.evento);
            if(page==='eventos')await eventParticipants4();
            if(page==='resultados'){
                resultReady=false;const official=await api('/administrador/resultados/por-evento?'+new URLSearchParams({idEvento:eventId}));
                if(official.idEvento!==Number(eventId)||typeof official.tieneResultado!=='boolean')throw new Error('Consulta de resultado inconsistente.');
                officialResultId=official.resultado?String(official.resultado.idResultadoEvento):null;
                document.querySelectorAll('.management-form [name="idResultadoEvento"]').forEach(input=>{input.value=officialResultId||'';});
                $('detail-results').append(node('p',official.resultado?'Resultado: '+official.resultado.resultadoTexto+' · '+official.resultado.estadoResultado:'Este evento todavía no tiene resultado registrado.'));
                resultReady=true;resultContextMessage();
            }
        });
    }
    function populate(name,rows,key,label){
        document.querySelectorAll('.management-form [name="'+name+'"]').forEach(select=>{
            if(select.tagName!=='SELECT')return;const old=select.value;
            window.BetZoneAdmin.choices(select,rows,key,label);if(rows.some(row=>String(row[key])===old))select.value=old;
        });
    }
    function bindEventFields(event){
        populate('idMercado',event.mercados,'idMercado','mercado');
        populate('idSeleccion',event.mercados.flatMap(m=>m.selecciones),'idSeleccion','seleccion');
        if(page==='mercados'){
            // Restaura sólo referencias confirmadas por esta consulta administrativa.
            const market=event.mercados.find(m=>m.idMercado===selectedMarket?.id)
                || (event.mercados.length===1?event.mercados[0]:null);
            selectedMarket=null;selectedSelection=null;
            if(market)useMarket(market);
            else {
                document.querySelectorAll('.management-form [name="idMercado"]').forEach(select=>{select.value='';});
                document.querySelectorAll('.management-form [name="idSeleccion"]').forEach(select=>{select.value='';});
                selectionMessage();
            }
        }
        if(page==='eventos'){
            populate('idParticipante',[], 'idParticipante','nombre');
        }
        document.querySelectorAll('.management-form [name="idMercado"]').forEach(select=>{
            select.onchange=()=>{
                const market=event.mercados.find(m=>String(m.idMercado)===select.value);
                if(market)useMarket(market);
                else if(page==='mercados'){
                    selectedMarket=null;selectedSelection=null;manualReferences=false;
                    document.querySelectorAll('.management-form [name="idMercado"]').forEach(input=>{input.value='';});
                    populate('idSeleccion',event.mercados.flatMap(m=>m.selecciones),'idSeleccion','seleccion');
                    selectionMessage();sync();
                }
            };
        });
        if(page==='mercados')document.querySelectorAll('.management-form [name="idSeleccion"]').forEach(select=>{
            select.onchange=()=>{
                const market=event.mercados.find(m=>(!selectedMarket||m.idMercado===selectedMarket.id)
                    &&m.selecciones.some(s=>String(s.idSeleccion)===select.value));
                const selection=market?.selecciones.find(s=>String(s.idSeleccion)===select.value);
                selectedSelection=null;
                if(selection){useMarket(market);select.value=String(selection.idSeleccion);selectedSelection={id:selection.idSeleccion,nombre:selection.seleccion};}
                selectionMessage();
            };
        });
    }
    async function catalogContext(){
        const sport=$('browse-sport').value;
        if(phase4){
            document.querySelectorAll('.management-form').forEach(form=>{form.reset();delete form.dataset.loadedId;delete form.dataset.countryBlocked;});
            officialEvent4=null;
            if(page==='catalogos'){participantPage4=1;participantTotal4=0;$('participant-results').replaceChildren();$('participant-page').textContent='';window.BetZoneAdmin.choices($('participant-league'),[],'idLiga','nombre','Todo el deporte');}
        }
        catalogParticipants=[];catalogLeagues=[];listedEvents=[];
        for(const name of ['idLiga','idParticipante','idMercado','idSeleccion'])populate(name,[],name,'nombre');
        if($('detail-id')){window.BetZoneAdmin.choices($('detail-id'),[],'idEvento','evento','Primero consulta eventos por deporte');$('detail-results').replaceChildren();}
        document.querySelectorAll('.management-form [name="idEvento"],.management-form [name="idResultadoEvento"]').forEach(input=>{input.value='';});
        connectedEvent=null;selectedMarket=null;selectedSelection=null;resultReady=false;officialResultId=null;
        if(!sport)return;
        populate('idDeporte',[{idDeporte:Number(sport),nombre:$('browse-sport').selectedOptions[0].textContent}],'idDeporte','nombre');
        if(page==='catalogos')await query('/ligas/exploracion?'+new URLSearchParams({idDeporte:sport}),async data=>{
            await consumeLeagues4(data,sport);
        });
        else $('browse-form').requestSubmit();
    }
    renderForms();
    if (page === 'eventos' && $('event-wizard') && window.BetZoneEventWizard) {
        eventWizard = window.BetZoneEventWizard({request:api,base,role,onEvent:selectEvent,onDetail:renderDetail,onError:report,onSport:(id,name) => {
            const sport=$('browse-sport');
            if(sport.value===String(id))return;
            if(validId(id)&&typeof name==='string'&&![...sport.options].some(o=>o.value===String(id)))sport.append(window.BetZoneAdmin.option(id,name));
            sport.value=String(id);window.BetZoneAdmin.resetEvents();
            officialEvent4=null;catalogParticipants=[];catalogLeagues=[];listedEvents=[];eventParticipantPage4=1;eventParticipantTotal4=0;
            document.querySelectorAll('.management-form').forEach(form=>{form.reset();delete form.dataset.loadedId;});
            for(const field of ['idLiga','idParticipante'])populate(field,[],field,'nombre');
            window.BetZoneAdmin.choices($('detail-id'),[],'idEvento','evento');
            $('detail-results').replaceChildren();$('browse-results').replaceChildren();
            $('selected-live').hidden=true;$('selected-markets').hidden=true;
        },run:async work => {
            if (busy || sessionBlocked || uncertain) return;
            busy = true; sync();
            try { await work(); } finally { busy = false; sync(); }
        }});
    }
    if (page === 'resultados') Object.assign(labels,{idResultadoEvento:'ID de resultado del evento',idResolucion:'ID de resolución',resultado:'Resolución',requiereNuevaResolucion:'Requiere nueva resolución'});
    sync();
    if (page === 'resultados' && !['ADMINISTRADOR','OPERADOR_EVENTOS','CAJERO','AUDITOR'].includes(role)) {
        status('No se pudo obtener el rol de la sesión administrativa. Vuelve a iniciar sesión.',true);
        $('management-login').hidden=false;
    }
    document.querySelector('[data-nav="'+page+'"]').setAttribute('aria-current','page');
    $('acknowledge-write').addEventListener('click',()=> { if (!busy && (!phase4||(uncertainChecked4&&!sessionBlocked&&['ADMINISTRADOR','OPERADOR_EVENTOS'].includes(role))) && window.confirm('¿Comprobaste en los registros si la escritura se aplicó? Habilitar no vuelve a enviar ninguna operación.')) { uncertain=false;if(phase4){uncertainWrite4=null;uncertainChecked4=false;if($('uncertain-verification'))$('uncertain-verification').hidden=true;} sync(); status('Formularios habilitados. Revisa los datos antes de enviar.'); } });
    $('load-sports').addEventListener('click',()=> {
        if(phase4&&(busy||sessionBlocked))return;
        $('browse-results').replaceChildren();
        if(phase4){
            sports4=[];catalogParticipants=[];catalogLeagues=[];officialEvent4=null;listedEvents=[];
            for(const name of ['idDeporte','idLiga','idParticipante'])populate(name,[],name,'nombre');
            window.BetZoneAdmin.choices($('browse-sport'),[],'idDeporte','nombre','Selecciona un deporte');
            if(page==='catalogos'){$('participant-results').replaceChildren();window.BetZoneAdmin.choices($('participant-league'),[],'idLiga','nombre','Todo el deporte');}
            else{$('detail-results').replaceChildren();window.BetZoneAdmin.choices($('detail-id'),[],'idEvento','evento');if(!eventWizard)window.BetZoneAdmin.choices($('wizard-recovery-id'),[],'idEvento','evento');}
        }
        query('/deportes/exploracion',data=> {
            if (!Array.isArray(data.deportes)) throw new Error('Respuesta de deportes inválida.');
            if(phase4){
                if(!namedRows(data.deportes,'idDeporte')||data.deportes.some(s=>s.activo!==true||typeof s.permiteSimulacion!=='boolean'))throw new Error('Catálogo de deportes inconsistente.');
                sports4=data.deportes;catalogParticipants=[];catalogLeagues=[];officialEvent4=null;
                document.querySelectorAll('.management-form').forEach(form=>{form.reset();delete form.dataset.loadedId;});
                for(const name of ['idLiga','idParticipante'])populate(name,[],name,'nombre');
            }
            populate('idDeporte',data.deportes,'idDeporte','nombre');
            if($('browse-sport').tagName==='SELECT'){
                const old=$('browse-sport').value;$('browse-sport').replaceChildren();const placeholder=node('option','Selecciona un deporte');placeholder.value='';$('browse-sport').append(placeholder);
                data.deportes.forEach(sport=>{const option=node('option',sport.nombre);option.value=String(sport.idDeporte);$('browse-sport').append(option);});
                if(data.deportes.some(sport=>String(sport.idDeporte)===old))$('browse-sport').value=old;
            }
            table($('browse-results'),'Deportes activos',['ID','Deporte','Acción'],data.deportes.map(sport=>[sport.idDeporte,sport.nombre,action('Usar deporte',()=> {
                $('browse-sport').value=String(sport.idDeporte); document.querySelectorAll('.management-form [name="idDeporte"]').forEach(input=>{input.value=String(sport.idDeporte);}); $('browse-sport').dispatchEvent(new Event('change')); status('Deporte seleccionado.');
            })]));
        });
    });
    $('browse-sport').addEventListener('change',()=>{if(!busy){window.BetZoneAdmin.resetEvents();$('browse-results').replaceChildren();catalogContext();}});
    if($('detail-id'))$('detail-id').addEventListener('change',()=>{if(!busy&&$('detail-id').value)detail($('detail-id').value);});
    document.querySelectorAll('.management-form [name="idLiga"]').forEach(select=>select.addEventListener('change',()=>{if(phase4&&select.form.dataset.operation!=='ligas/actualizar')return;const l=catalogLeagues.find(l=>String(l.idLiga)===select.value);if(l)fill('ligas/actualizar',l);}));
    document.querySelectorAll('.management-form [name="idParticipante"]').forEach(select=>select.addEventListener('change',()=>{if(page==='catalogos'&&select.form.dataset.operation==='participantes/actualizar'){const p=catalogParticipants.find(p=>String(p.idParticipante)===select.value);if(p)fill('participantes/actualizar',p);}}));
    $('browse-form').addEventListener('submit',event=> {
        event.preventDefault(); if (busy) return;
        $('browse-results').replaceChildren();
        if (page === 'catalogos') {catalogContext();return;}
        const eventPath=window.BetZoneAdmin.eventsPath($('browse-sport').value)+(page==='eventos'&&$('event-state-filter').value?'&'+new URLSearchParams({estado:$('event-state-filter').value}):'');
        if(page==='eventos'){officialEvent4=null;$('detail-results').replaceChildren();}
        query(eventPath,data=> {
            if (!Array.isArray(data.eventos)) throw new Error('Respuesta de eventos inválida.');
            if(page==='eventos'&&(new Set(data.eventos.map(e=>e.idEvento)).size!==data.eventos.length||data.eventos.length!==Math.min(100,Math.max(0,data.total-(data.pagina-1)*100))||data.eventos.some(e=>!Number.isInteger(e.idEvento)||!validId(e.idEvento)||!validId(e.idLiga)||typeof e.evento!=='string'||!e.evento.trim()||!stamp(e.fechaInicio)||!states.includes(e.estadoEvento)||e.idDeporte!==Number($('browse-sport').value)||($('event-state-filter').value&&e.estadoEvento!==$('event-state-filter').value))))throw new Error('Listado administrativo inconsistente.');
            window.BetZoneAdmin.pageData(data);listedEvents=data.eventos;
            if($('wizard-recovery-id')&&!eventWizard)window.BetZoneAdmin.choices($('wizard-recovery-id'),data.eventos,'idEvento',window.BetZoneAdmin.eventLabel);
            window.BetZoneAdmin.choices($('detail-id'),data.eventos,'idEvento',window.BetZoneAdmin.eventLabel);
            if(!data.eventos.length)status('No hay eventos disponibles en esta consulta.');
            table($('browse-results'),'Eventos administrativos de esta página',['Evento','Liga','Estado','Referencia','Acción'],data.eventos.map(event=>[event.evento,event.liga,event.estadoEvento,event.idEvento,action('Abrir evento',()=>detail(event.idEvento))]));
        });
    });
    if ($('detail-form')) $('detail-form').addEventListener('submit',event=>{event.preventDefault(); if (!busy) detail($('detail-id').value);});
    if (page === 'resultados') $('detail-id').addEventListener('input', () => {
        if (resultEventContext !== null && Number($('detail-id').value) !== Number(resultEventContext)) {
            resultReady = false; $('detail-results').replaceChildren(); $('operation-result').hidden = true;
            officialResultId = null; eventSelectionIds.clear();
            document.querySelectorAll('.management-form [name="idResultadoEvento"], .management-form [name="idSeleccion"]').forEach(input => { input.value = ''; input.readOnly = false; });
            $('selected-live').hidden = true; $('selected-markets').hidden = true; resultContextMessage(); sync();
        }
    });
    window.addEventListener('pagehide',()=>{controllers.forEach(controller=>controller.abort());});
    if(phase4)window.addEventListener('pagehide',()=>{leaving4=true;});
    if(phase4)$('contenido').addEventListener('input',event=>{
        if(uncertain&&(event.target.closest('#browse-form,#participant-query,#detail-form,#event-participant-query')||event.target.id==='event-state-filter')){pendingVerification4();sync();}
    });
    if(page==='catalogos'){
        $('participant-query').addEventListener('submit',event=>{event.preventDefault();if(busy||sessionBlocked)return;participantPage4=1;queryParticipants4();});
        for(const [id,delta] of [['participant-prev',-1],['participant-next',1]])$(id).addEventListener('click',()=>{if(!$(id).disabled){participantPage4+=delta;queryParticipants4();}});
        for(const id of ['participant-search','participant-active','participant-league','participant-size'])$(id).addEventListener('input',()=>{catalogParticipants=[];participantTotal4=0;participantPage4=1;populate('idParticipante',[],'idParticipante','nombre');$('participant-results').replaceChildren();sync();});
    }
    async function runQuery4(work){
        if(busy||sessionBlocked)return;if(uncertain)pendingVerification4();busy=true;sync();status('Consultando participantes…');
        try{await work();status('Página consultada. Se muestran únicamente los datos devueltos.');}catch(error){report(error);}finally{busy=false;sync();}
    }
    function queryParticipants4(){return runQuery4(catalogParticipants4);}
    if(page==='eventos'){
        $('event-state-filter').addEventListener('change',()=>{if(!busy){window.BetZoneAdmin.resetEvents();$('browse-form').requestSubmit();}});
        $('event-participant-query').addEventListener('submit',event=>{event.preventDefault();if(!busy){eventParticipantPage4=1;runQuery4(eventParticipants4);}});
        for(const [id,delta] of [['event-participant-prev',-1],['event-participant-next',1]])$(id).addEventListener('click',()=>{if(!$(id).disabled){eventParticipantPage4+=delta;runQuery4(eventParticipants4);}});
        $('event-participant-search').addEventListener('input',()=>{catalogParticipants=[];eventParticipantTotal4=0;populate('idParticipante',[],'idParticipante','nombre');sync();});
    }
    if(page!=='catalogos')window.BetZoneAdmin.eventPagination($('browse-form'));
    if(page==='catalogos')api('/administrador/catalogos/paises').then(data=>{
        if(!namedRows(data.paises,'idPais'))throw new Error('Catálogo de países inválido.');
        countries4=data.paises;
        populate('idPais',data.paises,'idPais','nombre');sync();
    }).catch(report);
    const initial = new URLSearchParams(location.search).get('idEvento');
    if(page==='eventos'&&eventWizard){
        if(initial!==null&&!validId(initial))status('Referencia de evento inválida. No se cargó otro evento.',true);
        else eventWizard.refresh(initial===null?undefined:initial);
    }else if ($('detail-form') && initial && /^[0-9]+$/.test(initial) && Number(initial)>0 && Number(initial)<=2147483647) { $('detail-id').value=initial; detail(initial); }
    else if (eventWizard) eventWizard.loadSports().then(()=>$('load-sports').click());
    else $('load-sports').click();
})();

