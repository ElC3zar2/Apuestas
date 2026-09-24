// =========================================================
// BETZONE — registro.jsp
// Mismo comportamiento funcional del formulario original,
// + toggle de contraseña y floating labels para el nuevo diseño.
// =========================================================

document.addEventListener("DOMContentLoaded", () => {
  initPasswordToggles();
  initFloatingLabels();
});

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

    /* DPI DE GUATEMALA */
    if (tipoDocumento === "DPI") {

        numeroDocumento.value = "";
        numeroDocumento.maxLength = 13;
        numeroDocumento.minLength = 13;
        numeroDocumento.pattern = "[0-9]{13}";
        numeroDocumento.placeholder = "13 dígitos";
        numeroDocumento.title = "El DPI debe contener exactamente 13 dígitos.";
        ayudaDocumento.textContent = "El DPI debe contener 13 dígitos.";

    }
    /* PASAPORTE */
    else if (tipoDocumento === "PASAPORTE") {

        numeroDocumento.value = "";
        numeroDocumento.maxLength = 50;
        numeroDocumento.removeAttribute("minlength");
        numeroDocumento.removeAttribute("pattern");
        numeroDocumento.placeholder = "Número de pasaporte";
        numeroDocumento.title = "Ingrese el número de pasaporte.";
        ayudaDocumento.textContent = "El formato depende del país.";

    }
    /* OTRO DOCUMENTO */
    else if (tipoDocumento === "OTRO") {

        numeroDocumento.value = "";
        numeroDocumento.maxLength = 50;
        numeroDocumento.removeAttribute("minlength");
        numeroDocumento.removeAttribute("pattern");
        numeroDocumento.placeholder = "Número de documento";
        numeroDocumento.title = "Ingrese el número del documento.";
        ayudaDocumento.textContent = "Máximo 50 caracteres.";

    }
    /* NINGÚN TIPO SELECCIONADO */
    else {

        numeroDocumento.value = "";
        numeroDocumento.maxLength = 50;
        numeroDocumento.removeAttribute("minlength");
        numeroDocumento.removeAttribute("pattern");
        numeroDocumento.placeholder = "";
        ayudaDocumento.textContent = "";
    }

    // Sincroniza el floating label tras el reset programático del valor.
    numeroDocumento.classList.remove("has-value");
}


/*
 * =====================================================
 * CAMBIO DE PAÍS (lógica original, sin cambios)
 * =====================================================
 */
function cambiarPais() {

    const pais = document.getElementById("IdPais");
    const opcion = pais.options[pais.selectedIndex];
    const codigo = opcion.getAttribute("data-codigo");

    const bloqueGuatemala = document.getElementById("bloqueGuatemala");
    const bloqueExterior = document.getElementById("bloqueExterior");

    const departamento = document.getElementById("idDepartamento");
    const municipio = document.getElementById("idMunicipio");
    const ciudadExterior = document.getElementById("ciudadExterior");

    /*
     * GUATEMALA
     * Departamento obligatorio. Municipio obligatorio. Ciudad exterior bloqueada.
     */
    if (codigo === "GT") {

        bloqueGuatemala.style.display = "grid";
        bloqueExterior.style.display = "none";

        departamento.disabled = false;
        departamento.required = true;

        municipio.disabled = false;
        municipio.required = true;

        ciudadExterior.disabled = true;
        ciudadExterior.required = false;
        ciudadExterior.value = "";
        ciudadExterior.classList.remove("has-value");
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
        municipio.innerHTML = '<option value="">Seleccione primero un departamento</option>';

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
 * CARGAR MUNICIPIOS (lógica original, sin cambios)
 * =====================================================
 */
function cargarMunicipios() {

    const idDepartamento = document.getElementById("idDepartamento").value;
    const municipio = document.getElementById("idMunicipio");

    /* No se seleccionó departamento. */
    if (!idDepartamento) {
        municipio.innerHTML = '<option value="">Seleccione primero un departamento</option>';
        return;
    }

    municipio.innerHTML = '<option value="">Cargando municipios...</option>';

    /* URL AL MUNICIPIO SERVLET. */
    const contextPath = window.APP_CONTEXT_PATH || "";
    const url = contextPath
        + '/municipios?idDepartamento='
        + encodeURIComponent(idDepartamento);

    fetch(url)
        .then(response => {
            if (!response.ok) {
                throw new Error("No fue posible cargar los municipios.");
            }
            return response.json();
        })
        .then(datos => {
            municipio.innerHTML = '<option value="">Seleccione un municipio</option>';

            datos.forEach(item => {
                const opcion = document.createElement("option");
                opcion.value = item.idMunicipio;
                opcion.textContent = item.nombre;
                municipio.appendChild(opcion);
            });
        })
        .catch(error => {
            municipio.innerHTML = '<option value="">Error al cargar municipios</option>';
            console.error(error);
        });
}



