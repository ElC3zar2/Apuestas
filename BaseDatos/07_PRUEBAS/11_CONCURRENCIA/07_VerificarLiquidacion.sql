/* ============================================================
   SESION B - LIQUIDACION CONCURRENTE

   Ejecutar en conexión/PC B.
   ============================================================ */

SET NOCOUNT ON;
GO


DECLARE @IdAdministrador INT;
DECLARE @IdBoleto INT;


SELECT
    @IdAdministrador = IdAdministrador,
    @IdBoleto = IdBoletoGanador

FROM dbo.PruebaConcurrenciaContexto
WHERE IdContexto = 1
  AND EstadoPrueba = 'LISTO_LIQUIDACION';


IF @IdBoleto IS NULL
    THROW 71501,
          'Primero ejecute 04_VerificarApuesta.sql.',
          1;


PRINT '=======================================================';
PRINT ' SESION B - LIQUIDACION';
PRINT '=======================================================';
PRINT 'Esperando 10 segundos...';


WAITFOR DELAY '00:00:10';


BEGIN TRY

    EXEC dbo.sp_LiquidarBoleto

        @IdUsuarioProceso = @IdAdministrador,

        @IdBoleto = @IdBoleto,

        @IpOrigen = 'LIQUIDACION_B';


    PRINT '';
    PRINT 'SESION B FINALIZADA.';

END TRY
BEGIN CATCH

    PRINT '';
    PRINT 'SESION B DEVOLVIO ERROR.';

    PRINT 'Error: '
        + CONVERT(VARCHAR(20), ERROR_NUMBER());

    PRINT 'Mensaje: '
        + ERROR_MESSAGE();

END CATCH;
GO