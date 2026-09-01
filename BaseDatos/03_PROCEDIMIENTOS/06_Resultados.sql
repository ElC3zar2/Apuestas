/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   SQL SERVER 2022 / AZURE SQL

   ARCHIVO:
   03_PROCEDIMIENTOS/06_Resultados.sql

   OBJETIVO:
   Centralizar el registro, resolución, oficialización,
   corrección y anulación de resultados deportivos.

   INCLUYE:
   - Registro preliminar del resultado de un evento.
   - Resolución individual de selecciones.
   - Oficialización del resultado.
   - Propagación de resultados a DetalleBoleto.
   - Corrección controlada de un resultado oficial.
   - Anulación controlada de un resultado/evento.

   DEPENDENCIA:
   - Utiliza dbo.sp_ValidarPermisoEventos definido en
     04_EventosMercados.sql.

   REGLAS PRINCIPALES:
   - OPERADOR_EVENTOS y ADMINISTRADOR pueden registrar,
     resolver y oficializar resultados.
   - Solo ADMINISTRADOR puede corregir o anular un resultado
     que ya fue oficializado.
   - Un resultado oficial no puede corregirse/anularse cuando
     ya existen boletos afectados en estado LIQUIDADO.
   - La liquidación financiera de boletos NO ocurre aquí.
     Corresponde a 07_Liquidacion.sql.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


/* ============================================================
   1. REGISTRAR RESULTADO DE EVENTO

   El evento debe estar en PENDIENTE_RESULTADO.

   Si todavía no existe ResultadoEvento:
       crea uno en estado PENDIENTE.

   Si ya existe en PENDIENTE o CORREGIDO:
       actualiza el texto/observación sin crear duplicados.

   OFICIAL o ANULADO requieren los procedimientos especiales.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_RegistrarResultadoEvento
(
    @IdUsuarioProceso INT,
    @IdEvento INT,
    @ResultadoTexto VARCHAR(250),
    @Observacion VARCHAR(500) = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @ResultadoTexto =
        NULLIF(LTRIM(RTRIM(@ResultadoTexto)), '');

    SET @Observacion =
        NULLIF(LTRIM(RTRIM(@Observacion)), '');

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');


    IF @IdEvento IS NULL
        THROW 61001, 'IdEvento es obligatorio.', 1;

    IF @ResultadoTexto IS NULL
        THROW 61002, 'ResultadoTexto es obligatorio.', 1;


    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;


    DECLARE @IdEstadoResultadoPendiente INT;

    SELECT @IdEstadoResultadoPendiente = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'RESULTADO_EVENTO'
      AND E.Codigo = 'PENDIENTE'
      AND E.Activo = 1;

    IF @IdEstadoResultadoPendiente IS NULL
        THROW 61003, 'No existe el estado RESULTADO_EVENTO/PENDIENTE.', 1;


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
            THROW 61004, 'El evento indicado no existe.', 1;

        IF @EstadoEvento <> 'PENDIENTE_RESULTADO'
            THROW 61005, 'El evento debe estar en PENDIENTE_RESULTADO para registrar su resultado.', 1;


        DECLARE @IdResultado INT;
        DECLARE @EstadoResultadoActual VARCHAR(40);


        SELECT
            @IdResultado = RE.IdResultado,
            @EstadoResultadoActual = ER.Codigo
        FROM dbo.ResultadoEvento AS RE WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS ER
            ON ER.IdEstado = RE.IdEstado
        INNER JOIN dbo.TipoEstado AS TER
            ON TER.IdTipoEstado = ER.IdTipoEstado
           AND TER.Codigo = 'RESULTADO_EVENTO'
        WHERE RE.IdEvento = @IdEvento;


        IF @IdResultado IS NULL
        BEGIN

            INSERT INTO dbo.ResultadoEvento
            (
                IdEvento,
                IdEstado,
                IdUsuarioRegistro,
                ResultadoTexto,
                Observacion
            )
            VALUES
            (
                @IdEvento,
                @IdEstadoResultadoPendiente,
                @IdUsuarioProceso,
                @ResultadoTexto,
                @Observacion
            );

            SET @IdResultado =
                CONVERT(INT, SCOPE_IDENTITY());

            SET @EstadoResultadoActual = 'PENDIENTE';

        END
        ELSE
        BEGIN

            IF @EstadoResultadoActual NOT IN ('PENDIENTE', 'CORREGIDO')
                THROW 61006, 'El resultado ya fue oficializado o anulado y no puede modificarse mediante este procedimiento.', 1;

            UPDATE dbo.ResultadoEvento
            SET
                IdUsuarioRegistro = @IdUsuarioProceso,
                ResultadoTexto = @ResultadoTexto,
                Observacion = @Observacion
            WHERE IdResultado = @IdResultado;

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
            'RESULTADO_EVENTO_REGISTRADO',
            'ResultadoEvento',
            @IdResultado,
            @IpOrigen,
            CONCAT
            (
                'Resultado registrado/actualizado para evento ',
                @IdEvento,
                ': ',
                @ResultadoTexto,
                '.'
            )
        );


        COMMIT TRANSACTION;


        SELECT
            @IdResultado AS IdResultado,
            @IdEvento AS IdEvento,
            @EstadoResultadoActual AS EstadoResultado,
            @ResultadoTexto AS ResultadoTexto,
            @Observacion AS Observacion;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   2. RESOLVER SELECCION

   RESULTADOS:
   - GANADA
   - PERDIDA
   - ANULADA

   La selección debe pertenecer al mismo evento que el
   ResultadoEvento.

   Este procedimiento registra la resolución, pero todavía
   NO modifica DetalleBoleto. La propagación ocurre únicamente
   al oficializar el resultado del evento.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ResolverSeleccion
(
    @IdUsuarioProceso INT,
    @IdResultadoEvento INT,
    @IdSeleccion INT,
    @Resultado VARCHAR(20),
    @Observacion VARCHAR(500) = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Resultado =
        NULLIF(UPPER(LTRIM(RTRIM(@Resultado))), '');

    SET @Observacion =
        NULLIF(LTRIM(RTRIM(@Observacion)), '');

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');


    IF @IdResultadoEvento IS NULL
        THROW 61007, 'IdResultadoEvento es obligatorio.', 1;

    IF @IdSeleccion IS NULL
        THROW 61008, 'IdSeleccion es obligatorio.', 1;

    IF @Resultado IS NULL
       OR @Resultado NOT IN ('GANADA', 'PERDIDA', 'ANULADA')
        THROW 61009, 'Resultado debe ser GANADA, PERDIDA o ANULADA.', 1;


    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;


    BEGIN TRY
        BEGIN TRANSACTION;


        DECLARE @IdEventoResultado INT;
        DECLARE @EstadoResultadoEvento VARCHAR(40);


        SELECT
            @IdEventoResultado = RE.IdEvento,
            @EstadoResultadoEvento = E.Codigo
        FROM dbo.ResultadoEvento AS RE WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = RE.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'RESULTADO_EVENTO'
        WHERE RE.IdResultado = @IdResultadoEvento;


        IF @IdEventoResultado IS NULL
            THROW 61010, 'El ResultadoEvento indicado no existe.', 1;

        IF @EstadoResultadoEvento NOT IN ('PENDIENTE', 'CORREGIDO')
            THROW 61011, 'Solo se pueden resolver selecciones mientras el resultado esté PENDIENTE o CORREGIDO.', 1;


        DECLARE @IdEventoSeleccion INT;
        DECLARE @EstadoMercado VARCHAR(40);
        DECLARE @SeleccionActiva BIT;


        SELECT
            @IdEventoSeleccion = M.IdEvento,
            @EstadoMercado = E.Codigo,
            @SeleccionActiva = S.Activo
        FROM dbo.Seleccion AS S WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado = S.IdMercado
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = M.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'MERCADO'
        WHERE S.IdSeleccion = @IdSeleccion;


        IF @IdEventoSeleccion IS NULL
            THROW 61012, 'La selección indicada no existe.', 1;

        IF @IdEventoSeleccion <> @IdEventoResultado
            THROW 61013, 'La selección no pertenece al mismo evento del resultado indicado.', 1;

        IF @SeleccionActiva = 0
            THROW 61014, 'La selección indicada está inactiva.', 1;


        IF @EstadoMercado = 'ANULADO'
           AND @Resultado <> 'ANULADA'
            THROW 61015, 'Las selecciones de un mercado ANULADO solo pueden resolverse como ANULADA.', 1;


        DECLARE @IdResolucion INT;


        SELECT @IdResolucion = IdResolucion
        FROM dbo.ResolucionSeleccion WITH (UPDLOCK, HOLDLOCK)
        WHERE IdSeleccion = @IdSeleccion;


        IF @IdResolucion IS NULL
        BEGIN

            INSERT INTO dbo.ResolucionSeleccion
            (
                IdSeleccion,
                IdResultadoEvento,
                Resultado,
                IdUsuarioRegistro,
                Observacion
            )
            VALUES
            (
                @IdSeleccion,
                @IdResultadoEvento,
                @Resultado,
                @IdUsuarioProceso,
                @Observacion
            );

            SET @IdResolucion =
                CONVERT(INT, SCOPE_IDENTITY());

        END
        ELSE
        BEGIN

            UPDATE dbo.ResolucionSeleccion
            SET
                IdResultadoEvento = @IdResultadoEvento,
                Resultado = @Resultado,
                IdUsuarioRegistro = @IdUsuarioProceso,
                FechaResolucion = SYSDATETIME(),
                Observacion = @Observacion
            WHERE IdResolucion = @IdResolucion;

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
            'SELECCION_RESUELTA',
            'ResolucionSeleccion',
            @IdResolucion,
            @IpOrigen,
            CONCAT
            (
                'Selección ',
                @IdSeleccion,
                ' resuelta como ',
                @Resultado,
                ' para ResultadoEvento ',
                @IdResultadoEvento,
                '.'
            )
        );


        COMMIT TRANSACTION;


        SELECT
            @IdResolucion AS IdResolucion,
            @IdResultadoEvento AS IdResultadoEvento,
            @IdSeleccion AS IdSeleccion,
            @Resultado AS Resultado,
            @Observacion AS Observacion;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   3. OFICIALIZAR RESULTADO DE EVENTO

   EFECTOS:
   - Comprueba que los mercados ya no acepten apuestas.
   - Resuelve automáticamente como ANULADA toda selección
     perteneciente a un mercado ANULADO.
   - Exige que todas las demás selecciones estén resueltas.
   - Propaga ResolucionSeleccion -> DetalleBoleto.
   - Marca ResultadoEvento como OFICIAL.
   - Marca mercados no anulados como LIQUIDADO.
   - Marca Evento como FINALIZADO.

   NO LIQUIDA FINANCIERAMENTE LOS BOLETOS.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_OficializarResultadoEvento
(
    @IdUsuarioProceso INT,
    @IdResultadoEvento INT,
    @Observacion VARCHAR(500) = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Observacion =
        NULLIF(LTRIM(RTRIM(@Observacion)), '');

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');


    IF @IdResultadoEvento IS NULL
        THROW 61016, 'IdResultadoEvento es obligatorio.', 1;


    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;


    DECLARE @IdEstadoResultadoOficial INT;
    DECLARE @IdEstadoEventoFinalizado INT;
    DECLARE @IdEstadoMercadoLiquidado INT;


    SELECT @IdEstadoResultadoOficial = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'RESULTADO_EVENTO'
      AND E.Codigo = 'OFICIAL'
      AND E.Activo = 1;


    SELECT @IdEstadoEventoFinalizado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'EVENTO'
      AND E.Codigo = 'FINALIZADO'
      AND E.Activo = 1;


    SELECT @IdEstadoMercadoLiquidado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'MERCADO'
      AND E.Codigo = 'LIQUIDADO'
      AND E.Activo = 1;


    IF @IdEstadoResultadoOficial IS NULL
        THROW 61017, 'No existe el estado RESULTADO_EVENTO/OFICIAL.', 1;

    IF @IdEstadoEventoFinalizado IS NULL
        THROW 61018, 'No existe el estado EVENTO/FINALIZADO.', 1;

    IF @IdEstadoMercadoLiquidado IS NULL
        THROW 61019, 'No existe el estado MERCADO/LIQUIDADO.', 1;


    BEGIN TRY
        BEGIN TRANSACTION;


        DECLARE @IdEvento INT;
        DECLARE @EstadoResultadoActual VARCHAR(40);
        DECLARE @EstadoEvento VARCHAR(40);


        SELECT
            @IdEvento = RE.IdEvento,
            @EstadoResultadoActual = ER.Codigo,
            @EstadoEvento = EE.Codigo
        FROM dbo.ResultadoEvento AS RE WITH (UPDLOCK, HOLDLOCK)

        INNER JOIN dbo.Estado AS ER
            ON ER.IdEstado = RE.IdEstado

        INNER JOIN dbo.TipoEstado AS TER
            ON TER.IdTipoEstado = ER.IdTipoEstado
           AND TER.Codigo = 'RESULTADO_EVENTO'

        INNER JOIN dbo.Evento AS EV WITH (UPDLOCK, HOLDLOCK)
            ON EV.IdEvento = RE.IdEvento

        INNER JOIN dbo.Estado AS EE
            ON EE.IdEstado = EV.IdEstado

        INNER JOIN dbo.TipoEstado AS TEE
            ON TEE.IdTipoEstado = EE.IdTipoEstado
           AND TEE.Codigo = 'EVENTO'

        WHERE RE.IdResultado = @IdResultadoEvento;


        IF @IdEvento IS NULL
            THROW 61020, 'El ResultadoEvento indicado no existe.', 1;


        IF @EstadoResultadoActual = 'OFICIAL'
        BEGIN
            COMMIT TRANSACTION;

            SELECT
                @IdResultadoEvento AS IdResultado,
                @IdEvento AS IdEvento,
                'OFICIAL' AS EstadoResultado,
                'FINALIZADO' AS EstadoEvento,
                CAST(1 AS BIT) AS SinCambios;

            RETURN;
        END;


        IF @EstadoResultadoActual NOT IN ('PENDIENTE', 'CORREGIDO')
            THROW 61021, 'El resultado no puede oficializarse en su estado actual.', 1;


        IF @EstadoEvento <> 'PENDIENTE_RESULTADO'
            THROW 61022, 'El evento debe estar en PENDIENTE_RESULTADO para oficializar su resultado.', 1;


        /* Ningún mercado puede permanecer recibiendo o preparando
           apuestas al momento de oficializar. */
        IF EXISTS
        (
            SELECT 1
            FROM dbo.Mercado AS M
            INNER JOIN dbo.Estado AS E
                ON E.IdEstado = M.IdEstado
            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
               AND TE.Codigo = 'MERCADO'
            WHERE M.IdEvento = @IdEvento
              AND E.Codigo IN ('BORRADOR', 'ABIERTO', 'SUSPENDIDO')
        )
            THROW 61023, 'Todos los mercados deben estar CERRADOS, LIQUIDADOS o ANULADOS antes de oficializar el resultado.', 1;


        /* ====================================================
           MERCADOS ANULADOS:
           Todas sus selecciones se convierten en ANULADA.
           ==================================================== */

        UPDATE RS
        SET
            RS.IdResultadoEvento = @IdResultadoEvento,
            RS.Resultado = 'ANULADA',
            RS.IdUsuarioRegistro = @IdUsuarioProceso,
            RS.FechaResolucion = SYSDATETIME(),
            RS.Observacion = 'Resolución automática por mercado anulado.'
        FROM dbo.ResolucionSeleccion AS RS
        INNER JOIN dbo.Seleccion AS S
            ON S.IdSeleccion = RS.IdSeleccion
        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado = S.IdMercado
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = M.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'MERCADO'
        WHERE M.IdEvento = @IdEvento
          AND E.Codigo = 'ANULADO';


        INSERT INTO dbo.ResolucionSeleccion
        (
            IdSeleccion,
            IdResultadoEvento,
            Resultado,
            IdUsuarioRegistro,
            Observacion
        )
        SELECT
            S.IdSeleccion,
            @IdResultadoEvento,
            'ANULADA',
            @IdUsuarioProceso,
            'Resolución automática por mercado anulado.'
        FROM dbo.Seleccion AS S
        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado = S.IdMercado
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = M.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'MERCADO'
        WHERE M.IdEvento = @IdEvento
          AND E.Codigo = 'ANULADO'
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.ResolucionSeleccion AS RS
              WHERE RS.IdSeleccion = S.IdSeleccion
          );


        /* ====================================================
           VERIFICAR RESOLUCIONES COMPLETAS
           ==================================================== */

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Seleccion AS S
            INNER JOIN dbo.Mercado AS M
                ON M.IdMercado = S.IdMercado
            WHERE M.IdEvento = @IdEvento
              AND S.Activo = 1
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM dbo.ResolucionSeleccion AS RS
                  WHERE RS.IdSeleccion = S.IdSeleccion
                    AND RS.IdResultadoEvento = @IdResultadoEvento
              )
        )
            THROW 61024, 'Existen selecciones activas del evento que todavía no han sido resueltas.', 1;


        /* ====================================================
           PROPAGAR RESULTADOS A DETALLE BOLETO
           ==================================================== */

        UPDATE DB
        SET DB.Resultado = RS.Resultado
        FROM dbo.DetalleBoleto AS DB
        INNER JOIN dbo.ResolucionSeleccion AS RS
            ON RS.IdSeleccion = DB.IdSeleccion
           AND RS.IdResultadoEvento = @IdResultadoEvento
        INNER JOIN dbo.Seleccion AS S
            ON S.IdSeleccion = DB.IdSeleccion
        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado = S.IdMercado
        WHERE M.IdEvento = @IdEvento
          AND DB.Resultado = 'PENDIENTE';


        /* ====================================================
           CERRAR CUALQUIER CUOTA QUE SIGA ACTIVA
           ==================================================== */

        UPDATE C
        SET
            C.Activo = 0,
            C.FechaFin = COALESCE(C.FechaFin, SYSDATETIME())
        FROM dbo.Cuota AS C
        INNER JOIN dbo.Seleccion AS S
            ON S.IdSeleccion = C.IdSeleccion
        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado = S.IdMercado
        WHERE M.IdEvento = @IdEvento
          AND C.Activo = 1;


        /* ====================================================
           MARCAR MERCADOS NO ANULADOS COMO LIQUIDADOS
           ==================================================== */

        UPDATE M
        SET M.IdEstado = @IdEstadoMercadoLiquidado
        FROM dbo.Mercado AS M
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = M.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'MERCADO'
        WHERE M.IdEvento = @IdEvento
          AND E.Codigo <> 'ANULADO';


        /* ====================================================
           OFICIALIZAR RESULTADO Y FINALIZAR EVENTO
           ==================================================== */

        UPDATE dbo.ResultadoEvento
        SET
            IdEstado = @IdEstadoResultadoOficial,
            IdUsuarioRegistro = @IdUsuarioProceso,
            Observacion =
                CASE
                    WHEN @Observacion IS NULL
                        THEN Observacion
                    ELSE @Observacion
                END
        WHERE IdResultado = @IdResultadoEvento;


        UPDATE dbo.Evento
        SET IdEstado = @IdEstadoEventoFinalizado
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
            'RESULTADO_EVENTO_OFICIALIZADO',
            'ResultadoEvento',
            @IdResultadoEvento,
            @IpOrigen,
            CONCAT
            (
                'Resultado oficializado para evento ',
                @IdEvento,
                '. Las resoluciones fueron propagadas a los boletos pendientes.'
            )
        );


        COMMIT TRANSACTION;


        SELECT
            @IdResultadoEvento AS IdResultado,
            @IdEvento AS IdEvento,
            'OFICIAL' AS EstadoResultado,
            'FINALIZADO' AS EstadoEvento,
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
   4. CORREGIR RESULTADO OFICIAL

   SOLO ADMINISTRADOR.

   Se utiliza cuando un resultado ya oficializado necesita ser
   corregido ANTES de que algún boleto afectado haya sido
   liquidado financieramente.

   EFECTOS:
   - ResultadoEvento pasa a CORREGIDO.
   - Evento vuelve a PENDIENTE_RESULTADO.
   - Mercados LIQUIDADOS vuelven a CERRADO.
   - Se eliminan las resoluciones anteriores del evento.
   - DetalleBoleto vuelve a PENDIENTE para las selecciones del
     evento.
   - Luego deben resolverse nuevamente las selecciones y volver
     a ejecutar sp_OficializarResultadoEvento.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CorregirResultadoEvento
(
    @IdUsuarioProceso INT,
    @IdResultadoEvento INT,
    @NuevoResultadoTexto VARCHAR(250),
    @Motivo VARCHAR(500),
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NuevoResultadoTexto =
        NULLIF(LTRIM(RTRIM(@NuevoResultadoTexto)), '');

    SET @Motivo =
        NULLIF(LTRIM(RTRIM(@Motivo)), '');

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');


    IF @IdUsuarioProceso IS NULL
        THROW 61025, 'IdUsuarioProceso es obligatorio.', 1;

    IF @IdResultadoEvento IS NULL
        THROW 61026, 'IdResultadoEvento es obligatorio.', 1;

    IF @NuevoResultadoTexto IS NULL
        THROW 61027, 'NuevoResultadoTexto es obligatorio.', 1;

    IF @Motivo IS NULL
        THROW 61028, 'El motivo de la corrección es obligatorio.', 1;


    DECLARE @RolUsuarioProceso VARCHAR(50);
    DECLARE @EstadoUsuarioProceso VARCHAR(40);


    SELECT
        @RolUsuarioProceso = R.Nombre,
        @EstadoUsuarioProceso = E.Codigo
    FROM dbo.Usuario AS U
    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol
    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = U.IdEstado
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'USUARIO'
    WHERE U.IdUsuario = @IdUsuarioProceso;


    IF @RolUsuarioProceso IS NULL
        THROW 61029, 'El usuario que procesa la corrección no existe.', 1;

    IF @RolUsuarioProceso <> 'ADMINISTRADOR'
        THROW 61030, 'Solo un ADMINISTRADOR puede corregir un resultado oficial.', 1;

    IF @EstadoUsuarioProceso <> 'ACTIVO'
        THROW 61031, 'El ADMINISTRADOR debe estar ACTIVO.', 1;


    DECLARE @IdEstadoResultadoCorregido INT;
    DECLARE @IdEstadoEventoPendienteResultado INT;
    DECLARE @IdEstadoMercadoCerrado INT;


    SELECT @IdEstadoResultadoCorregido = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'RESULTADO_EVENTO'
      AND E.Codigo = 'CORREGIDO'
      AND E.Activo = 1;


    SELECT @IdEstadoEventoPendienteResultado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'EVENTO'
      AND E.Codigo = 'PENDIENTE_RESULTADO'
      AND E.Activo = 1;


    SELECT @IdEstadoMercadoCerrado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'MERCADO'
      AND E.Codigo = 'CERRADO'
      AND E.Activo = 1;


    IF @IdEstadoResultadoCorregido IS NULL
        THROW 61032, 'No existe el estado RESULTADO_EVENTO/CORREGIDO.', 1;

    IF @IdEstadoEventoPendienteResultado IS NULL
        THROW 61033, 'No existe el estado EVENTO/PENDIENTE_RESULTADO.', 1;

    IF @IdEstadoMercadoCerrado IS NULL
        THROW 61034, 'No existe el estado MERCADO/CERRADO.', 1;


    BEGIN TRY
        BEGIN TRANSACTION;


        DECLARE @IdEvento INT;
        DECLARE @EstadoResultadoActual VARCHAR(40);


        SELECT
            @IdEvento = RE.IdEvento,
            @EstadoResultadoActual = E.Codigo
        FROM dbo.ResultadoEvento AS RE WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = RE.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'RESULTADO_EVENTO'
        WHERE RE.IdResultado = @IdResultadoEvento;


        IF @IdEvento IS NULL
            THROW 61035, 'El ResultadoEvento indicado no existe.', 1;

        IF @EstadoResultadoActual <> 'OFICIAL'
            THROW 61036, 'Solo se puede corregir un resultado que esté OFICIAL.', 1;


        /* No permitir correcciones después de una liquidación
           financiera, porque requeriría un proceso formal de reverso. */
        IF EXISTS
        (
            SELECT 1
            FROM dbo.Boleto AS B
            INNER JOIN dbo.Estado AS EB
                ON EB.IdEstado = B.IdEstado
            INNER JOIN dbo.TipoEstado AS TEB
                ON TEB.IdTipoEstado = EB.IdTipoEstado
               AND TEB.Codigo = 'BOLETO'
            WHERE EB.Codigo = 'LIQUIDADO'
              AND EXISTS
              (
                  SELECT 1
                  FROM dbo.DetalleBoleto AS DB
                  INNER JOIN dbo.Seleccion AS S
                      ON S.IdSeleccion = DB.IdSeleccion
                  INNER JOIN dbo.Mercado AS M
                      ON M.IdMercado = S.IdMercado
                  WHERE DB.IdBoleto = B.IdBoleto
                    AND M.IdEvento = @IdEvento
              )
        )
            THROW 61037, 'No se puede corregir el resultado porque ya existen boletos afectados que fueron liquidados.', 1;


        UPDATE dbo.ResultadoEvento
        SET
            IdEstado = @IdEstadoResultadoCorregido,
            IdUsuarioRegistro = @IdUsuarioProceso,
            ResultadoTexto = @NuevoResultadoTexto,
            Observacion = @Motivo
        WHERE IdResultado = @IdResultadoEvento;


        UPDATE dbo.Evento
        SET IdEstado = @IdEstadoEventoPendienteResultado
        WHERE IdEvento = @IdEvento;


        UPDATE M
        SET M.IdEstado = @IdEstadoMercadoCerrado
        FROM dbo.Mercado AS M
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = M.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'MERCADO'
        WHERE M.IdEvento = @IdEvento
          AND E.Codigo = 'LIQUIDADO';


        /* Restablecer detalles afectados antes de recalcular. */
        UPDATE DB
        SET DB.Resultado = 'PENDIENTE'
        FROM dbo.DetalleBoleto AS DB
        INNER JOIN dbo.Seleccion AS S
            ON S.IdSeleccion = DB.IdSeleccion
        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado = S.IdMercado
        WHERE M.IdEvento = @IdEvento;


        DELETE RS
        FROM dbo.ResolucionSeleccion AS RS
        INNER JOIN dbo.Seleccion AS S
            ON S.IdSeleccion = RS.IdSeleccion
        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado = S.IdMercado
        WHERE M.IdEvento = @IdEvento;


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
            'RESULTADO_EVENTO_CORREGIDO',
            'ResultadoEvento',
            @IdResultadoEvento,
            @IpOrigen,
            CONCAT
            (
                'Resultado oficial regresado a proceso de resolución. Motivo: ',
                @Motivo,
                '.'
            )
        );


        COMMIT TRANSACTION;


        SELECT
            @IdResultadoEvento AS IdResultado,
            @IdEvento AS IdEvento,
            'CORREGIDO' AS EstadoResultado,
            'PENDIENTE_RESULTADO' AS EstadoEvento,
            CAST(1 AS BIT) AS RequiereNuevaResolucion;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   5. ANULAR RESULTADO / EVENTO

   SOLO ADMINISTRADOR.

   Se utiliza cuando el evento o su resultado deben invalidarse.

   REGLAS:
   - No se permite si ya existen boletos afectados LIQUIDADOS.
   - Todas las selecciones pasan a ANULADA.
   - DetalleBoleto se propaga a ANULADA.
   - Los mercados pasan a ANULADO.
   - Las cuotas activas se cierran.
   - El evento pasa a CANCELADO.
   - ResultadoEvento pasa a ANULADO.

   El efecto financiero sobre los boletos será procesado
   posteriormente por 07_Liquidacion.sql.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_AnularResultadoEvento
(
    @IdUsuarioProceso INT,
    @IdResultadoEvento INT,
    @Motivo VARCHAR(500),
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Motivo =
        NULLIF(LTRIM(RTRIM(@Motivo)), '');

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');


    IF @IdUsuarioProceso IS NULL
        THROW 61038, 'IdUsuarioProceso es obligatorio.', 1;

    IF @IdResultadoEvento IS NULL
        THROW 61039, 'IdResultadoEvento es obligatorio.', 1;

    IF @Motivo IS NULL
        THROW 61040, 'El motivo de la anulación es obligatorio.', 1;


    DECLARE @RolUsuarioProceso VARCHAR(50);
    DECLARE @EstadoUsuarioProceso VARCHAR(40);


    SELECT
        @RolUsuarioProceso = R.Nombre,
        @EstadoUsuarioProceso = E.Codigo
    FROM dbo.Usuario AS U
    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol
    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = U.IdEstado
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'USUARIO'
    WHERE U.IdUsuario = @IdUsuarioProceso;


    IF @RolUsuarioProceso IS NULL
        THROW 61041, 'El usuario que procesa la anulación no existe.', 1;

    IF @RolUsuarioProceso <> 'ADMINISTRADOR'
        THROW 61042, 'Solo un ADMINISTRADOR puede anular un resultado.', 1;

    IF @EstadoUsuarioProceso <> 'ACTIVO'
        THROW 61043, 'El ADMINISTRADOR debe estar ACTIVO.', 1;


    DECLARE @IdEstadoResultadoAnulado INT;
    DECLARE @IdEstadoEventoCancelado INT;
    DECLARE @IdEstadoMercadoAnulado INT;


    SELECT @IdEstadoResultadoAnulado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'RESULTADO_EVENTO'
      AND E.Codigo = 'ANULADO'
      AND E.Activo = 1;


    SELECT @IdEstadoEventoCancelado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'EVENTO'
      AND E.Codigo = 'CANCELADO'
      AND E.Activo = 1;


    SELECT @IdEstadoMercadoAnulado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'MERCADO'
      AND E.Codigo = 'ANULADO'
      AND E.Activo = 1;


    IF @IdEstadoResultadoAnulado IS NULL
        THROW 61044, 'No existe el estado RESULTADO_EVENTO/ANULADO.', 1;

    IF @IdEstadoEventoCancelado IS NULL
        THROW 61045, 'No existe el estado EVENTO/CANCELADO.', 1;

    IF @IdEstadoMercadoAnulado IS NULL
        THROW 61046, 'No existe el estado MERCADO/ANULADO.', 1;


    BEGIN TRY
        BEGIN TRANSACTION;


        DECLARE @IdEvento INT;
        DECLARE @EstadoResultadoActual VARCHAR(40);


        SELECT
            @IdEvento = RE.IdEvento,
            @EstadoResultadoActual = E.Codigo
        FROM dbo.ResultadoEvento AS RE WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = RE.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'RESULTADO_EVENTO'
        WHERE RE.IdResultado = @IdResultadoEvento;


        IF @IdEvento IS NULL
            THROW 61047, 'El ResultadoEvento indicado no existe.', 1;


        IF @EstadoResultadoActual = 'ANULADO'
        BEGIN
            COMMIT TRANSACTION;

            SELECT
                @IdResultadoEvento AS IdResultado,
                @IdEvento AS IdEvento,
                'ANULADO' AS EstadoResultado,
                'CANCELADO' AS EstadoEvento,
                CAST(1 AS BIT) AS SinCambios;

            RETURN;
        END;


        IF EXISTS
        (
            SELECT 1
            FROM dbo.Boleto AS B
            INNER JOIN dbo.Estado AS EB
                ON EB.IdEstado = B.IdEstado
            INNER JOIN dbo.TipoEstado AS TEB
                ON TEB.IdTipoEstado = EB.IdTipoEstado
               AND TEB.Codigo = 'BOLETO'
            WHERE EB.Codigo = 'LIQUIDADO'
              AND EXISTS
              (
                  SELECT 1
                  FROM dbo.DetalleBoleto AS DB
                  INNER JOIN dbo.Seleccion AS S
                      ON S.IdSeleccion = DB.IdSeleccion
                  INNER JOIN dbo.Mercado AS M
                      ON M.IdMercado = S.IdMercado
                  WHERE DB.IdBoleto = B.IdBoleto
                    AND M.IdEvento = @IdEvento
              )
        )
            THROW 61048, 'No se puede anular el resultado porque ya existen boletos afectados que fueron liquidados.', 1;


        /* ====================================================
           TODAS LAS SELECCIONES DEL EVENTO -> ANULADA
           ==================================================== */

        UPDATE RS
        SET
            RS.IdResultadoEvento = @IdResultadoEvento,
            RS.Resultado = 'ANULADA',
            RS.IdUsuarioRegistro = @IdUsuarioProceso,
            RS.FechaResolucion = SYSDATETIME(),
            RS.Observacion = @Motivo
        FROM dbo.ResolucionSeleccion AS RS
        INNER JOIN dbo.Seleccion AS S
            ON S.IdSeleccion = RS.IdSeleccion
        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado = S.IdMercado
        WHERE M.IdEvento = @IdEvento;


        INSERT INTO dbo.ResolucionSeleccion
        (
            IdSeleccion,
            IdResultadoEvento,
            Resultado,
            IdUsuarioRegistro,
            Observacion
        )
        SELECT
            S.IdSeleccion,
            @IdResultadoEvento,
            'ANULADA',
            @IdUsuarioProceso,
            @Motivo
        FROM dbo.Seleccion AS S
        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado = S.IdMercado
        WHERE M.IdEvento = @IdEvento
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.ResolucionSeleccion AS RS
              WHERE RS.IdSeleccion = S.IdSeleccion
          );


        UPDATE DB
        SET DB.Resultado = 'ANULADA'
        FROM dbo.DetalleBoleto AS DB
        INNER JOIN dbo.Seleccion AS S
            ON S.IdSeleccion = DB.IdSeleccion
        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado = S.IdMercado
        WHERE M.IdEvento = @IdEvento;


        /* Cerrar cuotas activas. */
        UPDATE C
        SET
            C.Activo = 0,
            C.FechaFin = COALESCE(C.FechaFin, SYSDATETIME())
        FROM dbo.Cuota AS C
        INNER JOIN dbo.Seleccion AS S
            ON S.IdSeleccion = C.IdSeleccion
        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado = S.IdMercado
        WHERE M.IdEvento = @IdEvento
          AND C.Activo = 1;


        UPDATE dbo.Mercado
        SET IdEstado = @IdEstadoMercadoAnulado
        WHERE IdEvento = @IdEvento;


        UPDATE dbo.Evento
        SET IdEstado = @IdEstadoEventoCancelado
        WHERE IdEvento = @IdEvento;


        UPDATE dbo.ResultadoEvento
        SET
            IdEstado = @IdEstadoResultadoAnulado,
            IdUsuarioRegistro = @IdUsuarioProceso,
            Observacion = @Motivo
        WHERE IdResultado = @IdResultadoEvento;


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
            'RESULTADO_EVENTO_ANULADO',
            'ResultadoEvento',
            @IdResultadoEvento,
            @IpOrigen,
            CONCAT
            (
                'Resultado y evento anulados. Motivo: ',
                @Motivo,
                '.'
            )
        );


        COMMIT TRANSACTION;


        SELECT
            @IdResultadoEvento AS IdResultado,
            @IdEvento AS IdEvento,
            'ANULADO' AS EstadoResultado,
            'CANCELADO' AS EstadoEvento,
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
PRINT ' PROCEDIMIENTOS DE RESULTADOS CREADOS / ACTUALIZADOS';
PRINT '=======================================================';
GO