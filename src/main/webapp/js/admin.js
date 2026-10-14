(() => {
    'use strict';
    const base = document.body.dataset.contextPath || '';
    const loginUrl = base + '/administrador/login';
    const homeUrl = base + '/administrador/inicio.jsp';
    const message = (id, text, error = false) => {
        const element = document.getElementById(id);
        element.textContent = text;
        element.dataset.error = String(error);
    };
    const errors = {
        400: 'Los parámetros no son válidos. Revisa los datos e inténtalo de nuevo.',
        401: 'Tu sesión venció o no está disponible. Vuelve a iniciar sesión.',
        403: 'Tu cuenta no tiene permiso para realizar esta consulta.',
        503: 'El servicio no está disponible temporalmente. Inténtalo de nuevo.'
    };
    async function request(path, options = {}) {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), 20000);
        try {
            return await fetch(base + path, {
                credentials: 'same-origin', cache: 'no-store', ...options,
                signal: controller.signal
            });
        } finally { clearTimeout(timer); }
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
            button.disabled = true;
            message('login-status', 'Validando acceso…');
            try {
                const response = await request('/administrador/login', {
                    method: 'POST', body: new URLSearchParams(new FormData(login))
                });
                // El servlet responde 303 al JSP protegido; fetch sigue esa redirección.
                if (response.ok && response.redirected && new URL(response.url).pathname === homeUrl) {
                    location.replace(homeUrl);
                    return;
                }
                login.elements.contrasena.value = '';
                message('login-status', response.status === 400 || response.status === 401
                    ? 'No fue posible iniciar sesión con los datos proporcionados.'
                    : 'No fue posible iniciar sesión. Inténtalo de nuevo.', true);
                login.elements.contrasena.focus();
            } catch (error) { message('login-status', networkError(error), true); }
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
            try {
                const tokenResponse = await request('/administrador/seguridad/csrf', { headers: { Accept: 'application/json' } });
                if (tokenResponse.status === 401) { location.replace(loginUrl); return; }
                if (!tokenResponse.ok) throw failure(tokenResponse);
                const token = await tokenResponse.json();
                if (token.ok !== true || typeof token.csrfToken !== 'string' || !token.csrfToken) throw new Error('token');
                const response = await request('/administrador/logout', {
                    method: 'POST', headers: { 'X-CSRF-Token': token.csrfToken }
                });
                if (response.status === 401 || (response.ok && response.redirected && new URL(response.url).pathname === loginUrl)) {
                    location.replace(loginUrl);
                    return;
                }
                throw failure(response);
            } catch (error) { message('logout-status', error.status ? error.message : networkError(error), true); }
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
            const response = await request('/administrador/dashboard/resumen?' + query, { headers: { Accept: 'application/json' } });
            if (!response.ok) throw failure(response);
            if (response.redirected) { const error = new Error(errors[401]); error.status = 401; throw error; }
            const data = await response.json();
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
    window.addEventListener('pageshow', event => { if (event.persisted) load(); });
    load();
})();
