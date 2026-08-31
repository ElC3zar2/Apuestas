/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   07_PRUEBAS/04_PruebaEventosMercados.sql

   OBJETIVO:
   Probar el ciclo de creación de:
   - Liga
   - Participantes
   - Evento
   - EventoParticipante
   - Mercado
   - Selecciones
   - Cuotas
   - Estados de evento y mercado

   Toda la prueba termina con ROLLBACK.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


BEGIN TRY

    BEGIN TRANSACTION;


    PRINT '=======================================================';
    PRINT ' PRUEBA DE EVENTOS Y MERCADOS';
    PRINT '=======================================================';


    /* ========================================================
       1. ADMINISTRADOR / OPERADOR
       ======================================================== */

    DECLARE @IdUsuarioProceso INT;


    SELECT TOP (1)
        @IdUsuarioProceso = U.IdUsuario

    FROM dbo.Usuario AS U

    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol

    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = U.IdEstado

    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'USUARIO'

    WHERE R.Nombre IN
          (
              'ADMINISTRADOR',
              'OPERADOR_EVENTOS'
          )
      AND E.Codigo = 'ACTIVO'

    ORDER BY
        CASE
            WHEN R.Nombre = 'OPERADOR_EVENTOS'
                THEN 0
            ELSE 1
        END,
        U.IdUsuario;


    IF @IdUsuarioProceso IS NULL
        THROW 70201, 'No existe ADMINISTRADOR u OPERADOR_EVENTOS activo.', 1;


    /* ========================================================
       2. DEPORTE Y PAIS
       ======================================================== */

    DECLARE @IdDeporte INT;
    DECLARE @IdPais INT;


    SELECT TOP (1)
        @IdDeporte = IdDeporte
    FROM dbo.Deporte
    WHERE Nombre = 'Futbol'
      AND Activo = 1;


    SELECT @IdPais = IdPais
    FROM dbo.Pais
    WHERE CodigoISO2 = 'GT'
      AND Activo = 1;


    IF @IdDeporte IS NULL
        THROW 70202, 'No existe el deporte Futbol.', 1;


    IF @IdPais IS NULL
        THROW 70203, 'No existe Guatemala.', 1;


    DECLARE @Codigo VARCHAR(20) =
        LEFT
        (
            REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
            12
        );
    DECLARE @NombreLiga VARCHAR(150) =
    CONCAT('Liga Prueba ', @Codigo);

    DECLARE @NombreParticipante1 VARCHAR(150) =
        CONCAT('Equipo A ', @Codigo);

    DECLARE @NombreParticipante2 VARCHAR(150) =
        CONCAT('Equipo B ', @Codigo);

    DECLARE @NombreEvento VARCHAR(200) =
        CONCAT('Equipo A vs Equipo B ', @Codigo);

    DECLARE @NombreSeleccion1 VARCHAR(150) =
        CONCAT('Equipo A ', @Codigo);

    DECLARE @NombreSeleccion2 VARCHAR(150) =
        CONCAT('Equipo B ', @Codigo);


    /* ========================================================
       3. CREAR LIGA
       ======================================================== */

    DECLARE @Liga TABLE
    (
        IdLiga INT,
        IdDeporte INT,
        IdPais INT NULL,
        Nombre VARCHAR(150),
        Activo BIT
    );


    INSERT INTO @Liga
    EXEC dbo.sp_CrearLiga

        @IdUsuarioProceso = @IdUsuarioProceso,

        @IdDeporte = @IdDeporte,

        @Nombre = @NombreLiga,

        @IdPais = @IdPais,

        @IpOrigen = '127.0.0.1';


    DECLARE @IdLiga INT;

    SELECT @IdLiga = IdLiga
    FROM @Liga;


    IF @IdLiga IS NULL
        THROW 70204, 'No se creó correctamente la liga.', 1;


    PRINT '';
    PRINT 'Liga creada: '
        + CONVERT(VARCHAR(20), @IdLiga);


    /* ========================================================
       4. CREAR DOS PARTICIPANTES
       ======================================================== */

    DECLARE @Participante1 TABLE
    (
        IdParticipante INT,
        IdDeporte INT,
        IdPais INT NULL,
        Nombre VARCHAR(150),
        TipoParticipante VARCHAR(30),
        Activo BIT
    );


    DECLARE @Participante2 TABLE
    (
        IdParticipante INT,
        IdDeporte INT,
        IdPais INT NULL,
        Nombre VARCHAR(150),
        TipoParticipante VARCHAR(30),
        Activo BIT
    );


    INSERT INTO @Participante1
    EXEC dbo.sp_CrearParticipante

        @IdUsuarioProceso = @IdUsuarioProceso,

        @IdDeporte = @IdDeporte,

        @Nombre = @NombreParticipante1,

        @TipoParticipante = 'EQUIPO',

        @IdPais = @IdPais,

        @IpOrigen = '127.0.0.1';


    INSERT INTO @Participante2
    EXEC dbo.sp_CrearParticipante

        @IdUsuarioProceso = @IdUsuarioProceso,

        @IdDeporte = @IdDeporte,

        @Nombre = @NombreParticipante2,

        @TipoParticipante = 'EQUIPO',

        @IdPais = @IdPais,

        @IpOrigen = '127.0.0.1';


    DECLARE @IdParticipante1 INT;
    DECLARE @IdParticipante2 INT;


    SELECT @IdParticipante1 = IdParticipante
    FROM @Participante1;


    SELECT @IdParticipante2 = IdParticipante
    FROM @Participante2;


    IF @IdParticipante1 IS NULL
       OR @IdParticipante2 IS NULL
        THROW 70205, 'No se crearon correctamente los participantes.', 1;


    /* ========================================================
       5. CREAR EVENTO
       ======================================================== */

    DECLARE @Evento TABLE
    (
        IdEvento INT,
        IdLiga INT,
        IdEstado INT,
        EstadoEvento VARCHAR(40),
        Nombre VARCHAR(200),
        FechaInicio DATETIME2,
        FechaFin DATETIME2 NULL
    );


    DECLARE @FechaInicio DATETIME2 =
        DATEADD(DAY, 2, SYSDATETIME());
    DECLARE @FechaFin DATETIME2 =
        DATEADD(HOUR, 2, @FechaInicio);

    INSERT INTO @Evento
    EXEC dbo.sp_CrearEvento

        @IdUsuarioProceso = @IdUsuarioProceso,

        @IdLiga = @IdLiga,

        @Nombre = @NombreEvento,

        @FechaInicio = @FechaInicio,

        @FechaFin = @FechaFin,

        @IpOrigen = '127.0.0.1';


    DECLARE @IdEvento INT;

    SELECT @IdEvento = IdEvento
    FROM @Evento;


    IF @IdEvento IS NULL
        THROW 70206, 'No se creó correctamente el evento.', 1;


    /* ========================================================
       6. AGREGAR PARTICIPANTES
       ======================================================== */

    EXEC dbo.sp_AgregarParticipanteEvento

        @IdUsuarioProceso = @IdUsuarioProceso,

        @IdEvento = @IdEvento,

        @IdParticipante = @IdParticipante1,

        @OrdenParticipante = 1,

        @EsLocal = 1,

        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_AgregarParticipanteEvento

        @IdUsuarioProceso = @IdUsuarioProceso,

        @IdEvento = @IdEvento,

        @IdParticipante = @IdParticipante2,

        @OrdenParticipante = 2,

        @EsLocal = 0,

        @IpOrigen = '127.0.0.1';


    IF
    (
        SELECT COUNT(*)
        FROM dbo.EventoParticipante
        WHERE IdEvento = @IdEvento
    ) <> 2
        THROW 70207, 'El evento no contiene los dos participantes esperados.', 1;


    PRINT '';
    PRINT 'Evento con 2 participantes: OK';


    /* ========================================================
       7. CREAR MERCADO
       ======================================================== */

    DECLARE @Mercado TABLE
    (
        IdMercado INT,
        IdEvento INT,
        IdEstado INT,
        EstadoMercado VARCHAR(40),
        Nombre VARCHAR(150),
        Descripcion VARCHAR(250) NULL
    );


    INSERT INTO @Mercado
    EXEC dbo.sp_CrearMercado

        @IdUsuarioProceso = @IdUsuarioProceso,

        @IdEvento = @IdEvento,

        @Nombre = 'Ganador del partido',

        @Descripcion =
            'Mercado temporal para prueba automática.',

        @IpOrigen = '127.0.0.1';


    DECLARE @IdMercado INT;

    SELECT @IdMercado = IdMercado
    FROM @Mercado;


    IF @IdMercado IS NULL
        THROW 70208, 'No se creó correctamente el mercado.', 1;


    /* ========================================================
       8. CREAR SELECCIONES
       ======================================================== */

    DECLARE @Seleccion1 TABLE
    (
        IdSeleccion INT,
        IdMercado INT,
        Nombre VARCHAR(150),
        Activo BIT
    );


    DECLARE @Seleccion2 TABLE
    (
        IdSeleccion INT,
        IdMercado INT,
        Nombre VARCHAR(150),
        Activo BIT
    );


    INSERT INTO @Seleccion1
    EXEC dbo.sp_CrearSeleccion

        @IdUsuarioProceso = @IdUsuarioProceso,

        @IdMercado = @IdMercado,

        @Nombre = @NombreSeleccion1,

        @IpOrigen = '127.0.0.1';


    INSERT INTO @Seleccion2
    EXEC dbo.sp_CrearSeleccion

        @IdUsuarioProceso = @IdUsuarioProceso,

        @IdMercado = @IdMercado,

        @Nombre = @NombreSeleccion2,

        @IpOrigen = '127.0.0.1';


    DECLARE @IdSeleccion1 INT;
    DECLARE @IdSeleccion2 INT;


    SELECT @IdSeleccion1 = IdSeleccion
    FROM @Seleccion1;


    SELECT @IdSeleccion2 = IdSeleccion
    FROM @Seleccion2;


    IF @IdSeleccion1 IS NULL
       OR @IdSeleccion2 IS NULL
        THROW 70209, 'No se crearon correctamente las selecciones.', 1;


    /* ========================================================
       9. REGISTRAR CUOTAS
       ======================================================== */

    EXEC dbo.sp_RegistrarCuota

        @IdUsuarioProceso = @IdUsuarioProceso,

        @IdSeleccion = @IdSeleccion1,

        @Valor = 1.8500,

        @IpOrigen = '127.0.0.1';


    EXEC dbo.sp_RegistrarCuota

        @IdUsuarioProceso = @IdUsuarioProceso,

        @IdSeleccion = @IdSeleccion2,

        @Valor = 2.1000,

        @IpOrigen = '127.0.0.1';


    IF
    (
        SELECT COUNT(*)

        FROM dbo.Cuota AS C

        INNER JOIN dbo.Seleccion AS S
            ON S.IdSeleccion = C.IdSeleccion

        WHERE S.IdMercado = @IdMercado
          AND C.Activo = 1
    ) <> 2
        THROW 70210, 'Las selecciones no poseen las dos cuotas activas esperadas.', 1;


    PRINT '';
    PRINT 'Selecciones y cuotas: OK';


    /* ========================================================
       10. EVENTO BORRADOR -> PROGRAMADO
       ======================================================== */

    EXEC dbo.sp_CambiarEstadoEvento

        @IdUsuarioProceso = @IdUsuarioProceso,

        @IdEvento = @IdEvento,

        @NuevoEstado = 'PROGRAMADO',

        @Motivo = 'Prueba automática.',

        @IpOrigen = '127.0.0.1';


    IF NOT EXISTS
    (
        SELECT 1

        FROM dbo.Evento AS EV

        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = EV.IdEstado

        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'EVENTO'

        WHERE EV.IdEvento = @IdEvento
          AND E.Codigo = 'PROGRAMADO'
    )
        THROW 70211, 'El evento no cambió correctamente a PROGRAMADO.', 1;


    /* ========================================================
       11. MERCADO BORRADOR -> ABIERTO
       ======================================================== */

    EXEC dbo.sp_CambiarEstadoMercado

        @IdUsuarioProceso = @IdUsuarioProceso,

        @IdMercado = @IdMercado,

        @NuevoEstado = 'ABIERTO',

        @Motivo = 'Prueba automática.',

        @IpOrigen = '127.0.0.1';


    IF NOT EXISTS
    (
        SELECT 1

        FROM dbo.Mercado AS M

        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = M.IdEstado

        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'MERCADO'

        WHERE M.IdMercado = @IdMercado
          AND E.Codigo = 'ABIERTO'
    )
        THROW 70212, 'El mercado no cambió correctamente a ABIERTO.', 1;


    PRINT '';
    PRINT 'Evento PROGRAMADO: OK';
    PRINT 'Mercado ABIERTO: OK';


    /* ========================================================
       12. VERIFICAR VISTAS
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.vw_EventosDisponibles
        WHERE IdEvento = @IdEvento
    )
        THROW 70213, 'El evento no aparece en vw_EventosDisponibles.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.vw_MercadosAbiertos
        WHERE IdMercado = @IdMercado
    )
        THROW 70214, 'El mercado no aparece en vw_MercadosAbiertos.', 1;


    IF
    (
        SELECT COUNT(*)
        FROM dbo.vw_CuotasActuales
        WHERE IdMercado = @IdMercado
    ) <> 2
        THROW 70215, 'vw_CuotasActuales no devuelve las cuotas esperadas.', 1;


    PRINT '';
    PRINT 'Vistas operativas: OK';


    /* ========================================================
       13. CAMBIO DE CUOTA / HISTORIAL
       ======================================================== */

    DECLARE @IdCuotaAnterior INT;


    SELECT @IdCuotaAnterior = IdCuota
    FROM dbo.Cuota
    WHERE IdSeleccion = @IdSeleccion1
      AND Activo = 1;


    EXEC dbo.sp_RegistrarCuota

        @IdUsuarioProceso = @IdUsuarioProceso,

        @IdSeleccion = @IdSeleccion1,

        @Valor = 1.9500,

        @IpOrigen = '127.0.0.1';


    IF EXISTS
    (
        SELECT 1
        FROM dbo.Cuota
        WHERE IdCuota = @IdCuotaAnterior
          AND Activo = 1
    )
        THROW 70216, 'La cuota anterior permaneció activa.', 1;


    IF
    (
        SELECT COUNT(*)
        FROM dbo.Cuota
        WHERE IdSeleccion = @IdSeleccion1
          AND Activo = 1
    ) <> 1
        THROW 70217, 'Debe existir exactamente una cuota activa por selección.', 1;


    PRINT '';
    PRINT 'Histórico de cuotas: OK';


    /* ========================================================
       14. VERIFICAR AUDITORIA
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Auditoria
        WHERE IdUsuario = @IdUsuarioProceso
          AND Accion = 'EVENTO_CREADO'
          AND IdRegistro = @IdEvento
    )
        THROW 70218, 'No existe auditoría de creación del evento.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Auditoria
        WHERE IdUsuario = @IdUsuarioProceso
          AND Accion = 'MERCADO_CREADO'
          AND IdRegistro = @IdMercado
    )
        THROW 70219, 'No existe auditoría de creación del mercado.', 1;


    PRINT '';
    PRINT 'Auditoría del módulo deportivo: OK';


    /* ========================================================
       RESULTADO
       ======================================================== */

    PRINT '';
    PRINT '=======================================================';
    PRINT ' RESULTADO: EVENTOS Y MERCADOS CORRECTOS';
    PRINT '=======================================================';


    SELECT *
    FROM dbo.vw_EventosDisponibles
    WHERE IdEvento = @IdEvento;


    SELECT *
    FROM dbo.vw_MercadosAbiertos
    WHERE IdMercado = @IdMercado;


    SELECT *
    FROM dbo.vw_CuotasActuales
    WHERE IdMercado = @IdMercado;


    ROLLBACK TRANSACTION;


    PRINT '';
    PRINT 'ROLLBACK realizado.';
    PRINT 'No quedaron eventos ni mercados de prueba.';


END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;


    PRINT '';
    PRINT '=======================================================';
    PRINT ' ERROR EN PRUEBA DE EVENTOS Y MERCADOS';
    PRINT '=======================================================';

    PRINT ERROR_MESSAGE();

    THROW;

END CATCH;
GO