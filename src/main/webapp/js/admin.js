(() => {
    'use strict';
    const base = document.body.dataset.contextPath || '';
    const loginUrl = base + '/administrador/login';
    const landingPaths = ['inicio', 'eventos', 'liquidaciones'].map(view => base + '/administrador/' + view);
    let leaving = false;
    const pending = new Set();
    window.addEventListener('pagehide', () => { leaving = true; pending.forEach(controller => controller.abort()); });
    document.querySelectorAll('.table-scroll').forEach(element => {
        element.tabIndex = 0;
        element.setAttribute('role', 'region');
        element.setAttribute('aria-label', element.querySelector('caption')?.textContent || 'Tabla con desplazamiento horizontal');
    });
    const message = (id, text, error = false) => {
        const element = document.getElementById(id);
        element.textContent = text;
        element.dataset.error = String(error);
    };
    const errors = {
        400: 'Los parámetros no son válidos. Revisa los datos e inténtalo de nuevo.',
        401: 'Tu sesión venció o no está disponible. Vuelve a iniciar sesión.',
        403: 'Tu cuenta no tiene permiso para realizar esta consulta.',
        404: 'No se encontró el recurso solicitado.',
        405: 'El servidor no admite este método.',
        409: 'La operación no corresponde al estado actual.',
        500: 'El servidor no pudo confirmar la operación. Verifica el estado antes de repetirla.',
        503: 'El servicio no está disponible temporalmente. Inténtalo de nuevo.'
    };
    async function request(path, options = {}) {
        const controller = new AbortController();
        pending.add(controller);
        const timer = setTimeout(() => controller.abort(), 20000);
        try {
            return await fetch(base + path, {
                credentials: 'same-origin', cache: 'no-store', ...options,
                signal: controller.signal
            });
        } finally { clearTimeout(timer); pending.delete(controller); }
    }
    function failure(response) {
        const error = new Error(errors[response.status] || 'No fue posible procesar la solicitud. Inténtalo de nuevo.');
        error.status = response.status;
        return error;
    }
    const networkError = error => error.name === 'AbortError'
        ? 'La solicitud tardó demasiado. Inténtalo de nuevo.'
        : 'No fue posible conectar con el servidor. Inténtalo de nuevo.';
    const login = document.getElementById('admin-login');
    if (login) {
        login.addEventListener('submit', async event => {
            event.preventDefault();
            const button = login.querySelector('button');
            if (button.disabled) return;
            if (!login.reportValidity()) return;
            button.disabled = true;
            message('login-status', 'Validando acceso…');
            try {
                const response = await request('/administrador/login', {
                    method: 'POST', body: new URLSearchParams(new FormData(login))
                });
                // El servlet responde 303 a la vista permitida; fetch sigue esa redirección.
                const destination = new URL(response.url, location.href);
                if (response.ok && response.redirected && destination.origin === location.origin && landingPaths.includes(destination.pathname)) {
                    location.replace(destination.pathname);
                    return;
                }
                login.elements.contrasena.value = '';
                message('login-status', response.status === 400 || response.status === 401
                    ? 'No fue posible iniciar sesión con los datos proporcionados.'
                    : 'No fue posible iniciar sesión. Inténtalo de nuevo.', true);
                login.elements.contrasena.focus();
            } catch (error) { if (!leaving) message('login-status', networkError(error), true); }
            finally { button.disabled = false; }
        });
    }
    const logout = document.getElementById('admin-logout');
    if (logout) {
        logout.addEventListener('submit', async event => {
            event.preventDefault();
            const button = logout.querySelector('button');
            if (button.disabled) return;
            button.disabled = true;
            message('logout-status', 'Cerrando sesión…');
            let sent = false;
            try {
                const token = await window.BetZoneAdmin.csrf();
                sent = true;
                const response = await request('/administrador/logout', {
                    method: 'POST', headers: { 'X-CSRF-Token': token }
                });
                const destination = new URL(response.url, location.href);
                if (response.status === 401 || (response.ok && response.redirected
                        && destination.origin === location.origin && destination.pathname === loginUrl)) {
                    location.replace(loginUrl);
                    return;
                }
                if (response.ok) throw new Error('El servidor no confirmó el cierre de sesión. Verifica el estado antes de repetirlo.');
                throw failure(response);
            } catch (error) {
                if (leaving) return;
                if (error.status === 401) { location.replace(loginUrl); return; }
                message('logout-status', error.status ? error.message
                    : error.name === 'AbortError' || error instanceof TypeError
                        ? sent ? 'No se pudo confirmar el cierre de sesión. Verifica el estado antes de repetirlo.' : networkError(error)
                        : error.message, true);
            }
            finally { button.disabled = false; }
        });
    }
    const filters = document.getElementById('dashboard-filters');
    if (!filters) return;
    const content = document.getElementById('dashboard-data');
    const sessionLink = document.getElementById('session-login');
    const analytics = document.getElementById('analytics-filters');
    const analyticsContent = document.getElementById('analytics-data');
    const sportSelect = document.getElementById('analytics-sport');
    const api = window.BetZoneAdmin;
    const authorized = ['ADMINISTRADOR', 'AUDITOR'].includes(document.body.dataset.adminRole);
    const number = new Intl.NumberFormat('es-GT', { maximumFractionDigits: 0 });
    const currency = new Intl.NumberFormat('es-GT', { style: 'currency', currency: 'GTQ', minimumFractionDigits: 2, maximumFractionDigits: 2 });
    const views = ['TODOS', 'PROGRAMADOS', 'PREVIA', 'EN_PROGRESO', 'PENDIENTE_RESULTADO', 'FINALIZADOS', 'BORRADOR', 'SUSPENDIDOS', 'CANCELADOS'];
    const modalityNames = { CONVENCIONAL: 'Convencional', MARCADOR_FINAL: 'Marcador final', PRIMERA_ANOTACION: 'Primera anotación' };
    const summaryState = { busy: false, revision: 0 }, analyticsState = { busy: false, revision: 0 };
    let incomplete = false;
    const issue = () => { throw new Error('El servidor devolvió una estructura incompleta o inconsistente.'); };
    const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
    const active = () => !leaving && !document.getElementById('contenido').hidden;
    // Se valida el JSON original y se preserva cada token numérico, sin tocar textos escapados.
    // El transporte compartido mantiene la validación de ok, HTTP, sesión y tipo de contenido.
    function exactJson(raw) {
        JSON.parse(raw);
        return JSON.parse(raw.replace(/"(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/g,
            token => token[0] === '"' ? token : JSON.stringify(token)));
    }
    function decimal(value, scale = 2, signed = false) {
        if (typeof value === 'number' && !Number.isSafeInteger(value)) return null;
        if (typeof value !== 'string' && typeof value !== 'number') return null;
        const match = /^(-?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$/.exec(String(value));
        if (!match || (!signed && match[1])) return null;
        const exponent = Number(match[4] || 0);
        if (!Number.isInteger(exponent) || Math.abs(exponent) > 100) return null;
        const digits = match[2] + (match[3] || ''), point = match[2].length + exponent;
        const whole = (point <= 0 ? '0' : digits.slice(0, point).padEnd(point, '0')).replace(/^0+(?=\d)/, '');
        const fraction = (point < 0 ? '0'.repeat(-point) + digits : digits.slice(point)).replace(/0+$/, '');
        if (whole.length > 36 || fraction.length > scale) return null;
        return { whole, fraction, negative: match[1] === '-' };
    }
    function format(value, money = false, signed = false) {
        const parsed = decimal(value, money ? 2 : 0, signed);
        if (!parsed) { incomplete = true; return '—'; }
        const grouped = number.format(BigInt(parsed.whole));
        if (!money) return (parsed.negative ? '-' : '') + grouped;
        // Solo se formatea con Number el patrón ±1; los dígitos y centavos oficiales son cadenas exactas.
        return currency.formatToParts(parsed.negative ? -1 : 1).map(part => part.type === 'integer'
            ? grouped : part.type === 'fraction' ? parsed.fraction.padEnd(2, '0') : part.value).join('');
    }
    function id(value) {
        const parsed = decimal(value, 0);
        return parsed && BigInt(parsed.whole) > 0n && BigInt(parsed.whole) <= 2147483647n ? parsed.whole : null;
    }
    const text = value => {
        if (value === null || value === undefined || value === '') return '—';
        if (typeof value === 'string') return value;
        incomplete = true; return '—';
    };
    function date(value) {
        if (value === null || value === undefined) return '—';
        if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,9})?)?$/.test(value)) {
            incomplete = true; return '—';
        }
        return value.replace('T', ' '); // LocalDateTime: sin convertir zona horaria.
    }
    function table(id, rows, columns, empty) {
        const body = document.getElementById(id);
        body.replaceChildren();
        if (!rows.length) {
            const row = body.insertRow();
            const cell = row.insertCell();
            cell.colSpan = columns.length;
            cell.textContent = empty;
            return;
        }
        for (const item of rows) {
            const row = body.insertRow();
            for (const column of columns) row.insertCell().textContent = column(item);
        }
    }
    function clear() {
        content.querySelectorAll('[data-metric], [data-money]').forEach(element => { element.textContent = '—'; });
        document.getElementById('sports-body').replaceChildren();
        document.getElementById('audit-body').replaceChildren();
        document.getElementById('house-body').replaceChildren();
    }
    function clearAnalytics() {
        document.getElementById('analytics-body').replaceChildren();
        document.getElementById('modalities-body').replaceChildren();
    }
    function block(form, busy) {
        form.querySelectorAll('select, button').forEach(element => { element.disabled = busy || !authorized; });
    }
    function query(form, eventQuery = false) {
        const hours = form.elements.horasPrevia.value;
        const amount = form.elements[eventQuery ? 'cantidad' : 'cantidadAuditoria'].value;
        if (!['24', '48', '72'].includes(hours) || !(eventQuery ? ['25', '50', '100', '250', '500'] : ['10', '25', '50', '100']).includes(amount)) {
            throw new Error('Selecciona filtros válidos antes de consultar.');
        }
        const result = new URLSearchParams({ horasPrevia: hours });
        if (eventQuery) {
            const view = form.elements.vista.value, sport = sportSelect.value;
            if (!views.includes(view) || (sport && (!id(sport) || ![...sportSelect.options].some(option => option.value === sport)))) {
                throw new Error('Selecciona un deporte y un estado válidos.');
            }
            result.set('vista', view); result.set('cantidad', amount);
            if (sport) result.set('idDeporte', sport);
        } else result.set('cantidadAuditoria', amount);
        return result;
    }
    function validate(data, requested, eventQuery = false) {
        if (!object(data) || data.ok !== true || !object(data.filtros)
                || !Array.isArray(data.modalidades) || !Array.isArray(data.conciliacionCasa)) issue();
        for (const [key, value] of requested) if (String(data.filtros[key]) !== value) issue();
        if (eventQuery && !requested.has('idDeporte') && data.filtros.idDeporte !== null) issue();
        const rows = eventQuery ? data.eventos : data.deportes;
        if (!Array.isArray(rows) || rows.some(row => !object(row))) issue();
        const key = eventQuery ? 'idEvento' : 'idDeporte', name = eventQuery ? 'evento' : 'deporte';
        if (rows.some(row => !id(row[key]) || typeof row[name] !== 'string' || !row[name].trim())
                || new Set(rows.map(row => id(row[key]))).size !== rows.length) issue();
        if (eventQuery) {
            if (rows.length > Number(requested.get('cantidad')) || rows.some(row => !id(row.idDeporte)
                    || (requested.has('idDeporte') && id(row.idDeporte) !== requested.get('idDeporte')))) issue();
        } else if (!object(data.resumen) || !Object.keys(data.resumen).length || !Array.isArray(data.auditoriaReciente)
                || data.auditoriaReciente.length > Number(requested.get('cantidadAuditoria'))
                || data.auditoriaReciente.some(row => !object(row))) issue();
        const modalities = new Set(), events = new Set(rows.map(row => id(row.idEvento)));
        for (const row of data.modalidades) {
            if (!object(row) || !id(row.idEvento) || !Object.hasOwn(modalityNames, row.tipoMercadoAplicado)
                    || (eventQuery && !events.has(id(row.idEvento)))) issue();
            const key = id(row.idEvento) + ':' + row.tipoMercadoAplicado;
            if (modalities.has(key)) issue(); modalities.add(key);
        }
        const wallets = new Set();
        for (const row of data.conciliacionCasa) {
            if (!object(row) || !id(row.idBilletera) || wallets.has(id(row.idBilletera))) issue();
            wallets.add(id(row.idBilletera));
        }
    }
    function report(id, error) {
        message(id, error.name === 'AbortError' || error instanceof TypeError ? networkError(error) : error.message, true);
    }
    function complete(id, label) {
        message(id, label + (incomplete ? ' Hay valores ausentes o inválidos: se muestran como —, sin sustituirlos por cero.' : ''), incomplete);
    }
    async function load() {
        if (!authorized || summaryState.busy || !active()) return;
        let requested;
        try { requested = query(filters); } catch (error) { clear(); report('dashboard-status', error); return; }
        const revision = ++summaryState.revision;
        summaryState.busy = true; block(filters, true);
        content.setAttribute('aria-busy', 'true');
        sessionLink.hidden = true;
        clear();
        message('dashboard-status', 'Cargando resumen…');
        try {
            const data = await api.request('/administrador/dashboard/resumen?' + requested, {}, exactJson);
            if (!active() || revision !== summaryState.revision || String(query(filters)) !== String(requested)) return;
            validate(data, requested);
            incomplete = false;
            content.querySelectorAll('[data-metric]').forEach(element => { element.textContent = format(data.resumen[element.dataset.metric]); });
            content.querySelectorAll('[data-money]').forEach(element => { element.textContent = format(data.resumen[element.dataset.money], true, element.dataset.money === 'resultadoCasaRealizado'); });
            table('sports-body', data.deportes, [r => text(r.deporte), r => format(r.eventosTotales), r => format(r.enProgreso), r => format(r.boletosRelacionados), r => format(r.clientesUnicos), r => format(r.boletosPendientes), r => format(r.montoApostadoRelacionado, true), r => format(r.premioPotencialPendienteRelacionado, true)], 'No hay actividad por deporte.');
            table('audit-body', data.auditoriaReciente, [r => date(r.fechaAccion), r => r.correo === null || r.correo === undefined ? 'No disponible' : r.correo === '' ? 'Correo vacío' : text(r.correo), r => text(r.accion), r => text(r.tablaAfectada), r => r.idRegistro == null ? '—' : format(r.idRegistro, false, true)], 'No hay acciones de auditoría recientes.');
            table('house-body', data.conciliacionCasa, [r => id(r.idBilletera), r => format(r.saldoDisponible, true), r => format(r.saldoComprometido, true), r => format(r.reservasBoletos, true), r => format(r.diferencia, true, true), r => format(r.reservasFueraDePendiente)], 'No se recibieron registros de conciliación CASA.');
            [...document.getElementById('house-body').rows].forEach((row, index) => {
                const wallet = data.conciliacionCasa[index]; if (!wallet) return;
                const difference = decimal(wallet.diferencia, 2, true), outside = decimal(wallet.reservasFueraDePendiente, 0);
                if ((difference && /[1-9]/.test(difference.whole + difference.fraction)) || (outside && BigInt(outside.whole) > 0n)) row.classList.add('warning');
            });
            const previousSport = sportSelect.value;
            sportSelect.replaceChildren(api.option('', 'Todos los deportes'));
            data.deportes.forEach(row => sportSelect.append(api.option(id(row.idDeporte), row.deporte)));
            if ([...sportSelect.options].some(option => option.value === previousSport)) sportSelect.value = previousSport;
            if (sportSelect.value !== previousSport) { ++analyticsState.revision; clearAnalytics(); message('analytics-status', 'La selección de deportes cambió. Consulta nuevamente.'); }
            complete('dashboard-status', 'Consulta recibida a las ' + new Date().toLocaleTimeString('es-GT') + '. Previa: ' + requested.get('horasPrevia') + ' h; auditoría: hasta ' + requested.get('cantidadAuditoria') + ' registros. Importes en GTQ.');
        } catch (error) {
            if (!active() || revision !== summaryState.revision) return;
            clear();
            sessionLink.hidden = error.status !== 401;
            report('dashboard-status', error);
        } finally {
            summaryState.busy = false;
            if (active()) { content.setAttribute('aria-busy', 'false'); block(filters, false); }
        }
    }
    async function loadAnalytics() {
        if (!authorized || analyticsState.busy || !active()) return;
        let requested;
        try { requested = query(analytics, true); } catch (error) { clearAnalytics(); report('analytics-status', error); return; }
        const revision = ++analyticsState.revision;
        analyticsState.busy = true; block(analytics, true); clearAnalytics();
        analyticsContent.setAttribute('aria-busy', 'true'); message('analytics-status', 'Consultando actividad por evento…');
        try {
            const data = await api.request('/administrador/analitica/eventos?' + requested, {}, exactJson);
            if (!active() || revision !== analyticsState.revision || String(query(analytics, true)) !== String(requested)) return;
            validate(data, requested, true); incomplete = false;
            table('analytics-body', data.eventos, [r => [r.evento, r.liga, r.deporte].map(text).join(' · '), r => text(r.estadoEvento) + ' / ' + text(r.estadoVisual), r => date(r.fechaInicio), r => format(r.mercadosAbiertos) + ' / ' + format(r.cantidadMercados), r => format(r.boletosRelacionados), r => format(r.clientesUnicos), r => format(r.montoApostadoRelacionado, true), r => format(r.premioPotencialPendienteRelacionado, true), r => format(r.exposicionPotencialRelacionada, true), r => format(r.resultadoCasaRealizadoRelacionado, true, true)], 'No hay eventos para los filtros consultados.');
            const events = new Map(data.eventos.map(row => [id(row.idEvento), row.evento]));
            table('modalities-body', data.modalidades, [r => events.get(id(r.idEvento)), r => modalityNames[r.tipoMercadoAplicado], r => format(r.cantidadDetalles), r => format(r.marcadoresExactos), r => format(r.aciertosResultado), r => format(r.aciertosPrimeraAnotacion)], 'No hay modalidades para los eventos consultados.');
            complete('analytics-status', 'Se recibieron ' + data.eventos.length + ' eventos; límite solicitado: ' + requested.get('cantidad') + '. Esta consulta no ofrece total general ni paginación.');
        } catch (error) {
            if (!active() || revision !== analyticsState.revision) return;
            clearAnalytics(); report('analytics-status', error);
        } finally {
            analyticsState.busy = false;
            if (active()) { analyticsContent.setAttribute('aria-busy', 'false'); block(analytics, false); }
        }
    }
    filters.addEventListener('change', () => { ++summaryState.revision; clear(); message('dashboard-status', 'Filtros modificados. Actualiza el resumen para consultarlos.'); });
    analytics.addEventListener('change', () => { ++analyticsState.revision; clearAnalytics(); message('analytics-status', 'Filtros modificados. Consulta nuevamente los eventos.'); });
    filters.addEventListener('submit', event => { event.preventDefault(); load(); });
    analytics.addEventListener('submit', event => { event.preventDefault(); loadAnalytics(); });
    if (authorized) load();
    else { clear(); clearAnalytics(); block(filters, true); block(analytics, true); message('dashboard-status', errors[403], true); message('analytics-status', errors[403], true); }
})();
