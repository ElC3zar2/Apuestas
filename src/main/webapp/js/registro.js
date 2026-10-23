// =========================================================
// BETZONE — registro.jsp
// Mismo comportamiento funcional del formulario original,
// + toggle de contraseña y floating labels para el nuevo diseño.
// =========================================================

document.addEventListener("DOMContentLoaded", () => {
  initPasswordToggles();
  initFloatingLabels();
  initSincronizacionPaises();
});

function initSincronizacionPaises() {
  const paisTelefono = document.getElementById("idPaisTelefono");
  const pais = document.getElementById("idPais");

  const sincronizar = () => {
    pais.value = paisTelefono.value;
    cambiarPais();
  };

  paisTelefono.addEventListener("change", sincronizar);

  // Respeta una residencia ya seleccionada al cargar la página.
  if (!pais.value && paisTelefono.value) {
    sincronizar();
  } else {
    cambiarPais();
  }
}

/**
 * Alterna la visibilidad de los inputs de contraseña
 * que tengan un botón .field__toggle asociado.
 */
function initPasswordToggles() {
  document.querySelectorAll(".field__toggle").forEach((btn) => {
    btn.addEventListener("click", () => {
      const input = document.getElementById(btn.dataset.target);
      if (!input) return;
      const showing = input.type === "text";
      input.type = showing ? "password" : "text";
      btn.setAttribute(
        "aria-label",
        showing ? "Mostrar contraseña" : "Ocultar contraseña"
      );
    });
  });
}

/**
 * Fallback en JS para navegadores donde :placeholder-shown
 * no cubra casos de autocompletado del navegador.
 */
function initFloatingLabels() {
  document.querySelectorAll(".field__input").forEach((input) => {
    const sync = () => input.classList.toggle("has-value", input.value.length > 0);
    input.addEventListener("input", sync);
    input.addEventListener("blur", sync);
    sync();
  });
}

/*
 * =====================================================
 * VALIDACIÓN DEL DOCUMENTO (lógica original, sin cambios)
 * =====================================================
 */
function cambiarTipoDocumento() {

    const tipoDocumento = document.getElementById("tipoDocumento").value;
    const numeroDocumento = document.getElementById("numeroDocumento");
    const ayudaDocumento = document.getElementById("ayudaDocumento");

    numeroDocumento.placeholder = " ";

    /* DPI DE GUATEMALA */
    if (tipoDocumento === "DPI") {

        numeroDocumento.value = "";
        numeroDocumento.maxLength = 13;
        numeroDocumento.minLength = 13;
        numeroDocumento.pattern = "[0-9]{13}";
        numeroDocumento.title = "El DPI debe contener exactamente 13 dígitos.";
        ayudaDocumento.textContent = "El DPI debe contener 13 dígitos.";

    }
    /* PASAPORTE */
    else if (tipoDocumento === "PASAPORTE") {

        numeroDocumento.value = "";
        numeroDocumento.maxLength = 50;
        numeroDocumento.removeAttribute("minlength");
        numeroDocumento.removeAttribute("pattern");
        numeroDocumento.title = "Ingrese el número de pasaporte.";
        ayudaDocumento.textContent = "El formato depende del país.";

    }
    /* OTRO DOCUMENTO */
    else if (tipoDocumento === "OTRO") {

        numeroDocumento.value = "";
        numeroDocumento.maxLength = 50;
        numeroDocumento.removeAttribute("minlength");
        numeroDocumento.removeAttribute("pattern");
        numeroDocumento.title = "Ingrese el número del documento.";
        ayudaDocumento.textContent = "Máximo 50 caracteres.";

    }
    /* NINGÚN TIPO SELECCIONADO */
    else {

        numeroDocumento.value = "";
        numeroDocumento.maxLength = 50;
        numeroDocumento.removeAttribute("minlength");
        numeroDocumento.removeAttribute("pattern");
        ayudaDocumento.textContent = "";
    }

    // Sincroniza el floating label tras el reset programático del valor.
    numeroDocumento.classList.remove("has-value");
}


/*
 * =====================================================
 * CAMBIO DE PAÍS
 * =====================================================
 */
function cambiarPais() {

    const pais = document.getElementById("idPais");
    const opcion = pais.options[pais.selectedIndex];
    const codigo = opcion.getAttribute("data-codigo");

    const bloqueGuatemala = document.getElementById("bloqueGuatemala");
    const bloqueExterior = document.getElementById("bloqueExterior");

    const departamento = document.getElementById("idDepartamento");
    const municipio = document.getElementById("idMunicipio");
    const ciudadExterior = document.getElementById("ciudadExterior");

    if (codigo !== "GT") {
        invalidarConsultaMunicipios();
        mostrarEstadoMunicipios("Seleccione primero un departamento");
    }

    /*
     * GUATEMALA
     * Departamento obligatorio. Municipio obligatorio. Ciudad exterior bloqueada.
     */
    if (codigo === "GT") {

        bloqueGuatemala.style.display = "grid";
        bloqueExterior.style.display = "none";

        departamento.disabled = false;
        departamento.required = true;

        municipio.required = true;

        ciudadExterior.disabled = true;
        ciudadExterior.required = false;
        ciudadExterior.value = "";
        ciudadExterior.classList.remove("has-value");
        cargarMunicipios();
    }
    /*
     * PAÍS EXTRANJERO
     * Departamento bloqueado. Municipio bloqueado. Ciudad exterior obligatoria.
     */
    else if (codigo) {

        bloqueGuatemala.style.display = "none";
        bloqueExterior.style.display = "block";

        departamento.disabled = true;
        departamento.required = false;
        departamento.value = "";

        municipio.disabled = true;
        municipio.required = false;

        ciudadExterior.disabled = false;
        ciudadExterior.required = true;
    }
    /*
     * NINGÚN PAÍS
     */
    else {

        bloqueGuatemala.style.display = "none";
        bloqueExterior.style.display = "none";

        departamento.disabled = true;
        departamento.required = false;

        municipio.disabled = true;
        municipio.required = false;

        ciudadExterior.disabled = true;
        ciudadExterior.required = false;
        ciudadExterior.value = "";
        ciudadExterior.classList.remove("has-value");
    }
}


/*
 * =====================================================
 * CARGAR MUNICIPIOS
 * =====================================================
 */
let solicitudMunicipios = 0;
let controladorMunicipios = null;

function invalidarConsultaMunicipios() {
    solicitudMunicipios += 1;
    if (controladorMunicipios) controladorMunicipios.abort();
    controladorMunicipios = null;
    return solicitudMunicipios;
}

function esGuatemala() {
    const pais = document.getElementById("idPais");
    const opcion = pais.options[pais.selectedIndex];
    return Boolean(opcion && opcion.getAttribute("data-codigo") === "GT");
}

function mostrarEstadoMunicipios(mensaje, cargando = false) {
    const municipio = document.getElementById("idMunicipio");
    const opcion = document.createElement("option");
    opcion.value = "";
    opcion.textContent = mensaje;
    municipio.replaceChildren(opcion);
    municipio.value = "";
    municipio.disabled = true;
    municipio.setAttribute("aria-busy", String(cargando));
}

function falloMunicipios(mensaje) {
    const error = new Error(mensaje);
    error.controlado = true;
    return error;
}

async function cargarMunicipios() {

    const idDepartamento = document.getElementById("idDepartamento").value;
    const municipio = document.getElementById("idMunicipio");

    const solicitud = invalidarConsultaMunicipios();
    if (!esGuatemala() || !idDepartamento) {
        mostrarEstadoMunicipios("Seleccione primero un departamento");
        return;
    }
    if (!/^\d+$/.test(idDepartamento) || !Number.isSafeInteger(Number(idDepartamento))
            || Number(idDepartamento) < 1 || Number(idDepartamento) > 2147483647) {
        mostrarEstadoMunicipios("Seleccione un departamento válido");
        return;
    }

    const controller = new AbortController();
    controladorMunicipios = controller;
    const vigente = () => solicitud === solicitudMunicipios && esGuatemala()
        && document.getElementById("idDepartamento").value === idDepartamento;
    mostrarEstadoMunicipios("Cargando municipios...", true);

    /* URL AL MUNICIPIO SERVLET. */
    const contextPath = window.APP_CONTEXT_PATH || "";
    const url = contextPath
        + '/municipios?idDepartamento='
        + encodeURIComponent(idDepartamento);

    let timeout;
    try {
        const consulta = async () => {
            const response = await fetch(url, {
                method: "GET", credentials: "same-origin", cache: "no-store",
                headers: { Accept: "application/json" }, signal: controller.signal
            });
            if (!response.ok) {
                const mensajes = {
                    400: "El departamento no es válido.",
                    401: "La consulta requiere una sesión válida.",
                    403: "No tiene permiso para consultar municipios.",
                    404: "La consulta de municipios no está disponible.",
                    500: "El servidor no pudo consultar los municipios.",
                    503: "La consulta no está disponible temporalmente."
                };
                throw falloMunicipios(mensajes[response.status] || "No fue posible consultar los municipios.");
            }
            if (response.redirected || !/^application\/json\s*(?:;|$)/i.test(response.headers.get("content-type") || "")) {
                throw falloMunicipios("El servidor devolvió una respuesta inesperada.");
            }
            let datos;
            try { datos = await response.json(); }
            catch (error) { throw falloMunicipios("La respuesta de municipios no contiene JSON válido."); }
            const ids = new Set();
            if (!Array.isArray(datos) || datos.some(item => {
                if (!item || typeof item !== "object" || !Number.isInteger(item.idMunicipio)
                        || item.idMunicipio < 1 || item.idMunicipio > 2147483647
                        || typeof item.nombre !== "string" || !item.nombre.trim() || ids.has(item.idMunicipio)) return true;
                ids.add(item.idMunicipio);
                return false;
            })) throw falloMunicipios("El catálogo de municipios tiene un formato inválido.");
            return datos;
        };
        const espera = new Promise((_, reject) => {
            timeout = window.setTimeout(() => {
                reject(falloMunicipios("La consulta de municipios superó el tiempo de espera."));
                controller.abort();
            }, 10000);
        });
        const datos = await Promise.race([consulta(), espera]);
        if (!vigente()) return;
        if (!datos.length) {
            mostrarEstadoMunicipios("No hay municipios disponibles para este departamento");
            return;
        }
        mostrarEstadoMunicipios("Seleccione un municipio");
        datos.forEach(item => {
            const opcion = document.createElement("option");
            opcion.value = String(item.idMunicipio);
            opcion.textContent = item.nombre;
            municipio.appendChild(opcion);
        });
        municipio.disabled = false;
    } catch (error) {
        if (!vigente()) return;
        const mensaje = error && error.controlado ? error.message : "No se pudo conectar con el servidor.";
        mostrarEstadoMunicipios(mensaje + " Cambie de departamento para reintentar.");
    } finally {
        window.clearTimeout(timeout);
        if (vigente()) {
            municipio.setAttribute("aria-busy", "false");
            controladorMunicipios = null;
        }
    }
}



