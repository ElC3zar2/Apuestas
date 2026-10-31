(() => {
    'use strict';
    if (document.body.dataset.liveInitialized) return;
    document.body.dataset.liveInitialized = 'true';
    const $ = id => document.getElementById(id);
    const role = (document.body.dataset.adminRole || '').trim();
    const paths = {
        state: '/administrador/eventos/simulacion/estado',
        change: '/administrador/eventos/estado/cambiar',
        register: '/administrador/eventos/incidencias/registrar',
        void: '/administrador/eventos/incidencias/anular',
        csrf: '/administrador/seguridad/csrf'
    };
    const messages = {
        400: 'Parámetros no válidos. Revisa el formulario.',
        401: 'La sesión administrativa expiró. Vuelve a iniciar sesión.',
        403: 'Acceso no permitido. Se requiere ADMINISTRADOR u OPERADOR_EVENTOS para operar eventos.',
        404: 'No se encontró el evento o recurso solicitado.',
        405: 'El servidor no permite este método para la operación.',
        408: 'La solicitud agotó el tiempo de espera; consulta el contexto antes de actuar.',
        409: 'La operación no es compatible con el estado actual. Actualiza el evento antes de reintentar.',
        500: 'El servidor no pudo procesar la operación.',
        503: 'Servicio temporalmente no disponible.'
    };
    let eventId = null, official = null, busy = false, timer = null, stopped = false, authorized = false;
    let voidId = null, catalogBusy = false;
    let refreshTask = null, viewVersion = 0;
    const canOperate = ['ADMINISTRADOR','OPERADOR_EVENTOS'].includes(role);
    const states = ['BORRADOR','PROGRAMADO','EN_VIVO','SUSPENDIDO','PENDIENTE_RESULTADO','FINALIZADO','CANCELADO'];
    const types = ['ANOTACION','FALTA','TARJETA_AMARILLA','TARJETA_ROJA','OTRA'];
    let context = null, fresh = false, uncertain = null;
    // Solo memoria de esta página: nunca persistir tokens ni permitir reenvíos inciertos.
    const integer = (v, min = 1) => Number.isInteger(v) && v >= min && v <= 2147483647;
    const idInput = v => /^[1-9][0-9]{0,9}$/.test(String(v)) && integer(Number(v));
    function bigintId(v) {
        if (!['number','string'].includes(typeof v)) return null;
        if (typeof v === 'number' && !Number.isSafeInteger(v)) return null;
        const s = String(v);
        return /^[1-9][0-9]{0,18}$/.test(s) && BigInt(s) <= 9223372036854775807n ? s : null;
    }
    function parseExact(raw) {
        let key = null;
        return JSON.parse(raw.replace(/"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/g, (token, offset) => {
            if (token[0] === '"') {
                key = /^\s*:/.test(raw.slice(offset + token.length)) ? JSON.parse(token) : null;
                return token;
            }
            const preserve = ['idIncidencia','idPrimeraAnotacion'].includes(key);
            key = null;
            return preserve ? JSON.stringify(token) : token;
        }));
    }
    const contract = () => { throw new Error('La respuesta no cumple el contrato o no corresponde al contexto. Actualiza manualmente.'); };
    const text = (v, max, nullable = false) => nullable && v === null || typeof v === 'string' && v.length <= max && (nullable || v.trim().length > 0);
    const date = v => v === null || typeof v === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,9})?)?$/.test(v);
    function validateState(s, id) {
        if (!s || s.idEvento !== Number(id) || !text(s.nombre,200) || !states.includes(s.estadoEvento)
            || typeof s.esSimulado !== 'boolean' || typeof s.tiempoVisualCumplido !== 'boolean'
            || !integer(s.segundosTranscurridos,0) || !(s.duracionSimulacionSegundos === null || integer(s.duracionSimulacionSegundos))
            || !date(s.fechaInicioRealUtc) || !date(s.fechaFinRealUtc) || !/^[a-f0-9]{16}$/i.test(s.versionFila)
            || !Array.isArray(s.participantes) || !Array.isArray(s.incidencias)) contract();
        const ids = new Set(), orders = new Set(), incidents = new Set(), sequences = new Set();
        for (const p of s.participantes) {
            if (!integer(p.idParticipante) || !integer(p.ordenParticipante) || p.ordenParticipante > 255 || !text(p.nombre,150)
                || !(p.marcadorActual === null || integer(p.marcadorActual,0)) || ids.has(p.idParticipante) || orders.has(p.ordenParticipante)) contract();
            ids.add(p.idParticipante); orders.add(p.ordenParticipante);
        }
        for (const i of s.incidencias) {
            const exact = bigintId(i.idIncidencia);
            if (!exact || incidents.has(exact) || !integer(i.secuencia) || sequences.has(i.secuencia) || !types.includes(i.tipoIncidencia)
                || !(i.idParticipante === null || ids.has(i.idParticipante)) || !(i.valorAnotacion === null || integer(i.valorAnotacion))
                || (i.tipoIncidencia === 'ANOTACION' ? i.idParticipante === null || i.valorAnotacion === null : i.valorAnotacion !== null)
                || !integer(i.segundoSimulacion,0) || !text(i.descripcion,500,true) || typeof i.esAnulada !== 'boolean'
                || !text(i.motivoAnulacion,500,true) || !date(i.fechaRegistroUtc) || i.fechaRegistroUtc === null || !date(i.fechaAnulacionUtc)
                || !/^[a-f0-9]{16}$/i.test(i.versionFila)) contract();
            i.idIncidencia = exact; incidents.add(exact); sequences.add(i.secuencia);
        }
        if ((s.idPrimeraAnotacion === null) !== (s.idPrimerParticipanteAnotador === null)) contract();
        if (s.idPrimeraAnotacion !== null) {
            const exact = bigintId(s.idPrimeraAnotacion), first = s.incidencias.find(i => i.idIncidencia === exact);
            if (!exact || !first || first.esAnulada || first.tipoIncidencia !== 'ANOTACION' || first.idParticipante !== s.idPrimerParticipanteAnotador) contract();
            s.idPrimeraAnotacion = exact;
        }
        return s;
    }
    function validateContext(d, id, s) {
        if (!d || d.idEvento !== Number(id) || !integer(d.idDeporte) || !integer(d.idLiga) || !text(d.deporte,150)
            || !text(d.evento,200) || !Array.isArray(d.participantes) || d.cantidadParticipantes !== d.participantes.length
            || d.participantes.length !== s.participantes.length || new Set(d.participantes.map(p=>p.idParticipante)).size !== d.participantes.length || d.simulacion?.esSimulado !== s.esSimulado
            || d.participantes.some(p => !s.participantes.some(x => x.idParticipante === p.idParticipante && x.ordenParticipante === p.ordenParticipante))) contract();
        return d;
    }
    const display = value => value === null || value === undefined || value === '' ? 'No disponible' : String(value);
    function status(id, text, error = false) {
        $(id).textContent = text;
        $(id).dataset.error = String(error);
    }
    function stopPolling() { clearTimeout(timer); timer = null; }
    function trackingStatus() {
        const message = stopped ? 'Seguimiento detenido al salir de la página.'
            : !eventId ? 'Selecciona un evento para consultar su estado.'
            : uncertain ? 'Seguimiento pausado por una escritura incierta. Conserva el contexto y actualiza manualmente para conciliar.'
            : busy || catalogBusy || refreshTask ? 'Consulta u operación en curso; no se superponen actualizaciones del mismo contexto.'
            : !authorized || !fresh ? 'Sin lectura actual confirmada. Utiliza Actualizar / reintentar; no se repiten solicitudes en bucle.'
            : official?.estadoEvento !== 'EN_VIVO' ? 'Seguimiento exclusivo de EN_VIVO detenido. La actualización manual sigue disponible.'
            : document.hidden ? 'Seguimiento pausado mientras la pestaña está oculta.'
            : timer !== null ? 'Seguimiento cada 3 segundos. Solo consulta; no ejecuta el cierre.'
            : 'Seguimiento pendiente de la siguiente consulta autorizada.';
        $('tracking-status').textContent = message;
    }
    function simulationNote(state) {
        if (!state.esSimulado) return 'Evento convencional: tiempo deportivo no disponible. Las incidencias se ordenan por secuencia y fecha de registro administrativo (UTC); el segundo técnico de compatibilidad no representa el tiempo real del partido. Esta pantalla no cambia su estado automáticamente.';
        if (state.estadoEvento === 'PENDIENTE_RESULTADO') return 'Simulación cerrada según el estado oficial. El resultado está pendiente de revisión; este panel no oficializa ni liquida apuestas.';
        if (state.estadoEvento === 'FINALIZADO') return 'El backend informa FINALIZADO. Este panel no ha oficializado resultados ni ejecutado operaciones financieras.';
        if (state.estadoEvento === 'CANCELADO') return 'El backend informa CANCELADO; no se reinicia ni se cierra de nuevo desde el seguimiento.';
        if (state.estadoEvento !== 'EN_VIVO') return 'Estado oficial: '+state.estadoEvento+'. El plazo se mide desde el inicio real registrado por el servidor, no desde la fecha programada ni desde esta página.';
        if (state.fechaInicioRealUtc === null || !integer(state.duracionSimulacionSegundos)) return 'Falta el inicio real o una duración válida en la respuesta oficial. No se deduce el vencimiento ni se solicita un cierre automático.';
        return state.tiempoVisualCumplido
            ? 'El indicador visual del servidor alcanzó la duración de '+state.duracionSimulacionSegundos+' segundos, pero todavía informa EN_VIVO. SQL verifica el vencimiento completo antes del cierre automático. Esta vista no confirma si el servicio está habilitado u operativo; se conserva el cierre manual autorizado como respaldo.'
            : 'Tiempo y duración recibidos del servidor desde el inicio real. El cierre automático depende de la configuración y disponibilidad del servidor, que esta vista no confirma. El navegador no adelanta el reloj ni cierra la simulación.';
    }
    function syncControls() {
        const available = canOperate && authorized && fresh && context && official && !busy && !catalogBusy && !refreshTask && !stopped && !uncertain;
        // Durante una lectura conservar la edición y el foco; los envíos siguen bloqueados.
        const editing = available || canOperate && authorized && context && official && Boolean(refreshTask) && !busy && !catalogBusy && !stopped && !uncertain;
        $('state-fields').disabled = !editing;
        $('incident-fields').disabled = !editing;
        $('void-fields').disabled = !editing;
        $('state-form').querySelector('[type="submit"]').disabled = !available || !transitions().includes($('new-state').value);
        const participant = $('participant').value;
        const participantValid = !participant || official?.participantes.some(p => String(p.idParticipante) === participant);
        const annotation = $('incident-type').value === 'ANOTACION';
        const incidentValid = types.includes($('incident-type').value) && $('description').value.trim().length <= 500
            && participantValid && (!annotation || Boolean(participant) && idInput($('annotation').value));
        $('incident-form').querySelector('[type="submit"]').disabled = !available || official?.estadoEvento !== 'EN_VIVO'
            || (official?.esSimulado === true && official.fechaInicioRealUtc === null) || !incidentValid;
        $('void-form').querySelector('[type="submit"]').disabled = !available || !['EN_VIVO','PENDIENTE_RESULTADO'].includes(official?.estadoEvento) || !official?.incidencias.some(i=>i.idIncidencia===voidId&&!i.esAnulada);
        $('refresh-event').disabled = busy || Boolean(refreshTask) || !eventId || stopped;
        for (const id of ['event-search', 'event-select', 'event-id-form']) {
            $(id).querySelectorAll('input, select, button').forEach(el => { el.disabled = !canOperate || busy || catalogBusy || stopped; });
        }
        document.querySelectorAll('[data-void-id]').forEach(el => { el.disabled = !editing || !['EN_VIVO','PENDIENTE_RESULTADO'].includes(official?.estadoEvento) || !official?.incidencias.some(i=>i.idIncidencia===el.dataset.voidId&&!i.esAnulada); });
        $('event-content').setAttribute('aria-busy', String(busy));window.BetZoneAdmin.syncPages(!canOperate||busy||catalogBusy||stopped);
        document.body.dataset.liveBusy = String(busy || catalogBusy || Boolean(refreshTask));
        $('acknowledge-live').disabled = !canOperate || !authorized || !fresh || busy || Boolean(refreshTask) || !reconciliationEvidence();
        trackingStatus();
    }
    function report(error, target = 'live-status') {
        const text = error.name === 'AbortError' ? 'La solicitud tardó demasiado o fue interrumpida. Reintenta manualmente.'
            : error.status ? messages[error.status] || 'No fue posible procesar la solicitud.'
            : error instanceof TypeError ? 'Error de red. Revisa la conexión y reintenta.'
            : error.message;
        status(target, text, true);
        if (error.status === 401 || error.status === 403) {
            authorized = false;
            fresh = false;
            stopPolling();
            $('live-login').hidden = error.status !== 401;
        }
    }
    async function api(path, options = {}) {
        const data = await window.BetZoneAdmin.request(path, options, parseExact);
        if (!data || data.ok !== true) contract();
        return data;
    }
    function schedule() {
        stopPolling();
        if (!busy && !catalogBusy && !refreshTask && !stopped && !document.hidden && authorized && fresh && !uncertain && official?.estadoEvento === 'EN_VIVO') {
            timer = setTimeout(() => refresh(), 3000);
        }
        trackingStatus();
    }
    function option(value, label) { const node = document.createElement('option'); node.value = value; node.textContent = label; return node; }
    function transitions() {
        // sp_CambiarEstadoEvento + sp_Iniciar/FinalizarSimulacionEvento.
        // FINALIZADO se establece exclusivamente desde oficialización.
        const graph = {
            BORRADOR: ['PROGRAMADO','CANCELADO'],
            PROGRAMADO: ['EN_VIVO','SUSPENDIDO','CANCELADO'],
            EN_VIVO: ['PENDIENTE_RESULTADO','SUSPENDIDO','CANCELADO'],
            SUSPENDIDO: ['PROGRAMADO','EN_VIVO','CANCELADO'],
            PENDIENTE_RESULTADO: ['CANCELADO']
        };
        return (graph[official?.estadoEvento] || []).filter(next =>
            !(official.esSimulado && (next === 'SUSPENDIDO' || (official.estadoEvento === 'SUSPENDIDO' && next !== 'CANCELADO')
                || (next === 'EN_VIVO' && (official.estadoEvento !== 'PROGRAMADO' || official.participantes.length !== 2
                || ![1,2].every(order=>official.participantes.some(p=>p.ordenParticipante===order)) || official.incidencias.length || official.fechaInicioRealUtc !== null))))
            && !(next === 'CANCELADO' && role !== 'ADMINISTRADOR'));
    }
    function syncEditors() {
        if (!official) return;
        const participants = $('participant');
        if (document.activeElement !== participants) {
            const selected = participants.value;
            const available = new Map(official.participantes.map(p => [String(p.idParticipante), p.nombre]));
            if (!participants.options.length) participants.append(option('', 'Sin participante'));
            for (const item of [...participants.options]) {
                if (!item.value) continue;
                if (available.has(item.value)) { item.textContent = available.get(item.value); item.disabled = false; }
                else if (item.value === selected) { item.disabled = true; item.textContent = 'Participante ' + item.value + ' · ya no disponible'; }
                else item.remove();
            }
            for (const [id, name] of available) if (![...participants.options].some(item => item.value === id)) participants.append(option(id, name));
            participants.value = selected;
        }
        const selector = $('new-state');
        if (document.activeElement !== selector) {
            const selected = selector.value;
            const allowed = transitions();
            const labels = {PROGRAMADO:'Programar · PROGRAMADO',EN_VIVO:'Iniciar · EN_VIVO',SUSPENDIDO:'Suspender · SUSPENDIDO',PENDIENTE_RESULTADO:'Cerrar simulación · PENDIENTE_RESULTADO',CANCELADO:'Cancelar · CANCELADO'};
            for (const item of [...selector.options]) if (item.value && !allowed.includes(item.value)) item.remove();
            for (const next of allowed) if (![...selector.options].some(item => item.value === next)) selector.append(option(next, labels[next]));
            selector.value = allowed.includes(selected) ? selected : '';
            $('transition-note').textContent = allowed.length ? 'Solo se muestran transiciones del estado oficial; el servidor valida las condiciones adicionales.' : 'No hay transiciones disponibles aquí. FINALIZADO se establece desde Resultados.';
        }
        $('state-reason').required = selector.value === 'CANCELADO';
    }
    function render(state) {
        official = state;
        $('event-content').hidden = false;
        $('event-name').textContent = display(state.nombre);
        $('official-id').textContent = display(state.idEvento);
        $('official-state').textContent = state.estadoEvento;
        $('official-simulated').textContent = state.esSimulado ? 'Simulado' : 'Convencional';
        $('official-time').textContent = state.esSimulado && Number.isInteger(state.segundosTranscurridos)
            ? state.segundosTranscurridos + ' s / ' + display(state.duracionSimulacionSegundos) + ' s' : 'Tiempo deportivo no disponible';
        const progress = $('official-progress');
        progress.hidden = !(state.esSimulado && state.duracionSimulacionSegundos > 0 && Number.isInteger(state.segundosTranscurridos));
        if (!progress.hidden) { progress.max = state.duracionSimulacionSegundos; progress.value = state.segundosTranscurridos; }
        $('time-note').textContent = simulationNote(state);
        $('official-start').textContent = display(state.fechaInicioRealUtc);
        $('official-end').textContent = display(state.fechaFinRealUtc);
        $('live-results').hidden = !['PENDIENTE_RESULTADO','FINALIZADO'].includes(state.estadoEvento);
        if (!$('live-results').hidden) $('live-results').href = (document.body.dataset.contextPath || '')+'/administrador/resultados?idEvento='+encodeURIComponent(state.idEvento);
        $('scoreboard').replaceChildren();
        for (const participant of state.participantes) {
            const article = document.createElement('article');
            const label = document.createElement('span'); label.textContent = display(participant.nombre);
            const score = document.createElement('strong'); score.textContent = participant.marcadorActual === null || participant.marcadorActual === undefined ? 'Sin marcador' : display(participant.marcadorActual);
            article.append(label, score); $('scoreboard').append(article);
        }
        if (!state.participantes.length) $('scoreboard').textContent = 'El backend no devolvió participantes ni marcador.';
        syncEditors();
        const first = state.participantes.find(p => p.idParticipante === state.idPrimerParticipanteAnotador);
        $('first-score').textContent = state.idPrimerParticipanteAnotador == null ? 'Sin primera anotación informada.' : 'Primera anotación oficial: ' + (first ? first.nombre : display(state.idPrimerParticipanteAnotador)) + ' · Incidencia ' + state.idPrimeraAnotacion;
        const body = $('incidents-body');
        $('incident-time-heading').textContent = state.esSimulado ? 'Segundo de simulación / registro (UTC)' : 'Registro administrativo (UTC)';
        // Conservar también el foco de una acción del historial mientras se navega con teclado.
        if (body.contains(document.activeElement)) return;
        body.replaceChildren();
        if (!state.incidencias.length) { const cell = body.insertRow().insertCell(); cell.colSpan = 8; cell.textContent = 'No hay incidencias registradas.'; }
        for (const incident of state.incidencias) {
            const row = body.insertRow();
            const participant = state.participantes.find(p => p.idParticipante === incident.idParticipante);
            for (const value of [display(incident.idIncidencia) + ' / ' + display(incident.secuencia), incident.tipoIncidencia,
                participant ? participant.nombre : incident.idParticipante, incident.valorAnotacion,
                (state.esSimulado ? incident.segundoSimulacion + ' s · ' : '') + incident.fechaRegistroUtc + ' UTC',
                incident.descripcion, incident.esAnulada ? 'ANULADA · ' + display(incident.motivoAnulacion) : 'VIGENTE']) {
                row.insertCell().textContent = display(value);
            }
            const action = row.insertCell();
            if (!incident.esAnulada) {
                const button = document.createElement('button'); button.type = 'button'; button.textContent = 'Anular'; button.dataset.voidId = String(incident.idIncidencia);
                button.addEventListener('click', () => {
                    if (!ready() || !['EN_VIVO','PENDIENTE_RESULTADO'].includes(official?.estadoEvento)
                        || !official.incidencias.some(item => item.idIncidencia === incident.idIncidencia && !item.esAnulada)) return;
                    if (voidId && voidId !== String(incident.idIncidencia) && $('void-reason').value.trim()
                        && !window.confirm('Hay un motivo escrito para otra incidencia. ¿Cambiar de incidencia y conservar ese borrador?')) return;
                    voidId = String(incident.idIncidencia); $('void-title').textContent = 'Anular incidencia ' + voidId;
                    $('void-form').hidden = false; $('void-reason').focus();
                });
                action.append(button);
            } else action.textContent = 'Anulada';
        }
    }
    async function readState(version = ++viewVersion, id = eventId) {
        const detail = await api('/administrador/eventos/detalle?idEvento=' + encodeURIComponent(id));
        if (stopped || version !== viewVersion || id !== eventId) return false;
        const data = await api(paths.state + '?idEvento=' + encodeURIComponent(id));
        if (stopped || version !== viewVersion || id !== eventId) return false;
        const state = validateState(data.resultado, id);
        const nextContext = validateContext(detail.evento, id, state);
        context = nextContext;
        render(state); authorized = canOperate; fresh = true; $('live-login').hidden = true;
        $('event-sport').textContent = 'Deporte: ' + context.deporte;
        $('update-status').textContent = 'Lectura actualizada · ' + new Date().toLocaleString();
        showUncertain();
        return true;
    }
    function refresh() {
        if (busy || catalogBusy || stopped || !eventId || refreshTask) return refreshTask;
        stopPolling();
        const version = ++viewVersion, id = eventId;
        fresh = false;
        refreshTask = (async () => {
        try {
            if (!await readState(version, id)) return;
            status('live-status', 'Estado actualizado. ' + (official.estadoEvento === 'EN_VIVO' ? 'Seguimiento cada 3 segundos.' : 'Seguimiento automático detenido.'));
        } catch (error) { if (!stopped && version === viewVersion && id === eventId) { fresh = false; report(error); $('update-status').textContent = 'Lectura desactualizada; última información válida conservada.'; showUncertain(); } }
        finally { if (version === viewVersion) { refreshTask = null; syncControls(); schedule(); } }
        })();
        syncControls();
        return refreshTask;
    }
    async function open(id) {
        if (!canOperate || busy || catalogBusy || stopped || !idInput(id)) return;
        if (String(Number(id)) === eventId) { await refresh(true); return; }
        const hasDraft = [...document.querySelectorAll('#description, #annotation, #state-reason, #void-reason')].some(input => input.value.trim())
            || $('participant').value || $('new-state').value || $('incident-type').value !== 'ANOTACION' || voidId;
        if (eventId && hasDraft
            && !window.confirm('Cambiar de evento descartará los borradores del evento actual. ¿Continuar?')) return;
        ++viewVersion; stopPolling(); refreshTask = null;
        eventId = String(Number(id)); official = null; context = null; fresh = false; authorized = false;
        $('event-content').hidden = true; $('void-form').hidden = true; voidId = null;
        $('live-results').hidden = true;
        $('event-sport').textContent = 'Consultando deporte…'; $('event-id').value = eventId;
        $('incident-form').reset(); $('state-form').reset(); $('void-form').reset();
        $('participant').replaceChildren(option('', 'Sin participante'));
        $('new-state').replaceChildren(option('', 'Selecciona una transición'));
        $('update-status').textContent = 'Consultando estado oficial…';
        showUncertain(); incidentType(); await refresh(true);
    }
    function incidentType() {
        const annotation = $('incident-type').value === 'ANOTACION';
        $('annotation-label').hidden = !annotation; $('annotation').disabled = !annotation; $('annotation').required = annotation;
        $('participant').required = annotation;
        syncControls();
    }
    function ready() { return canOperate && authorized && fresh && context && official && !busy && !catalogBusy && !refreshTask && !stopped && !uncertain; }
    function reconciliationEvidence() {
        if (!uncertain || !fresh || !context || !official || uncertain.eventId !== eventId
            || uncertain.sport !== context.idDeporte || uncertain.league !== context.idLiga) return false;
        if (uncertain.path === paths.change) return official.estadoEvento === uncertain.payload.nuevoEstado;
        if (uncertain.path === paths.void) return official.incidencias.some(i=>i.idIncidencia===uncertain.payload.idIncidencia&&i.esAnulada);
        return false;
    }
    function showUncertain() {
        $('uncertain-live').hidden = !uncertain;
        if (!uncertain) return;
        $('uncertain-description').textContent = 'Escritura incierta: ' + uncertain.path + ' · Evento ' + uncertain.eventId
            + ' · Payload original: ' + JSON.stringify(uncertain.payload) + '. No se reenvía el POST. '
            + (reconciliationEvidence() ? 'El mismo registro muestra el estado solicitado. Esto no demuestra que el POST original lo causara. Revisa y confirma expresamente para levantar el bloqueo.'
                : 'No hay evidencia suficiente para levantar el bloqueo. Consulta el evento original. El registro de incidencia sin ID confirmado requiere conciliación del responsable técnico mediante la UUID; el marcador, tipo o descripción no lo identifican.');
    }
    function validateOutcome(path, p, r, snapshot) {
        if (!r || typeof r !== 'object' || Array.isArray(r)) contract();
        if (path === paths.register) {
            if (!bigintId(r.idIncidencia) || typeof r.solicitudIdempotente !== 'boolean') contract();
            r.idIncidencia = bigintId(r.idIncidencia); return;
        }
        if (typeof r.sinCambios !== 'boolean') contract();
        if (path === paths.void) { if (bigintId(r.idIncidencia) !== p.idIncidencia) contract(); r.idIncidencia = bigintId(r.idIncidencia); return; }
        if (r.idEvento !== Number(p.idEvento)) contract();
        if (p.nuevoEstado === 'CANCELADO') {
            if (!integer(r.idResultado) || r.estadoEvento !== 'CANCELADO' || r.estadoResultado !== 'ANULADO') contract();
        } else if (snapshot.esSimulado && ['EN_VIVO','PENDIENTE_RESULTADO'].includes(p.nuevoEstado)) {
            if (r.estadoActual !== undefined || r.estadoAnterior !== undefined) contract();
            if (r.registrado != null) {
                const result = r.registrado;
                if (p.nuevoEstado !== 'PENDIENTE_RESULTADO' || !integer(result.idResultado) || result.idEvento !== Number(p.idEvento)
                    || !['PENDIENTE','CORREGIDO'].includes(result.estadoResultado) || !text(result.resultadoTexto,250) || !text(result.observacion,500,true)) contract();
            }
        } else if (!states.includes(r.estadoAnterior) || r.estadoActual !== p.nuevoEstado || r.sinCambios !== (r.estadoAnterior === r.estadoActual)) contract();
    }
    async function mutate(path, payload, success, onSuccess) {
        if (!ready()) return;
        const snapshot = official, operation = {path, payload:Object.freeze({...payload}), eventId, sport:context.idDeporte, league:context.idLiga};
        busy = true; stopPolling(); syncControls();
        ++viewVersion;
        status('live-status', 'Enviando solicitud. Espera la respuesta antes de repetirla.');
        let sent = false;
        try {
            if (stopped) return;
            const token = await api(paths.csrf);
            if (stopped) return;
            if (typeof token.csrfToken !== 'string' || !/^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$/.test(token.csrfToken)) throw new Error('El servidor no devolvió un token CSRF válido.');
            sent = true;
            const result = await api(path, { method: 'POST', headers: { 'X-CSRF-Token': token.csrfToken }, body: new URLSearchParams(payload) });
            if (stopped) return;
            const outcome = result.resultado;
            validateOutcome(path,payload,outcome,snapshot);
            $('confirmed-live').hidden = false;
            $('confirmed-live').textContent = 'POST confirmado · ' + path + ' · Evento ' + operation.eventId + ' · ' + JSON.stringify(outcome)
                + (path === paths.register ? outcome.solicitudIdempotente ? ' · Solicitud idempotente reconocida.' : ' · Incidencia nueva registrada.' : '');
            if (onSuccess) onSuccess();
            fresh = false;
            try { await readState(); if (!stopped) status('live-status', success + ' Estado oficial actualizado.'); }
            catch (error) { if (!stopped) { fresh = false; report(error); $('update-status').textContent = 'Lectura desactualizada; POST confirmado conservado.'; status('live-status', success + ' POST confirmado. No se pudo actualizar el estado. Usa Actualizar / reintentar.', true); } }
        } catch (error) {
            if (sent) { uncertain = Object.freeze(operation); fresh = false; }
            if (stopped) return;
            report(error);
            if (sent) {
                const resultReview = path === paths.void && !snapshot.esSimulado && error.status === 409
                    ? ' La anulación convencional puede estar impedida por un resultado registrado o liquidaciones. Revisa el evento en el flujo de Resultados; este panel no modifica ese resultado.' : '';
                status('live-status', 'Resultado de escritura incierto. Nuevas escrituras bloqueadas; conserva esta página y concilia el contexto original. ' + (messages[error.status] || error.message) + resultReview, true);
                showUncertain();
            }
        } finally { busy = false; syncControls(); schedule(); }
    }
    $('state-form').addEventListener('submit', event => {
        event.preventDefault(); if (!ready()) return;
        const next = $('new-state').value;
        if (!transitions().includes(next)) { status('live-status', 'La transición seleccionada ya no está disponible para el estado oficial.', true); syncEditors(); syncControls(); return; }
        if ($('state-reason').value.trim().length > 250 || next === 'CANCELADO' && !$('state-reason').value.trim()) { status('live-status','Revisa el motivo: máximo 250 caracteres; obligatorio al cancelar.',true); return; }
        const impact = next === 'CANCELADO' ? 'Cancelar afecta el evento y sus mercados; requiere ADMINISTRADOR. No confirma liquidación de apuestas.'
            : official.esSimulado && next === 'EN_VIVO' ? 'Iniciar la simulación inicializa el marcador y el backend cierra mercados y desactiva cuotas aplicables.'
            : next === 'PENDIENTE_RESULTADO' ? 'Cerrar deja el evento pendiente de resultado; no oficializa ni liquida apuestas.' : 'El servidor validará la transición.';
        if (!window.confirm('Evento ' + eventId + ': solicitar ' + next + '. ' + impact + ' ¿Continuar?')) return;
        const payload = { idEvento: eventId, nuevoEstado: next };
        if ($('state-reason').value.trim()) payload.motivo = $('state-reason').value.trim();
        mutate(paths.change, payload, 'Solicitud de transición aceptada.', () => { $('state-reason').value = ''; });
    });
    $('incident-form').addEventListener('submit', event => {
        event.preventDefault(); if (!ready() || official?.estadoEvento !== 'EN_VIVO'
            || (official.esSimulado && official.fechaInicioRealUtc === null)) return;
        if (!$('incident-form').reportValidity()) return;
        if (!types.includes($('incident-type').value) || $('description').value.trim().length > 500
            || ($('incident-type').value === 'ANOTACION' && (!$('participant').value || !idInput($('annotation').value)))) {
            status('live-status','Revisa el tipo, participante, anotación entera positiva y descripción (máximo 500 caracteres).',true); return;
        }
        if ($('participant').value && !official.participantes.some(p => String(p.idParticipante) === $('participant').value)) { status('live-status', 'El participante seleccionado ya no está disponible. Revisa el formulario.', true); return; }
        const payload = { idEvento: eventId, tipoIncidencia: $('incident-type').value };
        if ($('participant').value) payload.idParticipante = $('participant').value;
        if (payload.tipoIncidencia === 'ANOTACION') payload.valorAnotacion = $('annotation').value;
        if ($('description').value.trim()) payload.descripcion = $('description').value.trim();
        if (!window.confirm('¿Registrar ' + payload.tipoIncidencia + ' en el evento ' + eventId + '? El backend validará las reglas deportivas.')) return;
        if (!globalThis.crypto?.randomUUID) { status('live-status', 'El navegador requiere un contexto seguro para generar la referencia de operación.', true); return; }
        payload.referenciaOperacion = crypto.randomUUID();
        if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(payload.referenciaOperacion)) return;
        mutate(paths.register, payload, 'Incidencia registrada.', () => { $('incident-form').reset(); incidentType(); });
    });
    $('incident-type').addEventListener('change', incidentType);
    for (const id of ['annotation','description']) $(id).addEventListener('input', syncControls);
    $('void-form').addEventListener('submit', event => {
        event.preventDefault(); if (!ready() || !bigintId(voidId) || !['EN_VIVO','PENDIENTE_RESULTADO'].includes(official?.estadoEvento)
            || !official.incidencias.some(i=>i.idIncidencia===voidId&&!i.esAnulada)) return;
        const reason = $('void-reason').value.trim();
        if (reason.length > 500) { status('live-status','El motivo admite como máximo 500 caracteres.',true); return; }
        if (!reason) { $('void-reason').setCustomValidity('Escribe el motivo de anulación.'); $('void-reason').reportValidity(); return; }
        if (!window.confirm('¿Anular la incidencia ' + voidId + ' del evento ' + eventId + '? Motivo: ' + reason)) return;
        mutate(paths.void, { idIncidencia: voidId, motivo: reason }, 'Incidencia anulada.', () => { $('void-form').hidden = true; $('void-form').reset(); voidId = null; });
    });
    $('void-reason').addEventListener('input', () => $('void-reason').setCustomValidity(''));
    $('void-cancel').addEventListener('click', () => { $('void-form').hidden = true; voidId = null; });
    for (const id of ['participant','new-state']) {
        $(id).addEventListener('blur', () => { syncEditors(); syncControls(); });
        $(id).addEventListener('change', () => { syncEditors(); syncControls(); });
    }
    $('incidents-body').addEventListener('focusout', () => queueMicrotask(() => {
        if (official && !busy && !stopped && !$('incidents-body').contains(document.activeElement)) { render(official); syncControls(); }
    }));
    $('refresh-event').addEventListener('click', () => refresh(true));
    $('acknowledge-live').addEventListener('click', () => {
        if (!canOperate || !authorized || !fresh || busy || refreshTask || stopped || !reconciliationEvidence()) return;
        if (!window.confirm('He revisado el mismo evento y registro: su estado actual coincide. No demuestra la causa del POST original. ¿Levantar el bloqueo sin reenviar?')) return;
        $('reconciled-live').hidden = false;
        $('reconciled-live').textContent = 'Revisión manual: ' + uncertain.path + ' · Evento ' + uncertain.eventId + ' · ' + JSON.stringify(uncertain.payload)
            + '. Estado actual coincidente; causalidad del POST original no demostrada.';
        uncertain = null; showUncertain(); syncControls(); schedule();
    });
    $('event-id-form').addEventListener('submit', event => { event.preventDefault(); open($('event-id').value); });
    $('event-select').addEventListener('submit', event => { event.preventDefault(); open($('event-list').value); });
    async function sports() {
        if (!canOperate || stopped || catalogBusy || busy) return;
        catalogBusy = true; syncControls(); status('catalog-status', 'Cargando deportes…');
        try {
            if (refreshTask) await refreshTask;
            if (stopped) return;
            const data = await api('/deportes/exploracion');
            if (!Array.isArray(data.deportes) || !integer(data.cantidad,0) || data.cantidad !== data.deportes.length
                || new Set(data.deportes.map(s=>s.idDeporte)).size !== data.deportes.length
                || data.deportes.some(s=>!integer(s.idDeporte)||!text(s.nombre,150)||typeof s.activo!=='boolean'||typeof s.permiteSimulacion!=='boolean')) throw new Error('Respuesta de deportes inválida.');
            if (stopped) return;
            $('sport').replaceChildren(option('', 'Selecciona un deporte'));
            data.deportes.forEach(sport => $('sport').append(option(sport.idDeporte, sport.nombre)));
            status('catalog-status', data.deportes.length ? 'Selecciona deporte y busca eventos, o consulta un ID real.' : 'No hay deportes activos. Puedes localizar un evento por ID.');
        } catch (error) { report(error, 'catalog-status'); }
        finally { catalogBusy = false; syncControls(); schedule(); }
    }
    $('sport').addEventListener('change',()=>{if(!busy&&!catalogBusy){window.BetZoneAdmin.resetEvents();$('event-list').replaceChildren(option('','Busca eventos del deporte seleccionado'));$('event-search').requestSubmit();}});
    $('retry-sports').addEventListener('click', sports);
    $('event-search').addEventListener('submit', async event => {
        event.preventDefault(); if (!canOperate || stopped || catalogBusy || busy || !idInput($('sport').value)) return;
        catalogBusy = true; syncControls(); $('event-list').replaceChildren(option('', 'Cargando eventos…'));
        status('catalog-status', 'Consultando eventos…');
        try {
            if (refreshTask) await refreshTask;
            if (stopped) return;
            const data = await api(window.BetZoneAdmin.eventsPath($('sport').value));
            if (stopped) return;
            if (!Array.isArray(data.eventos) || data.eventos.length > data.tamanoPagina
                || new Set(data.eventos.map(e=>e.idEvento)).size !== data.eventos.length
                || data.eventos.some(e=>!integer(e.idEvento)||e.idDeporte!==Number($('sport').value)||!states.includes(e.estadoEvento)||!text(e.evento,200))) throw new Error('Respuesta de eventos inválida.');
            $('event-list').replaceChildren(option('', 'Selecciona un evento'));
            window.BetZoneAdmin.pageData(data);data.eventos.forEach(item => $('event-list').append(option(item.idEvento, window.BetZoneAdmin.eventLabel(item))));
            status('catalog-status', data.eventos.length ? 'Eventos devueltos: ' + data.eventos.length + ' en esta página.' : 'No hay eventos en esta consulta. Puedes consultar un ID real.');
        } catch (error) { $('event-list').replaceChildren(option('', 'Sin lista disponible')); report(error, 'catalog-status'); }
        finally { catalogBusy = false; syncControls(); schedule(); }
    });
    document.addEventListener('visibilitychange', () => { if (document.hidden) { stopPolling(); trackingStatus(); } else if (official?.estadoEvento === 'EN_VIVO') refresh(); else trackingStatus(); });
    window.addEventListener('beforeunload', event => { if (uncertain || busy) { event.preventDefault(); event.returnValue = ''; } });
    window.addEventListener('pagehide', () => { stopped = true; fresh = false; ++viewVersion; stopPolling(); trackingStatus(); });
    window.addEventListener('pageshow', event => { if (event.persisted) { stopped = false; authorized = false; if (eventId) refresh(true); } });
    // Actualizar solo los avisos existentes; no hay nuevas acciones ni POST
    // en el polling. El estado operativo del ejecutor no forma parte del DTO.
    const autoNotice=document.querySelector('#contenido > p.warning');
    if(autoNotice)autoNotice.textContent='El cierre automático depende de la configuración y disponibilidad del servidor. Esta pantalla no confirma que esté activo: solo consulta el estado oficial. Conserva el cierre manual autorizado como respaldo.';
    const manualNotice=$('state-form').parentElement.querySelector('p.warning');
    if(manualNotice)manualNotice.textContent='Cerrar la simulación deja el resultado pendiente; no oficializa ni liquida apuestas. FINALIZADO solo se establece desde Resultados. El cierre manual sigue disponible y el seguimiento no ejecuta cierres.';
    window.BetZoneAdmin.eventPagination($('event-search'));incidentType(); syncControls();
    const initialEvent = new URLSearchParams(location.search).get('idEvento');
    if (!canOperate) { status('live-status','Este módulo requiere ADMINISTRADOR u OPERADOR_EVENTOS. No hay acceso de lectura ni escritura para este rol.',true); return; }
    if (initialEvent && idInput(initialEvent)) {
        sports().then(() => open(initialEvent));
    } else { if (initialEvent !== null) status('live-status','La referencia de evento no es válida.',true); sports(); }
})();


