(() => {
    "use strict";
    const contextPath = window.APP_CONTEXT_PATH || "";
    const movements = document.body.dataset.walletPage === "movimientos";
    const get = id => document.getElementById(id);
    const section = get("consulta-billetera"), status = get("estado-billetera"), content = get("datos-billetera");
    let controller, version = 0, applied = {params: new URLSearchParams(), limit: 100};
    const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
    const number = value => (typeof value === "number" || typeof value === "string" && /^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?$/.test(value)) && Number.isFinite(Number(value));
    const financialKeys = new Set(["saldoDisponible","saldoComprometido","saldoVirtualTotal","monto","saldoDisponibleAnterior","saldoDisponiblePosterior","variacionSaldoDisponible","saldoComprometidoAnterior","saldoComprometidoPosterior","variacionSaldoComprometido"]);
    function readFinancial(source) {
        let key = null;
        return JSON.parse(source.replace(/"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/g,(token,offset)=>{
            if (token[0] === '"') { key = /^\s*:/.test(source.slice(offset + token.length)) ? JSON.parse(token) : null; return token; }
            const field = key; key = null; return financialKeys.has(field) ? JSON.stringify(token) : token;
        }));
    }
    const id = value => Number.isSafeInteger(value) && value > 0;
    const string = value => typeof value === "string";
    const text = value => string(value) && value.trim().length > 0;
    const nullableText = value => value === null || string(value);
    const nullableId = value => value === null || id(value);
    const display = value => value === null || value === "" ? "No disponible" : String(value);
    function node(tag, className, value) {
        const element = document.createElement(tag);
        if (className) element.className = className;
        if (value !== undefined) element.textContent = value;
        return element;
    }
    function fault(message, session = false) { const error = new Error(message); error.session = session; error.controlled = true; return error; }
    function localDate(value, input = false) {
        if (!string(value)) return null;
        const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,9}))?)?$/.exec(value);
        if (!match || (input && match[7])) return null;
        const [year, month, day, hour, minute, second] = [match[1],match[2],match[3],match[4],match[5],match[6] || "00"].map(Number);
        const leap = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
        const days = [31,leap ? 29 : 28,31,30,31,30,31,31,30,31,30,31];
        if (year < 1 || month < 1 || month > 12 || day < 1 || day > days[month-1] || hour > 23 || minute > 59 || second > 59) return null;
        return {wire: value.length === 16 ? value + ":00" : value, label: match[3] + "/" + match[2] + "/" + match[1] + " · " + match[4] + ":" + match[5] + ":" + (match[6] || "00")};
    }
    const date = value => value === null ? "No informada" : localDate(value).label;
    async function consultar(route, currentController) {
        let timedOut = false;
        const timeout = window.setTimeout(() => { timedOut = true; currentController.abort(); },15000);
        try {
            const response = await fetch(contextPath + route,{method:"GET",credentials:"same-origin",cache:"no-store",headers:{Accept:"application/json"},signal:currentController.signal});
            if (response.status === 401) throw fault("Tu sesión no está disponible o ha expirado. Inicia sesión para consultar tu billetera.",true);
            if (response.redirected) {
                const target = new URL(response.url,window.location.href);
                const login = target.pathname === contextPath + "/usuario/login" || target.pathname === contextPath + "/usuario/login.jsp";
                throw fault(login ? "Tu sesión ha expirado. Inicia sesión para continuar." : "La consulta fue redirigida a una respuesta inesperada.",login);
            }
            if (!response.ok) {
                const errors = {400:"Los parámetros de la consulta no son válidos.",403:"No tienes permiso para consultar esta información.",404:"No se encontró la billetera o la información solicitada.",500:"El servidor no pudo completar la consulta. Intenta nuevamente."};
                throw fault(errors[response.status] || "No fue posible completar la consulta.");
            }
            const type = (response.headers.get("content-type") || "").split(";")[0].trim().toLowerCase();
            if (type !== "application/json") throw fault(type === "text/html" ? "Se recibió HTML en lugar de JSON. Si tu sesión expiró, vuelve a iniciar sesión." : "El servidor devolvió un formato inesperado.",type === "text/html");
            let data;
            try { data = readFinancial(await response.text()); }
            catch (error) { if (currentController.signal.aborted) throw error; throw fault("La respuesta JSON del servidor no es válida."); }
            if (!object(data) || data.ok !== true) throw fault("La respuesta del servidor no contiene un resultado válido.");
            return data;
        } catch (error) {
            if (timedOut) throw fault("La consulta superó el tiempo de espera. Vuelve a intentar.");
            if (error.name === "TypeError") throw fault("No se pudo conectar con el servidor. Revisa tu conexión.");
            throw error;
        } finally { window.clearTimeout(timeout); }
    }
    function estado(message, loading = false, error = false, session = false) {
        content.replaceChildren(); content.hidden = true;
        status.hidden = false; status.classList.toggle("is-loading",loading); status.classList.toggle("is-error",error);
        get("mensaje-billetera").textContent = message;
        get("reintentar-billetera").hidden = !error; get("login-billetera").hidden = !session;
        section.setAttribute("aria-busy",String(loading));
        if (movements) get("cantidad-movimientos").textContent = "";
    }
    function fact(target,title,value) {
        const item = node("div"); item.append(node("dt","",title),node("dd","",display(value))); target.append(item);
    }
    function validarResumen(data) {
        if (!id(data.idUsuario) || !id(data.idBilletera) || !text(data.correo) || !text(data.rol) || !text(data.estadoUsuario)
                || !localDate(data.fechaCreacion) || ["saldoDisponible","saldoComprometido","saldoVirtualTotal"].some(key => !number(data[key]))) throw fault("La información de la billetera está incompleta o tiene un formato inesperado.");
    }
    function resumen(data) {
        const fragment = document.createDocumentFragment(), balances = node("dl","wallet-balances");
        [["Saldo disponible","saldoDisponible","Disponible según esta consulta; no garantiza la aprobación de una próxima apuesta."],["Saldo comprometido","saldoComprometido","Importe informado como comprometido por el servidor."],["Saldo virtual total","saldoVirtualTotal","Total virtual informado por el servidor."]].forEach(([label,key,help]) => {
            const item = node("div","wallet-balance"); item.append(node("dt","",label),node("dd","",String(data[key])),node("dd","muted wallet-balance-help",help)); balances.append(item);
        });
        const info = node("section","panel wallet-info"), facts = node("dl","wallet-facts");
        info.append(node("h2","","Información de la billetera"));
        fact(facts,"Correo",data.correo); fact(facts,"Estado del usuario",data.estadoUsuario); fact(facts,"Rol",data.rol);
        fact(facts,"Billetera",data.idBilletera); fact(facts,"Fecha de creación",date(data.fechaCreacion));
        info.append(facts); fragment.append(balances,info); return fragment;
    }
    function validarMovimientos(data,limit) {
        const amounts = ["monto","saldoDisponibleAnterior","saldoDisponiblePosterior","variacionSaldoDisponible","saldoComprometidoAnterior","saldoComprometidoPosterior","variacionSaldoComprometido"];
        if (!Number.isSafeInteger(data.cantidad) || data.cantidad < 0 || !Array.isArray(data.movimientos) || data.cantidad !== data.movimientos.length || data.cantidad > limit) throw fault("El historial de movimientos está incompleto o tiene un formato inesperado.");
        const ids = new Set();
        for (const item of data.movimientos) {
            if (!object(item) || !id(item.idMovimiento) || ids.has(item.idMovimiento) || !id(item.idTransaccion)
                    || !text(item.referenciaOperacion) || !text(item.tipoTransaccion) || !text(item.nombreTipoTransaccion) || !text(item.estadoTransaccion)
                    || !localDate(item.fechaMovimiento) || !localDate(item.fechaSolicitud) || !(item.fechaProcesamiento === null || localDate(item.fechaProcesamiento))
                    || !nullableText(item.descripcion) || !nullableText(item.usuarioProceso) || !nullableId(item.idUsuarioProceso) || !nullableId(item.idBoleto)
                    || amounts.some(key => !number(item[key]))) throw fault("El servidor devolvió un movimiento incompleto o con datos inesperados.");
            ids.add(item.idMovimiento);
        }
    }
    function movimiento(item) {
        const card = node("article","panel movement"), header = node("div","movement-header"), title = node("div");
        title.append(node("h3","",item.nombreTipoTransaccion),node("p","muted",date(item.fechaMovimiento)));
        header.append(title,node("span","movement-state","Estado: " + item.estadoTransaccion));
        card.append(header,node("p","movement-description",display(item.descripcion)));
        const facts = node("dl","wallet-facts");
        fact(facts,"Monto",item.monto); fact(facts,"Referencia",item.referenciaOperacion); fact(facts,"Tipo de transacción",item.tipoTransaccion);
        fact(facts,"Movimiento",item.idMovimiento); fact(facts,"Transacción",item.idTransaccion); fact(facts,"Boleto asociado",item.idBoleto);
        fact(facts,"Solicitud",date(item.fechaSolicitud)); fact(facts,"Procesamiento",date(item.fechaProcesamiento)); fact(facts,"Procesado por",item.usuarioProceso);
        card.append(facts);
        const balances = node("dl","wallet-facts movement-saldos");
        fact(balances,"Disponible anterior",item.saldoDisponibleAnterior); fact(balances,"Disponible posterior",item.saldoDisponiblePosterior); fact(balances,"Variación disponible",item.variacionSaldoDisponible);
        fact(balances,"Comprometido anterior",item.saldoComprometidoAnterior); fact(balances,"Comprometido posterior",item.saldoComprometidoPosterior); fact(balances,"Variación comprometida",item.variacionSaldoComprometido);
        card.append(balances);
        if (item.idBoleto !== null) {
            const link = node("a","text-link","Abrir comprobante del boleto relacionado ↗");
            link.href = contextPath + "/usuario/boletos/imprimir?idBoleto=" + encodeURIComponent(item.idBoleto);
            link.target = "_blank"; link.rel = "noopener noreferrer"; card.append(link);
        }
        return card;
    }
    function filtros() {
        const error = get("error-filtros");
        error.hidden = true;
        const fields = [get("fecha-desde"),get("fecha-hasta"),get("limite-movimientos")];
        fields.forEach(field => field.removeAttribute("aria-invalid"));
        const reject = (field,message) => { field.setAttribute("aria-invalid","true"); field.focus(); error.textContent = message; error.hidden = false; return null; };
        const params = new URLSearchParams();
        for (const [field,key] of [[fields[0],"fechaDesde"],[fields[1],"fechaHasta"]]) {
            if (field.validity.badInput || (field.value && !localDate(field.value,true))) return reject(field,"Introduce una fecha y hora válidas, con precisión de segundos.");
            if (field.value) params.set(key,localDate(field.value,true).wire);
        }
        if (params.has("fechaDesde") && params.has("fechaHasta") && params.get("fechaDesde") > params.get("fechaHasta")) return reject(fields[1],"La fecha Desde no puede ser posterior a Hasta.");
        const count = fields[2].value.trim();
        if (fields[2].validity.badInput || (count && (!/^\d+$/.test(count) || Number(count) < 1 || Number(count) > 500))) return reject(fields[2],"La cantidad debe ser un número entero entre 1 y 500.");
        if (count) params.set("cantidad",String(Number(count)));
        return {params,limit: count ? Number(count) : 100};
    }
    function notaFiltros() {
        const labels = [];
        if (applied.params.has("fechaDesde")) labels.push("Desde " + date(applied.params.get("fechaDesde")));
        if (applied.params.has("fechaHasta")) labels.push("Hasta " + date(applied.params.get("fechaHasta")));
        labels.push("Máximo " + applied.limit + " movimientos");
        get("filtros-aplicados").textContent = labels.join(" · ");
    }
    async function cargar(next = applied) {
        if (controller) controller.abort();
        const current = ++version;
        applied = next;
        controller = new AbortController(); const currentController = controller;
        if (movements) notaFiltros();
        estado(movements ? "Cargando movimientos…" : "Cargando billetera…",true);
        try {
            const query = movements ? applied.params.toString() : "";
            const data = await consultar("/usuario/billetera/" + (movements ? "movimientos" : "resumen") + (query ? "?" + query : ""),currentController);
            if (current !== version) return;
            if (movements) {
                validarMovimientos(data,applied.limit);
                if (!data.cantidad) {
                    estado(applied.params.size ? "No hay movimientos para los filtros aplicados. Puedes limpiar los filtros." : "Todavía no hay movimientos en tu billetera.");
                    return;
                }
                const fragment = document.createDocumentFragment(); data.movimientos.forEach(item => fragment.append(movimiento(item))); content.replaceChildren(fragment);
                get("cantidad-movimientos").textContent = data.cantidad + (data.cantidad === 1 ? " movimiento mostrado" : " movimientos mostrados");
            } else { validarResumen(data); content.replaceChildren(resumen(data)); }
            status.hidden = true; content.hidden = false;
        } catch (error) {
            if (current !== version) return;
            estado(error.name === "AbortError" ? "La consulta se interrumpió. Vuelve a intentar." : error.controlled ? error.message : "No fue posible completar la consulta.",false,true,error.session === true);
        } finally { if (current === version) section.setAttribute("aria-busy","false"); }
    }
    get("reintentar-billetera").addEventListener("click",() => cargar());
    if (movements) {
        get("filtros-movimientos").addEventListener("submit",event => { event.preventDefault(); const next = filtros(); if (next) cargar(next); });
        get("limpiar-filtros").addEventListener("click",() => {
            get("filtros-movimientos").reset(); get("error-filtros").hidden = true;
            ["fecha-desde","fecha-hasta","limite-movimientos"].forEach(key => get(key).removeAttribute("aria-invalid"));
            cargar({params: new URLSearchParams(),limit:100});
        });
    }
    cargar();
})();
