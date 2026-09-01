/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   SQL SERVER 2022 / AZURE SQL

   ARCHIVO:
   03_PROCEDIMIENTOS/03_Billetera.sql

   OBJETIVO:
   Centralizar las operaciones permitidas sobre billeteras
   de saldo virtual.

   INCLUYE:
   - Consulta de billetera de un usuario.
   - Consulta del historial de movimientos.
   - Ajuste administrativo controlado de saldo disponible.

   REGLAS:
   - El sistema NO maneja dinero real.
   - No existen depósitos ni retiros bancarios.
   - Los saldos críticos no deben modificarse directamente
     desde Java.
   - Todo ajuste administrativo queda respaldado por:
       TransaccionFinanciera
       MovimientoBilletera
       Auditoria
   - Los ajustes solo afectan SaldoDisponible.
   - SaldoComprometido se modifica únicamente por los flujos
     de apuesta y liquidación.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerBilleteraUsuario
(
    @IdUsuario INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @IdUsuario IS NULL
        THROW 58001, 'IdUsuario es obligatorio.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Usuario
        WHERE IdUsuario = @IdUsuario
    )
        THROW 58002, 'El usuario indicado no existe.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Billetera
        WHERE IdUsuario = @IdUsuario
    )
        THROW 58003, 'El usuario indicado no posee una billetera.', 1;

    SELECT
        U.IdUsuario,
        U.Correo,
        R.Nombre AS Rol,
        E.Codigo AS EstadoUsuario,
        B.IdBilletera,
        B.SaldoDisponible,
        B.SaldoComprometido,
        CAST(B.SaldoDisponible + B.SaldoComprometido AS DECIMAL(12,2)) AS SaldoVirtualTotal,
        B.FechaCreacion
    FROM dbo.Usuario AS U
    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol
    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = U.IdEstado
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'USUARIO'
    INNER JOIN dbo.Billetera AS B
        ON B.IdUsuario = U.IdUsuario
    WHERE U.IdUsuario = @IdUsuario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerMovimientosBilletera
(
    @IdUsuario INT,
    @FechaDesde DATETIME2 = NULL,
    @FechaHasta DATETIME2 = NULL,
    @Cantidad INT = 100
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @IdUsuario IS NULL
        THROW 58004, 'IdUsuario es obligatorio.', 1;

    IF @Cantidad IS NULL OR @Cantidad < 1 OR @Cantidad > 500
        THROW 58005, 'Cantidad debe estar entre 1 y 500.', 1;

    IF @FechaDesde IS NOT NULL
       AND @FechaHasta IS NOT NULL
       AND @FechaHasta < @FechaDesde
        THROW 58006, 'FechaHasta no puede ser anterior a FechaDesde.', 1;

    DECLARE @IdBilletera INT;

    SELECT @IdBilletera = IdBilletera
    FROM dbo.Billetera
    WHERE IdUsuario = @IdUsuario;

    IF @IdBilletera IS NULL
    BEGIN
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Usuario
            WHERE IdUsuario = @IdUsuario
        )
            THROW 58007, 'El usuario indicado no existe.', 1;

        THROW 58008, 'El usuario indicado no posee una billetera.', 1;
    END;

    SELECT TOP (@Cantidad)
        M.IdMovimiento,
        M.FechaMovimiento,
        T.IdTransaccion,
        T.ReferenciaOperacion,
        T.Monto,
        T.FechaSolicitud,
        T.FechaProcesamiento,
        T.Descripcion,
        TT.Codigo AS TipoTransaccion,
        TT.Nombre AS NombreTipoTransaccion,
        E.Codigo AS EstadoTransaccion,
        T.IdBoleto,
        M.SaldoDisponibleAnterior,
        M.SaldoDisponiblePosterior,
        CAST(M.SaldoDisponiblePosterior - M.SaldoDisponibleAnterior AS DECIMAL(12,2))
            AS VariacionSaldoDisponible,
        M.SaldoComprometidoAnterior,
        M.SaldoComprometidoPosterior,
        CAST(M.SaldoComprometidoPosterior - M.SaldoComprometidoAnterior AS DECIMAL(12,2))
            AS VariacionSaldoComprometido,
        T.IdUsuarioProceso,
        UP.Correo AS UsuarioProceso
    FROM dbo.MovimientoBilletera AS M
    INNER JOIN dbo.TransaccionFinanciera AS T
        ON T.IdTransaccion = M.IdTransaccion
    INNER JOIN dbo.TipoTransaccion AS TT
        ON TT.IdTipoTransaccion = T.IdTipoTransaccion
    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = T.IdEstado
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'TRANSACCION'
    LEFT JOIN dbo.Usuario AS UP
        ON UP.IdUsuario = T.IdUsuarioProceso
    WHERE M.IdBilletera = @IdBilletera
      AND (@FechaDesde IS NULL OR M.FechaMovimiento >= @FechaDesde)
      AND (@FechaHasta IS NULL OR M.FechaMovimiento <= @FechaHasta)
    ORDER BY
        M.FechaMovimiento DESC,
        M.IdMovimiento DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AjustarSaldoVirtual
(
    @IdUsuarioObjetivo INT,
    @IdUsuarioProceso INT,
    @Operacion VARCHAR(10),
    @Monto DECIMAL(12,2),
    @Motivo VARCHAR(250),
    @ReferenciaOperacion UNIQUEIDENTIFIER,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Operacion = NULLIF(UPPER(LTRIM(RTRIM(@Operacion))), '');
    SET @Motivo = NULLIF(LTRIM(RTRIM(@Motivo)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @IdUsuarioObjetivo IS NULL
        THROW 58009, 'IdUsuarioObjetivo es obligatorio.', 1;

    IF @IdUsuarioProceso IS NULL
        THROW 58010, 'IdUsuarioProceso es obligatorio.', 1;

    IF @Operacion IS NULL OR @Operacion NOT IN ('CREDITO', 'DEBITO')
        THROW 58011, 'Operacion debe ser CREDITO o DEBITO.', 1;

    IF @Monto IS NULL OR @Monto <= 0
        THROW 58012, 'Monto debe ser mayor que cero.', 1;

    IF @Motivo IS NULL
        THROW 58013, 'El motivo del ajuste es obligatorio.', 1;

    IF @ReferenciaOperacion IS NULL
        THROW 58014, 'ReferenciaOperacion es obligatoria.', 1;

    DECLARE @IdTipoAjusteAdmin INT;
    DECLARE @IdEstadoTransaccionCompletada INT;

    SELECT @IdTipoAjusteAdmin = IdTipoTransaccion
    FROM dbo.TipoTransaccion
    WHERE Codigo = 'AJUSTE_ADMIN'
      AND Activo = 1;

    IF @IdTipoAjusteAdmin IS NULL
        THROW 58015, 'No existe el tipo de transacción AJUSTE_ADMIN activo.', 1;

    SELECT @IdEstadoTransaccionCompletada = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'TRANSACCION'
      AND E.Codigo = 'COMPLETADA'
      AND E.Activo = 1;

    IF @IdEstadoTransaccionCompletada IS NULL
        THROW 58016, 'No existe el estado TRANSACCION/COMPLETADA.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @RolUsuarioProceso VARCHAR(50);
        DECLARE @EstadoUsuarioProceso VARCHAR(40);

        SELECT
            @RolUsuarioProceso = R.Nombre,
            @EstadoUsuarioProceso = E.Codigo
        FROM dbo.Usuario AS U WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Rol AS R
            ON R.IdRol = U.IdRol
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = U.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'USUARIO'
        WHERE U.IdUsuario = @IdUsuarioProceso;

        IF @RolUsuarioProceso IS NULL
            THROW 58017, 'El usuario que procesa el ajuste no existe.', 1;

        IF @RolUsuarioProceso NOT IN ('ADMINISTRADOR', 'CAJERO')
            THROW 58018, 'El usuario no tiene autorización para realizar ajustes de saldo.', 1;

        IF @EstadoUsuarioProceso <> 'ACTIVO'
            THROW 58019, 'El usuario que procesa el ajuste debe estar ACTIVO.', 1;

        DECLARE @IdBilletera INT;
        DECLARE @EstadoUsuarioObjetivo VARCHAR(40);

        SELECT
            @IdBilletera = B.IdBilletera,
            @EstadoUsuarioObjetivo = E.Codigo
        FROM dbo.Usuario AS U
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = U.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'USUARIO'
        LEFT JOIN dbo.Billetera AS B
            ON B.IdUsuario = U.IdUsuario
        WHERE U.IdUsuario = @IdUsuarioObjetivo;

        IF @EstadoUsuarioObjetivo IS NULL
            THROW 58020, 'El usuario objetivo no existe.', 1;

        IF @IdBilletera IS NULL
            THROW 58021, 'El usuario objetivo no posee una billetera.', 1;

        IF @EstadoUsuarioObjetivo = 'CERRADO'
            THROW 58022, 'No se permiten ajustes sobre una cuenta cerrada.', 1;

        DECLARE @IdTransaccionExistente BIGINT;
        DECLARE @IdBilleteraExistente INT;
        DECLARE @IdTipoExistente INT;
        DECLARE @MontoExistente DECIMAL(12,2);

        SELECT
            @IdTransaccionExistente = T.IdTransaccion,
            @IdBilleteraExistente = T.IdBilletera,
            @IdTipoExistente = T.IdTipoTransaccion,
            @MontoExistente = T.Monto
        FROM dbo.TransaccionFinanciera AS T WITH (UPDLOCK, HOLDLOCK)
        WHERE T.ReferenciaOperacion = @ReferenciaOperacion;

        IF @IdTransaccionExistente IS NOT NULL
        BEGIN
            DECLARE @AnteriorExistente DECIMAL(12,2);
            DECLARE @PosteriorExistente DECIMAL(12,2);
            DECLARE @ComprometidoAnteriorExistente DECIMAL(12,2);
            DECLARE @ComprometidoPosteriorExistente DECIMAL(12,2);

            SELECT
                @AnteriorExistente = M.SaldoDisponibleAnterior,
                @PosteriorExistente = M.SaldoDisponiblePosterior,
                @ComprometidoAnteriorExistente = M.SaldoComprometidoAnterior,
                @ComprometidoPosteriorExistente = M.SaldoComprometidoPosterior
            FROM dbo.MovimientoBilletera AS M
            WHERE M.IdTransaccion = @IdTransaccionExistente;

            IF @IdBilleteraExistente <> @IdBilletera
               OR @IdTipoExistente <> @IdTipoAjusteAdmin
               OR @MontoExistente <> @Monto
               OR @AnteriorExistente IS NULL
               OR (@Operacion = 'CREDITO'
                   AND @PosteriorExistente - @AnteriorExistente <> @Monto)
               OR (@Operacion = 'DEBITO'
                   AND @AnteriorExistente - @PosteriorExistente <> @Monto)
            BEGIN
                THROW 58023, 'ReferenciaOperacion ya fue utilizada por una operación diferente.', 1;
            END;

            COMMIT TRANSACTION;

            SELECT
                @IdUsuarioObjetivo AS IdUsuario,
                @IdBilletera AS IdBilletera,
                @IdTransaccionExistente AS IdTransaccion,
                @ReferenciaOperacion AS ReferenciaOperacion,
                @Operacion AS Operacion,
                @Monto AS Monto,
                @AnteriorExistente AS SaldoDisponibleAnterior,
                @PosteriorExistente AS SaldoDisponiblePosterior,
                @ComprometidoAnteriorExistente AS SaldoComprometidoAnterior,
                @ComprometidoPosteriorExistente AS SaldoComprometidoPosterior,
                CAST(1 AS BIT) AS SolicitudIdempotente;

            RETURN;
        END;

        DECLARE @SaldoDisponibleAnterior DECIMAL(12,2);
        DECLARE @SaldoDisponiblePosterior DECIMAL(12,2);
        DECLARE @SaldoComprometido DECIMAL(12,2);

        SELECT
            @SaldoDisponibleAnterior = SaldoDisponible,
            @SaldoComprometido = SaldoComprometido
        FROM dbo.Billetera WITH (UPDLOCK, ROWLOCK)
        WHERE IdBilletera = @IdBilletera;

        IF @SaldoDisponibleAnterior IS NULL
            THROW 58024, 'No fue posible bloquear la billetera objetivo.', 1;

        IF @Operacion = 'CREDITO'
        BEGIN
            SET @SaldoDisponiblePosterior = @SaldoDisponibleAnterior + @Monto;
        END
        ELSE
        BEGIN
            IF @SaldoDisponibleAnterior < @Monto
                THROW 58025, 'Saldo disponible insuficiente para realizar el débito administrativo.', 1;

            SET @SaldoDisponiblePosterior = @SaldoDisponibleAnterior - @Monto;
        END;

        DECLARE @IdTransaccion BIGINT;

        INSERT INTO dbo.TransaccionFinanciera
        (
            IdBilletera,
            IdTipoTransaccion,
            IdEstado,
            IdBoleto,
            ReferenciaOperacion,
            Monto,
            FechaProcesamiento,
            IdUsuarioProceso,
            Descripcion
        )
        VALUES
        (
            @IdBilletera,
            @IdTipoAjusteAdmin,
            @IdEstadoTransaccionCompletada,
            NULL,
            @ReferenciaOperacion,
            @Monto,
            SYSDATETIME(),
            @IdUsuarioProceso,
            CONCAT(@Operacion, ': ', @Motivo)
        );

        SET @IdTransaccion = CONVERT(BIGINT, SCOPE_IDENTITY());

        UPDATE dbo.Billetera
        SET SaldoDisponible = @SaldoDisponiblePosterior
        WHERE IdBilletera = @IdBilletera;

        INSERT INTO dbo.MovimientoBilletera
        (
            IdBilletera,
            IdTransaccion,
            SaldoDisponibleAnterior,
            SaldoDisponiblePosterior,
            SaldoComprometidoAnterior,
            SaldoComprometidoPosterior
        )
        VALUES
        (
            @IdBilletera,
            @IdTransaccion,
            @SaldoDisponibleAnterior,
            @SaldoDisponiblePosterior,
            @SaldoComprometido,
            @SaldoComprometido
        );

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            ReferenciaOperacion,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            CASE
                WHEN @Operacion = 'CREDITO'
                    THEN 'AJUSTE_SALDO_CREDITO'
                ELSE 'AJUSTE_SALDO_DEBITO'
            END,
            'Billetera',
            @IdBilletera,
            @ReferenciaOperacion,
            @IpOrigen,
            CONCAT
            (
                'Ajuste administrativo sobre usuario ',
                @IdUsuarioObjetivo,
                '. ',
                @Motivo,
                ' Saldo anterior: ',
                CONVERT(VARCHAR(30), @SaldoDisponibleAnterior),
                '. Saldo posterior: ',
                CONVERT(VARCHAR(30), @SaldoDisponiblePosterior),
                '.'
            )
        );

        COMMIT TRANSACTION;

        SELECT
            @IdUsuarioObjetivo AS IdUsuario,
            @IdBilletera AS IdBilletera,
            @IdTransaccion AS IdTransaccion,
            @ReferenciaOperacion AS ReferenciaOperacion,
            @Operacion AS Operacion,
            @Monto AS Monto,
            @SaldoDisponibleAnterior AS SaldoDisponibleAnterior,
            @SaldoDisponiblePosterior AS SaldoDisponiblePosterior,
            @SaldoComprometido AS SaldoComprometidoAnterior,
            @SaldoComprometido AS SaldoComprometidoPosterior,
            CAST(0 AS BIT) AS SolicitudIdempotente;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

PRINT '=======================================================';
PRINT ' PROCEDIMIENTOS DE BILLETERA CREADOS / ACTUALIZADOS';
PRINT '=======================================================';
GO