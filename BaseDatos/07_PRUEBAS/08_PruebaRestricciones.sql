/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   07_PRUEBAS/08_PruebaRestricciones.sql

   OBJETIVO:
   Probar:
   - sp_AgregarRestriccionUsuario
   - sp_LevantarRestriccionUsuario
   - Integración con sp_RealizarApuesta
   - Restricción APOSTAR
   - Restricción TODAS_OPERACIONES

   FLUJO:
   1. Crear usuario habilitado.
   2. Aplicar restricción APOSTAR.
   3. Levantarla.
   4. Comprobar que puede apostar.
   5. Aplicar TODAS_OPERACIONES.
   6. Intentar otra apuesta.
   7. sp_RealizarApuesta debe lanzar error 60039.

   El error final esperado provoca el ROLLBACK completo de
   todos los datos temporales.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


BEGIN TRY

    BEGIN TRANSACTION;


    PRINT '=======================================================';
    PRINT ' PRUEBA DE RESTRICCIONES';
    PRINT '=======================================================';


    /* ========================================================
       1. ADMINISTRADOR
       ======================================================== */

    DECLARE @IdAdministrador INT;


    SELECT TOP (1)
        @IdAdministrador = U.IdUsuario
    FROM dbo.Usuario AS U
    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol
    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = U.IdEstado
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'USUARIO'
    WHERE R.Nombre = 'ADMINISTRADOR'
      AND E.Codigo = 'ACTIVO'
    ORDER BY U.IdUsuario;


    IF @IdAdministrador IS NULL
        THROW 70601, 'No existe ADMINISTRADOR ACTIVO.', 1;


    /* ========================================================
       2. CATALOGOS
       ======================================================== */

    DECLARE @IdPais INT;
    DECLARE @IdMunicipio INT;
    DECLARE @IdDeporte INT;


    SELECT @IdPais = IdPais
    FROM dbo.Pais
    WHERE CodigoISO2 = 'GT'
      AND Activo = 1;


    SELECT TOP (1)
        @IdMunicipio = M.IdMunicipio
    FROM dbo.Municipio AS M
    INNER JOIN dbo.Departamento AS D
        ON D.IdDepartamento = M.IdDepartamento
    WHERE D.IdPais = @IdPais
      AND D.Activo = 1
      AND M.Activo = 1
    ORDER BY M.IdMunicipio;


    SELECT @IdDeporte = IdDeporte
    FROM dbo.Deporte
    WHERE Nombre = 'Futbol'
      AND Activo = 1;


    IF @IdPais IS NULL
       OR @IdMunicipio IS NULL
       OR @IdDeporte IS NULL
        THROW 70602, 'Faltan catálogos requeridos.', 1;


    DECLARE @Codigo VARCHAR(20) =
        LEFT
        (
            REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
            12
        );

    DECLARE @Documento VARCHAR(50) =
        CONCAT('RES-', @Codigo);

    DECLARE @NombreParticipanteA VARCHAR(150) =
        CONCAT('Restriccion Equipo A ', @Codigo);

    DECLARE @NombreParticipanteB VARCHAR(150) =
        CONCAT('Restriccion Equipo B ', @Codigo);

    DECLARE @NombreMercado VARCHAR(150) =
        CONCAT('Mercado Restricciones ', @Codigo);

    /* ========================================================
       3. CREAR USUARIO
       ======================================================== */

    DECLARE @Correo VARCHAR(150) =
        CONCAT('restriccion.', @Codigo, '@apuestas.test');


    EXEC dbo.sp_RegistrarUsuarioCliente

        @Nombre = 'Usuario',
        @Apellido = 'Restriccion',

        @Correo = @Correo,

        @Contrasena =
            '$2a$12$HashTemporalRestricciones123456789012345678901234567890',

        @FechaNacimiento = '2000-01-01',

        @Genero = 'M',

        @Telefono = '55550400',

        @TipoDocumento = 'DPI',

        @NumeroDocumento = @Documento,

        @IdPais = @IdPais,

        @IdMunicipio = @IdMunicipio,

        @CiudadExterior = NULL,

        @Direccion = 'Dirección temporal prueba restricciones';


    DECLARE @IdUsuario INT;


    SELECT @IdUsuario = IdUsuario
    FROM dbo.Usuario
    WHERE Correo = @Correo;


    IF @IdUsuario IS NULL
        THROW 70603, 'No se creó el usuario temporal.', 1;


    /* ========================================================
       4. HABILITAR USUARIO PARA APOSTAR
       ======================================================== */

    DECLARE @IdEstadoVerificacionAprobada INT;


    SELECT @IdEstadoVerificacionAprobada = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'VERIFICACION'
      AND E.Codigo = 'APROBADA';


    UPDATE dbo.Usuario
    SET CorreoVerificado = 1
    WHERE IdUsuario = @IdUsuario;


    UPDATE dbo.VerificacionUsuario
    SET
        IdEstado = @IdEstadoVerificacionAprobada,
        IdUsuarioRevisor = @IdAdministrador,
        FechaInicioRevision = SYSDATETIME(),
        FechaResolucion = SYSDATETIME()
    WHERE IdUsuario = @IdUsuario;


    EXEC dbo.sp_SincronizarHabilitacionUsuario
        @IdUsuario = @IdUsuario;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario AS U
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = U.IdEstado
        WHERE U.IdUsuario = @IdUsuario
          AND U.CorreoVerificado = 1
          AND E.Codigo = 'ACTIVO'
    )
        THROW 70604, 'El usuario no quedó habilitado.', 1;


    /* ========================================================
       5. CREAR ESTRUCTURA DEPORTIVA MINIMA
       ======================================================== */

    DECLARE @NombreLiga VARCHAR(150) =
        'Liga Restricciones ' + @Codigo;


    EXEC dbo.sp_CrearLiga

        @IdUsuarioProceso = @IdAdministrador,

        @IdDeporte = @IdDeporte,

        @Nombre = @NombreLiga,

        @IdPais = @IdPais,

        @IpOrigen = '127.0.0.1';


    DECLARE @IdLiga INT;


    SELECT @IdLiga = IdLiga
    FROM dbo.Liga
    WHERE Nombre = @NombreLiga
      AND IdDeporte = @IdDeporte;


    EXEC dbo.sp_CrearParticipante

        @IdUsuarioProceso = @IdAdministrador,

        @IdDeporte = @IdDeporte,

        @Nombre = @NombreParticipanteA,

        @TipoParticipante = 'EQUIPO',

        @IdPais = @IdPais,

        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_CrearParticipante

        @IdUsuarioProceso = @IdAdministrador,

        @IdDeporte = @IdDeporte,

        @Nombre = @NombreParticipanteB,

        @TipoParticipante = 'EQUIPO',

        @IdPais = @IdPais,

        @IpOrigen = '127.0.0.1';


    DECLARE @IdParticipanteA INT;
    DECLARE @IdParticipanteB INT;


    SELECT @IdParticipanteA = IdParticipante
    FROM dbo.Participante
    WHERE Nombre = 'Restriccion Equipo A ' + @Codigo;


    SELECT @IdParticipanteB = IdParticipante
    FROM dbo.Participante
    WHERE Nombre = 'Restriccion Equipo B ' + @Codigo;


    DECLARE @NombreEvento VARCHAR(200) =
        'Restriccion A vs B ' + @Codigo;


    DECLARE @FechaInicio DATETIME2 =
        DATEADD(DAY, 1, SYSDATETIME());

    DECLARE @FechaFin DATETIME2 =
        DATEADD(HOUR, 2, @FechaInicio);

    EXEC dbo.sp_CrearEvento

        @IdUsuarioProceso = @IdAdministrador,

        @IdLiga = @IdLiga,

        @Nombre = @NombreEvento,

        @FechaInicio = @FechaInicio,

        @FechaFin = @FechaFin,

        @IpOrigen = '127.0.0.1';


    DECLARE @IdEvento INT;


    SELECT @IdEvento = IdEvento
    FROM dbo.Evento
    WHERE Nombre = @NombreEvento;


    EXEC dbo.sp_AgregarParticipanteEvento

        @IdUsuarioProceso = @IdAdministrador,

        @IdEvento = @IdEvento,

        @IdParticipante = @IdParticipanteA,

        @OrdenParticipante = 1,

        @EsLocal = 1,

        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_AgregarParticipanteEvento

        @IdUsuarioProceso = @IdAdministrador,

        @IdEvento = @IdEvento,

        @IdParticipante = @IdParticipanteB,

        @OrdenParticipante = 2,

        @EsLocal = 0,

        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_CrearMercado

        @IdUsuarioProceso = @IdAdministrador,

        @IdEvento = @IdEvento,

        @Nombre = @NombreMercado,

        @Descripcion = 'Mercado temporal.',

        @IpOrigen = '127.0.0.1';


    DECLARE @IdMercado INT;


    SELECT @IdMercado = IdMercado
    FROM dbo.Mercado
    WHERE IdEvento = @IdEvento;


    EXEC dbo.sp_CrearSeleccion

        @IdUsuarioProceso = @IdAdministrador,

        @IdMercado = @IdMercado,

        @Nombre = 'Equipo A',

        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_CrearSeleccion

        @IdUsuarioProceso = @IdAdministrador,

        @IdMercado = @IdMercado,

        @Nombre = 'Equipo B',

        @IpOrigen = '127.0.0.1';


    DECLARE @IdSeleccion INT;


    SELECT @IdSeleccion = IdSeleccion
    FROM dbo.Seleccion
    WHERE IdMercado = @IdMercado
      AND Nombre = 'Equipo A';


    EXEC dbo.sp_RegistrarCuota

        @IdUsuarioProceso = @IdAdministrador,

        @IdSeleccion = @IdSeleccion,

        @Valor = 1.9000,

        @IpOrigen = '127.0.0.1';


    DECLARE @IdSeleccionB INT;


    SELECT @IdSeleccionB = IdSeleccion
    FROM dbo.Seleccion
    WHERE IdMercado = @IdMercado
      AND Nombre = 'Equipo B';


    EXEC dbo.sp_RegistrarCuota

        @IdUsuarioProceso = @IdAdministrador,

        @IdSeleccion = @IdSeleccionB,

        @Valor = 2.0000,

        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_CambiarEstadoEvento

        @IdUsuarioProceso = @IdAdministrador,

        @IdEvento = @IdEvento,

        @NuevoEstado = 'PROGRAMADO',

        @Motivo = 'Prueba restricciones.',

        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_CambiarEstadoMercado

        @IdUsuarioProceso = @IdAdministrador,

        @IdMercado = @IdMercado,

        @NuevoEstado = 'ABIERTO',

        @Motivo = 'Prueba restricciones.',

        @IpOrigen = '127.0.0.1';


    /* ========================================================
       6. AGREGAR RESTRICCION APOSTAR
       ======================================================== */

    PRINT '';
    PRINT '1. AGREGAR RESTRICCION APOSTAR';
    DECLARE @FechaFinRestriccion DATETIME2 =
        DATEADD(DAY, 1, SYSDATETIME());

    EXEC dbo.sp_AgregarRestriccionUsuario

        @IdUsuarioProceso = @IdAdministrador,

        @IdUsuarioObjetivo = @IdUsuario,

        @TipoRestriccion = 'APOSTAR',

        @Motivo = 'Prueba temporal de restricción.',

        @FechaFin = @FechaFinRestriccion,

        @IpOrigen = '127.0.0.1';


    DECLARE @IdRestriccion INT;


    SELECT TOP (1)
        @IdRestriccion = IdRestriccion
    FROM dbo.RestriccionUsuario
    WHERE IdUsuario = @IdUsuario
      AND TipoRestriccion = 'APOSTAR'
      AND Activa = 1
    ORDER BY IdRestriccion DESC;


    IF @IdRestriccion IS NULL
        THROW 70605, 'No se creó la restricción APOSTAR.', 1;


    PRINT 'Restricción APOSTAR creada: OK';


    /* ========================================================
       7. LEVANTAR RESTRICCION
       ======================================================== */

    EXEC dbo.sp_LevantarRestriccionUsuario

        @IdUsuarioProceso = @IdAdministrador,

        @IdRestriccion = @IdRestriccion,

        @MotivoLevantamiento =
            'Fin de primera etapa de prueba.',

        @IpOrigen = '127.0.0.1';


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.RestriccionUsuario
        WHERE IdRestriccion = @IdRestriccion
          AND Activa = 0
          AND FechaFin IS NOT NULL
    )
        THROW 70606, 'La restricción no fue levantada correctamente.', 1;


    PRINT 'Levantamiento de restricción: OK';


    /* ========================================================
       8. USUARIO DEBE PODER APOSTAR DESPUES DEL LEVANTAMIENTO
       ======================================================== */

    DECLARE @MontoMinimo DECIMAL(12,2);


    SELECT @MontoMinimo =
        TRY_CONVERT(DECIMAL(12,2), Valor)
    FROM dbo.ConfiguracionSistema
    WHERE Clave = 'MONTO_MINIMO_APUESTA';


    DECLARE @Monto DECIMAL(12,2);


    SET @Monto =
        CASE
            WHEN @MontoMinimo > 10.00
                THEN @MontoMinimo
            ELSE 10.00
        END;


    DECLARE @Json NVARCHAR(MAX) =
        N'['
        + CONVERT(NVARCHAR(20), @IdSeleccion)
        + N']';


    DECLARE @ReferenciaPermitida UNIQUEIDENTIFIER =
        NEWID();


    PRINT '';
    PRINT '2. APUESTA DESPUES DE LEVANTAR RESTRICCION';


    EXEC dbo.sp_RealizarApuesta

        @IdUsuario = @IdUsuario,

        @SeleccionesJson = @Json,

        @Monto = @Monto,

        @ReferenciaOperacion = @ReferenciaPermitida,

        @IpOrigen = '127.0.0.1';


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Boleto
        WHERE ReferenciaOperacion = @ReferenciaPermitida
          AND IdUsuario = @IdUsuario
    )
        THROW 70607, 'El usuario no pudo apostar después de levantar la restricción.', 1;


    PRINT 'Apuesta permitida: OK';


    /* ========================================================
       9. AGREGAR TODAS_OPERACIONES
       ======================================================== */

    PRINT '';
    PRINT '3. AGREGAR TODAS_OPERACIONES';


    EXEC dbo.sp_AgregarRestriccionUsuario

        @IdUsuarioProceso = @IdAdministrador,

        @IdUsuarioObjetivo = @IdUsuario,

        @TipoRestriccion = 'TODAS_OPERACIONES',

        @Motivo =
            'Prueba final de bloqueo de operaciones.',

        @FechaFin = NULL,

        @IpOrigen = '127.0.0.1';


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.RestriccionUsuario
        WHERE IdUsuario = @IdUsuario
          AND TipoRestriccion = 'TODAS_OPERACIONES'
          AND Activa = 1
    )
        THROW 70608, 'No se creó TODAS_OPERACIONES.', 1;


    PRINT 'TODAS_OPERACIONES creada: OK';


    /* ========================================================
       10. AUDITORIA
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Auditoria
        WHERE IdUsuario = @IdAdministrador
          AND Accion = 'RESTRICCION_USUARIO_AGREGADA'
    )
        THROW 70609, 'No existe auditoría de creación de restricción.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Auditoria
        WHERE IdUsuario = @IdAdministrador
          AND Accion = 'RESTRICCION_USUARIO_LEVANTADA'
    )
        THROW 70610, 'No existe auditoría del levantamiento.', 1;


    PRINT 'Auditoría de restricciones: OK';


    /* ========================================================
       11. PRUEBA FINAL

       ESTA APUESTA DEBE FALLAR CON ERROR 60039.

       IMPORTANTE:
       sp_RealizarApuesta ejecutará ROLLBACK de la transacción
       completa al detectar la restricción.

       Por eso esta prueba se hace al FINAL.
       ======================================================== */

    PRINT '';
    PRINT '4. INTENTAR APUESTA CON RESTRICCION VIGENTE';
    PRINT 'Se espera ERROR 60039...';


    DECLARE @ReferenciaBloqueada UNIQUEIDENTIFIER =
        NEWID();


    EXEC dbo.sp_RealizarApuesta

        @IdUsuario = @IdUsuario,

        @SeleccionesJson = @Json,

        @Monto = @Monto,

        @ReferenciaOperacion = @ReferenciaBloqueada,

        @IpOrigen = '127.0.0.1';


    /* Si llega aquí, la prueba falló. */

    THROW 70611,
          'ERROR: sp_RealizarApuesta permitió apostar a un usuario restringido.',
          1;


END TRY
BEGIN CATCH

    /* ========================================================
       ERROR 60039 ES EL RESULTADO ESPERADO.
       ======================================================== */

    IF ERROR_NUMBER() = 60039
    BEGIN

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;


        PRINT '';
        PRINT '=======================================================';
        PRINT ' RESULTADO: PRUEBA DE RESTRICCIONES CORRECTA';
        PRINT '=======================================================';

        PRINT 'sp_RealizarApuesta rechazó correctamente al usuario.';
        PRINT 'Error esperado recibido: 60039';
        PRINT 'La transacción temporal fue revertida.';
        PRINT 'No quedaron datos permanentes.';

    END
    ELSE
    BEGIN

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;


        PRINT '';
        PRINT '=======================================================';
        PRINT ' ERROR NO ESPERADO EN PRUEBA DE RESTRICCIONES';
        PRINT '=======================================================';

        PRINT 'Error: '
            + CONVERT(VARCHAR(20), ERROR_NUMBER());

        PRINT 'Mensaje: '
            + ERROR_MESSAGE();


        THROW;

    END;

END CATCH;
GO