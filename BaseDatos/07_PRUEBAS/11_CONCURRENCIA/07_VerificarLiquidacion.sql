/* ============================================================
   VERIFICACION DE LIQUIDACION CONCURRENTE

   OBJETIVO:
   Comprobar que dos solicitudes simultaneas de liquidacion
   no duplicaron:
   - LiquidacionBoleto
   - Premio del usuario
   - Pago de premio de CASA
   - Movimientos financieros

   RESULTADO ESPERADO:
   - 1 sola liquidacion COMPLETADA.
   - Boleto GANADOR / LIQUIDADO.
   - Usuario recibe Q800.
   - Saldo comprometido vuelve a Q0.
   - CASA paga solamente Q400 de ganancia neta.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


BEGIN TRY

    PRINT '=======================================================';
    PRINT ' VERIFICACION DE LIQUIDACION CONCURRENTE';
    PRINT '=======================================================';
    PRINT '';


    DECLARE @IdBoleto INT;
    DECLARE @IdBilleteraUsuario INT;
    DECLARE @IdBilleteraCasa INT;

    DECLARE @SaldoUsuarioAntes DECIMAL(12,2);
    DECLARE @ComprometidoAntes DECIMAL(12,2);
    DECLARE @SaldoCasaAntes DECIMAL(12,2);

    DECLARE @MontoLiquidadoEsperado DECIMAL(12,2);
    DECLARE @GananciaNetaEsperada DECIMAL(12,2);


    SELECT
        @IdBoleto = IdBoletoGanador,
        @IdBilleteraUsuario = IdBilleteraUsuario,
        @IdBilleteraCasa = IdBilleteraCasa,

        @SaldoUsuarioAntes =
            SaldoUsuarioAntesLiquidacion,

        @ComprometidoAntes =
            ComprometidoAntesLiquidacion,

        @SaldoCasaAntes =
            SaldoCasaAntesLiquidacion,

        @MontoLiquidadoEsperado =
            MontoLiquidadoEsperado,

        @GananciaNetaEsperada =
            GananciaNetaEsperada

    FROM dbo.PruebaConcurrenciaContexto
    WHERE IdContexto = 1;


    IF @IdBoleto IS NULL
        THROW 71601,
            'No existe boleto preparado para verificar la liquidación.',
            1;


    /* ========================================================
       1. EXACTAMENTE UNA LIQUIDACION
       ======================================================== */

    DECLARE @CantidadLiquidaciones INT;


    SELECT @CantidadLiquidaciones = COUNT(*)
    FROM dbo.LiquidacionBoleto
    WHERE IdBoleto = @IdBoleto;


    PRINT 'Liquidaciones registradas: '
        + CONVERT(VARCHAR(10), @CantidadLiquidaciones);


    IF @CantidadLiquidaciones <> 1
        THROW 71602,
            'ERROR DE CONCURRENCIA: debía existir una sola liquidación.',
            1;


    DECLARE @EstadoLiquidacion VARCHAR(40);
    DECLARE @MontoLiquidado DECIMAL(12,2);


    SELECT
        @EstadoLiquidacion = E.Codigo,
        @MontoLiquidado = LB.MontoLiquidado

    FROM dbo.LiquidacionBoleto AS LB

    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = LB.IdEstado

    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'LIQUIDACION'

    WHERE LB.IdBoleto = @IdBoleto;


    IF @EstadoLiquidacion <> 'COMPLETADA'
        THROW 71603,
            'La liquidación no quedó COMPLETADA.',
            1;


    IF @MontoLiquidado <> @MontoLiquidadoEsperado
        THROW 71604,
            'El monto liquidado no coincide con el esperado.',
            1;


    PRINT 'Liquidacion unica y COMPLETADA: OK';


    /* ========================================================
       2. ESTADO DEL BOLETO
       ======================================================== */

    DECLARE @ResultadoBoleto VARCHAR(20);
    DECLARE @EstadoBoleto VARCHAR(40);


    SELECT
        @ResultadoBoleto = B.Resultado,
        @EstadoBoleto = E.Codigo

    FROM dbo.Boleto AS B

    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = B.IdEstado

    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'BOLETO'

    WHERE B.IdBoleto = @IdBoleto;


    IF @ResultadoBoleto <> 'GANADOR'
        THROW 71605,
            'El boleto no quedó como GANADOR.',
            1;


    IF @EstadoBoleto <> 'LIQUIDADO'
        THROW 71606,
            'El boleto no quedó LIQUIDADO.',
            1;


    PRINT 'Boleto GANADOR / LIQUIDADO: OK';


    /* ========================================================
       3. SALDOS DEL USUARIO
       ======================================================== */

    DECLARE @DisponibleUsuarioActual DECIMAL(12,2);
    DECLARE @ComprometidoUsuarioActual DECIMAL(12,2);

    DECLARE @DisponibleUsuarioEsperado DECIMAL(12,2);


    SELECT
        @DisponibleUsuarioActual = SaldoDisponible,
        @ComprometidoUsuarioActual = SaldoComprometido

    FROM dbo.Billetera
    WHERE IdBilletera = @IdBilleteraUsuario;


    SET @DisponibleUsuarioEsperado =
        @SaldoUsuarioAntes
        + @MontoLiquidadoEsperado;


    PRINT '';
    PRINT 'Saldo usuario antes: Q'
        + CONVERT(VARCHAR(30), @SaldoUsuarioAntes);

    PRINT 'Monto liquidado: Q'
        + CONVERT(VARCHAR(30), @MontoLiquidadoEsperado);

    PRINT 'Saldo usuario esperado: Q'
        + CONVERT(VARCHAR(30), @DisponibleUsuarioEsperado);

    PRINT 'Saldo usuario real: Q'
        + CONVERT(VARCHAR(30), @DisponibleUsuarioActual);

    PRINT 'Comprometido usuario real: Q'
        + CONVERT(VARCHAR(30), @ComprometidoUsuarioActual);


    IF @DisponibleUsuarioActual
       <> @DisponibleUsuarioEsperado
        THROW 71607,
            'El saldo disponible del usuario fue alterado incorrectamente.',
            1;


    IF @ComprometidoUsuarioActual <> 0
        THROW 71608,
            'El saldo comprometido del usuario no fue liberado correctamente.',
            1;


    PRINT 'Saldo del usuario liquidado una sola vez: OK';


    /* ========================================================
       4. SALDO DE CASA
       ======================================================== */

    DECLARE @SaldoCasaActual DECIMAL(12,2);
    DECLARE @SaldoCasaEsperado DECIMAL(12,2);


    SELECT @SaldoCasaActual = SaldoDisponible
    FROM dbo.Billetera
    WHERE IdBilletera = @IdBilleteraCasa;


    SET @SaldoCasaEsperado =
        @SaldoCasaAntes
        - @GananciaNetaEsperada;


    PRINT '';
    PRINT 'Saldo CASA antes: Q'
        + CONVERT(VARCHAR(30), @SaldoCasaAntes);

    PRINT 'Ganancia neta pagada: Q'
        + CONVERT(VARCHAR(30), @GananciaNetaEsperada);

    PRINT 'Saldo CASA esperado: Q'
        + CONVERT(VARCHAR(30), @SaldoCasaEsperado);

    PRINT 'Saldo CASA real: Q'
        + CONVERT(VARCHAR(30), @SaldoCasaActual);


    IF @SaldoCasaActual <> @SaldoCasaEsperado
        THROW 71609,
            'CASA pagó un monto incorrecto o duplicado.',
            1;


    PRINT 'Pago de CASA realizado una sola vez: OK';


    /* ========================================================
       5. TRANSACCION PREMIO DEL USUARIO
       ======================================================== */

    DECLARE @CantidadPremios INT;


    SELECT @CantidadPremios = COUNT(*)

    FROM dbo.TransaccionFinanciera AS TF

    INNER JOIN dbo.TipoTransaccion AS TT
        ON TT.IdTipoTransaccion =
           TF.IdTipoTransaccion

    WHERE TF.IdBoleto = @IdBoleto
      AND TF.IdBilletera =
          @IdBilleteraUsuario
      AND TT.Codigo = 'PREMIO'
      AND TF.Monto =
          @MontoLiquidadoEsperado;


    IF @CantidadPremios <> 1
        THROW 71610,
            'El premio del usuario fue omitido o duplicado.',
            1;


    PRINT 'PREMIO del usuario unico: OK';


    /* ========================================================
       6. PAGO DE PREMIO DE CASA
       ======================================================== */

    DECLARE @CantidadPagosCasa INT;


    SELECT @CantidadPagosCasa = COUNT(*)

    FROM dbo.TransaccionFinanciera AS TF

    INNER JOIN dbo.TipoTransaccion AS TT
        ON TT.IdTipoTransaccion =
           TF.IdTipoTransaccion

    WHERE TF.IdBoleto = @IdBoleto
      AND TF.IdBilletera =
          @IdBilleteraCasa
      AND TT.Codigo = 'PAGO_PREMIO'
      AND TF.Monto =
          @GananciaNetaEsperada;


    IF @CantidadPagosCasa <> 1
        THROW 71611,
            'El pago de premio de CASA fue omitido o duplicado.',
            1;


    PRINT 'PAGO_PREMIO de CASA unico: OK';


    /* ========================================================
       RESULTADO FINAL
       ======================================================== */

    UPDATE dbo.PruebaConcurrenciaContexto
    SET EstadoPrueba = 'COMPLETADA'
    WHERE IdContexto = 1;


    PRINT '';
    PRINT '=======================================================';
    PRINT ' LIQUIDACION CONCURRENTE: CORRECTA';
    PRINT '=======================================================';
    PRINT '';
    PRINT 'Dos solicitudes intentaron liquidar el mismo boleto.';
    PRINT 'Solo se genero una liquidacion financiera.';
    PRINT 'No se duplico el premio del usuario.';
    PRINT 'No se duplico el pago realizado por CASA.';
    PRINT 'Idempotencia y concurrencia: OK';


END TRY
BEGIN CATCH

    PRINT '';
    PRINT '=======================================================';
    PRINT ' ERROR EN VERIFICACION DE LIQUIDACION CONCURRENTE';
    PRINT '=======================================================';

    PRINT 'Error: '
        + CONVERT(VARCHAR(20), ERROR_NUMBER());

    PRINT 'Mensaje: '
        + ERROR_MESSAGE();

    THROW;

END CATCH;
GO