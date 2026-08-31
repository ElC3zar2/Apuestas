/* ============================================================
   SESION A - LIQUIDACION CONCURRENTE

   Ejecutar en conexión/PC A.
   Inmediatamente ejecutar también SESION B.
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
    THROW 71401,
          'Primero ejecute 04_VerificarApuesta.sql.',
          1;


PRINT '=======================================================';
PRINT ' SESION A - LIQUIDACION';
PRINT '=======================================================';
PRINT 'Esperando 10 segundos...';
PRINT 'Ejecute ahora la SESION B.';


WAITFOR DELAY '00:00:10';


BEGIN TRY

    EXEC dbo.sp_LiquidarBoleto

        @IdUsuarioProceso = @IdAdministrador,

        @IdBoleto = @IdBoleto,

        @IpOrigen = 'LIQUIDACION_A';


    PRINT '';
    PRINT 'SESION A FINALIZADA.';

END TRY
BEGIN CATCH

    PRINT '';
    PRINT 'SESION A DEVOLVIO ERROR.';

    PRINT 'Error: '
        + CONVERT(VARCHAR(20), ERROR_NUMBER());

    PRINT 'Mensaje: '
        + ERROR_MESSAGE();

END CATCH;
GO