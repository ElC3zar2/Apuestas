(() => {
    'use strict';
    const $ = id => document.getElementById(id);
    const page = document.body.dataset.management;
    if (!page) return;
    const base = document.body.dataset.contextPath || '';
    const role = (document.body.dataset.adminRole || '').trim();
    const field = (name, label, type = 'text', required = true, extra = {}) => ({ name, label, type, required, ...extra });
    const id = (name, label, required = true) => field(name, label, 'number', required, { min: '1', max: '2147483647', step: '1' });
    const name = (max = 150) => field('nombre', 'Nombre', 'text', true, { maxLength: max });
    const choices = (name, label, options, required = true) => field(name, label, 'select', required, { options });
    const reason = () => field('motivo', 'Motivo (opcional)', 'textarea', false, { maxLength: 250 });
    const country = () => id('idPais', 'ID real del país (opcional)', false);
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
            ['participantes/crear', 'Registrar participante', [id('idDeporte','ID real del deporte'), name(), choices('tipoParticipante','Tipo de participante',['EQUIPO','ATLETA']), country()]],
            ['participantes/actualizar', 'Modificar participante', [id('idParticipante','ID real del participante'), name(), country(), active()]]
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
    const controllers = new Set();
    const display = value => value == null || value === '' ? '—' : typeof value === 'boolean' ? (value ? 'Sí' : 'No') : String(value);
    function node(tag, text, className) { const el = document.createElement(tag); if (text !== undefined) el.textContent = text; if (className) el.className = className; return el; }
    function status(text, error = false) { $('management-status').textContent = text; $('management-status').dataset.error = String(error); }
    function sync() {
        document.querySelectorAll('#contenido input, #contenido select, #contenido textarea, #contenido button').forEach(el => {
            el.disabled = busy || sessionBlocked || (uncertain && Boolean(el.closest('.management-form')))
                || (page === 'resultados' && Boolean(el.closest('.management-form')) && (!resultReady || !['ADMINISTRADOR','OPERADOR_EVENTOS'].includes(role)))
                || (el.closest('[data-admin-only]') !== null && role !== 'ADMINISTRADOR');
        });
        $('acknowledge-write').hidden = !uncertain;
        $('management-forms').setAttribute('aria-busy', String(busy));
        if (eventWizard) eventWizard.sync(busy || sessionBlocked || uncertain);
    }
    function report(error) {
        status(error.status ? errors[error.status] || 'Error al procesar la solicitud.' : error.name === 'AbortError' ? 'Solicitud interrumpida o demasiado lenta. Reintenta manualmente la consulta.' : error instanceof TypeError ? 'No fue posible conectar con el servidor.' : error.message, true);
        if (error.status === 401 || error.status === 403) status('Servidor HTTP '+error.status+' en '+(error.endpoint || 'la operación solicitada')+': '+(error.status===401?errors[401]:'Acceso denegado por el backend. No se modificaron sus permisos.'),true);
        if (error.status === 401 || (error.status === 403 && page !== 'resultados')) {
            sessionBlocked = true; $('management-login').hidden = false;
        }
    }
    async function api(path, options = {}) {
        const controller = new AbortController(); controllers.add(controller);
        const timer = setTimeout(() => controller.abort(), 15000);
        try {
            const response = await fetch(base + path, {credentials:'same-origin',cache:'no-store',...options,headers:{Accept:'application/json',...options.headers},signal:controller.signal});
            if (response.redirected) { const error = new Error(); error.status = 401; error.endpoint = path.split('?')[0]; throw error; }
            if (!response.ok) { const error = new Error(); error.status = response.status; error.endpoint = path.split('?')[0]; throw error; }
            const raw = await response.text();
            if (!raw.trim()) throw new Error('El servidor devolvió una respuesta vacía.');
            let data;
            try { data = JSON.parse(raw); } catch { throw new Error('El servidor devolvió JSON inválido.'); }
            if (!data || data.ok !== true) throw new Error('La respuesta no confirma la operación.');
            return data;
        } finally { clearTimeout(timer); controllers.delete(controller); }
    }
    async function query(path, consume) {
        if (busy || sessionBlocked) return;
        busy = true; sync(); status('Consultando información…');
        try { consume(await api(path)); status('Consulta completada. Se muestran únicamente los datos devueltos.'); }
        catch (error) { report(error); }
        finally { busy = false; sync(); }
    }
    function link(path, text) { const a = node('a',text); a.href = base + path; return a; }
    function action(text, callback) { const button = node('button',text); button.type = 'button'; button.addEventListener('click', () => { if (!busy && !sessionBlocked) callback(); }); return button; }
    function table(target, caption, headings, rows) {
        const wrap = node('div',undefined,'table-scroll'); const table = node('table'); table.append(node('caption',caption));
        const header = node('tr'); headings.forEach(text => { const th = node('th',text); th.scope = 'col'; header.append(th); });
        const thead = node('thead'); thead.append(header); table.append(thead);
        const body = node('tbody');
        if (!rows.length) { const row = node('tr'); const cell = node('td','No hay registros disponibles en esta consulta.'); cell.colSpan = headings.length; row.append(cell); body.append(row); }
        for (const values of rows) { const row = node('tr'); values.forEach(value => { const cell = node('td'); if (value instanceof Node) cell.append(value); else cell.textContent = display(value); row.append(cell); }); body.append(row); }
        table.append(body); wrap.append(table); target.append(wrap);
    }
    function fill(formRoute, values) {
        const form = document.querySelector('[data-operation="'+formRoute+'"]'); if (!form) return;
        for (const [key,value] of Object.entries(values)) {
            const control = form.elements.namedItem(key); if (!control) continue;
            control.value = value == null ? '' : String(value);
        }
        form.scrollIntoView({behavior:'smooth',block:'center'});
        status('Datos copiados al formulario. Revisa todos los campos antes de enviar.');
    }
    function selectEvent(eventId) {
        if (!Number.isInteger(Number(eventId)) || Number(eventId) < 1 || Number(eventId) > 2147483647) return;
        if (page === 'resultados' && resultEventContext !== String(eventId)) {
            document.querySelectorAll('.management-form').forEach(form => form.reset());
            document.querySelectorAll('.management-form [name="idResultadoEvento"]').forEach(input => { input.value = ''; input.readOnly = false; });
            officialResultId = null; resultReady = false; eventSelectionIds.clear();
            $('operation-result').hidden = true; $('operation-values').replaceChildren();
            resultEventContext = String(eventId);
        }
        document.querySelectorAll('.management-form [name="idEvento"]').forEach(input => { input.value = String(eventId); });
        if ($('detail-id')) $('detail-id').value = String(eventId);
        if ($('selected-live')) { $('selected-live').href = base+'/administrador/en-vivo.jsp?idEvento='+encodeURIComponent(eventId); $('selected-live').hidden = false; }
        if ($('selected-markets')) { $('selected-markets').href = base+'/administrador/mercados.jsp?idEvento='+encodeURIComponent(eventId); $('selected-markets').hidden = false; }
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
            : 'Evento #'+resultEventContext+' consultado. Registra un resultado para reutilizar su ID, o introduce el ID real de un resultado anterior. La consulta disponible no proporciona ese ID.';
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
    function showResult(result, bindResult = true) {
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
            $('operation-values').append(link('/administrador/eventos.jsp?idEvento='+encodeURIComponent(result.idEvento),'Consultar evento'),document.createTextNode(' · '),link('/administrador/en-vivo.jsp?idEvento='+encodeURIComponent(result.idEvento),'Abrir control en vivo'));
        }
        if (result.idMercado) document.querySelectorAll('.management-form [name="idMercado"]').forEach(input => { input.value = String(result.idMercado); });
        if (result.idSeleccion) document.querySelectorAll('.management-form [name="idSeleccion"]').forEach(input => { input.value = String(result.idSeleccion); });
    }
    function renderForms() {
        operations[page].forEach(([route,title,fields],index) => {
            if (page === 'eventos' && route === 'eventos/crear' && $('event-wizard')) return;
            const panel = node('section',undefined,'panel'); panel.append(node('h2',title));
            const form = node('form',undefined,'live-form management-form'); form.dataset.operation = route; form.action = base+'/administrador/'+route; form.method = 'post';
            if (route === 'resultados/corregir' || route === 'resultados/anular') {
                form.dataset.adminOnly = 'true'; panel.append(node('p','Acción exclusiva de ADMINISTRADOR.','warning'));
            }
            const fieldset = node('fieldset'); fieldset.append(node('legend','Los campos sin indicación de opcional son obligatorios.'));
            fields.forEach(schema => {
                const label = node('label',schema.label); const input = node(schema.type === 'textarea' ? 'textarea' : schema.type === 'select' ? 'select' : 'input');
                input.id = 'operation-'+index+'-'+schema.name; label.htmlFor = input.id; input.name = schema.name; input.required = schema.required;
                if (schema.type !== 'textarea' && schema.type !== 'select') input.type = schema.type;
                if (schema.type === 'select') {
                    if (!schema.required) { const empty = node('option','Sin especificar'); empty.value = ''; input.append(empty); }
                    schema.options.forEach(option => { const [value,text] = Array.isArray(option) ? option : [option,option]; const el = node('option',text); el.value = value; input.append(el); });
                }
                for (const key of ['min','max','step','maxLength','pattern','inputMode']) if (schema[key] !== undefined) input[key] = schema[key];
                if (schema.type === 'textarea') input.rows = 2;
                label.append(input); fieldset.append(label);
            });
            if (route === 'cuotas/registrar') fieldset.append(node('small','Punto decimal y hasta cuatro decimales. El backend decide qué valor exige cada modalidad y valida el rango; no se calculan cuotas aquí.'));
            if (route.includes('estado/cambiar')) fieldset.append(node('small','El backend valida la transición. Cambiar estado no sustituye la oficialización de resultados ni la liquidación de apuestas.'));
            if (route === 'eventos/crear') fieldset.append(node('small','La duración es opcional y la controla el backend. Las fechas se envían sin convertir la zona horaria.'));
            const submit = node('button',title,'primary'); submit.type = 'submit'; fieldset.append(submit);
            form.append(fieldset); panel.append(form); $('management-forms').append(panel);
            form.addEventListener('submit', async event => {
                event.preventDefault(); if (busy || uncertain || sessionBlocked) return;
                if (page === 'resultados' && (!resultReady || !['ADMINISTRADOR','OPERADOR_EVENTOS'].includes(role))) return;
                if (form.dataset.adminOnly && role !== 'ADMINISTRADOR') return;
                const payload = new URLSearchParams();
                for (const schema of fields) {
                    let value = form.elements.namedItem(schema.name).value.trim();
                    if (schema.required && !value) { status('Completa el campo: '+schema.label,true); return; }
                    if (schema.type === 'datetime-local' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) value += ':00';
                    if (value) payload.set(schema.name,value);
                }
                const fingerprint = payload.toString();
                if (page === 'resultados' && payload.has('idEvento') && Number(payload.get('idEvento')) !== Number(resultEventContext)) { status('Consulta primero el detalle de ese evento para cambiar el contexto de resultados.',true); return; }
                if (page !== 'resultados' && form.dataset.lastSuccess === fingerprint) { status('Este formulario ya recibió confirmación con los mismos datos. Consulta el resultado antes de crear otra operación.',true); return; }
                const confirmation = page === 'resultados'
                    ? title+' · evento #'+resultEventContext+(payload.has('idResultadoEvento')?' · resultado #'+payload.get('idResultadoEvento'):'')
                        +(payload.has('idResultadoEvento') && !officialResultId ? '. El ID es manual: comprueba que pertenece al evento; no existe una consulta que permita verificarlo antes del envío.' : '')+' ¿Confirmar?'
                    : title+' con los datos indicados. ¿Confirmar?';
                if (!window.confirm(confirmation)) return;
                busy = true; sync(); status('Enviando operación…'); let sent = false;
                $('operation-result').hidden = true;
                try {
                    const token = await api('/administrador/seguridad/csrf');
                    if (typeof token.csrfToken !== 'string' || !token.csrfToken) throw new Error('Token CSRF no válido.');
                    sent = true;
                    const data = await api('/administrador/'+route,{method:'POST',headers:{'X-CSRF-Token':token.csrfToken},body:payload});
                    if (!data.resultado || typeof data.resultado !== 'object' || Array.isArray(data.resultado) || !Object.keys(data.resultado).length) throw new Error('Respuesta sin resultado oficial.');
                    const bindResult = page === 'resultados' ? confirmResultResponse(route,data.resultado,payload) : true;
                    form.dataset.lastSuccess = fingerprint;
                    showResult(data.resultado,bindResult); status(title+': operación confirmada por el servidor. Actualiza las consultas para ver los datos actuales.');
                } catch (error) {
                    report(error);
                    if (sent && (!error.status || error.status >= 500)) {
                        uncertain = true;
                        status('El resultado de la escritura no está confirmado. Consulta los registros antes de repetir; estas operaciones no ofrecen una referencia de idempotencia.',true);
                    }
                } finally { busy = false; sync(); }
            });
        });
    }
    function renderDetail(event) {
        if (!event || !Number.isInteger(event.idEvento) || !Array.isArray(event.participantes) || !Array.isArray(event.mercados)) throw new Error('El detalle no cumple el contrato esperado.');
        const target = $('detail-results'); target.replaceChildren(); selectEvent(event.idEvento);
        target.append(node('h3',display(event.nombre)));
        resultValues(target,{idEvento:event.idEvento,idLiga:event.idLiga,estadoEvento:event.estadoEvento,fechaInicio:event.fechaInicio,fechaFin:event.fechaFin});
        if (page === 'resultados') resultValues(target,{resultadoTexto:event.resultadoTexto,estadoResultado:event.estadoResultado});
        target.append(node('p','Deporte: '+display(event.deporte)+' · Liga: '+display(event.liga),'muted'));
        if (page !== 'resultados') target.append(link('/administrador/resultados.jsp?idEvento='+encodeURIComponent(event.idEvento),'Resultados de este evento'));
        if (page === 'eventos') target.append(action('Cargar datos para configurar este evento',() => fill('eventos/actualizar',{idEvento:event.idEvento,nombre:event.nombre,fechaInicio:event.fechaInicio,fechaFin:event.fechaFin})));
        table(target,'Participantes asociados',['ID','Participante','Tipo','Orden','Local','País'],event.participantes.map(p=>[p.idParticipante,p.participante,p.tipoParticipante,p.ordenParticipante,p.esLocal,p.idPais]));
        for (const market of event.mercados) {
            target.append(node('h3','#'+display(market.idMercado)+' · '+display(market.mercado)));
            target.append(node('p','Modalidad: '+display(market.tipoMercado)+' · Estado: '+display(market.estadoMercado)+' · '+display(market.descripcionMercado),'muted'));
            if (page === 'mercados') target.append(action('Usar ID de este mercado',() => {
                document.querySelectorAll('.management-form [name="idMercado"]').forEach(input => {input.value=String(market.idMercado);}); status('ID de mercado seleccionado.');
            }));
            if (!Array.isArray(market.selecciones)) throw new Error('Respuesta de selecciones inválida.');
            table(target,'Selecciones y cuotas disponibles',['ID selección','Selección','Participante ID','Activa','Cuota ID','Cuota','Valor','Valor resultado','Cuota activa','Acción'],market.selecciones.map(selection=>[
                selection.idSeleccion,selection.seleccion,selection.idParticipante,selection.seleccionActiva,selection.idCuota,selection.cuota,selection.valor,selection.valorResultado,selection.cuotaActiva,
                page === 'mercados' ? action('Usar selección',()=>fill('cuotas/registrar',{idSeleccion:selection.idSeleccion,valor:'',valorResultado:''}))
                    : page === 'resultados' ? action('Resolver selección',()=>fill('resultados/selecciones/resolver',{idSeleccion:selection.idSeleccion,resultado:''})) : '—'
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
        if (page === 'resultados') {
            if (resultEventContext !== null && resultEventContext !== String(eventId)
                && [...document.querySelectorAll('.management-form textarea')].some(input => input.value.trim())
                && !window.confirm('Cambiar de evento descartará los borradores e IDs anteriores. ¿Continuar?')) return;
            selectEvent(eventId); resultReady = false; resultContextMessage();
        }
        $('detail-results').replaceChildren();
        $('selected-live').hidden = true; $('selected-markets').hidden = true;
        query('/eventos/exploracion/detalle?idEvento='+encodeURIComponent(eventId),data=> {
            if (data.evento?.idEvento !== Number(eventId)) throw new Error('El ID devuelto no coincide con la consulta.');
            renderDetail(data.evento);
        });
    }
    renderForms();
    if (page === 'eventos' && $('event-wizard') && window.BetZoneEventWizard) {
        eventWizard = window.BetZoneEventWizard({request:api,base,role,onEvent:selectEvent,onError:report,onSport:id => { $('browse-sport').value=String(id); },run:async work => {
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
    $('acknowledge-write').addEventListener('click',()=> { if (!busy && window.confirm('¿Comprobaste en los registros si la escritura se aplicó? Habilitar no vuelve a enviar ninguna operación.')) { uncertain=false; sync(); status('Formularios habilitados. Revisa los datos antes de enviar.'); } });
    $('load-sports').addEventListener('click',()=> {
        $('browse-results').replaceChildren();
        query('/deportes/exploracion',data=> {
            if (!Array.isArray(data.deportes)) throw new Error('Respuesta de deportes inválida.');
            table($('browse-results'),'Deportes activos',['ID','Deporte','Acción'],data.deportes.map(sport=>[sport.idDeporte,sport.nombre,action('Usar deporte',()=> {
                $('browse-sport').value=String(sport.idDeporte); document.querySelectorAll('.management-form [name="idDeporte"]').forEach(input=>{input.value=String(sport.idDeporte);}); status('ID de deporte seleccionado.');
            })]));
        });
    });
    $('browse-form').addEventListener('submit',event=> {
        event.preventDefault(); if (busy) return;
        $('browse-results').replaceChildren();
        if (page === 'catalogos') query('/ligas/exploracion?idDeporte='+encodeURIComponent($('browse-sport').value),data=> {
            if (!Array.isArray(data.ligas)) throw new Error('Respuesta de ligas inválida.');
            table($('browse-results'),'Ligas disponibles por deporte',['ID','Nombre','Deporte ID','País ID','Activa','Acción'],data.ligas.map(liga=>[liga.idLiga,liga.nombre,liga.idDeporte,liga.idPais,liga.activo,action('Modificar',()=>fill('ligas/actualizar',{idLiga:liga.idLiga,nombre:liga.nombre,idPais:liga.idPais,activo:liga.activo}))]));
        });
        else query('/eventos/exploracion?'+new URLSearchParams({idDeporte:$('browse-sport').value,vista:'TODOS',cantidad:'100'}),data=> {
            if (!Array.isArray(data.eventos)) throw new Error('Respuesta de eventos inválida.');
            table($('browse-results'),'Eventos disponibles (máximo 100; también puedes consultar por ID)',['ID','Evento','Liga','Estado','Acción'],data.eventos.map(event=>[event.idEvento,event.evento,event.liga,event.estadoEvento,action('Consultar evento',()=>detail(event.idEvento))]));
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
    const initial = new URLSearchParams(location.search).get('idEvento');
    if ($('detail-form') && initial && /^[0-9]+$/.test(initial) && Number(initial)>0 && Number(initial)<=2147483647) { if(page==='eventos')$('advanced-event-management').open=true; $('detail-id').value=initial; detail(initial); }
    else if (eventWizard) eventWizard.loadSports();
})();

