/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   07_PRUEBAS/01_VerificarInstalacion.sql

   OBJETIVO:
   Comprobar que la instalación definitiva contiene todos los
   componentes requeridos.

   NO MODIFICA DATOS.
   ============================================================ */

SET NOCOUNT ON;
GO

PRINT '=======================================================';
PRINT ' VERIFICACION GENERAL DE INSTALACION';
PRINT '=======================================================';
PRINT '';


/* ============================================================
   1. VERIFICAR LAS 30 TABLAS
   ============================================================ */

DECLARE @TablasEsperadas TABLE
(
    Nombre SYSNAME PRIMARY KEY
);

INSERT INTO @TablasEsperadas (Nombre)
VALUES
('Rol'),
('Pais'),
('Departamento'),
('Municipio'),
('TipoEstado'),
('Estado'),
('Usuario'),
('PerfilUsuario'),
('VerificacionUsuario'),
('RestriccionUsuario'),
('TokenSeguridad'),
('Deporte'),
('Liga'),
('Participante'),
('Evento'),
('EventoParticipante'),
('Mercado'),
('Seleccion'),
('Cuota'),
('ResultadoEvento'),
('ResolucionSeleccion'),
('Billetera'),
('Boleto'),
('DetalleBoleto'),
('TipoTransaccion'),
('TransaccionFinanciera'),
('MovimientoBilletera'),
('LiquidacionBoleto'),
('Auditoria'),
('ConfiguracionSistema');


DECLARE @CantidadTablas INT;

SELECT @CantidadTablas = COUNT(*)
FROM sys.tables AS T
INNER JOIN @TablasEsperadas AS E
    ON E.Nombre = T.name
WHERE SCHEMA_NAME(T.schema_id) = 'dbo';


PRINT 'TABLAS encontradas: '
    + CONVERT(VARCHAR(10), @CantidadTablas)
    + ' / 30';


IF @CantidadTablas <> 30
BEGIN

    PRINT 'ERROR: faltan tablas.';

    SELECT
        E.Nombre AS TablaFaltante
    FROM @TablasEsperadas AS E
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.tables AS T
        WHERE T.name = E.Nombre
          AND SCHEMA_NAME(T.schema_id) = 'dbo'
    );

END
ELSE
BEGIN
    PRINT 'OK: las 30 tablas existen.';
END;

PRINT '';


/* ============================================================
   2. VERIFICAR LOS 47 PROCEDIMIENTOS
   ============================================================ */

DECLARE @ProcedimientosEsperados TABLE
(
    Nombre SYSNAME PRIMARY KEY
);

INSERT INTO @ProcedimientosEsperados (Nombre)
VALUES

/* Registro */
('sp_RegistrarUsuarioCliente'),

/* Seguridad */
('sp_ObtenerUsuarioAutenticacion'),
('sp_RegistrarIntentoLogin'),
('sp_CrearTokenSeguridad'),
('sp_ValidarTokenSeguridad'),
('sp_VerificarCorreoConToken'),
('sp_RestablecerContrasenaConToken'),
('sp_CambiarContrasenaUsuario'),

/* Billetera */
('sp_ObtenerBilleteraUsuario'),
('sp_ObtenerMovimientosBilletera'),
('sp_AjustarSaldoVirtual'),

/* Eventos / mercados */
('sp_ValidarPermisoEventos'),
('sp_CrearLiga'),
('sp_ActualizarLiga'),
('sp_CrearParticipante'),
('sp_ActualizarParticipante'),
('sp_CrearEvento'),
('sp_ActualizarEvento'),
('sp_AgregarParticipanteEvento'),
('sp_CrearMercado'),
('sp_CrearSeleccion'),
('sp_RegistrarCuota'),
('sp_CambiarEstadoEvento'),
('sp_CambiarEstadoMercado'),

/* Apuestas */
('sp_CotizarApuesta'),
('sp_RealizarApuesta'),
('sp_ObtenerBoleto'),

/* Resultados */
('sp_RegistrarResultadoEvento'),
('sp_ResolverSeleccion'),
('sp_OficializarResultadoEvento'),
('sp_CorregirResultadoEvento'),
('sp_AnularResultadoEvento'),

/* Liquidacion */
('sp_ValidarPermisoLiquidacion'),
('sp_ObtenerBoletosListosLiquidar'),
('sp_LiquidarBoleto'),
('sp_ObtenerLiquidacionBoleto'),

/* Administracion */
('sp_ValidarPermisoAdministracionUsuario'),
('sp_ObtenerDetalleAdministrativoUsuario'),
('sp_ObtenerUsuariosPendientesVerificacion'),
('sp_SincronizarHabilitacionUsuario'),
('sp_IniciarRevisionUsuario'),
('sp_AprobarVerificacionUsuario'),
('sp_RechazarVerificacionUsuario'),
('sp_ReabrirVerificacionUsuario'),
('sp_CambiarEstadoUsuarioAdministrativo'),
('sp_AgregarRestriccionUsuario'),
('sp_LevantarRestriccionUsuario');


DECLARE @CantidadProcedimientos INT;

SELECT @CantidadProcedimientos = COUNT(*)
FROM sys.procedures AS P
INNER JOIN @ProcedimientosEsperados AS E
    ON E.Nombre = P.name
WHERE SCHEMA_NAME(P.schema_id) = 'dbo';


PRINT 'PROCEDIMIENTOS encontrados: '
    + CONVERT(VARCHAR(10), @CantidadProcedimientos)
    + ' / 47';


IF @CantidadProcedimientos <> 47
BEGIN

    PRINT 'ERROR: faltan procedimientos.';

    SELECT
        E.Nombre AS ProcedimientoFaltante
    FROM @ProcedimientosEsperados AS E
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.procedures AS P
        WHERE P.name = E.Nombre
          AND SCHEMA_NAME(P.schema_id) = 'dbo'
    );

END
ELSE
BEGIN
    PRINT 'OK: los 47 procedimientos existen.';
END;

PRINT '';


/* ============================================================
   3. VERIFICAR LAS 11 VISTAS
   ============================================================ */

DECLARE @VistasEsperadas TABLE
(
    Nombre SYSNAME PRIMARY KEY
);

INSERT INTO @VistasEsperadas (Nombre)
VALUES
('vw_EventosDisponibles'),
('vw_EventoParticipantes'),
('vw_MercadosAbiertos'),
('vw_CuotasActuales'),
('vw_BoletosUsuario'),
('vw_DetalleBoletos'),
('vw_HistorialMovimientos'),
('vw_EstadoVerificacionUsuario'),
('vw_ResumenBilleteras'),
('vw_ResumenAdministrativo'),
('vw_AuditoriaSistema');


DECLARE @CantidadVistas INT;

SELECT @CantidadVistas = COUNT(*)
FROM sys.views AS V
INNER JOIN @VistasEsperadas AS E
    ON E.Nombre = V.name
WHERE SCHEMA_NAME(V.schema_id) = 'dbo';


PRINT 'VISTAS encontradas: '
    + CONVERT(VARCHAR(10), @CantidadVistas)
    + ' / 11';


IF @CantidadVistas <> 11
BEGIN

    PRINT 'ERROR: faltan vistas.';

    SELECT
        E.Nombre AS VistaFaltante
    FROM @VistasEsperadas AS E
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.views AS V
        WHERE V.name = E.Nombre
          AND SCHEMA_NAME(V.schema_id) = 'dbo'
    );

END
ELSE
BEGIN
    PRINT 'OK: las 11 vistas existen.';
END;

PRINT '';


/* ============================================================
   4. VERIFICAR LOS 5 TRIGGERS
   ============================================================ */

DECLARE @TriggersEsperados TABLE
(
    Nombre SYSNAME PRIMARY KEY
);

INSERT INTO @TriggersEsperados (Nombre)
VALUES
('tr_Auditoria_ProtegerHistorial'),
('tr_MovimientoBilletera_ProtegerHistorial'),
('tr_TransaccionFinanciera_ProhibirEliminacion'),
('tr_ConfiguracionSistema_AuditarCambios'),
('tr_ConfiguracionSistema_ProhibirEliminacion');


DECLARE @CantidadTriggers INT;

SELECT @CantidadTriggers = COUNT(*)
FROM sys.triggers AS T
INNER JOIN @TriggersEsperados AS E
    ON E.Nombre = T.name
WHERE T.parent_id <> 0;


PRINT 'TRIGGERS encontrados: '
    + CONVERT(VARCHAR(10), @CantidadTriggers)
    + ' / 5';


IF @CantidadTriggers <> 5
BEGIN

    PRINT 'ERROR: faltan triggers.';

    SELECT
        E.Nombre AS TriggerFaltante
    FROM @TriggersEsperados AS E
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.triggers AS T
        WHERE T.name = E.Nombre
    );

END
ELSE
BEGIN
    PRINT 'OK: los 5 triggers existen.';
END;

PRINT '';


/* ============================================================
   5. VERIFICAR CONFIGURACION
   ============================================================ */

DECLARE @ConfiguracionesEsperadas TABLE
(
    Clave VARCHAR(100) PRIMARY KEY
);

INSERT INTO @ConfiguracionesEsperadas (Clave)
VALUES
('SALDO_INICIAL_USUARIO'),
('SALDO_INICIAL_CASA'),
('EDAD_MINIMA_USUARIO'),
('MAX_INTENTOS_LOGIN'),
('TIEMPO_BLOQUEO_LOGIN_MIN'),
('TIEMPO_TOKEN_RECUPERACION_MIN'),
('TIEMPO_TOKEN_VERIFICACION_MIN'),
('MONTO_MINIMO_APUESTA');


DECLARE @CantidadConfiguraciones INT;

SELECT @CantidadConfiguraciones = COUNT(*)
FROM dbo.ConfiguracionSistema AS C
INNER JOIN @ConfiguracionesEsperadas AS E
    ON E.Clave = C.Clave;


PRINT 'CONFIGURACIONES encontradas: '
    + CONVERT(VARCHAR(10), @CantidadConfiguraciones)
    + ' / 8';


IF @CantidadConfiguraciones <> 8
BEGIN

    PRINT 'ERROR: faltan configuraciones.';

    SELECT
        E.Clave AS ConfiguracionFaltante
    FROM @ConfiguracionesEsperadas AS E
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.ConfiguracionSistema AS C
        WHERE C.Clave = E.Clave
    );

END
ELSE
BEGIN
    PRINT 'OK: las 8 configuraciones existen.';
END;

PRINT '';


/* ============================================================
   6. VERIFICAR ROLES
   ============================================================ */

DECLARE @RolesEsperados TABLE
(
    Nombre VARCHAR(50) PRIMARY KEY
);

INSERT INTO @RolesEsperados (Nombre)
VALUES
('ADMINISTRADOR'),
('OPERADOR_EVENTOS'),
('CAJERO'),
('AUDITOR'),
('USUARIO'),
('CASA');


DECLARE @CantidadRoles INT;

SELECT @CantidadRoles = COUNT(*)
FROM dbo.Rol AS R
INNER JOIN @RolesEsperados AS E
    ON E.Nombre = R.Nombre;


PRINT 'ROLES encontrados: '
    + CONVERT(VARCHAR(10), @CantidadRoles)
    + ' / 6';


IF @CantidadRoles <> 6
    PRINT 'ERROR: faltan roles.';
ELSE
    PRINT 'OK: los 6 roles existen.';

PRINT '';


/* ============================================================
   7. VERIFICAR DEPORTES
   ============================================================ */

DECLARE @CantidadDeportes INT;

SELECT @CantidadDeportes = COUNT(*)
FROM dbo.Deporte
WHERE Nombre IN
(
    'Futbol',
    'Baloncesto',
    'Beisbol',
    'Tenis'
);


PRINT 'DEPORTES iniciales encontrados: '
    + CONVERT(VARCHAR(10), @CantidadDeportes)
    + ' / 4';


IF @CantidadDeportes <> 4
    PRINT 'ERROR: faltan deportes iniciales.';
ELSE
    PRINT 'OK: los 4 deportes iniciales existen.';

PRINT '';


/* ============================================================
   8. VERIFICAR GEOGRAFIA
   ============================================================ */

DECLARE @CantidadPaises INT;
DECLARE @CantidadDepartamentos INT;
DECLARE @CantidadMunicipios INT;
DECLARE @IdGuatemala INT;


SELECT @CantidadPaises = COUNT(*)
FROM dbo.Pais;


SELECT @IdGuatemala = IdPais
FROM dbo.Pais
WHERE CodigoISO2 = 'GT';


SELECT @CantidadDepartamentos = COUNT(*)
FROM dbo.Departamento
WHERE IdPais = @IdGuatemala;


SELECT @CantidadMunicipios = COUNT(*)
FROM dbo.Municipio AS M
INNER JOIN dbo.Departamento AS D
    ON D.IdDepartamento = M.IdDepartamento
WHERE D.IdPais = @IdGuatemala;


PRINT 'PAISES cargados: '
    + CONVERT(VARCHAR(10), @CantidadPaises);

PRINT 'DEPARTAMENTOS Guatemala: '
    + CONVERT(VARCHAR(10), @CantidadDepartamentos)
    + ' / 22';

PRINT 'MUNICIPIOS Guatemala: '
    + CONVERT(VARCHAR(10), @CantidadMunicipios)
    + ' / 340';


IF @CantidadDepartamentos <> 22
    PRINT 'ERROR: Guatemala no posee los 22 departamentos esperados.';
ELSE
    PRINT 'OK: departamentos completos.';


IF @CantidadMunicipios <> 340
    PRINT 'ERROR: Guatemala no posee los 340 municipios esperados.';
ELSE
    PRINT 'OK: municipios completos.';

PRINT '';


/* ============================================================
   9. VERIFICAR TIPOS DE TRANSACCION
   ============================================================ */

DECLARE @TiposTransaccionEsperados TABLE
(
    Codigo VARCHAR(40) PRIMARY KEY
);

INSERT INTO @TiposTransaccionEsperados (Codigo)
VALUES
('CARGA_INICIAL'),
('APUESTA'),
('PREMIO'),
('PERDIDA_APUESTA'),
('DEVOLUCION'),
('GANANCIA_CASA'),
('PAGO_PREMIO'),
('AJUSTE_ADMIN');


DECLARE @CantidadTiposTransaccion INT;

SELECT @CantidadTiposTransaccion = COUNT(*)
FROM dbo.TipoTransaccion AS TT
INNER JOIN @TiposTransaccionEsperados AS E
    ON E.Codigo = TT.Codigo;


PRINT 'TIPOS TRANSACCION encontrados: '
    + CONVERT(VARCHAR(10), @CantidadTiposTransaccion)
    + ' / 8';


IF @CantidadTiposTransaccion <> 8
    PRINT 'ERROR: faltan tipos de transacción.';
ELSE
    PRINT 'OK: los 8 tipos de transacción existen.';

PRINT '';


/* ============================================================
   10. VERIFICAR CASA
   ============================================================ */

DECLARE @CantidadCasa INT;
DECLARE @CantidadBilleterasCasa INT;


SELECT @CantidadCasa = COUNT(*)
FROM dbo.Usuario AS U
INNER JOIN dbo.Rol AS R
    ON R.IdRol = U.IdRol
WHERE R.Nombre = 'CASA';


SELECT @CantidadBilleterasCasa = COUNT(*)
FROM dbo.Usuario AS U
INNER JOIN dbo.Rol AS R
    ON R.IdRol = U.IdRol
INNER JOIN dbo.Billetera AS B
    ON B.IdUsuario = U.IdUsuario
WHERE R.Nombre = 'CASA';


PRINT 'CUENTAS CASA: '
    + CONVERT(VARCHAR(10), @CantidadCasa);

PRINT 'BILLETERAS CASA: '
    + CONVERT(VARCHAR(10), @CantidadBilleterasCasa);


IF @CantidadCasa <> 1
    PRINT 'ERROR: debe existir exactamente una cuenta CASA.';
ELSE
    PRINT 'OK: existe una única cuenta CASA.';


IF @CantidadBilleterasCasa <> 1
    PRINT 'ERROR: CASA debe poseer exactamente una billetera.';
ELSE
    PRINT 'OK: CASA posee una única billetera.';

PRINT '';


/* ============================================================
   11. VERIFICAR INDICES CRITICOS
   ============================================================ */

DECLARE @IndicesCriticos TABLE
(
    Nombre SYSNAME PRIMARY KEY
);

INSERT INTO @IndicesCriticos (Nombre)
VALUES
('UX_PerfilUsuario_Documento'),
('UX_Cuota_Seleccion_Activa'),
('IX_Boleto_Usuario_Fecha'),
('IX_MovimientoBilletera_Billetera_Fecha'),
('IX_Auditoria_Tabla_Registro_Fecha');


DECLARE @CantidadIndicesCriticos INT;

SELECT @CantidadIndicesCriticos = COUNT(*)
FROM sys.indexes AS I
INNER JOIN @IndicesCriticos AS E
    ON E.Nombre = I.name;


PRINT 'INDICES CRITICOS encontrados: '
    + CONVERT(VARCHAR(10), @CantidadIndicesCriticos)
    + ' / 5';


IF @CantidadIndicesCriticos <> 5
BEGIN

    PRINT 'ERROR: faltan índices críticos.';

    SELECT
        E.Nombre AS IndiceFaltante
    FROM @IndicesCriticos AS E
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes AS I
        WHERE I.name = E.Nombre
    );

END
ELSE
BEGIN
    PRINT 'OK: los índices críticos existen.';
END;

PRINT '';


/* ============================================================
   12. RESUMEN FINAL
   ============================================================ */

DECLARE @Errores INT = 0;

IF @CantidadTablas <> 30
    SET @Errores += 1;

IF @CantidadProcedimientos <> 47
    SET @Errores += 1;

IF @CantidadVistas <> 11
    SET @Errores += 1;

IF @CantidadTriggers <> 5
    SET @Errores += 1;

IF @CantidadConfiguraciones <> 8
    SET @Errores += 1;

IF @CantidadRoles <> 6
    SET @Errores += 1;

IF @CantidadDeportes <> 4
    SET @Errores += 1;

IF @CantidadDepartamentos <> 22
    SET @Errores += 1;

IF @CantidadMunicipios <> 340
    SET @Errores += 1;

IF @CantidadTiposTransaccion <> 8
    SET @Errores += 1;

IF @CantidadCasa <> 1
    SET @Errores += 1;

IF @CantidadBilleterasCasa <> 1
    SET @Errores += 1;

IF @CantidadIndicesCriticos <> 5
    SET @Errores += 1;


PRINT '=======================================================';

IF @Errores = 0
BEGIN
    PRINT ' RESULTADO: INSTALACION ESTRUCTURAL CORRECTA';
END
ELSE
BEGIN
    PRINT ' RESULTADO: SE DETECTARON '
        + CONVERT(VARCHAR(10), @Errores)
        + ' PROBLEMAS';
END;

PRINT '=======================================================';
GO