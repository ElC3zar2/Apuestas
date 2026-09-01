/* ============================================================
   VERIFICACION DE APUESTAS CONCURRENTES

   RESULTADO OBLIGATORIO:
   - 1 boleto creado.
   - Q100 disponible.
   - Q400 comprometido.
   - 1 transacción APUESTA.

   Después prepara resultado GANADOR para probar liquidación.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


BEGIN TRY

    BEGIN TRANSACTION;


    DECLARE @IdAdministrador INT;
    DECLARE @IdUsuario INT;
    DECLARE @IdBilletera INT;

    DECLARE @IdEvento INT;
    DECLARE @IdMercado INT;

    DECLARE @IdSeleccionA INT;
    DECLARE @IdSeleccionB INT;

    DECLARE @ReferenciaA UNIQUEIDENTIFIER;
    DECLARE @ReferenciaB UNIQUEIDENTIFIER;

    DECLARE @IdBilleteraCasa INT;


    SELECT
        @IdAdministrador = IdAdministrador,
        @IdUsuario = IdUsuarioPrueba,
        @IdBilletera = IdBilleteraUsuario,
        @IdBilleteraCasa = IdBilleteraCasa,
        @IdEvento = IdEvento,
        @IdMercado = IdMercado,
        @IdSeleccionA = IdSeleccionA,
        @IdSeleccionB = IdSeleccionB,
        @ReferenciaA = ReferenciaA,
        @ReferenciaB = ReferenciaB

    FROM dbo.PruebaConcurrenciaContexto
    WHERE IdContexto = 1;


    IF @IdUsuario IS NULL
        THROW 71301,
              'No existe contexto de concurrencia.',
              1;


    /* ========================================================
       1. EXACTAMENTE UN BOLETO
       ======================================================== */

    DECLARE @CantidadBoletos INT;


    SELECT @CantidadBoletos = COUNT(*)
    FROM dbo.Boleto
    WHERE ReferenciaOperacion IN
          (
              @ReferenciaA,
              @ReferenciaB
          );


    PRINT 'Boletos creados: '
        + CONVERT(VARCHAR(10), @CantidadBoletos);


    IF @CantidadBoletos <> 1
        THROW 71302,
              'ERROR DE CONCURRENCIA: debía existir exactamente un boleto.',
              1;


    /* ========================================================
       2. EXACTAMENTE UNA TRANSACCION APUESTA
       ======================================================== */

    DECLARE @CantidadTransacciones INT;


    SELECT @CantidadTransacciones = COUNT(*)

    FROM dbo.TransaccionFinanciera AS TF

    INNER JOIN dbo.TipoTransaccion AS TT
        ON TT.IdTipoTransaccion = TF.IdTipoTransaccion

    WHERE TF.ReferenciaOperacion IN
          (
              @ReferenciaA,
              @ReferenciaB
          )
      AND TT.Codigo = 'APUESTA';


    IF @CantidadTransacciones <> 1
        THROW 71303,
              'Debe existir exactamente una transacción APUESTA.',
              1;


    /* ========================================================
       3. SALDOS
       ======================================================== */

    DECLARE @Disponible DECIMAL(12,2);
    DECLARE @Comprometido DECIMAL(12,2);


    SELECT
        @Disponible = SaldoDisponible,
        @Comprometido = SaldoComprometido

    FROM dbo.Billetera
    WHERE IdBilletera = @IdBilletera;


    PRINT 'Saldo disponible: Q'
        + CONVERT(VARCHAR(30), @Disponible);

    PRINT 'Saldo comprometido: Q'
        + CONVERT(VARCHAR(30), @Comprometido);


    IF @Disponible <> 100.00
        THROW 71304,
              'ERROR: SaldoDisponible debía quedar en Q100.',
              1;


    IF @Comprometido <> 400.00
        THROW 71305,
              'ERROR: SaldoComprometido debía quedar en Q400.',
              1;


    DECLARE @IdBoleto INT;


    SELECT @IdBoleto = IdBoleto
    FROM dbo.Boleto
    WHERE ReferenciaOperacion IN
          (
              @ReferenciaA,
              @ReferenciaB
          );


    PRINT '';
    PRINT '=======================================================';
    PRINT ' CONCURRENCIA DE APUESTAS: CORRECTA';
    PRINT '=======================================================';
    PRINT 'Una operación ganó el bloqueo.';
    PRINT 'La segunda no pudo gastar saldo inexistente.';


    /* ========================================================
       4. PREPARAR RESULTADO PARA LIQUIDACION CONCURRENTE
       ======================================================== */

    EXEC dbo.sp_CambiarEstadoEvento

        @IdUsuarioProceso = @IdAdministrador,

        @IdEvento = @IdEvento,

        @NuevoEstado = 'EN_VIVO',

        @Motivo =
            'Preparación de liquidación concurrente.',

        @IpOrigen = 'PRUEBA_CONCURRENCIA';


    EXEC dbo.sp_CambiarEstadoMercado

        @IdUsuarioProceso = @IdAdministrador,

        @IdMercado = @IdMercado,

        @NuevoEstado = 'CERRADO',

        @Motivo =
            'Preparación de liquidación concurrente.',

        @IpOrigen = 'PRUEBA_CONCURRENCIA';


    EXEC dbo.sp_CambiarEstadoEvento

        @IdUsuarioProceso = @IdAdministrador,

        @IdEvento = @IdEvento,

        @NuevoEstado = 'PENDIENTE_RESULTADO',

        @Motivo =
            'Preparación de liquidación concurrente.',

        @IpOrigen = 'PRUEBA_CONCURRENCIA';


    EXEC dbo.sp_RegistrarResultadoEvento

        @IdUsuarioProceso = @IdAdministrador,

        @IdEvento = @IdEvento,

        @ResultadoTexto = 'Equipo A 2 - 0 Equipo B',

        @Observacion =
            'Resultado preparado para prueba concurrente.',

        @IpOrigen = 'PRUEBA_CONCURRENCIA';


    DECLARE @IdResultadoEvento INT;


    SELECT @IdResultadoEvento = IdResultado
    FROM dbo.ResultadoEvento
    WHERE IdEvento = @IdEvento;


    EXEC dbo.sp_ResolverSeleccion

        @IdUsuarioProceso = @IdAdministrador,

        @IdResultadoEvento = @IdResultadoEvento,

        @IdSeleccion = @IdSeleccionA,

        @Resultado = 'GANADA',

        @Observacion = 'Equipo A ganador.',

        @IpOrigen = 'PRUEBA_CONCURRENCIA';


    EXEC dbo.sp_ResolverSeleccion

        @IdUsuarioProceso = @IdAdministrador,

        @IdResultadoEvento = @IdResultadoEvento,

        @IdSeleccion = @IdSeleccionB,

        @Resultado = 'PERDIDA',

        @Observacion = 'Equipo B perdedor.',

        @IpOrigen = 'PRUEBA_CONCURRENCIA';


    EXEC dbo.sp_OficializarResultadoEvento

        @IdUsuarioProceso = @IdAdministrador,

        @IdResultadoEvento = @IdResultadoEvento,

        @Observacion =
            'Resultado oficial para concurrencia.',

        @IpOrigen = 'PRUEBA_CONCURRENCIA';


    /* ========================================================
       5. GUARDAR VALORES PRE-LIQUIDACION
       ======================================================== */

    DECLARE @SaldoUsuarioAntes DECIMAL(12,2);
    DECLARE @ComprometidoAntes DECIMAL(12,2);
    DECLARE @SaldoCasaAntes DECIMAL(12,2);


    SELECT
        @SaldoUsuarioAntes = SaldoDisponible,
        @ComprometidoAntes = SaldoComprometido

    FROM dbo.Billetera
    WHERE IdBilletera = @IdBilletera;


    SELECT @SaldoCasaAntes = SaldoDisponible
    FROM dbo.Billetera
    WHERE IdBilletera = @IdBilleteraCasa;


    UPDATE dbo.PruebaConcurrenciaContexto
    SET
        IdBoletoGanador = @IdBoleto,

        SaldoUsuarioAntesLiquidacion =
            @SaldoUsuarioAntes,

        ComprometidoAntesLiquidacion =
            @ComprometidoAntes,

        SaldoCasaAntesLiquidacion =
            @SaldoCasaAntes,

        MontoLiquidadoEsperado = 800.00,

        GananciaNetaEsperada = 400.00,

        EstadoPrueba = 'LISTO_LIQUIDACION'

    WHERE IdContexto = 1;


    COMMIT TRANSACTION;


    PRINT '';
    PRINT 'Boleto preparado para liquidación: '
        + CONVERT(VARCHAR(20), @IdBoleto);

    PRINT '';
    PRINT 'SIGUIENTE:';
    PRINT 'Ejecutar 05_SesionA_Liquidacion.sql';
    PRINT 'y 06_SesionB_Liquidacion.sql simultáneamente.';


END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT ERROR_MESSAGE();

    THROW;

END CATCH;
GO