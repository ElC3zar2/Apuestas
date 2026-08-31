/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   SQL SERVER 2022 / AZURE SQL

   ARCHIVO:
   03_PROCEDIMIENTOS/04_EventosMercados.sql

   OBJETIVO:
   Centralizar la administración del catálogo deportivo y la
   construcción operativa de eventos, mercados, selecciones
   y cuotas.

   INCLUYE:
   - Validación de permisos del módulo.
   - Creación y actualización de ligas.
   - Creación y actualización de participantes.
   - Creación y actualización de eventos.
   - Asociación de participantes a eventos.
   - Creación de mercados.
   - Creación de selecciones.
   - Registro histórico de cuotas.
   - Cambios controlados de estado de evento y mercado.

   ROLES AUTORIZADOS:
   - ADMINISTRADOR
   - OPERADOR_EVENTOS

   REGLAS:
   - Las operaciones sensibles quedan auditadas.
   - No se utilizan IdEstado fijos.
   - Los estados se resuelven por TipoEstado + Codigo.
   - Las cuotas mantienen histórico.
   - Registrar una nueva cuota cierra la cuota activa anterior.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


/* ============================================================
   1. VALIDAR PERMISO DEL MODULO DE EVENTOS

   Procedimiento auxiliar utilizado por los demás procedimientos
   de este archivo.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ValidarPermisoEventos
(
    @IdUsuarioProceso INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @IdUsuarioProceso IS NULL
        THROW 59001, 'IdUsuarioProceso es obligatorio.', 1;

    DECLARE @Rol VARCHAR(50);
    DECLARE @EstadoUsuario VARCHAR(40);

    SELECT
        @Rol = R.Nombre,
        @EstadoUsuario = E.Codigo
    FROM dbo.Usuario AS U
    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol
    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = U.IdEstado
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'USUARIO'
    WHERE U.IdUsuario = @IdUsuarioProceso;

    IF @Rol IS NULL
        THROW 59002, 'El usuario que procesa la operación no existe.', 1;

    IF @Rol NOT IN ('ADMINISTRADOR', 'OPERADOR_EVENTOS')
        THROW 59003, 'El usuario no tiene permisos para administrar eventos y mercados.', 1;

    IF @EstadoUsuario <> 'ACTIVO'
        THROW 59004, 'El usuario que procesa la operación debe estar ACTIVO.', 1;
END;
GO


/* ============================================================
   2. CREAR LIGA
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CrearLiga
(
    @IdUsuarioProceso INT,
    @IdDeporte INT,
    @Nombre VARCHAR(150),
    @IdPais INT = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @Nombre IS NULL
        THROW 59005, 'El nombre de la liga es obligatorio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Deporte
        WHERE IdDeporte = @IdDeporte
          AND Activo = 1
    )
        THROW 59006, 'El deporte indicado no existe o está inactivo.', 1;

    IF @IdPais IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Pais
           WHERE IdPais = @IdPais
             AND Activo = 1
       )
        THROW 59007, 'El país indicado no existe o está inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Liga WITH (UPDLOCK, HOLDLOCK)
            WHERE IdDeporte = @IdDeporte
              AND Nombre = @Nombre
        )
            THROW 59008, 'Ya existe una liga con ese nombre para el deporte indicado.', 1;

        INSERT INTO dbo.Liga
        (
            IdDeporte,
            IdPais,
            Nombre,
            Activo
        )
        VALUES
        (
            @IdDeporte,
            @IdPais,
            @Nombre,
            1
        );

        DECLARE @IdLiga INT =
            CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'LIGA_CREADA',
            'Liga',
            @IdLiga,
            @IpOrigen,
            CONCAT('Liga creada: ', @Nombre, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            @IdLiga AS IdLiga,
            @IdDeporte AS IdDeporte,
            @IdPais AS IdPais,
            @Nombre AS Nombre,
            CAST(1 AS BIT) AS Activo;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   3. ACTUALIZAR LIGA
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ActualizarLiga
(
    @IdUsuarioProceso INT,
    @IdLiga INT,
    @Nombre VARCHAR(150),
    @IdPais INT = NULL,
    @Activo BIT,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @IdLiga IS NULL
        THROW 59009, 'IdLiga es obligatorio.', 1;

    IF @Nombre IS NULL
        THROW 59010, 'El nombre de la liga es obligatorio.', 1;

    IF @Activo IS NULL
        THROW 59011, 'Activo es obligatorio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    IF @IdPais IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Pais
           WHERE IdPais = @IdPais
             AND Activo = 1
       )
        THROW 59012, 'El país indicado no existe o está inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IdDeporte INT;

        SELECT @IdDeporte = IdDeporte
        FROM dbo.Liga WITH (UPDLOCK, HOLDLOCK)
        WHERE IdLiga = @IdLiga;

        IF @IdDeporte IS NULL
            THROW 59013, 'La liga indicada no existe.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Liga
            WHERE IdDeporte = @IdDeporte
              AND Nombre = @Nombre
              AND IdLiga <> @IdLiga
        )
            THROW 59014, 'Ya existe otra liga con ese nombre para el mismo deporte.', 1;

        IF @Activo = 0
           AND EXISTS
           (
               SELECT 1
               FROM dbo.Evento
               WHERE IdLiga = @IdLiga
           )
            THROW 59015, 'No se puede desactivar una liga que ya tiene eventos registrados.', 1;

        UPDATE dbo.Liga
        SET
            Nombre = @Nombre,
            IdPais = @IdPais,
            Activo = @Activo
        WHERE IdLiga = @IdLiga;

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'LIGA_ACTUALIZADA',
            'Liga',
            @IdLiga,
            @IpOrigen,
            CONCAT('Liga actualizada: ', @Nombre, '. Activo=', @Activo, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            IdLiga,
            IdDeporte,
            IdPais,
            Nombre,
            Activo
        FROM dbo.Liga
        WHERE IdLiga = @IdLiga;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   4. CREAR PARTICIPANTE
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CrearParticipante
(
    @IdUsuarioProceso INT,
    @IdDeporte INT,
    @Nombre VARCHAR(150),
    @TipoParticipante VARCHAR(30),
    @IdPais INT = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @TipoParticipante =
        NULLIF(UPPER(LTRIM(RTRIM(@TipoParticipante))), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @Nombre IS NULL
        THROW 59016, 'El nombre del participante es obligatorio.', 1;

    IF @TipoParticipante IS NULL
       OR @TipoParticipante NOT IN ('EQUIPO', 'ATLETA')
        THROW 59017, 'TipoParticipante debe ser EQUIPO o ATLETA.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Deporte
        WHERE IdDeporte = @IdDeporte
          AND Activo = 1
    )
        THROW 59018, 'El deporte indicado no existe o está inactivo.', 1;

    IF @IdPais IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Pais
           WHERE IdPais = @IdPais
             AND Activo = 1
       )
        THROW 59019, 'El país indicado no existe o está inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Participante WITH (UPDLOCK, HOLDLOCK)
            WHERE IdDeporte = @IdDeporte
              AND Nombre = @Nombre
              AND TipoParticipante = @TipoParticipante
        )
            THROW 59020, 'Ya existe ese participante para el deporte indicado.', 1;

        INSERT INTO dbo.Participante
        (
            IdDeporte,
            IdPais,
            Nombre,
            TipoParticipante,
            Activo
        )
        VALUES
        (
            @IdDeporte,
            @IdPais,
            @Nombre,
            @TipoParticipante,
            1
        );

        DECLARE @IdParticipante INT =
            CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'PARTICIPANTE_CREADO',
            'Participante',
            @IdParticipante,
            @IpOrigen,
            CONCAT('Participante creado: ', @Nombre, ' (', @TipoParticipante, ').')
        );

        COMMIT TRANSACTION;

        SELECT
            @IdParticipante AS IdParticipante,
            @IdDeporte AS IdDeporte,
            @IdPais AS IdPais,
            @Nombre AS Nombre,
            @TipoParticipante AS TipoParticipante,
            CAST(1 AS BIT) AS Activo;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   5. ACTUALIZAR PARTICIPANTE
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ActualizarParticipante
(
    @IdUsuarioProceso INT,
    @IdParticipante INT,
    @Nombre VARCHAR(150),
    @IdPais INT = NULL,
    @Activo BIT,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @IdParticipante IS NULL
        THROW 59021, 'IdParticipante es obligatorio.', 1;

    IF @Nombre IS NULL
        THROW 59022, 'El nombre del participante es obligatorio.', 1;

    IF @Activo IS NULL
        THROW 59023, 'Activo es obligatorio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    IF @IdPais IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Pais
           WHERE IdPais = @IdPais
             AND Activo = 1
       )
        THROW 59024, 'El país indicado no existe o está inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IdDeporte INT;
        DECLARE @TipoParticipante VARCHAR(30);

        SELECT
            @IdDeporte = IdDeporte,
            @TipoParticipante = TipoParticipante
        FROM dbo.Participante WITH (UPDLOCK, HOLDLOCK)
        WHERE IdParticipante = @IdParticipante;

        IF @IdDeporte IS NULL
            THROW 59025, 'El participante indicado no existe.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Participante
            WHERE IdDeporte = @IdDeporte
              AND Nombre = @Nombre
              AND TipoParticipante = @TipoParticipante
              AND IdParticipante <> @IdParticipante
        )
            THROW 59026, 'Ya existe otro participante con ese nombre para el mismo deporte.', 1;

        IF @Activo = 0
           AND EXISTS
           (
               SELECT 1
               FROM dbo.EventoParticipante
               WHERE IdParticipante = @IdParticipante
           )
            THROW 59027, 'No se puede desactivar un participante que ya está asociado a eventos.', 1;

        UPDATE dbo.Participante
        SET
            Nombre = @Nombre,
            IdPais = @IdPais,
            Activo = @Activo
        WHERE IdParticipante = @IdParticipante;

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'PARTICIPANTE_ACTUALIZADO',
            'Participante',
            @IdParticipante,
            @IpOrigen,
            CONCAT('Participante actualizado: ', @Nombre, '. Activo=', @Activo, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            IdParticipante,
            IdDeporte,
            IdPais,
            Nombre,
            TipoParticipante,
            Activo
        FROM dbo.Participante
        WHERE IdParticipante = @IdParticipante;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   6. CREAR EVENTO
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CrearEvento
(
    @IdUsuarioProceso INT,
    @IdLiga INT,
    @Nombre VARCHAR(200),
    @FechaInicio DATETIME2,
    @FechaFin DATETIME2 = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @Nombre IS NULL
        THROW 59028, 'El nombre del evento es obligatorio.', 1;

    IF @FechaInicio IS NULL
        THROW 59029, 'FechaInicio es obligatoria.', 1;

    IF @FechaFin IS NOT NULL
       AND @FechaFin <= @FechaInicio
        THROW 59030, 'FechaFin debe ser posterior a FechaInicio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Liga
        WHERE IdLiga = @IdLiga
          AND Activo = 1
    )
        THROW 59031, 'La liga indicada no existe o está inactiva.', 1;

    DECLARE @IdEstadoBorrador INT;

    SELECT @IdEstadoBorrador = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'EVENTO'
      AND E.Codigo = 'BORRADOR'
      AND E.Activo = 1;

    IF @IdEstadoBorrador IS NULL
        THROW 59032, 'No existe el estado EVENTO/BORRADOR.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Evento
        (
            IdLiga,
            IdEstado,
            Nombre,
            FechaInicio,
            FechaFin
        )
        VALUES
        (
            @IdLiga,
            @IdEstadoBorrador,
            @Nombre,
            @FechaInicio,
            @FechaFin
        );

        DECLARE @IdEvento INT =
            CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'EVENTO_CREADO',
            'Evento',
            @IdEvento,
            @IpOrigen,
            CONCAT('Evento creado en estado BORRADOR: ', @Nombre, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            @IdEvento AS IdEvento,
            @IdLiga AS IdLiga,
            @IdEstadoBorrador AS IdEstado,
            'BORRADOR' AS EstadoEvento,
            @Nombre AS Nombre,
            @FechaInicio AS FechaInicio,
            @FechaFin AS FechaFin;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   7. ACTUALIZAR EVENTO

   No cambia la liga ni los participantes.
   Se limita a datos descriptivos y fechas.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ActualizarEvento
(
    @IdUsuarioProceso INT,
    @IdEvento INT,
    @Nombre VARCHAR(200),
    @FechaInicio DATETIME2,
    @FechaFin DATETIME2 = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @IdEvento IS NULL
        THROW 59033, 'IdEvento es obligatorio.', 1;

    IF @Nombre IS NULL
        THROW 59034, 'El nombre del evento es obligatorio.', 1;

    IF @FechaInicio IS NULL
        THROW 59035, 'FechaInicio es obligatoria.', 1;

    IF @FechaFin IS NOT NULL
       AND @FechaFin <= @FechaInicio
        THROW 59036, 'FechaFin debe ser posterior a FechaInicio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @EstadoActual VARCHAR(40);

        SELECT @EstadoActual = E.Codigo
        FROM dbo.Evento AS EV WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = EV.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'EVENTO'
        WHERE EV.IdEvento = @IdEvento;

        IF @EstadoActual IS NULL
            THROW 59037, 'El evento indicado no existe.', 1;

        IF @EstadoActual NOT IN ('BORRADOR', 'PROGRAMADO', 'SUSPENDIDO')
            THROW 59038, 'El evento ya no puede modificar sus datos generales en su estado actual.', 1;

        UPDATE dbo.Evento
        SET
            Nombre = @Nombre,
            FechaInicio = @FechaInicio,
            FechaFin = @FechaFin
        WHERE IdEvento = @IdEvento;

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'EVENTO_ACTUALIZADO',
            'Evento',
            @IdEvento,
            @IpOrigen,
            CONCAT('Evento actualizado: ', @Nombre, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            EV.IdEvento,
            EV.IdLiga,
            EV.IdEstado,
            E.Codigo AS EstadoEvento,
            EV.Nombre,
            EV.FechaInicio,
            EV.FechaFin
        FROM dbo.Evento AS EV
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = EV.IdEstado
        WHERE EV.IdEvento = @IdEvento;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   8. AGREGAR PARTICIPANTE A EVENTO

   Solo se permite mientras el evento está en BORRADOR.
   También valida que participante y liga pertenezcan al mismo
   deporte.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_AgregarParticipanteEvento
(
    @IdUsuarioProceso INT,
    @IdEvento INT,
    @IdParticipante INT,
    @OrdenParticipante TINYINT,
    @EsLocal BIT = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @OrdenParticipante IS NULL OR @OrdenParticipante <= 0
        THROW 59039, 'OrdenParticipante debe ser mayor que cero.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @EstadoEvento VARCHAR(40);
        DECLARE @IdDeporteEvento INT;
        DECLARE @IdDeporteParticipante INT;

        SELECT
            @EstadoEvento = E.Codigo,
            @IdDeporteEvento = L.IdDeporte
        FROM dbo.Evento AS EV WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = EV.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'EVENTO'
        INNER JOIN dbo.Liga AS L
            ON L.IdLiga = EV.IdLiga
        WHERE EV.IdEvento = @IdEvento;

        IF @EstadoEvento IS NULL
            THROW 59040, 'El evento indicado no existe.', 1;

        IF @EstadoEvento <> 'BORRADOR'
            THROW 59041, 'Solo se pueden agregar participantes a un evento en BORRADOR.', 1;

        SELECT @IdDeporteParticipante = IdDeporte
        FROM dbo.Participante
        WHERE IdParticipante = @IdParticipante
          AND Activo = 1;

        IF @IdDeporteParticipante IS NULL
            THROW 59042, 'El participante indicado no existe o está inactivo.', 1;

        IF @IdDeporteParticipante <> @IdDeporteEvento
            THROW 59043, 'El participante no pertenece al mismo deporte que la liga del evento.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.EventoParticipante
            WHERE IdEvento = @IdEvento
              AND IdParticipante = @IdParticipante
        )
            THROW 59044, 'El participante ya está asociado al evento.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.EventoParticipante
            WHERE IdEvento = @IdEvento
              AND OrdenParticipante = @OrdenParticipante
        )
            THROW 59045, 'El orden indicado ya está ocupado por otro participante del evento.', 1;

        INSERT INTO dbo.EventoParticipante
        (
            IdEvento,
            IdParticipante,
            OrdenParticipante,
            EsLocal
        )
        VALUES
        (
            @IdEvento,
            @IdParticipante,
            @OrdenParticipante,
            @EsLocal
        );

        DECLARE @IdEventoParticipante INT =
            CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'PARTICIPANTE_AGREGADO_EVENTO',
            'EventoParticipante',
            @IdEventoParticipante,
            @IpOrigen,
            CONCAT('Participante ', @IdParticipante, ' agregado al evento ', @IdEvento, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            @IdEventoParticipante AS IdEventoParticipante,
            @IdEvento AS IdEvento,
            @IdParticipante AS IdParticipante,
            @OrdenParticipante AS OrdenParticipante,
            @EsLocal AS EsLocal;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   9. CREAR MERCADO

   Se permite para eventos:
   BORRADOR, PROGRAMADO o EN_VIVO.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CrearMercado
(
    @IdUsuarioProceso INT,
    @IdEvento INT,
    @Nombre VARCHAR(150),
    @Descripcion VARCHAR(250) = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @Nombre IS NULL
        THROW 59046, 'El nombre del mercado es obligatorio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    DECLARE @IdEstadoBorrador INT;

    SELECT @IdEstadoBorrador = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'MERCADO'
      AND E.Codigo = 'BORRADOR'
      AND E.Activo = 1;

    IF @IdEstadoBorrador IS NULL
        THROW 59047, 'No existe el estado MERCADO/BORRADOR.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @EstadoEvento VARCHAR(40);

        SELECT @EstadoEvento = E.Codigo
        FROM dbo.Evento AS EV WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = EV.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'EVENTO'
        WHERE EV.IdEvento = @IdEvento;

        IF @EstadoEvento IS NULL
            THROW 59048, 'El evento indicado no existe.', 1;

        IF @EstadoEvento NOT IN ('BORRADOR', 'PROGRAMADO', 'EN_VIVO')
            THROW 59049, 'No se pueden crear mercados para el evento en su estado actual.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Mercado
            WHERE IdEvento = @IdEvento
              AND Nombre = @Nombre
        )
            THROW 59050, 'Ya existe un mercado con ese nombre para el evento.', 1;

        INSERT INTO dbo.Mercado
        (
            IdEvento,
            IdEstado,
            Nombre,
            Descripcion
        )
        VALUES
        (
            @IdEvento,
            @IdEstadoBorrador,
            @Nombre,
            @Descripcion
        );

        DECLARE @IdMercado INT =
            CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'MERCADO_CREADO',
            'Mercado',
            @IdMercado,
            @IpOrigen,
            CONCAT('Mercado creado en BORRADOR: ', @Nombre, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            @IdMercado AS IdMercado,
            @IdEvento AS IdEvento,
            @IdEstadoBorrador AS IdEstado,
            'BORRADOR' AS EstadoMercado,
            @Nombre AS Nombre,
            @Descripcion AS Descripcion;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   10. CREAR SELECCION

   Solo se permite mientras el mercado está en BORRADOR.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CrearSeleccion
(
    @IdUsuarioProceso INT,
    @IdMercado INT,
    @Nombre VARCHAR(150),
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @Nombre IS NULL
        THROW 59051, 'El nombre de la selección es obligatorio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @EstadoMercado VARCHAR(40);

        SELECT @EstadoMercado = E.Codigo
        FROM dbo.Mercado AS M WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = M.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'MERCADO'
        WHERE M.IdMercado = @IdMercado;

        IF @EstadoMercado IS NULL
            THROW 59052, 'El mercado indicado no existe.', 1;

        IF @EstadoMercado <> 'BORRADOR'
            THROW 59053, 'Solo se pueden crear selecciones en un mercado en BORRADOR.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Seleccion
            WHERE IdMercado = @IdMercado
              AND Nombre = @Nombre
        )
            THROW 59054, 'Ya existe una selección con ese nombre para el mercado.', 1;

        INSERT INTO dbo.Seleccion
        (
            IdMercado,
            Nombre,
            Activo
        )
        VALUES
        (
            @IdMercado,
            @Nombre,
            1
        );

        DECLARE @IdSeleccion INT =
            CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'SELECCION_CREADA',
            'Seleccion',
            @IdSeleccion,
            @IpOrigen,
            CONCAT('Selección creada: ', @Nombre, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            @IdSeleccion AS IdSeleccion,
            @IdMercado AS IdMercado,
            @Nombre AS Nombre,
            CAST(1 AS BIT) AS Activo;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   11. REGISTRAR CUOTA

   - Mantiene histórico de cuotas.
   - Cierra la cuota activa anterior.
   - Puede utilizarse en mercados BORRADOR, ABIERTO o SUSPENDIDO.
   - No permite cuotas para mercados CERRADOS, LIQUIDADOS o ANULADOS.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_RegistrarCuota
(
    @IdUsuarioProceso INT,
    @IdSeleccion INT,
    @Valor DECIMAL(10,4),
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @Valor IS NULL OR @Valor <= 1
        THROW 59055, 'La cuota debe ser mayor que 1.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IdMercado INT;
        DECLARE @EstadoMercado VARCHAR(40);
        DECLARE @SeleccionActiva BIT;

        SELECT
            @IdMercado = S.IdMercado,
            @SeleccionActiva = S.Activo,
            @EstadoMercado = E.Codigo
        FROM dbo.Seleccion AS S
        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado = S.IdMercado
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = M.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'MERCADO'
        WHERE S.IdSeleccion = @IdSeleccion;

        IF @IdMercado IS NULL
            THROW 59056, 'La selección indicada no existe.', 1;

        IF @SeleccionActiva = 0
            THROW 59057, 'La selección indicada está inactiva.', 1;

        IF @EstadoMercado NOT IN ('BORRADOR', 'ABIERTO', 'SUSPENDIDO')
            THROW 59058, 'No se pueden registrar cuotas para el mercado en su estado actual.', 1;

        /* Serializar cambios de cuota de la misma selección. */
        DECLARE @IdCuotaAnterior INT;

        SELECT TOP (1)
            @IdCuotaAnterior = IdCuota
        FROM dbo.Cuota WITH (UPDLOCK, HOLDLOCK)
        WHERE IdSeleccion = @IdSeleccion
          AND Activo = 1
        ORDER BY IdCuota DESC;

        DECLARE @Ahora DATETIME2 = SYSDATETIME();

        UPDATE dbo.Cuota
        SET
            Activo = 0,
            FechaFin = @Ahora
        WHERE IdSeleccion = @IdSeleccion
          AND Activo = 1;

        INSERT INTO dbo.Cuota
        (
            IdSeleccion,
            Valor,
            FechaInicio,
            FechaFin,
            Activo
        )
        VALUES
        (
            @IdSeleccion,
            @Valor,
            @Ahora,
            NULL,
            1
        );

        DECLARE @IdCuota INT =
            CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'CUOTA_REGISTRADA',
            'Cuota',
            @IdCuota,
            @IpOrigen,
            CONCAT
            (
                'Nueva cuota ',
                CONVERT(VARCHAR(30), @Valor),
                ' para selección ',
                @IdSeleccion,
                '. Cuota anterior=',
                COALESCE(CONVERT(VARCHAR(20), @IdCuotaAnterior), 'NULL'),
                '.'
            )
        );

        COMMIT TRANSACTION;

        SELECT
            @IdCuota AS IdCuota,
            @IdSeleccion AS IdSeleccion,
            @Valor AS Valor,
            @Ahora AS FechaInicio,
            CAST(1 AS BIT) AS Activo,
            @IdCuotaAnterior AS IdCuotaAnterior;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   12. CAMBIAR ESTADO DE EVENTO

   TRANSICIONES PERMITIDAS:
   BORRADOR            -> PROGRAMADO, CANCELADO
   PROGRAMADO          -> EN_VIVO, SUSPENDIDO, CANCELADO
   EN_VIVO             -> PENDIENTE_RESULTADO, SUSPENDIDO, CANCELADO
   SUSPENDIDO          -> PROGRAMADO, EN_VIVO, CANCELADO
   PENDIENTE_RESULTADO -> FINALIZADO, CANCELADO

   FINALIZADO y CANCELADO son terminales.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CambiarEstadoEvento
(
    @IdUsuarioProceso INT,
    @IdEvento INT,
    @NuevoEstado VARCHAR(40),
    @Motivo VARCHAR(250) = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NuevoEstado =
        NULLIF(UPPER(LTRIM(RTRIM(@NuevoEstado))), '');
    SET @Motivo = NULLIF(LTRIM(RTRIM(@Motivo)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @IdEvento IS NULL
        THROW 59059, 'IdEvento es obligatorio.', 1;

    IF @NuevoEstado IS NULL
        THROW 59060, 'NuevoEstado es obligatorio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    DECLARE @IdNuevoEstado INT;

    SELECT @IdNuevoEstado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'EVENTO'
      AND E.Codigo = @NuevoEstado
      AND E.Activo = 1;

    IF @IdNuevoEstado IS NULL
        THROW 59061, 'El nuevo estado de evento no existe o está inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @EstadoActual VARCHAR(40);

        SELECT @EstadoActual = E.Codigo
        FROM dbo.Evento AS EV WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = EV.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'EVENTO'
        WHERE EV.IdEvento = @IdEvento;

        IF @EstadoActual IS NULL
            THROW 59062, 'El evento indicado no existe.', 1;

        IF @EstadoActual = @NuevoEstado
        BEGIN
            COMMIT TRANSACTION;

            SELECT
                @IdEvento AS IdEvento,
                @EstadoActual AS EstadoAnterior,
                @NuevoEstado AS EstadoActual,
                CAST(1 AS BIT) AS SinCambios;

            RETURN;
        END;

        IF NOT
        (
            (@EstadoActual = 'BORRADOR'
                AND @NuevoEstado IN ('PROGRAMADO', 'CANCELADO'))
            OR
            (@EstadoActual = 'PROGRAMADO'
                AND @NuevoEstado IN ('EN_VIVO', 'SUSPENDIDO', 'CANCELADO'))
            OR
            (@EstadoActual = 'EN_VIVO'
                AND @NuevoEstado IN ('PENDIENTE_RESULTADO', 'SUSPENDIDO', 'CANCELADO'))
            OR
            (@EstadoActual = 'SUSPENDIDO'
                AND @NuevoEstado IN ('PROGRAMADO', 'EN_VIVO', 'CANCELADO'))
            OR
            (@EstadoActual = 'PENDIENTE_RESULTADO'
                AND @NuevoEstado IN ('FINALIZADO', 'CANCELADO'))
        )
            THROW 59063, 'La transición de estado solicitada para el evento no está permitida.', 1;

        /* Antes de publicar un evento, exigir al menos 2 participantes. */
        IF @NuevoEstado = 'PROGRAMADO'
           AND
           (
               SELECT COUNT(*)
               FROM dbo.EventoParticipante
               WHERE IdEvento = @IdEvento
           ) < 2
            THROW 59064, 'El evento debe tener al menos dos participantes antes de pasar a PROGRAMADO.', 1;

        UPDATE dbo.Evento
        SET IdEstado = @IdNuevoEstado
        WHERE IdEvento = @IdEvento;

        /* Al cancelar un evento, impedir nuevas apuestas cerrando
           mercados operativos. No se liquidan aquí; eso corresponde
           al módulo de resultados/liquidación. */
        IF @NuevoEstado = 'CANCELADO'
        BEGIN
            DECLARE @IdMercadoAnulado INT;

            SELECT @IdMercadoAnulado = E.IdEstado
            FROM dbo.Estado AS E
            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
            WHERE TE.Codigo = 'MERCADO'
              AND E.Codigo = 'ANULADO'
              AND E.Activo = 1;

            IF @IdMercadoAnulado IS NULL
                THROW 59065, 'No existe el estado MERCADO/ANULADO.', 1;

            UPDATE M
            SET IdEstado = @IdMercadoAnulado
            FROM dbo.Mercado AS M
            INNER JOIN dbo.Estado AS E
                ON E.IdEstado = M.IdEstado
            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
               AND TE.Codigo = 'MERCADO'
            WHERE M.IdEvento = @IdEvento
              AND E.Codigo NOT IN ('LIQUIDADO', 'ANULADO');
        END;

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'ESTADO_EVENTO_CAMBIADO',
            'Evento',
            @IdEvento,
            @IpOrigen,
            CONCAT
            (
                'Estado ',
                @EstadoActual,
                ' -> ',
                @NuevoEstado,
                CASE
                    WHEN @Motivo IS NULL THEN ''
                    ELSE CONCAT('. Motivo: ', @Motivo)
                END
            )
        );

        COMMIT TRANSACTION;

        SELECT
            @IdEvento AS IdEvento,
            @EstadoActual AS EstadoAnterior,
            @NuevoEstado AS EstadoActual,
            CAST(0 AS BIT) AS SinCambios;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   13. CAMBIAR ESTADO DE MERCADO

   TRANSICIONES PERMITIDAS:
   BORRADOR   -> ABIERTO, ANULADO
   ABIERTO    -> SUSPENDIDO, CERRADO, ANULADO
   SUSPENDIDO -> ABIERTO, CERRADO, ANULADO
   CERRADO    -> LIQUIDADO, ANULADO

   LIQUIDADO y ANULADO son terminales.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CambiarEstadoMercado
(
    @IdUsuarioProceso INT,
    @IdMercado INT,
    @NuevoEstado VARCHAR(40),
    @Motivo VARCHAR(250) = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NuevoEstado =
        NULLIF(UPPER(LTRIM(RTRIM(@NuevoEstado))), '');
    SET @Motivo = NULLIF(LTRIM(RTRIM(@Motivo)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @IdMercado IS NULL
        THROW 59066, 'IdMercado es obligatorio.', 1;

    IF @NuevoEstado IS NULL
        THROW 59067, 'NuevoEstado es obligatorio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    DECLARE @IdNuevoEstado INT;

    SELECT @IdNuevoEstado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'MERCADO'
      AND E.Codigo = @NuevoEstado
      AND E.Activo = 1;

    IF @IdNuevoEstado IS NULL
        THROW 59068, 'El nuevo estado de mercado no existe o está inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @EstadoActual VARCHAR(40);
        DECLARE @EstadoEvento VARCHAR(40);

        SELECT
            @EstadoActual = EM.Codigo,
            @EstadoEvento = EE.Codigo
        FROM dbo.Mercado AS M WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS EM
            ON EM.IdEstado = M.IdEstado
        INNER JOIN dbo.TipoEstado AS TEM
            ON TEM.IdTipoEstado = EM.IdTipoEstado
           AND TEM.Codigo = 'MERCADO'
        INNER JOIN dbo.Evento AS EV
            ON EV.IdEvento = M.IdEvento
        INNER JOIN dbo.Estado AS EE
            ON EE.IdEstado = EV.IdEstado
        INNER JOIN dbo.TipoEstado AS TEE
            ON TEE.IdTipoEstado = EE.IdTipoEstado
           AND TEE.Codigo = 'EVENTO'
        WHERE M.IdMercado = @IdMercado;

        IF @EstadoActual IS NULL
            THROW 59069, 'El mercado indicado no existe.', 1;

        IF @EstadoActual = @NuevoEstado
        BEGIN
            COMMIT TRANSACTION;

            SELECT
                @IdMercado AS IdMercado,
                @EstadoActual AS EstadoAnterior,
                @NuevoEstado AS EstadoActual,
                CAST(1 AS BIT) AS SinCambios;

            RETURN;
        END;

        IF NOT
        (
            (@EstadoActual = 'BORRADOR'
                AND @NuevoEstado IN ('ABIERTO', 'ANULADO'))
            OR
            (@EstadoActual = 'ABIERTO'
                AND @NuevoEstado IN ('SUSPENDIDO', 'CERRADO', 'ANULADO'))
            OR
            (@EstadoActual = 'SUSPENDIDO'
                AND @NuevoEstado IN ('ABIERTO', 'CERRADO', 'ANULADO'))
            OR
            (@EstadoActual = 'CERRADO'
                AND @NuevoEstado IN ('LIQUIDADO', 'ANULADO'))
        )
            THROW 59070, 'La transición de estado solicitada para el mercado no está permitida.', 1;

        IF @NuevoEstado = 'ABIERTO'
        BEGIN
            IF @EstadoEvento NOT IN ('PROGRAMADO', 'EN_VIVO')
                THROW 59071, 'Solo se puede abrir un mercado cuando el evento está PROGRAMADO o EN_VIVO.', 1;

            IF
            (
                SELECT COUNT(*)
                FROM dbo.Seleccion
                WHERE IdMercado = @IdMercado
                  AND Activo = 1
            ) < 2
                THROW 59072, 'El mercado debe tener al menos dos selecciones activas antes de abrirse.', 1;

            IF EXISTS
            (
                SELECT 1
                FROM dbo.Seleccion AS S
                WHERE S.IdMercado = @IdMercado
                  AND S.Activo = 1
                  AND NOT EXISTS
                  (
                      SELECT 1
                      FROM dbo.Cuota AS C
                      WHERE C.IdSeleccion = S.IdSeleccion
                        AND C.Activo = 1
                  )
            )
                THROW 59073, 'Todas las selecciones activas deben tener una cuota activa antes de abrir el mercado.', 1;
        END;

        UPDATE dbo.Mercado
        SET IdEstado = @IdNuevoEstado
        WHERE IdMercado = @IdMercado;

        /* Cuando un mercado deja de aceptar apuestas, cerrar
           también sus cuotas activas. */
        IF @NuevoEstado IN ('CERRADO', 'LIQUIDADO', 'ANULADO')
        BEGIN
            UPDATE C
            SET
                Activo = 0,
                FechaFin = COALESCE(C.FechaFin, SYSDATETIME())
            FROM dbo.Cuota AS C
            INNER JOIN dbo.Seleccion AS S
                ON S.IdSeleccion = C.IdSeleccion
            WHERE S.IdMercado = @IdMercado
              AND C.Activo = 1;
        END;

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'ESTADO_MERCADO_CAMBIADO',
            'Mercado',
            @IdMercado,
            @IpOrigen,
            CONCAT
            (
                'Estado ',
                @EstadoActual,
                ' -> ',
                @NuevoEstado,
                CASE
                    WHEN @Motivo IS NULL THEN ''
                    ELSE CONCAT('. Motivo: ', @Motivo)
                END
            )
        );

        COMMIT TRANSACTION;

        SELECT
            @IdMercado AS IdMercado,
            @EstadoActual AS EstadoAnterior,
            @NuevoEstado AS EstadoActual,
            CAST(0 AS BIT) AS SinCambios;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


PRINT '=======================================================';
PRINT ' PROCEDIMIENTOS DE EVENTOS Y MERCADOS CREADOS / ACTUALIZADOS';
PRINT '=======================================================';
GO