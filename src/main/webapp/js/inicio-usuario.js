(() => {
    "use strict";
    const dashboard = document.getElementById("contenido");
    if (!dashboard) return;
    const contextPath = dashboard.dataset.contextPath || "";
    const integer = new Intl.NumberFormat("es-GT", { maximumFractionDigits: 0 });
    const counts = new Set(["cantidadBoletos", "boletosPendientes", "boletosGanadores", "boletosPerdedores", "boletosAnulados"]);
    const signed = new Set(["resultadoNetoRealizado", "gananciaNetaPotencialPendiente"]);
    const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
    function fallo(message) { const error = new Error(message); error.controlled = true; return error; }

    // JSON.parse convierte decimales a Number. Esta segunda lectura conserva sus
    // tokens originales como texto para presentarlos sin redondeo ni aritmetica.
    // Las cadenas JSON (incluidas claves y escapes) se mantienen intactas.
    function leerRespuesta(source) {
        const data = JSON.parse(source);
        const exact = JSON.parse(source.replace(/"(?:[^"\\]|\\.)*"|(-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)/g,
            (token, numeric) => numeric === undefined ? token : JSON.stringify(numeric)));
        if (!object(data) || data.ok !== true) throw fallo("No fue posible obtener los datos. Intenta nuevamente.");
        return {data, exact};
    }

    async function consultar(ruta) {
        const controller = new AbortController();
        let timeout;
        try {
            const consulta = async () => {
                const response = await fetch(contextPath + ruta, {
                    method: "GET", credentials: "same-origin", cache: "no-store",
                    headers: { Accept: "application/json" }, signal: controller.signal
                });
                if (response.redirected || response.status === 401) {
                    throw fallo("La consulta no pudo completarse con tu sesión actual. Vuelve a iniciar sesión si ha expirado.");
                }
                if (!response.ok) {
                    const messages = {400: "Los datos de la consulta no son válidos.", 403: "No tienes permiso para consultar este resumen.",
                        404: "El resumen solicitado no está disponible.", 500: "El servidor no pudo cargar este resumen.", 503: "Este resumen no está disponible temporalmente."};
                    throw fallo(messages[response.status] || "No fue posible completar la consulta. Intenta nuevamente.");
                }
                if (!/^application\/json\s*(?:;|$)/i.test(response.headers.get("content-type") || "")) {
                    throw fallo("No se recibió JSON válido. Si tu sesión expiró, vuelve a iniciar sesión.");
                }
                const source = await response.text();
                try { return leerRespuesta(source); }
                catch (error) {
                    if (error.controlled) throw error;
                    throw fallo("La respuesta JSON no es válida. Intenta nuevamente.");
                }
            };
            const espera = new Promise((_, reject) => {
                timeout = window.setTimeout(() => {
                    reject(fallo("La consulta está tardando demasiado. Intenta nuevamente."));
                    controller.abort();
                }, 15000);
            });
            return await Promise.race([consulta(), espera]);
        } catch (error) {
            if (error && error.controlled) throw error;
            throw fallo("No se pudo conectar con el servidor. Revisa tu conexión e intenta nuevamente.");
        } finally { window.clearTimeout(timeout); }
    }

    function prepararPanel(id, ruta, analitica) {
        const panel = document.getElementById(id);
        const status = panel.querySelector(".data-status");
        const grids = [...panel.querySelectorAll("dl")];
        const retry = panel.querySelector(".retry");
        const fields = [...panel.querySelectorAll("[data-field]")];
        const loadingText = status.textContent;
        let loading = false;
        async function cargar() {
            if (loading) return;
            loading = true;
            panel.setAttribute("aria-busy", "true");
            grids.forEach(grid => grid.classList.add("is-loading"));
            status.classList.remove("is-error");
            status.textContent = loadingText;
            retry.hidden = true;
            fields.forEach(field => { field.textContent = "—"; });
            try {
                const {data, exact} = await consultar(ruta);
                const values = analitica ? data.resumen : data;
                const originals = analitica ? exact.resumen : exact;
                if (!object(values) || !object(originals)) throw fallo("El resumen recibido no es válido. Intenta nuevamente.");
                const rendered = fields.map(field => {
                    const key = field.dataset.field;
                    if (!Object.prototype.hasOwnProperty.call(values, key)) throw fallo("El resumen recibido está incompleto. Intenta nuevamente.");
                    const value = values[key];
                    if (value === null && analitica && key !== "cantidadBoletos") return "No disponible";
                    if (typeof value !== "number" || !Number.isFinite(value)
                            || (counts.has(key) && (!Number.isSafeInteger(value) || value < 0 || value > values.cantidadBoletos))
                            || (analitica && !signed.has(key) && value < 0)) {
                        throw fallo("El resumen recibido contiene valores inesperados. Intenta nuevamente.");
                    }
                    return counts.has(key) ? integer.format(value) : originals[key];
                });
                fields.forEach((field, index) => { field.textContent = rendered[index]; });
                status.textContent = analitica && values.cantidadBoletos === 0
                    ? "No hay boletos registrados. Se muestran los valores informados por el backend; los campos sin información indican No disponible."
                    : "Datos consultados correctamente.";
            } catch (error) {
                status.classList.add("is-error");
                status.textContent = error && error.controlled ? error.message : "No fue posible cargar este resumen. Intenta nuevamente.";
                retry.hidden = false;
            } finally {
                panel.setAttribute("aria-busy", "false");
                grids.forEach(grid => grid.classList.remove("is-loading"));
                loading = false;
            }
        }
        retry.addEventListener("click", cargar);
        cargar();
    }
    prepararPanel("resumen-billetera", "/usuario/billetera/resumen", false);
    prepararPanel("resumen-actividad", "/usuario/analitica/resumen", true);
})();
