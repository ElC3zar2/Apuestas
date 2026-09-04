<%-- 
    Document   : registro
    Created on : 22-ago-2026, 22:57:41
    Author     : cesar
--%>

<%@page import="com.apuestas.modelo.Pais"%>
<%@page import="com.apuestas.modelo.Departamento"%>
<%@page import="java.util.List"%>
<%@page contentType="text/html" pageEncoding="UTF-8"%>

<!DOCTYPE html>

<html>

<head>

    <meta charset="UTF-8">

    <title>Crear cuenta</title>

</head>

<body>

<h1>Crear cuenta</h1>


<%
    if (request.getAttribute("error") != null) {
%>

<p style="color:red;">
    <%= request.getAttribute("error") %>
</p>

<%
    }
%>


<form
    action="${pageContext.request.contextPath}/registro"
    method="POST">

    <!-- NOMBRE -->

    <label>Nombre:</label>

    <input
        type="text"
        name="nombre"
        maxlength="100"
        required>

    <br><br>


    <!-- APELLIDO -->

    <label>Apellido:</label>

    <input
        type="text"
        name="apellido"
        maxlength="100"
        required>

    <br><br>


    <!-- CORREO -->

    <label>Correo:</label>

    <input
        type="email"
        name="correo"
        maxlength="150"
        required>

    <br><br>


    <!-- CONTRASEÑA -->

    <label>Contraseña:</label>

    <input
        type="password"
        name="contrasena"
        minlength="8"
        required>

    <br><br>


    <!-- FECHA NACIMIENTO -->

    <label>Fecha de nacimiento:</label>

    <input
        type="date"
        name="fechaNacimiento"
        required>

    <br><br>


    <!-- GÉNERO -->

    <label>Género:</label>

    <select
        name="genero"
        required>

        <option value="">
            Seleccione
        </option>

        <option value="M">
            Masculino
        </option>

        <option value="F">
            Femenino
        </option>

    </select>

    <br><br>


    <!-- TELÉFONO -->

    <label>Teléfono:</label>

    <input
        type="tel"
        name="telefono"
        maxlength="25"
        pattern="[0-9+() -]+"
        title="Puede utilizar números, +, espacios, paréntesis y guiones."
        placeholder="+502 5555-5555"
        required>

    <br><br>


    <!-- TIPO DOCUMENTO -->

    <label>Tipo de documento:</label>

    <select
        id="tipoDocumento"
        name="tipoDocumento"
        onchange="cambiarTipoDocumento()"
        required>

        <option value="">
            Seleccione
        </option>

        <option value="DPI">
            DPI
        </option>

        <option value="PASAPORTE">
            Pasaporte
        </option>

        <option value="OTRO">
            Otro
        </option>

    </select>

    <br><br>


    <!-- NÚMERO DOCUMENTO -->

    <label>Número de documento:</label>

    <input
        type="text"
        id="numeroDocumento"
        name="numeroDocumento"
        maxlength="50"
        required>

    <span id="ayudaDocumento"></span>

    <br><br>


    <!-- PAÍS -->

    <label>País:</label>

    <select
        id="idPais"
        name="idPais"
        onchange="cambiarPais()"
        required>

        <option value="">
            Seleccione un país
        </option>

        <%
            List<Pais> paises =
                    (List<Pais>)
                    request.getAttribute("paises");

            if (paises != null) {

                for (Pais pais : paises) {
        %>

        <option
            value="<%= pais.getIdPais() %>"
            data-codigo="<%= pais.getCodigoISO2() %>">

            <%= pais.getNombre() %>

        </option>

        <%
                }
            }
        %>

    </select>

    <br><br>


    <!-- UBICACIÓN GUATEMALA -->

    <div
        id="bloqueGuatemala"
        style="display:none;">

        <label>Departamento:</label>

        <select
            id="idDepartamento"
            onchange="cargarMunicipios()"
            disabled>

            <option value="">
                Seleccione un departamento
            </option>

            <%
                List<Departamento> departamentos =
                        (List<Departamento>)
                        request.getAttribute(
                                "departamentos"
                        );

                if (departamentos != null) {

                    for (Departamento departamento
                            : departamentos) {
            %>

            <option
                value="<%= departamento.getIdDepartamento() %>">

                <%= departamento.getNombre() %>

            </option>

            <%
                    }
                }
            %>

        </select>

        <br><br>


        <label>Municipio:</label>

        <select
            id="idMunicipio"
            name="idMunicipio"
            disabled>

            <option value="">
                Seleccione primero un departamento
            </option>

        </select>

        <br><br>

    </div>


    <!-- UBICACIÓN EXTRANJERO -->

    <div
        id="bloqueExterior"
        style="display:none;">

        <label>Ciudad exterior:</label>

        <input
            type="text"
            id="ciudadExterior"
            name="ciudadExterior"
            maxlength="120"
            disabled>

        <br><br>

    </div>


    <!-- DIRECCIÓN -->

    <label>Dirección:</label>

    <input
        type="text"
        name="direccion"
        maxlength="250"
        required>

    <br><br>


    <button type="submit">
        Crear cuenta
    </button>

</form>


<script>

/*
 * =====================================================
 * VALIDACIÓN DEL DOCUMENTO
 * =====================================================
 */

function cambiarTipoDocumento() {

    const tipoDocumento =
        document.getElementById(
            "tipoDocumento"
        ).value;

    const numeroDocumento =
        document.getElementById(
            "numeroDocumento"
        );

    const ayudaDocumento =
        document.getElementById(
            "ayudaDocumento"
        );


    /*
     * DPI DE GUATEMALA
     */
    if (tipoDocumento === "DPI") {

        numeroDocumento.value = "";

        numeroDocumento.maxLength = 13;

        numeroDocumento.minLength = 13;

        numeroDocumento.pattern =
            "[0-9]{13}";

        numeroDocumento.placeholder =
            "13 dígitos";

        numeroDocumento.title =
            "El DPI debe contener exactamente 13 dígitos.";

        ayudaDocumento.textContent =
            " El DPI debe contener 13 dígitos.";

    }

    /*
     * PASAPORTE
     */
    else if (tipoDocumento === "PASAPORTE") {

        numeroDocumento.value = "";

        numeroDocumento.maxLength = 50;

        numeroDocumento.removeAttribute(
            "minlength"
        );

        numeroDocumento.removeAttribute(
            "pattern"
        );

        numeroDocumento.placeholder =
            "Número de pasaporte";

        numeroDocumento.title =
            "Ingrese el número de pasaporte.";

        ayudaDocumento.textContent =
            " El formato depende del país.";

    }

    /*
     * OTRO DOCUMENTO
     */
    else if (tipoDocumento === "OTRO") {

        numeroDocumento.value = "";

        numeroDocumento.maxLength = 50;

        numeroDocumento.removeAttribute(
            "minlength"
        );

        numeroDocumento.removeAttribute(
            "pattern"
        );

        numeroDocumento.placeholder =
            "Número de documento";

        numeroDocumento.title =
            "Ingrese el número del documento.";

        ayudaDocumento.textContent =
            " Máximo 50 caracteres.";

    }

    /*
     * NINGÚN TIPO SELECCIONADO
     */
    else {

        numeroDocumento.value = "";

        numeroDocumento.maxLength = 50;

        numeroDocumento.removeAttribute(
            "minlength"
        );

        numeroDocumento.removeAttribute(
            "pattern"
        );

        numeroDocumento.placeholder =
            "";

        ayudaDocumento.textContent =
            "";
    }
}


/*
 * =====================================================
 * CAMBIO DE PAÍS
 * =====================================================
 */

function cambiarPais() {

    const pais =
        document.getElementById(
            "idPais"
        );

    const opcion =
        pais.options[
            pais.selectedIndex
        ];

    const codigo =
        opcion.getAttribute(
            "data-codigo"
        );


    const bloqueGuatemala =
        document.getElementById(
            "bloqueGuatemala"
        );

    const bloqueExterior =
        document.getElementById(
            "bloqueExterior"
        );


    const departamento =
        document.getElementById(
            "idDepartamento"
        );

    const municipio =
        document.getElementById(
            "idMunicipio"
        );

    const ciudadExterior =
        document.getElementById(
            "ciudadExterior"
        );


    /*
     * =================================================
     * GUATEMALA
     * =================================================
     *
     * Departamento obligatorio.
     * Municipio obligatorio.
     * Ciudad exterior bloqueada.
     */
    if (codigo === "GT") {

        bloqueGuatemala.style.display =
            "block";

        bloqueExterior.style.display =
            "none";


        departamento.disabled =
            false;

        departamento.required =
            true;


        municipio.disabled =
            false;

        municipio.required =
            true;


        ciudadExterior.disabled =
            true;

        ciudadExterior.required =
            false;

        ciudadExterior.value =
            "";
    }


    /*
     * =================================================
     * PAÍS EXTRANJERO
     * =================================================
     *
     * Departamento bloqueado.
     * Municipio bloqueado.
     * Ciudad exterior obligatoria.
     */
    else if (codigo) {

        bloqueGuatemala.style.display =
            "none";

        bloqueExterior.style.display =
            "block";


        departamento.disabled =
            true;

        departamento.required =
            false;

        departamento.value =
            "";


        municipio.disabled =
            true;

        municipio.required =
            false;

        municipio.innerHTML =
            '<option value="">Seleccione primero un departamento</option>';


        ciudadExterior.disabled =
            false;

        ciudadExterior.required =
            true;
    }


    /*
     * =================================================
     * NINGÚN PAÍS
     * =================================================
     */
    else {

        bloqueGuatemala.style.display =
            "none";

        bloqueExterior.style.display =
            "none";


        departamento.disabled =
            true;

        departamento.required =
            false;


        municipio.disabled =
            true;

        municipio.required =
            false;


        ciudadExterior.disabled =
            true;

        ciudadExterior.required =
            false;

        ciudadExterior.value =
            "";
    }
}


/*
 * =====================================================
 * CARGAR MUNICIPIOS
 * =====================================================
 */

function cargarMunicipios() {

    const idDepartamento =
        document.getElementById(
            "idDepartamento"
        ).value;


    const municipio =
        document.getElementById(
            "idMunicipio"
        );


    /*
     * No se seleccionó departamento.
     */
    if (!idDepartamento) {

        municipio.innerHTML =
            '<option value="">Seleccione primero un departamento</option>';

        return;
    }


    municipio.innerHTML =
        '<option value="">Cargando municipios...</option>';


    /*
     * URL AL MUNICIPIO SERVLET.
     */
    const url =
        '${pageContext.request.contextPath}'
        + '/municipios?idDepartamento='
        + encodeURIComponent(
            idDepartamento
        );


    fetch(url)

        .then(response => {

            if (!response.ok) {

                throw new Error(
                    "No fue posible cargar los municipios."
                );
            }

            return response.json();
        })

        .then(datos => {

            municipio.innerHTML =
                '<option value="">Seleccione un municipio</option>';


            datos.forEach(item => {

                const opcion =
                    document.createElement(
                        "option"
                    );

                opcion.value =
                    item.idMunicipio;

                opcion.textContent =
                    item.nombre;

                municipio.appendChild(
                    opcion
                );
            });
        })

        .catch(error => {

            municipio.innerHTML =
                '<option value="">Error al cargar municipios</option>';

            console.error(
                error
            );
        });
}

</script>


</body>

</html>