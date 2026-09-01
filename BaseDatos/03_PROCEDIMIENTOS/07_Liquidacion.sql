/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   SQL SERVER 2022 / AZURE SQL

   ARCHIVO:
   03_PROCEDIMIENTOS/07_Liquidacion.sql

   OBJETIVO:
   Centralizar la liquidación financiera de boletos resueltos
   utilizando exclusivamente saldo virtual.

   INCLUYE:
   - Validación de permisos de liquidación.
   - Consulta de boletos listos para liquidar.
   - Liquidación atómica de un boleto.
   - Consulta del resultado de una liquidación.

   REGLAS FINANCIERAS:
   1. APUESTA GANADORA
      - El saldo comprometido del usuario disminuye por la apuesta.
      - El usuario recibe MontoLiquidado en SaldoDisponible.
      - La CASA paga únicamente la ganancia neta:
            MontoLiquidado - MontoApostado.
      - Si hubo selecciones ANULADAS, su cuota equivale a 1.0000.

   2. APUESTA PERDEDORA
      - El saldo comprometido del usuario disminuye por la apuesta.
      - El usuario no recibe saldo disponible.
      - La CASA recibe el MontoApostado.

   3. APUESTA TOTALMENTE ANULADA
      - El saldo comprometido vuelve a SaldoDisponible.
      - La CASA no gana ni pierde saldo.

   IMPORTANTE:
   - El sistema NO maneja dinero real.
   - La liquidación financiera ocurre solo cuando TODOS los
     DetalleBoleto están resueltos.
   - Un boleto solo puede liquidarse una vez.
   - Se bloquean billeteras para proteger concurrencia.
   - Se bloquea CASA primero y luego la billetera del usuario,
     manteniendo un orden consistente en liquidaciones.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


/* ============================================================
   1. VALIDAR PERMISO DE LIQUIDACION

   ROLES AUTORIZADOS:
   - ADMINISTRADOR
   - CAJERO

   El OPERADOR_EVENTOS registra resultados, pero no realiza
   la liquidación financiera. Esto mantiene separación de roles.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ValidarPermisoLiquidacion
(
    @IdUsuarioProceso INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @IdUsuarioProceso IS NULL
        THROW 62001, 'IdUsuarioProceso es obligatorio.', 1;

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
        THROW 62002, 'El usuario que procesa la liquidación no existe.', 1;

    IF @Rol NOT IN ('ADMINISTRADOR', 'CAJERO')
        THROW 62003, 'El usuario no tiene permisos para liquidar boletos.', 1;

    IF @EstadoUsuario <> 'ACTIVO'
        THROW 62004, 'El usuario que procesa la liquidación debe estar ACTIVO.', 1;
END;
GO


/* ============================================================
   2. OBTENER BOLETOS LISTOS PARA LIQUIDAR

   Un boleto está listo cuando:
   - Estado BOLETO/PENDIENTE.
   - Tiene por lo menos un detalle.
   - Ningún detalle está PENDIENTE.
   - Todavía no posee una liquidación completada.

   @Cantidad limita el resultado para uso administrativo.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerBoletosListosLiquidar
(
    @IdUsuarioProceso INT,
    @Cantidad INT = 100
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Cantidad IS NULL OR @Cantidad < 1 OR @Cantidad > 500
        THROW 62005, 'Cantidad debe estar entre 1 y 500.', 1;

    EXEC dbo.sp_ValidarPermisoLiquidacion
        @IdUsuarioProceso = @IdUsuarioProceso;

    SELECT TOP (@Cantidad)
        B.IdBoleto,
        B.CodigoBoleto,
        B.IdUsuario,
        U.Correo,
        B.TipoBoleto,
        B.MontoApostado,
        B.CuotaTotal,
        B.GananciaPotencial,
        B.FechaCreacion,

        COUNT(DB.IdDetalle) AS CantidadSelecciones,

        SUM
        (
            CASE
                WHEN DB.Resultado = 'GANADA' THEN 1
                ELSE 0
            END
        ) AS SeleccionesGanadas,

        SUM
        (
            CASE
                WHEN DB.Resultado = 'PERDIDA' THEN 1
                ELSE 0
            END
        ) AS SeleccionesPerdidas,

        SUM
        (
            CASE
                WHEN DB.Resultado = 'ANULADA' THEN 1
                ELSE 0
            END
        ) AS SeleccionesAnuladas,

        CASE
            WHEN SUM(CASE WHEN DB.Resultado = 'PERDIDA' THEN 1 ELSE 0 END) > 0
                THEN 'PERDEDOR'

            WHEN SUM(CASE WHEN DB.Resultado = 'GANADA' THEN 1 ELSE 0 END) = 0
             AND SUM(CASE WHEN DB.Resultado = 'ANULADA' THEN 1 ELSE 0 END) = COUNT(DB.IdDetalle)
                THEN 'ANULADO'

            ELSE 'GANADOR'
        END AS ResultadoPropuesto

    FROM dbo.Boleto AS B

    INNER JOIN dbo.Usuario AS U
        ON U.IdUsuario = B.IdUsuario

    INNER JOIN dbo.Estado AS EB
        ON EB.IdEstado = B.IdEstado

    INNER JOIN dbo.TipoEstado AS TEB
        ON TEB.IdTipoEstado = EB.IdTipoEstado
       AND TEB.Codigo = 'BOLETO'

    INNER JOIN dbo.DetalleBoleto AS DB
        ON DB.IdBoleto = B.IdBoleto

    WHERE EB.Codigo = 'PENDIENTE'

      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.DetalleBoleto AS DP
          WHERE DP.IdBoleto = B.IdBoleto
            AND DP.Resultado = 'PENDIENTE'
      )

      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.LiquidacionBoleto AS LB
          INNER JOIN dbo.Estado AS EL
              ON EL.IdEstado = LB.IdEstado
          INNER JOIN dbo.TipoEstado AS TEL
              ON TEL.IdTipoEstado = EL.IdTipoEstado
             AND TEL.Codigo = 'LIQUIDACION'
          WHERE LB.IdBoleto = B.IdBoleto
            AND EL.Codigo = 'COMPLETADA'
      )

    GROUP BY
        B.IdBoleto,
        B.CodigoBoleto,
        B.IdUsuario,
        U.Correo,
        B.TipoBoleto,
        B.MontoApostado,
        B.CuotaTotal,
        B.GananciaPotencial,
        B.FechaCreacion

    HAVING COUNT(DB.IdDetalle) > 0

    ORDER BY
        B.FechaCreacion,
        B.IdBoleto;
END;
GO


/* ============================================================
   3. LIQUIDAR BOLETO

   PROCEDIMIENTO CRITICO.

   RESULTADO:
   - GANADOR
   - PERDEDOR
   - ANULADO

   Para boletos compuestos:
   - Una selección PERDIDA hace perder todo el boleto.
   - Selecciones ANULADAS equivalen a cuota 1.0000.
   - Si todas están ANULADAS se devuelve el monto completo.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_LiquidarBoleto
(
    @IdUsuarioProceso INT,
    @IdBoleto INT,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @IpOrigen =
        NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @IdBoleto IS NULL
        THROW 62006, 'IdBoleto es obligatorio.', 1;


    EXEC dbo.sp_ValidarPermisoLiquidacion
        @IdUsuarioProceso = @IdUsuarioProceso;


    /* ========================================================
       CATALOGOS NECESARIOS
       ======================================================== */

    DECLARE @IdEstadoLiquidacionEnProceso INT;
    DECLARE @IdEstadoLiquidacionCompletada INT;

    DECLARE @IdEstadoBoletoLiquidado INT;
    DECLARE @IdEstadoBoletoAnulado INT;

    DECLARE @IdEstadoTransaccionCompletada INT;

    DECLARE @IdTipoPremio INT;
    DECLARE @IdTipoPerdidaApuesta INT;
    DECLARE @IdTipoDevolucion INT;
    DECLARE @IdTipoGananciaCasa INT;
    DECLARE @IdTipoPagoPremio INT;


    SELECT @IdEstadoLiquidacionEnProceso = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'LIQUIDACION'
      AND E.Codigo = 'EN_PROCESO'
      AND E.Activo = 1;


    SELECT @IdEstadoLiquidacionCompletada = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'LIQUIDACION'
      AND E.Codigo = 'COMPLETADA'
      AND E.Activo = 1;


    SELECT @IdEstadoBoletoLiquidado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'BOLETO'
      AND E.Codigo = 'LIQUIDADO'
      AND E.Activo = 1;


    SELECT @IdEstadoBoletoAnulado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'BOLETO'
      AND E.Codigo = 'ANULADO'
      AND E.Activo = 1;


    SELECT @IdEstadoTransaccionCompletada = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'TRANSACCION'
      AND E.Codigo = 'COMPLETADA'
      AND E.Activo = 1;


    SELECT @IdTipoPremio = IdTipoTransaccion
    FROM dbo.TipoTransaccion
    WHERE Codigo = 'PREMIO'
      AND Activo = 1;


    SELECT @IdTipoPerdidaApuesta = IdTipoTransaccion
    FROM dbo.TipoTransaccion
    WHERE Codigo = 'PERDIDA_APUESTA'
      AND Activo = 1;


    SELECT @IdTipoDevolucion = IdTipoTransaccion
    FROM dbo.TipoTransaccion
    WHERE Codigo = 'DEVOLUCION'
      AND Activo = 1;


    SELECT @IdTipoGananciaCasa = IdTipoTransaccion
    FROM dbo.TipoTransaccion
    WHERE Codigo = 'GANANCIA_CASA'
      AND Activo = 1;


    SELECT @IdTipoPagoPremio = IdTipoTransaccion
    FROM dbo.TipoTransaccion
    WHERE Codigo = 'PAGO_PREMIO'
      AND Activo = 1;


    IF @IdEstadoLiquidacionEnProceso IS NULL
        THROW 62007, 'No existe el estado LIQUIDACION/EN_PROCESO.', 1;

    IF @IdEstadoLiquidacionCompletada IS NULL
        THROW 62008, 'No existe el estado LIQUIDACION/COMPLETADA.', 1;

    IF @IdEstadoBoletoLiquidado IS NULL
        THROW 62009, 'No existe el estado BOLETO/LIQUIDADO.', 1;

    IF @IdEstadoBoletoAnulado IS NULL
        THROW 62010, 'No existe el estado BOLETO/ANULADO.', 1;

    IF @IdEstadoTransaccionCompletada IS NULL
        THROW 62011, 'No existe el estado TRANSACCION/COMPLETADA.', 1;

    IF @IdTipoPremio IS NULL
        THROW 62012, 'No existe el tipo de transacción PREMIO.', 1;

    IF @IdTipoPerdidaApuesta IS NULL
        THROW 62013, 'No existe el tipo de transacción PERDIDA_APUESTA.', 1;

    IF @IdTipoDevolucion IS NULL
        THROW 62014, 'No existe el tipo de transacción DEVOLUCION.', 1;

    IF @IdTipoGananciaCasa IS NULL
        THROW 62015, 'No existe el tipo de transacción GANANCIA_CASA.', 1;

    IF @IdTipoPagoPremio IS NULL
        THROW 62016, 'No existe el tipo de transacción PAGO_PREMIO.', 1;


    BEGIN TRY
        BEGIN TRANSACTION;


        /* ====================================================
           VALIDAR / BLOQUEAR BOLETO
           ==================================================== */

        DECLARE @IdUsuario INT;
        DECLARE @EstadoBoleto VARCHAR(40);
        DECLARE @ResultadoBoletoActual VARCHAR(20);

        DECLARE @MontoApostado DECIMAL(12,2);
        DECLARE @CodigoBoleto VARCHAR(40);


        SELECT
            @IdUsuario = B.IdUsuario,
            @EstadoBoleto = E.Codigo,
            @ResultadoBoletoActual = B.Resultado,
            @MontoApostado = B.MontoApostado,
            @CodigoBoleto = B.CodigoBoleto

        FROM dbo.Boleto AS B WITH (UPDLOCK, HOLDLOCK)

        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = B.IdEstado

        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'BOLETO'

        WHERE B.IdBoleto = @IdBoleto;


        IF @IdUsuario IS NULL
            THROW 62017, 'El boleto indicado no existe.', 1;


        /* ====================================================
           IDEMPOTENCIA POR LiquidacionBoleto

           IdBoleto es UNIQUE en LiquidacionBoleto.
           Si ya fue completado, devolver el resultado existente.
           ==================================================== */

        DECLARE @IdLiquidacionExistente BIGINT;
        DECLARE @EstadoLiquidacionExistente VARCHAR(40);
        DECLARE @MontoLiquidadoExistente DECIMAL(12,2);
        DECLARE @IdTransaccionExistente BIGINT;


        SELECT
            @IdLiquidacionExistente = LB.IdLiquidacion,
            @EstadoLiquidacionExistente = E.Codigo,
            @MontoLiquidadoExistente = LB.MontoLiquidado,
            @IdTransaccionExistente = LB.IdTransaccion

        FROM dbo.LiquidacionBoleto AS LB WITH (UPDLOCK, HOLDLOCK)

        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = LB.IdEstado

        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'LIQUIDACION'

        WHERE LB.IdBoleto = @IdBoleto;


        IF @IdLiquidacionExistente IS NOT NULL
        BEGIN

            IF @EstadoLiquidacionExistente <> 'COMPLETADA'
                THROW 62018, 'El boleto ya posee una liquidación no completada que requiere revisión administrativa.', 1;


            COMMIT TRANSACTION;


            SELECT
                LB.IdLiquidacion,
                B.IdBoleto,
                B.CodigoBoleto,
                B.Resultado,
                EB.Codigo AS EstadoBoleto,
                LB.MontoLiquidado,
                LB.IdTransaccion,
                LB.FechaFinalizacion,
                CAST(1 AS BIT) AS SolicitudIdempotente

            FROM dbo.LiquidacionBoleto AS LB

            INNER JOIN dbo.Boleto AS B
                ON B.IdBoleto = LB.IdBoleto

            INNER JOIN dbo.Estado AS EB
                ON EB.IdEstado = B.IdEstado

            WHERE LB.IdLiquidacion = @IdLiquidacionExistente;

            RETURN;
        END;


        IF @EstadoBoleto <> 'PENDIENTE'
            THROW 62019, 'Solo se pueden liquidar boletos en estado PENDIENTE.', 1;


        /* ====================================================
           VALIDAR DETALLES RESUELTOS
           ==================================================== */

        DECLARE @CantidadDetalles INT;
        DECLARE @CantidadGanadas INT;
        DECLARE @CantidadPerdidas INT;
        DECLARE @CantidadAnuladas INT;


        SELECT
            @CantidadDetalles = COUNT(*),
            @CantidadGanadas =
                SUM(CASE WHEN Resultado = 'GANADA' THEN 1 ELSE 0 END),
            @CantidadPerdidas =
                SUM(CASE WHEN Resultado = 'PERDIDA' THEN 1 ELSE 0 END),
            @CantidadAnuladas =
                SUM(CASE WHEN Resultado = 'ANULADA' THEN 1 ELSE 0 END)

        FROM dbo.DetalleBoleto WITH (UPDLOCK, HOLDLOCK)
        WHERE IdBoleto = @IdBoleto;


        IF @CantidadDetalles IS NULL OR @CantidadDetalles = 0
            THROW 62020, 'El boleto no contiene detalles.', 1;


        IF EXISTS
        (
            SELECT 1
            FROM dbo.DetalleBoleto
            WHERE IdBoleto = @IdBoleto
              AND Resultado = 'PENDIENTE'
        )
            THROW 62021, 'El boleto todavía contiene selecciones pendientes de resolución.', 1;


        IF @CantidadGanadas + @CantidadPerdidas + @CantidadAnuladas
           <> @CantidadDetalles
            THROW 62022, 'El boleto contiene un estado de detalle no reconocido para liquidación.', 1;


        /* ====================================================
           DETERMINAR RESULTADO DEL BOLETO
           ==================================================== */

        DECLARE @ResultadoFinal VARCHAR(20);
        DECLARE @MontoLiquidado DECIMAL(12,2);
        DECLARE @GananciaNeta DECIMAL(12,2) = 0;


        IF @CantidadPerdidas > 0
        BEGIN
            SET @ResultadoFinal = 'PERDEDOR';
            SET @MontoLiquidado = 0;
        END
        ELSE IF @CantidadAnuladas = @CantidadDetalles
        BEGIN
            SET @ResultadoFinal = 'ANULADO';
            SET @MontoLiquidado = @MontoApostado;
        END
        ELSE
        BEGIN
            SET @ResultadoFinal = 'GANADOR';


            /* Selecciones ANULADAS equivalen a factor 1.
               Solo multiplicamos las GANADAS. */
            DECLARE @CuotasGanadoras TABLE
            (
                Orden INT IDENTITY(1,1) NOT NULL,
                Cuota DECIMAL(10,4) NOT NULL
            );


            INSERT INTO @CuotasGanadoras
            (
                Cuota
            )
            SELECT
                CuotaAplicada
            FROM dbo.DetalleBoleto
            WHERE IdBoleto = @IdBoleto
              AND Resultado = 'GANADA'
            ORDER BY IdDetalle;


            DECLARE @CuotaEfectivaCalculo DECIMAL(38,12) = 1;
            DECLARE @OrdenActual INT = 1;
            DECLARE @TotalCuotasGanadoras INT =
                (SELECT COUNT(*) FROM @CuotasGanadoras);
            DECLARE @CuotaActual DECIMAL(10,4);


            WHILE @OrdenActual <= @TotalCuotasGanadoras
            BEGIN

                SELECT @CuotaActual = Cuota
                FROM @CuotasGanadoras
                WHERE Orden = @OrdenActual;


                SET @CuotaEfectivaCalculo =
                    @CuotaEfectivaCalculo
                    * CONVERT(DECIMAL(38,12), @CuotaActual);


                SET @OrdenActual = @OrdenActual + 1;

            END;


            IF @CuotaEfectivaCalculo > 99999999.9999
                THROW 62023, 'La cuota efectiva excede el rango permitido por el sistema.', 1;


            DECLARE @CuotaEfectiva DECIMAL(12,4) =
                CONVERT(DECIMAL(12,4), ROUND(@CuotaEfectivaCalculo, 4));


            DECLARE @MontoLiquidadoCalculo DECIMAL(38,4) =
                CONVERT(DECIMAL(38,4), @MontoApostado)
                * CONVERT(DECIMAL(38,4), @CuotaEfectiva);


            IF @MontoLiquidadoCalculo > 9999999999.99
                THROW 62024, 'El monto de liquidación excede el rango permitido por el sistema.', 1;


            SET @MontoLiquidado =
                CONVERT(DECIMAL(12,2), ROUND(@MontoLiquidadoCalculo, 2));


            SET @GananciaNeta =
                @MontoLiquidado - @MontoApostado;


            IF @GananciaNeta < 0
                THROW 62025, 'La ganancia neta calculada es inválida.', 1;

        END;


        /* ====================================================
           LOCALIZAR CASA

           Debe existir exactamente una cuenta CASA activa con
           billetera para mantener un único contraparte financiero.
           ==================================================== */

        DECLARE @CantidadCuentasCasa INT;


        SELECT @CantidadCuentasCasa = COUNT(*)
        FROM dbo.Usuario AS UC

        INNER JOIN dbo.Rol AS RC
            ON RC.IdRol = UC.IdRol
           AND RC.Nombre = 'CASA'

        INNER JOIN dbo.Estado AS EC
            ON EC.IdEstado = UC.IdEstado

        INNER JOIN dbo.TipoEstado AS TEC
            ON TEC.IdTipoEstado = EC.IdTipoEstado
           AND TEC.Codigo = 'USUARIO'

        INNER JOIN dbo.Billetera AS BC
            ON BC.IdUsuario = UC.IdUsuario

        WHERE EC.Codigo = 'ACTIVO';


        IF @CantidadCuentasCasa <> 1
            THROW 62026, 'Debe existir exactamente una cuenta CASA activa con billetera.', 1;


        DECLARE @IdUsuarioCasa INT;
        DECLARE @IdBilleteraCasa INT;


        SELECT
            @IdUsuarioCasa = UC.IdUsuario,
            @IdBilleteraCasa = BC.IdBilletera

        FROM dbo.Usuario AS UC

        INNER JOIN dbo.Rol AS RC
            ON RC.IdRol = UC.IdRol
           AND RC.Nombre = 'CASA'

        INNER JOIN dbo.Estado AS EC
            ON EC.IdEstado = UC.IdEstado

        INNER JOIN dbo.TipoEstado AS TEC
            ON TEC.IdTipoEstado = EC.IdTipoEstado
           AND TEC.Codigo = 'USUARIO'

        INNER JOIN dbo.Billetera AS BC
            ON BC.IdUsuario = UC.IdUsuario

        WHERE EC.Codigo = 'ACTIVO';


        /* ====================================================
           LOCALIZAR BILLETERA DEL USUARIO
           ==================================================== */

        DECLARE @IdBilleteraUsuario INT;


        SELECT @IdBilleteraUsuario = IdBilletera
        FROM dbo.Billetera
        WHERE IdUsuario = @IdUsuario;


        IF @IdBilleteraUsuario IS NULL
            THROW 62027, 'El usuario propietario del boleto no posee una billetera.', 1;


        /* ====================================================
           BLOQUEAR BILLETERAS EN ORDEN CONSISTENTE:
           1. CASA
           2. USUARIO

           Esto serializa la contraparte CASA y reduce riesgo
           de interbloqueos entre liquidaciones concurrentes.
           ==================================================== */

        DECLARE @CasaDisponibleAnterior DECIMAL(12,2);
        DECLARE @CasaComprometidoAnterior DECIMAL(12,2);


        SELECT
            @CasaDisponibleAnterior = SaldoDisponible,
            @CasaComprometidoAnterior = SaldoComprometido

        FROM dbo.Billetera WITH (UPDLOCK, ROWLOCK)

        WHERE IdBilletera = @IdBilleteraCasa;


        IF @CasaDisponibleAnterior IS NULL
            THROW 62028, 'No fue posible bloquear la billetera de CASA.', 1;


        DECLARE @UsuarioDisponibleAnterior DECIMAL(12,2);
        DECLARE @UsuarioComprometidoAnterior DECIMAL(12,2);


        SELECT
            @UsuarioDisponibleAnterior = SaldoDisponible,
            @UsuarioComprometidoAnterior = SaldoComprometido

        FROM dbo.Billetera WITH (UPDLOCK, ROWLOCK)

        WHERE IdBilletera = @IdBilleteraUsuario;


        IF @UsuarioDisponibleAnterior IS NULL
            THROW 62029, 'No fue posible bloquear la billetera del usuario.', 1;


        IF @UsuarioComprometidoAnterior < @MontoApostado
            THROW 62030, 'El saldo comprometido del usuario es insuficiente para liquidar el boleto.', 1;


        /* CASA solo necesita solvencia para GANADOR. */
        IF @ResultadoFinal = 'GANADOR'
           AND @GananciaNeta > 0
           AND @CasaDisponibleAnterior < @GananciaNeta
            THROW 62031, 'La billetera CASA no posee saldo virtual suficiente para pagar la ganancia neta.', 1;


        /* ====================================================
           CREAR REGISTRO DE LIQUIDACION EN PROCESO
           ==================================================== */

        DECLARE @IdLiquidacion BIGINT;


        INSERT INTO dbo.LiquidacionBoleto
        (
            IdBoleto,
            IdEstado,
            IdTransaccion,
            MontoLiquidado,
            FechaInicioProceso,
            IdUsuarioProceso,
            Observacion
        )
        VALUES
        (
            @IdBoleto,
            @IdEstadoLiquidacionEnProceso,
            NULL,
            @MontoLiquidado,
            SYSDATETIME(),
            @IdUsuarioProceso,
            CONCAT
            (
                'Liquidación iniciada. Resultado calculado: ',
                @ResultadoFinal,
                '.'
            )
        );


        SET @IdLiquidacion =
            CONVERT(BIGINT, SCOPE_IDENTITY());


        /* ====================================================
           CALCULAR SALDOS DEL USUARIO
           ==================================================== */

        DECLARE @UsuarioDisponiblePosterior DECIMAL(12,2);
        DECLARE @UsuarioComprometidoPosterior DECIMAL(12,2);


        SET @UsuarioComprometidoPosterior =
            @UsuarioComprometidoAnterior - @MontoApostado;


        IF @ResultadoFinal = 'PERDEDOR'
            SET @UsuarioDisponiblePosterior =
                @UsuarioDisponibleAnterior;

        ELSE
            SET @UsuarioDisponiblePosterior =
                @UsuarioDisponibleAnterior + @MontoLiquidado;


        /* ====================================================
           TRANSACCION DEL USUARIO
           ==================================================== */

        DECLARE @IdTipoTransaccionUsuario INT;
        DECLARE @ReferenciaUsuario UNIQUEIDENTIFIER = NEWID();
        DECLARE @IdTransaccionUsuario BIGINT;


        SET @IdTipoTransaccionUsuario =
            CASE
                WHEN @ResultadoFinal = 'GANADOR'
                    THEN @IdTipoPremio

                WHEN @ResultadoFinal = 'PERDEDOR'
                    THEN @IdTipoPerdidaApuesta

                ELSE @IdTipoDevolucion
            END;


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
            @IdBilleteraUsuario,
            @IdTipoTransaccionUsuario,
            @IdEstadoTransaccionCompletada,
            @IdBoleto,
            @ReferenciaUsuario,

            CASE
                WHEN @ResultadoFinal = 'GANADOR'
                    THEN @MontoLiquidado
                ELSE @MontoApostado
            END,

            SYSDATETIME(),
            @IdUsuarioProceso,

            CASE
                WHEN @ResultadoFinal = 'GANADOR'
                    THEN CONCAT
                         (
                             'Premio virtual de boleto ',
                             @CodigoBoleto,
                             '. Monto liquidado=',
                             CONVERT(VARCHAR(30), @MontoLiquidado),
                             '.'
                         )

                WHEN @ResultadoFinal = 'PERDEDOR'
                    THEN CONCAT
                         (
                             'Liquidación de apuesta perdida ',
                             @CodigoBoleto,
                             '.'
                         )

                ELSE CONCAT
                     (
                         'Devolución virtual por boleto anulado ',
                         @CodigoBoleto,
                         '.'
                     )
            END
        );


        SET @IdTransaccionUsuario =
            CONVERT(BIGINT, SCOPE_IDENTITY());


        UPDATE dbo.Billetera
        SET
            SaldoDisponible = @UsuarioDisponiblePosterior,
            SaldoComprometido = @UsuarioComprometidoPosterior
        WHERE IdBilletera = @IdBilleteraUsuario;


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
            @IdBilleteraUsuario,
            @IdTransaccionUsuario,

            @UsuarioDisponibleAnterior,
            @UsuarioDisponiblePosterior,

            @UsuarioComprometidoAnterior,
            @UsuarioComprometidoPosterior
        );


        /* ====================================================
           CONTRAPARTE CASA
           ==================================================== */

        DECLARE @IdTransaccionCasa BIGINT = NULL;
        DECLARE @ReferenciaCasa UNIQUEIDENTIFIER = NULL;
        DECLARE @CasaDisponiblePosterior DECIMAL(12,2) =
            @CasaDisponibleAnterior;


        /* PERDEDOR:
           CASA recibe el monto apostado completo. */
        IF @ResultadoFinal = 'PERDEDOR'
        BEGIN

            SET @CasaDisponiblePosterior =
                @CasaDisponibleAnterior + @MontoApostado;

            SET @ReferenciaCasa = NEWID();


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
                @IdBilleteraCasa,
                @IdTipoGananciaCasa,
                @IdEstadoTransaccionCompletada,
                @IdBoleto,
                @ReferenciaCasa,
                @MontoApostado,
                SYSDATETIME(),
                @IdUsuarioProceso,
                CONCAT
                (
                    'Ganancia virtual de CASA por boleto perdido ',
                    @CodigoBoleto,
                    '.'
                )
            );


            SET @IdTransaccionCasa =
                CONVERT(BIGINT, SCOPE_IDENTITY());


            UPDATE dbo.Billetera
            SET SaldoDisponible = @CasaDisponiblePosterior
            WHERE IdBilletera = @IdBilleteraCasa;


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
                @IdBilleteraCasa,
                @IdTransaccionCasa,

                @CasaDisponibleAnterior,
                @CasaDisponiblePosterior,

                @CasaComprometidoAnterior,
                @CasaComprometidoAnterior
            );

        END;


        /* GANADOR:
           El usuario recupera su propia apuesta desde comprometido.
           CASA paga únicamente la ganancia neta. */
        IF @ResultadoFinal = 'GANADOR'
           AND @GananciaNeta > 0
        BEGIN

            SET @CasaDisponiblePosterior =
                @CasaDisponibleAnterior - @GananciaNeta;

            SET @ReferenciaCasa = NEWID();


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
                @IdBilleteraCasa,
                @IdTipoPagoPremio,
                @IdEstadoTransaccionCompletada,
                @IdBoleto,
                @ReferenciaCasa,
                @GananciaNeta,
                SYSDATETIME(),
                @IdUsuarioProceso,
                CONCAT
                (
                    'Pago virtual de ganancia neta del boleto ',
                    @CodigoBoleto,
                    '. Ganancia=',
                    CONVERT(VARCHAR(30), @GananciaNeta),
                    '.'
                )
            );


            SET @IdTransaccionCasa =
                CONVERT(BIGINT, SCOPE_IDENTITY());


            UPDATE dbo.Billetera
            SET SaldoDisponible = @CasaDisponiblePosterior
            WHERE IdBilletera = @IdBilleteraCasa;


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
                @IdBilleteraCasa,
                @IdTransaccionCasa,

                @CasaDisponibleAnterior,
                @CasaDisponiblePosterior,

                @CasaComprometidoAnterior,
                @CasaComprometidoAnterior
            );

        END;


        /* ANULADO:
           No existe movimiento de CASA. */


        /* ====================================================
           ACTUALIZAR BOLETO
           ==================================================== */

        UPDATE dbo.Boleto
        SET
            IdEstado =
                CASE
                    WHEN @ResultadoFinal = 'ANULADO'
                        THEN @IdEstadoBoletoAnulado
                    ELSE @IdEstadoBoletoLiquidado
                END,

            Resultado = @ResultadoFinal,
            FechaLiquidacion = SYSDATETIME()

        WHERE IdBoleto = @IdBoleto;


        /* ====================================================
           COMPLETAR LIQUIDACION
           ==================================================== */

        UPDATE dbo.LiquidacionBoleto
        SET
            IdEstado = @IdEstadoLiquidacionCompletada,
            IdTransaccion = @IdTransaccionUsuario,
            MontoLiquidado = @MontoLiquidado,
            FechaFinalizacion = SYSDATETIME(),
            Observacion =
                CONCAT
                (
                    'Liquidación completada. Resultado=',
                    @ResultadoFinal,
                    '. Monto apostado=',
                    CONVERT(VARCHAR(30), @MontoApostado),
                    '. Monto liquidado=',
                    CONVERT(VARCHAR(30), @MontoLiquidado),
                    '. Ganancia neta=',
                    CONVERT(VARCHAR(30), @GananciaNeta),
                    '.'
                )

        WHERE IdLiquidacion = @IdLiquidacion;


        /* ====================================================
           AUDITORIA
           ==================================================== */

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
            'BOLETO_LIQUIDADO',
            'LiquidacionBoleto',
            @IdLiquidacion,
            @ReferenciaUsuario,
            @IpOrigen,
            CONCAT
            (
                'Boleto ',
                @CodigoBoleto,
                ' liquidado como ',
                @ResultadoFinal,
                '. MontoApostado=',
                CONVERT(VARCHAR(30), @MontoApostado),
                '. MontoLiquidado=',
                CONVERT(VARCHAR(30), @MontoLiquidado),
                '. GananciaNeta=',
                CONVERT(VARCHAR(30), @GananciaNeta),
                '. IdTransaccionCasa=',
                COALESCE(CONVERT(VARCHAR(30), @IdTransaccionCasa), 'NULL'),
                '.'
            )
        );


        COMMIT TRANSACTION;


        /* ====================================================
           RESPUESTA ESTABLE PARA JAVA
           ==================================================== */

        SELECT
            @IdLiquidacion AS IdLiquidacion,

            @IdBoleto AS IdBoleto,
            @CodigoBoleto AS CodigoBoleto,

            @ResultadoFinal AS ResultadoBoleto,

            CASE
                WHEN @ResultadoFinal = 'ANULADO'
                    THEN 'ANULADO'
                ELSE 'LIQUIDADO'
            END AS EstadoBoleto,

            @MontoApostado AS MontoApostado,
            @MontoLiquidado AS MontoLiquidado,
            @GananciaNeta AS GananciaNeta,

            @IdTransaccionUsuario AS IdTransaccionUsuario,
            @ReferenciaUsuario AS ReferenciaUsuario,

            @IdTransaccionCasa AS IdTransaccionCasa,
            @ReferenciaCasa AS ReferenciaCasa,

            @UsuarioDisponibleAnterior AS UsuarioDisponibleAnterior,
            @UsuarioDisponiblePosterior AS UsuarioDisponiblePosterior,

            @UsuarioComprometidoAnterior AS UsuarioComprometidoAnterior,
            @UsuarioComprometidoPosterior AS UsuarioComprometidoPosterior,

            @CasaDisponibleAnterior AS CasaDisponibleAnterior,
            @CasaDisponiblePosterior AS CasaDisponiblePosterior,

            CAST(0 AS BIT) AS SolicitudIdempotente;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH;
END;
GO


/* ============================================================
   4. OBTENER LIQUIDACION DE BOLETO

   SEGURIDAD:
   - El propietario puede consultar su propia liquidación.
   - ADMINISTRADOR, CAJERO y AUDITOR pueden consultar cualquiera.

   DEVUELVE:
   - Resultado del boleto.
   - Estado de liquidación.
   - Monto liquidado.
   - Movimiento financiero principal del usuario.
   - Movimiento contraparte CASA cuando exista.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ObtenerLiquidacionBoleto
(
    @IdUsuarioSolicitante INT,
    @IdBoleto INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @IdUsuarioSolicitante IS NULL
        THROW 62032, 'IdUsuarioSolicitante es obligatorio.', 1;

    IF @IdBoleto IS NULL
        THROW 62033, 'IdBoleto es obligatorio.', 1;


    DECLARE @IdPropietario INT;

    SELECT @IdPropietario = IdUsuario
    FROM dbo.Boleto
    WHERE IdBoleto = @IdBoleto;


    IF @IdPropietario IS NULL
        THROW 62034, 'El boleto indicado no existe.', 1;


    DECLARE @RolSolicitante VARCHAR(50);
    DECLARE @EstadoSolicitante VARCHAR(40);


    SELECT
        @RolSolicitante = R.Nombre,
        @EstadoSolicitante = E.Codigo

    FROM dbo.Usuario AS U

    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol

    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = U.IdEstado

    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'USUARIO'

    WHERE U.IdUsuario = @IdUsuarioSolicitante;


    IF @RolSolicitante IS NULL
        THROW 62035, 'El usuario solicitante no existe.', 1;


    IF @IdUsuarioSolicitante <> @IdPropietario
       AND @RolSolicitante NOT IN ('ADMINISTRADOR', 'CAJERO', 'AUDITOR')
        THROW 62036, 'El usuario no tiene permisos para consultar esta liquidación.', 1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.LiquidacionBoleto
        WHERE IdBoleto = @IdBoleto
    )
        THROW 62037, 'El boleto todavía no posee una liquidación.', 1;


    /* Transacción contraparte de CASA, cuando existe. */
    DECLARE @IdTransaccionCasa BIGINT;


    SELECT TOP (1)
        @IdTransaccionCasa = TF.IdTransaccion

    FROM dbo.TransaccionFinanciera AS TF

    INNER JOIN dbo.TipoTransaccion AS TT
        ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

    INNER JOIN dbo.Billetera AS BC
        ON BC.IdBilletera = TF.IdBilletera

    INNER JOIN dbo.Usuario AS UC
        ON UC.IdUsuario = BC.IdUsuario

    INNER JOIN dbo.Rol AS RC
        ON RC.IdRol = UC.IdRol
       AND RC.Nombre = 'CASA'

    WHERE TF.IdBoleto = @IdBoleto
      AND TT.Codigo IN ('GANANCIA_CASA', 'PAGO_PREMIO')

    ORDER BY TF.IdTransaccion DESC;


    SELECT
        LB.IdLiquidacion,

        B.IdBoleto,
        B.CodigoBoleto,

        B.IdUsuario,
        U.Correo,

        B.Resultado AS ResultadoBoleto,
        EB.Codigo AS EstadoBoleto,

        B.MontoApostado,
        B.CuotaTotal,
        B.GananciaPotencial,

        LB.MontoLiquidado,

        EL.Codigo AS EstadoLiquidacion,

        LB.IdTransaccion AS IdTransaccionUsuario,
        @IdTransaccionCasa AS IdTransaccionCasa,

        LB.FechaCreacion,
        LB.FechaInicioProceso,
        LB.FechaFinalizacion,

        LB.IdUsuarioProceso,
        UP.Correo AS UsuarioProceso,

        LB.Observacion

    FROM dbo.LiquidacionBoleto AS LB

    INNER JOIN dbo.Boleto AS B
        ON B.IdBoleto = LB.IdBoleto

    INNER JOIN dbo.Usuario AS U
        ON U.IdUsuario = B.IdUsuario

    INNER JOIN dbo.Estado AS EB
        ON EB.IdEstado = B.IdEstado

    INNER JOIN dbo.Estado AS EL
        ON EL.IdEstado = LB.IdEstado

    LEFT JOIN dbo.Usuario AS UP
        ON UP.IdUsuario = LB.IdUsuarioProceso

    WHERE LB.IdBoleto = @IdBoleto;
END;
GO


PRINT '=======================================================';
PRINT ' PROCEDIMIENTOS DE LIQUIDACION CREADOS / ACTUALIZADOS';
PRINT '=======================================================';
GO