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
    const number = new Intl.NumberFormat('es-GT', { maximumFractionDigits: 0 });
    const currency = new Intl.NumberFormat('es-GT', { style: 'currency', currency: 'GTQ' });
    const numeric = value => (typeof value === 'number' || (typeof value === 'string' && value.trim() !== '')) && Number.isFinite(Number(value));
    const format = (value, money = false) => numeric(value) ? (money ? currency : number).format(Number(value)) : '—';
    const text = value => value === null || value === undefined || value === '' ? '—' : String(value);
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
    }
    async function load() {
        const button = filters.querySelector('button');
        if (button.disabled) return;
        button.disabled = true;
        content.setAttribute('aria-busy', 'true');
        sessionLink.hidden = true;
        clear();
        message('dashboard-status', 'Cargando resumen…');
        try {
            const query = new URLSearchParams(new FormData(filters));
            const data = await window.BetZoneAdmin.request('/administrador/dashboard/resumen?' + query);
            if (data.ok !== true || !data.resumen || !Array.isArray(data.deportes) || !Array.isArray(data.auditoriaReciente)) {
                throw new Error('invalid-response');
            }
            content.querySelectorAll('[data-metric]').forEach(element => { element.textContent = format(data.resumen[element.dataset.metric]); });
            content.querySelectorAll('[data-money]').forEach(element => { element.textContent = format(data.resumen[element.dataset.money], true); });
            table('sports-body', data.deportes, [r => text(r.deporte), r => format(r.eventosTotales), r => format(r.enProgreso), r => format(r.boletosRelacionados), r => format(r.montoApostadoRelacionado, true)], 'No hay actividad por deporte.');
            // LocalDateTime llega sin zona: se conserva la hora del servidor, sin reinterpretarla.
            table('audit-body', data.auditoriaReciente, [r => text(r.fechaAccion).replace('T', ' '), r => text(r.correo), r => text(r.accion), r => text(r.tablaAfectada), r => text(r.idRegistro)], 'No hay acciones de auditoría recientes.');
            message('dashboard-status', 'Actualizado a las ' + new Date().toLocaleTimeString('es-GT') + '. Importes en GTQ.');
        } catch (error) {
            if (leaving) return;
            clear();
            sessionLink.hidden = error.status !== 401;
            message('dashboard-status', error.status ? error.message : error.name === 'AbortError' || error instanceof TypeError
                ? networkError(error) : 'El servidor no devolvió un resumen válido. Inténtalo de nuevo.', true);
        } finally {
            content.setAttribute('aria-busy', 'false');
            button.disabled = false;
        }
    }
    filters.addEventListener('submit', event => { event.preventDefault(); load(); });
    load();
})();
