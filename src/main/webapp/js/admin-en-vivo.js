(() => {
    'use strict';
    const $ = id => document.getElementById(id);
    const base = document.body.dataset.contextPath || '';
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
        409: 'La operación no es compatible con el estado actual. Actualiza el evento antes de reintentar.',
        500: 'El servidor no pudo procesar la operación.',
        503: 'Servicio temporalmente no disponible.'
    };
    let eventId = null, official = null, busy = false, timer = null, stopped = false, authorized = false;
    let voidId = null, catalogBusy = false;
    let refreshTask = null, viewVersion = 0;
    const controllers = new Set();
    const references = new Map();
    const display = value => value === null || value === undefined || value === '' ? 'No disponible' : String(value);
    function status(id, text, error = false) {
        $(id).textContent = text;
        $(id).dataset.error = String(error);
    }
    function stopPolling() { clearTimeout(timer); timer = null; }
    function syncControls() {
        const available = authorized && official && !busy && !catalogBusy && !stopped;
        $('state-fields').disabled = !available;
        $('incident-fields').disabled = !available;
        $('void-fields').disabled = !available;
        $('state-form').querySelector('[type="submit"]').disabled = !available || !transitions().includes($('new-state').value);
        const participant = $('participant').value;
        const participantValid = !participant || official?.participantes.some(p => String(p.idParticipante) === participant);
        $('incident-form').querySelector('[type="submit"]').disabled = !available || official?.esSimulado !== true || official?.estadoEvento !== 'EN_VIVO' || !participantValid;
        $('void-form').querySelector('[type="submit"]').disabled = !available || !['EN_VIVO','PENDIENTE_RESULTADO'].includes(official?.estadoEvento);
        $('refresh-event').disabled = busy || Boolean(refreshTask) || !eventId || stopped;
        for (const id of ['event-search', 'event-select', 'event-id-form']) {
            $(id).querySelectorAll('input, select, button').forEach(el => { el.disabled = busy || catalogBusy; });
        }
        document.querySelectorAll('[data-void-id]').forEach(el => { el.disabled = !available || !['EN_VIVO','PENDIENTE_RESULTADO'].includes(official?.estadoEvento); });
        $('event-content').setAttribute('aria-busy', String(busy));window.BetZoneAdmin.syncPages(busy||catalogBusy||stopped);
    }
    function report(error, target = 'live-status') {
        const text = error.name === 'AbortError' ? 'La solicitud tardó demasiado o fue interrumpida. Reintenta manualmente.'
            : error.status ? messages[error.status] || 'No fue posible procesar la solicitud.'
            : error instanceof TypeError ? 'Error de red. Revisa la conexión y reintenta.'
            : error.message;
        status(target, text, true);
        if (error.status === 401 || error.status === 403) {
            authorized = false;
            stopPolling();
            $('live-login').hidden = error.status !== 401;
        }
    }
    async function api(path, options = {}) {
        return window.BetZoneAdmin.request(path, options);
    }
    function schedule() {
        stopPolling();
        if (!busy && !catalogBusy && !refreshTask && !stopped && !document.hidden && authorized && official?.estadoEvento === 'EN_VIVO') {
            timer = setTimeout(() => refresh(), 3000);
        }
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
            !(official.esSimulado && (next === 'SUSPENDIDO' || (next === 'EN_VIVO' && official.estadoEvento !== 'PROGRAMADO')))
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
        if (!state || state.idEvento !== Number(eventId) || typeof state.estadoEvento !== 'string' || !Array.isArray(state.participantes) || !Array.isArray(state.incidencias)) {
            throw new Error('El estado recibido no cumple el contrato esperado. Reintenta manualmente.');
        }
        official = state;
        $('event-content').hidden = false;
        $('event-name').textContent = display(state.nombre);
        $('official-id').textContent = display(state.idEvento);
        $('official-state').textContent = state.estadoEvento;
        $('official-time').textContent = state.esSimulado && Number.isInteger(state.segundosTranscurridos)
            ? state.segundosTranscurridos + ' s / ' + display(state.duracionSimulacionSegundos) + ' s' : 'Tiempo de simulación no disponible';
        const progress = $('official-progress');
        progress.hidden = !(state.esSimulado && state.duracionSimulacionSegundos > 0 && Number.isInteger(state.segundosTranscurridos));
        if (!progress.hidden) { progress.max = state.duracionSimulacionSegundos; progress.value = state.segundosTranscurridos; }
        $('time-note').textContent = state.tiempoVisualCumplido ? 'El backend indica que se cumplió el tiempo visual. La transición sigue siendo manual.' : 'Tiempo recibido del servidor; sin cronómetro ni finalización local.';
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
        $('first-score').textContent = state.idPrimerParticipanteAnotador == null ? 'Sin primera anotación informada.' : 'Primera anotación oficial: ' + (first ? first.nombre : display(state.idPrimerParticipanteAnotador));
        const body = $('incidents-body');
        // Conservar también el foco de una acción del historial mientras se navega con teclado.
        if (body.contains(document.activeElement)) return;
        body.replaceChildren();
        if (!state.incidencias.length) { const cell = body.insertRow().insertCell(); cell.colSpan = 8; cell.textContent = 'No hay incidencias registradas.'; }
        for (const incident of state.incidencias) {
            const row = body.insertRow();
            const participant = state.participantes.find(p => p.idParticipante === incident.idParticipante);
            for (const value of [display(incident.idIncidencia) + ' / ' + display(incident.secuencia), incident.tipoIncidencia,
                participant ? participant.nombre : incident.idParticipante, incident.valorAnotacion, incident.segundoSimulacion,
                incident.descripcion, incident.esAnulada ? 'ANULADA · ' + display(incident.motivoAnulacion) : 'VIGENTE']) {
                row.insertCell().textContent = display(value);
            }
            const action = row.insertCell();
            if (!incident.esAnulada) {
                if (!Number.isSafeInteger(incident.idIncidencia)) { action.textContent = 'ID fuera del rango seguro del navegador'; continue; }
                const button = document.createElement('button'); button.type = 'button'; button.textContent = 'Anular'; button.dataset.voidId = String(incident.idIncidencia);
                button.addEventListener('click', () => {
                    if (busy || !authorized || !['EN_VIVO','PENDIENTE_RESULTADO'].includes(official?.estadoEvento)
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
        const data = await api(paths.state + '?idEvento=' + encodeURIComponent(id));
        if (stopped || version !== viewVersion || id !== eventId) return false;
        render(data.resultado); authorized = true; $('live-login').hidden = true;
        return true;
    }
    function refresh(metadata = false) {
        if (busy || catalogBusy || stopped || !eventId || refreshTask) return refreshTask;
        stopPolling();
        const version = ++viewVersion, id = eventId;
        refreshTask = (async () => {
        try {
            if (!await readState(version, id)) return;
            status('live-status', 'Estado actualizado. ' + (official.estadoEvento === 'EN_VIVO' ? 'Seguimiento cada 3 segundos.' : 'Seguimiento automático detenido.'));
            if (metadata) {
                try {
                    const detail = await api('/eventos/exploracion/detalle?idEvento=' + encodeURIComponent(id));
                    if (!stopped && version === viewVersion && id === eventId && detail.evento?.idEvento === Number(id)) $('event-sport').textContent = 'Deporte: ' + display(detail.evento.deporte);
                } catch (error) {
                    if (stopped || version !== viewVersion || id !== eventId) return;
                    $('event-sport').textContent = 'Deporte no disponible en el detalle. Estado administrativo consultado.';
                    if (error.status === 401 || error.status === 403) report(error);
                }
            }
        } catch (error) { if (!stopped && version === viewVersion && id === eventId) { authorized = false; report(error); } }
        finally { refreshTask = null; syncControls(); schedule(); }
        })();
        syncControls();
        return refreshTask;
    }
    async function open(id) {
        if (busy || catalogBusy || !/^[0-9]+$/.test(String(id)) || Number(id) < 1 || Number(id) > 2147483647) return;
        if (String(Number(id)) === eventId) { await refresh(true); return; }
        const hasDraft = [...document.querySelectorAll('#description, #annotation, #state-reason, #void-reason')].some(input => input.value.trim())
            || $('participant').value || $('new-state').value || $('incident-type').value !== 'ANOTACION' || voidId;
        if (eventId && hasDraft
            && !window.confirm('Cambiar de evento descartará los borradores del evento actual. ¿Continuar?')) return;
        busy = true; ++viewVersion; stopPolling(); syncControls();
        if (refreshTask) await refreshTask;
        if (stopped) { busy = false; return; }
        stopPolling(); eventId = String(Number(id)); official = null; authorized = false; references.clear();
        $('event-content').hidden = true; $('void-form').hidden = true; voidId = null;
        $('event-sport').textContent = 'Consultando deporte…'; $('event-id').value = eventId;
        $('incident-form').reset(); $('state-form').reset(); $('void-form').reset();
        $('participant').replaceChildren(option('', 'Sin participante'));
        $('new-state').replaceChildren(option('', 'Selecciona una transición'));
        busy = false; incidentType(); await refresh(true);
    }
    function incidentType() {
        const annotation = $('incident-type').value === 'ANOTACION';
        $('annotation-label').hidden = !annotation; $('annotation').disabled = !annotation; $('annotation').required = annotation;
        $('participant').required = annotation;
    }
    async function mutate(path, payload, success, onSuccess) {
        if (busy || catalogBusy || stopped || !authorized || !official) return;
        busy = true; stopPolling(); syncControls();
        ++viewVersion;
        status('live-status', 'Enviando solicitud. Espera la respuesta antes de repetirla.');
        let sent = false;
        try {
            if (refreshTask) await refreshTask;
            if (stopped) return;
            const token = await api(paths.csrf);
            if (typeof token.csrfToken !== 'string' || !token.csrfToken) throw new Error('El servidor no devolvió un token CSRF válido.');
            sent = true;
            const result = await api(path, { method: 'POST', headers: { 'X-CSRF-Token': token.csrfToken }, body: new URLSearchParams(payload) });
            if (stopped) return;
            const outcome = result.resultado;
            if (!outcome || typeof outcome !== 'object' || Array.isArray(outcome)
                || (path === paths.register && (!Number.isSafeInteger(outcome.idIncidencia) || typeof outcome.solicitudIdempotente !== 'boolean'))
                || (path === paths.void && (String(outcome.idIncidencia) !== payload.idIncidencia || typeof outcome.sinCambios !== 'boolean'))
                || (path === paths.change && outcome.idEvento !== Number(payload.idEvento))) throw new Error('Respuesta sin confirmación de la operación solicitada.');
            if (onSuccess) onSuccess();
            try { await readState(); status('live-status', success + ' Estado oficial actualizado.'); }
            catch (error) { authorized = false; report(error); status('live-status', success + ' No se pudo actualizar el estado. Usa Actualizar / reintentar.', true); }
        } catch (error) {
            report(error);
            if (sent && (!error.status || error.status >= 500)) {
                authorized = false;
                status('live-status', 'Resultado de escritura no confirmado. Actualiza antes de repetir. Si reintentas la misma incidencia se conserva su referencia.', true);
            }
        } finally { busy = false; syncControls(); schedule(); }
    }
    $('state-form').addEventListener('submit', event => {
        event.preventDefault(); if (busy || !authorized) return;
        const next = $('new-state').value;
        if (!transitions().includes(next)) { status('live-status', 'La transición seleccionada ya no está disponible para el estado oficial.', true); syncEditors(); syncControls(); return; }
        if (next === 'CANCELADO' && !$('state-reason').value.trim()) { $('state-reason').reportValidity(); return; }
        if (!window.confirm('Evento ' + eventId + ': solicitar ' + next + '. El servidor validará la transición. ¿Continuar?')) return;
        const payload = { idEvento: eventId, nuevoEstado: next };
        if ($('state-reason').value.trim()) payload.motivo = $('state-reason').value.trim();
        mutate(paths.change, payload, 'Solicitud de transición aceptada.', () => { $('state-reason').value = ''; });
    });
    $('incident-form').addEventListener('submit', event => {
        event.preventDefault(); if (busy || !authorized || official?.estadoEvento !== 'EN_VIVO' || official?.esSimulado !== true) return;
        if ($('participant').value && !official.participantes.some(p => String(p.idParticipante) === $('participant').value)) { status('live-status', 'El participante seleccionado ya no está disponible. Revisa el formulario.', true); return; }
        const payload = { idEvento: eventId, tipoIncidencia: $('incident-type').value };
        if ($('participant').value) payload.idParticipante = $('participant').value;
        if (payload.tipoIncidencia === 'ANOTACION') payload.valorAnotacion = $('annotation').value;
        if ($('description').value.trim()) payload.descripcion = $('description').value.trim();
        const key = JSON.stringify(payload);
        if (!references.has(key)) {
            if (!globalThis.crypto?.randomUUID) { status('live-status', 'El navegador requiere un contexto seguro para generar la referencia de operación.', true); return; }
            references.set(key, crypto.randomUUID());
        }
        payload.referenciaOperacion = references.get(key);
        mutate(paths.register, payload, 'Incidencia registrada.', () => { references.delete(key); $('incident-form').reset(); incidentType(); });
    });
    $('incident-type').addEventListener('change', incidentType);
    $('void-form').addEventListener('submit', event => {
        event.preventDefault(); if (busy || !authorized || !voidId || !['EN_VIVO','PENDIENTE_RESULTADO'].includes(official?.estadoEvento)) return;
        const reason = $('void-reason').value.trim();
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
    $('event-id-form').addEventListener('submit', event => { event.preventDefault(); open($('event-id').value); });
    $('event-select').addEventListener('submit', event => { event.preventDefault(); open($('event-list').value); });
    async function sports() {
        if (catalogBusy || busy) return;
        catalogBusy = true; syncControls(); status('catalog-status', 'Cargando deportes…');
        try {
            if (refreshTask) await refreshTask;
            if (stopped) return;
            const data = await api('/deportes/exploracion');
            if (!Array.isArray(data.deportes)) throw new Error('Respuesta de deportes inválida.');
            $('sport').replaceChildren(option('', 'Selecciona un deporte'));
            data.deportes.forEach(sport => $('sport').append(option(sport.idDeporte, sport.nombre)));
            status('catalog-status', data.deportes.length ? 'Selecciona deporte y busca eventos, o consulta un ID real.' : 'No hay deportes activos. Puedes localizar un evento por ID.');
        } catch (error) { report(error, 'catalog-status'); }
        finally { catalogBusy = false; syncControls(); schedule(); }
    }
    $('sport').addEventListener('change',()=>{if(!busy&&!catalogBusy){window.BetZoneAdmin.resetEvents();$('event-list').replaceChildren(option('','Busca eventos del deporte seleccionado'));$('event-search').requestSubmit();}});
    $('retry-sports').addEventListener('click', sports);
    $('event-search').addEventListener('submit', async event => {
        event.preventDefault(); if (catalogBusy || busy) return;
        catalogBusy = true; syncControls(); $('event-list').replaceChildren(option('', 'Cargando eventos…'));
        status('catalog-status', 'Consultando eventos…');
        try {
            if (refreshTask) await refreshTask;
            if (stopped) return;
            const data = await api(window.BetZoneAdmin.eventsPath($('sport').value));
            if (!Array.isArray(data.eventos)) throw new Error('Respuesta de eventos inválida.');
            $('event-list').replaceChildren(option('', 'Selecciona un evento'));
            window.BetZoneAdmin.pageData(data);data.eventos.forEach(item => $('event-list').append(option(item.idEvento, window.BetZoneAdmin.eventLabel(item))));
            status('catalog-status', data.eventos.length ? 'Eventos devueltos: ' + data.eventos.length + ' en esta página.' : 'No hay eventos en esta consulta. Puedes consultar un ID real.');
        } catch (error) { $('event-list').replaceChildren(option('', 'Sin lista disponible')); report(error, 'catalog-status'); }
        finally { catalogBusy = false; syncControls(); schedule(); }
    });
    document.addEventListener('visibilitychange', () => { if (document.hidden) stopPolling(); else if (official?.estadoEvento === 'EN_VIVO') refresh(); });
    window.addEventListener('pagehide', () => { stopped = true; ++viewVersion; stopPolling(); controllers.forEach(controller => controller.abort()); });
    window.addEventListener('pageshow', event => { if (event.persisted) { stopped = false; authorized = false; if (eventId) refresh(true); } });
    window.BetZoneAdmin.eventPagination($('event-search'));incidentType(); syncControls();
    const initialEvent = new URLSearchParams(location.search).get('idEvento');
    if (initialEvent && /^[0-9]+$/.test(initialEvent) && Number(initialEvent) > 0 && Number(initialEvent) <= 2147483647) {
        sports().then(() => open(initialEvent));
    } else { sports(); }
})();


