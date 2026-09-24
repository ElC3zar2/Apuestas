/* ============================================================================
   PLATAFORMA APUESTAS - LIMPIEZA EXCLUSIVA DE DATOS DEMO
   Archivo: 03_LimpiarDatosDemo.sql

   ADVERTENCIA
   -----------
   Elimina UNICAMENTE registros identificados por:
   - correos cliente.%@apuestas.test
   - nombres con prefijo "DEMO IA - "

   NO elimina ni modifica:
   Rol, Pais, Departamento, Municipio, TipoEstado, Estado,
   Deporte, TipoTransaccion ni ConfiguracionSistema.

   Ejecutar solo si desea retirar los datos ficticios de revision.
   ============================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @UsuariosDemo TABLE (IdUsuario INT PRIMARY KEY);
    DECLARE @BilleterasDemo TABLE (IdBilletera INT PRIMARY KEY);
    DECLARE @BoletosDemo TABLE (IdBoleto INT PRIMARY KEY);
    DECLARE @TransaccionesDemo TABLE (IdTransaccion BIGINT PRIMARY KEY);
    DECLARE @EventosDemo TABLE (IdEvento INT PRIMARY KEY);
    DECLARE @MercadosDemo TABLE (IdMercado INT PRIMARY KEY);
    DECLARE @SeleccionesDemo TABLE (IdSeleccion INT PRIMARY KEY);
    DECLARE @ResultadosDemo TABLE (IdResultado INT PRIMARY KEY);
    DECLARE @ParticipantesDemo TABLE (IdParticipante INT PRIMARY KEY);
    DECLARE @LigasDemo TABLE (IdLiga INT PRIMARY KEY);

    INSERT INTO @UsuariosDemo
    SELECT IdUsuario
    FROM dbo.Usuario
    WHERE Correo LIKE 'cliente.%@apuestas.test';

    INSERT INTO @BilleterasDemo
    SELECT B.IdBilletera
    FROM dbo.Billetera AS B
    INNER JOIN @UsuariosDemo AS U
        ON U.IdUsuario = B.IdUsuario;

    INSERT INTO @BoletosDemo
    SELECT B.IdBoleto
    FROM dbo.Boleto AS B
    INNER JOIN @UsuariosDemo AS U
        ON U.IdUsuario = B.IdUsuario;

    INSERT INTO @EventosDemo
    SELECT IdEvento
    FROM dbo.Evento
    WHERE Nombre LIKE 'DEMO IA - %';

    INSERT INTO @MercadosDemo
    SELECT M.IdMercado
    FROM dbo.Mercado AS M
    INNER JOIN @EventosDemo AS E
        ON E.IdEvento = M.IdEvento;

    INSERT INTO @SeleccionesDemo
    SELECT S.IdSeleccion
    FROM dbo.Seleccion AS S
    INNER JOIN @MercadosDemo AS M
        ON M.IdMercado = S.IdMercado;

    INSERT INTO @ResultadosDemo
    SELECT R.IdResultado
    FROM dbo.ResultadoEvento AS R
    INNER JOIN @EventosDemo AS E
        ON E.IdEvento = R.IdEvento;

    INSERT INTO @ParticipantesDemo
    SELECT IdParticipante
    FROM dbo.Participante
    WHERE Nombre LIKE 'DEMO IA - %';

    INSERT INTO @LigasDemo
    SELECT IdLiga
    FROM dbo.Liga
    WHERE Nombre LIKE 'DEMO IA - %';

    /* Transacciones relacionadas con billeteras demo o boletos demo.
       Incluye contrapartes de CASA ligadas a boletos demo. */
    INSERT INTO @TransaccionesDemo
    SELECT DISTINCT TF.IdTransaccion
    FROM dbo.TransaccionFinanciera AS TF
    WHERE TF.IdBilletera IN (SELECT IdBilletera FROM @BilleterasDemo)
       OR TF.IdBoleto IN (SELECT IdBoleto FROM @BoletosDemo);

    /* Revertir el efecto neto que las transacciones demo hayan dejado
       en billeteras que NO se eliminaran, por ejemplo la cuenta CASA. */
    ;WITH NetoExterno AS
    (
        SELECT
            MB.IdBilletera,
            SUM(MB.SaldoDisponiblePosterior - MB.SaldoDisponibleAnterior) AS NetoDisponible,
            SUM(MB.SaldoComprometidoPosterior - MB.SaldoComprometidoAnterior) AS NetoComprometido
        FROM dbo.MovimientoBilletera AS MB
        INNER JOIN @TransaccionesDemo AS TD
            ON TD.IdTransaccion = MB.IdTransaccion
        WHERE MB.IdBilletera NOT IN (SELECT IdBilletera FROM @BilleterasDemo)
        GROUP BY MB.IdBilletera
    )
    UPDATE B
    SET
        B.SaldoDisponible = B.SaldoDisponible - N.NetoDisponible,
        B.SaldoComprometido = B.SaldoComprometido - N.NetoComprometido
    FROM dbo.Billetera AS B
    INNER JOIN NetoExterno AS N
        ON N.IdBilletera = B.IdBilletera;

    /* Auditoria que depende de los usuarios demo. */
    DELETE A
    FROM dbo.Auditoria AS A
    WHERE A.IdUsuario IN (SELECT IdUsuario FROM @UsuariosDemo);

    /* Auditoria administrativa de objetos demo. */
    DELETE A
    FROM dbo.Auditoria AS A
    WHERE
        (A.TablaAfectada = 'Evento' AND A.IdRegistro IN (SELECT IdEvento FROM @EventosDemo))
        OR
        (A.TablaAfectada = 'Mercado' AND A.IdRegistro IN (SELECT IdMercado FROM @MercadosDemo))
        OR
        (A.TablaAfectada = 'Participante' AND A.IdRegistro IN (SELECT IdParticipante FROM @ParticipantesDemo))
        OR
        (A.TablaAfectada = 'Liga' AND A.IdRegistro IN (SELECT IdLiga FROM @LigasDemo))
        OR
        (A.TablaAfectada = 'Boleto' AND A.IdRegistro IN (SELECT IdBoleto FROM @BoletosDemo));

    /* Liquidaciones primero, si en el futuro algun boleto demo fuera liquidado. */
    DELETE FROM dbo.LiquidacionBoleto
    WHERE IdBoleto IN (SELECT IdBoleto FROM @BoletosDemo);

    DELETE MB
    FROM dbo.MovimientoBilletera AS MB
    INNER JOIN @TransaccionesDemo AS T
        ON T.IdTransaccion = MB.IdTransaccion;

    DELETE TF
    FROM dbo.TransaccionFinanciera AS TF
    INNER JOIN @TransaccionesDemo AS T
        ON T.IdTransaccion = TF.IdTransaccion;

    DELETE FROM dbo.DetalleBoleto
    WHERE IdBoleto IN (SELECT IdBoleto FROM @BoletosDemo);

    DELETE FROM dbo.Boleto
    WHERE IdBoleto IN (SELECT IdBoleto FROM @BoletosDemo);

    DELETE RS
    FROM dbo.ResolucionSeleccion AS RS
    WHERE RS.IdSeleccion IN (SELECT IdSeleccion FROM @SeleccionesDemo)
       OR RS.IdResultadoEvento IN (SELECT IdResultado FROM @ResultadosDemo);

    DELETE FROM dbo.ResultadoEvento
    WHERE IdResultado IN (SELECT IdResultado FROM @ResultadosDemo);

    DELETE FROM dbo.Cuota
    WHERE IdSeleccion IN (SELECT IdSeleccion FROM @SeleccionesDemo);

    DELETE FROM dbo.Seleccion
    WHERE IdSeleccion IN (SELECT IdSeleccion FROM @SeleccionesDemo);

    DELETE FROM dbo.Mercado
    WHERE IdMercado IN (SELECT IdMercado FROM @MercadosDemo);

    DELETE FROM dbo.EventoParticipante
    WHERE IdEvento IN (SELECT IdEvento FROM @EventosDemo);

    DELETE FROM dbo.Evento
    WHERE IdEvento IN (SELECT IdEvento FROM @EventosDemo);

    DELETE FROM dbo.Participante
    WHERE IdParticipante IN (SELECT IdParticipante FROM @ParticipantesDemo);

    DELETE FROM dbo.Liga
    WHERE IdLiga IN (SELECT IdLiga FROM @LigasDemo);

    DELETE FROM dbo.TokenSeguridad
    WHERE IdUsuario IN (SELECT IdUsuario FROM @UsuariosDemo);

    DELETE FROM dbo.RestriccionUsuario
    WHERE IdUsuario IN (SELECT IdUsuario FROM @UsuariosDemo)
       OR IdUsuarioRegistro IN (SELECT IdUsuario FROM @UsuariosDemo);

    DELETE FROM dbo.VerificacionUsuario
    WHERE IdUsuario IN (SELECT IdUsuario FROM @UsuariosDemo);

    DELETE FROM dbo.PerfilUsuario
    WHERE IdUsuario IN (SELECT IdUsuario FROM @UsuariosDemo);

    /* Las transacciones ya fueron retiradas, ahora se pueden borrar billeteras. */
    DELETE FROM dbo.Billetera
    WHERE IdBilletera IN (SELECT IdBilletera FROM @BilleterasDemo);

    /* Eliminar cualquier auditoria remanente de esos usuarios antes de Usuario. */
    DELETE FROM dbo.Auditoria
    WHERE IdUsuario IN (SELECT IdUsuario FROM @UsuariosDemo);

    DELETE FROM dbo.Usuario
    WHERE IdUsuario IN (SELECT IdUsuario FROM @UsuariosDemo);

    COMMIT TRANSACTION;

    PRINT '=======================================================';
    PRINT ' DATOS DEMO ELIMINADOS CORRECTAMENTE';
    PRINT ' Catalogos criticos: NO MODIFICADOS';
    PRINT '=======================================================';

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    PRINT 'ERROR DURANTE LA LIMPIEZA DE DATOS DEMO:';
    PRINT ERROR_MESSAGE();
    THROW;
END CATCH;
