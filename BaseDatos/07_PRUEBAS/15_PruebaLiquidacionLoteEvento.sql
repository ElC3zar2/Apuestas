/* Ejecutar COMPLETO en SSMS sobre una instalacion LOCAL DESCARTABLE, sin
   transaccion ambiental y sin otras sesiones escribiendo. No usa Azure.
   Crea datos propios con sufijo aleatorio; no modifica semillas ni catalogos.
   Los commits por boleto son intencionales: descartar la BD tras la prueba.
   Los procedimientos # auxiliares desaparecen al cerrar esta conexion.
   Emite los DOS ResultSet con WITH RESULT SETS (valida esquema), precedidos
   del resumen esperado para comparacion visual. INSERT EXEC no se usa porque
   puede introducir una transaccion ambiental y destruir la prueba de commits
   por boleto. Las aserciones automaticas contrastan el estado persistido. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 THROW 71506,'Ejecutar sin transaccion ambiental.',1;
-- Permite repetir el archivo en la MISMA conexion despues de una ejecucion o fallo.
IF OBJECT_ID('tempdb..#CrearEventoLote','P') IS NOT NULL DROP PROCEDURE #CrearEventoLote;
IF OBJECT_ID('tempdb..#OficializarLote','P') IS NOT NULL DROP PROCEDURE #OficializarLote;
IF OBJECT_ID('tempdb..#ComprobarLote','P') IS NOT NULL DROP PROCEDURE #ComprobarLote;
DROP TABLE IF EXISTS #SaldoAntesReplay,#LiquidacionAntesReplay,#TransaccionAntesReplay,#MovimientoAntesReplay;
GO
CREATE PROCEDURE #CrearEventoLote
    @Admin INT,@Liga INT,@A INT,@B INT,@Nombre VARCHAR(200),
    @Evento INT OUTPUT,@G INT OUTPUT,@P INT OUTPUT,@N INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME2=DATEADD(DAY,1,SYSDATETIME()),@Fin DATETIME2,
        @Mercado INT;
    SET @Fin=DATEADD(HOUR,2,@Inicio);
    EXEC dbo.sp_CrearEvento @Admin,@Liga,@Nombre,@Inicio,@Fin,'127.0.0.1';
    SELECT @Evento=IdEvento FROM dbo.Evento WHERE IdLiga=@Liga AND Nombre=@Nombre;
    EXEC dbo.sp_AgregarParticipanteEvento @Admin,@Evento,@A,1,1,'127.0.0.1';
    EXEC dbo.sp_AgregarParticipanteEvento @Admin,@Evento,@B,2,0,'127.0.0.1';
    EXEC dbo.sp_CrearMercado @Admin,@Evento,'Lote convencional','Prueba local','127.0.0.1';
    SELECT @Mercado=IdMercado FROM dbo.Mercado WHERE IdEvento=@Evento;
    EXEC dbo.sp_CrearSeleccion @Admin,@Mercado,'G','127.0.0.1';
    EXEC dbo.sp_CrearSeleccion @Admin,@Mercado,'P','127.0.0.1';
    EXEC dbo.sp_CrearSeleccion @Admin,@Mercado,'N','127.0.0.1';
    SELECT @G=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@Mercado AND Nombre='G';
    SELECT @P=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@Mercado AND Nombre='P';
    SELECT @N=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@Mercado AND Nombre='N';
    EXEC dbo.sp_RegistrarCuota @Admin,@G,2.0000,'127.0.0.1';
    EXEC dbo.sp_RegistrarCuota @Admin,@P,2.0000,'127.0.0.1';
    EXEC dbo.sp_RegistrarCuota @Admin,@N,2.0000,'127.0.0.1';
    EXEC dbo.sp_CambiarEstadoEvento @Admin,@Evento,'PROGRAMADO','Prueba lote','127.0.0.1';
    EXEC dbo.sp_CambiarEstadoMercado @Admin,@Mercado,'ABIERTO','Prueba lote','127.0.0.1';
END;
GO
CREATE PROCEDURE #OficializarLote @Admin INT,@Evento INT,@G INT,@P INT,@N INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Mercado INT,@Resultado INT;
    SELECT @Mercado=IdMercado FROM dbo.Seleccion WHERE IdSeleccion=@G;
    EXEC dbo.sp_CambiarEstadoEvento @Admin,@Evento,'EN_VIVO','Prueba lote','127.0.0.1';
    EXEC dbo.sp_CambiarEstadoMercado @Admin,@Mercado,'CERRADO','Prueba lote','127.0.0.1';
    EXEC dbo.sp_CambiarEstadoEvento @Admin,@Evento,'PENDIENTE_RESULTADO','Prueba lote','127.0.0.1';
    EXEC dbo.sp_RegistrarResultadoEvento @Admin,@Evento,'Resultado convencional de prueba','Prueba lote','127.0.0.1';
    SELECT @Resultado=IdResultado FROM dbo.ResultadoEvento WHERE IdEvento=@Evento;
    EXEC dbo.sp_ResolverSeleccion @Admin,@Resultado,@G,'GANADA','Prueba lote','127.0.0.1';
    EXEC dbo.sp_ResolverSeleccion @Admin,@Resultado,@P,'PERDIDA','Prueba lote','127.0.0.1';
    EXEC dbo.sp_ResolverSeleccion @Admin,@Resultado,@N,'ANULADA','Prueba lote','127.0.0.1';
    EXEC dbo.sp_OficializarResultadoEvento @Admin,@Resultado,'Prueba lote','127.0.0.1';
END;
GO
CREATE PROCEDURE #ComprobarLote
    @Admin INT,@Evento INT,@Relacionados INT,@Elegibles INT,@Nuevos INT,@Ya INT,@Monto DECIMAL(38,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @RelacionadosReales INT,@Antes INT,@Despues INT,@MontoAntes DECIMAL(38,2),@MontoDespues DECIMAL(38,2);
    SELECT DISTINCT D.IdBoleto INTO #Boletos FROM dbo.DetalleBoleto D
        JOIN dbo.Seleccion S ON S.IdSeleccion=D.IdSeleccion WHERE S.IdEvento=@Evento;
    SELECT @RelacionadosReales=COUNT(*) FROM #Boletos;
    SELECT @Antes=COUNT(*),@MontoAntes=COALESCE(SUM(L.MontoLiquidado),0)
        FROM dbo.LiquidacionBoleto L JOIN #Boletos B ON B.IdBoleto=L.IdBoleto
        JOIN dbo.Estado E ON E.IdEstado=L.IdEstado WHERE E.Codigo='COMPLETADA';
    SELECT 'ESPERADO: comparar con el resumen inmediatamente siguiente' AS Comprobacion,
        @Evento AS IdEvento,@Relacionados AS BoletosRelacionados,@Elegibles AS BoletosElegibles,
        @Nuevos AS BoletosLiquidadosNuevos,@Ya AS BoletosYaLiquidados,
        @Relacionados-@Elegibles AS BoletosOmitidos,@Monto AS MontoTotalLiquidadoNuevo;
    EXEC dbo.sp_LiquidarBoletosEvento @Admin,@Evento,'127.0.0.1'
        WITH RESULT SETS (
            (IdEvento INT,BoletosRelacionados INT,BoletosElegibles INT,BoletosLiquidadosNuevos INT,
             BoletosYaLiquidados INT,BoletosOmitidos INT,MontoTotalLiquidadoNuevo DECIMAL(38,2)),
            (IdBoleto INT,CodigoBoleto VARCHAR(50),ResultadoBoleto VARCHAR(20),EstadoBoleto VARCHAR(40),
             IdLiquidacion BIGINT,MontoLiquidado DECIMAL(12,2),SolicitudIdempotente BIT));
    SELECT @Despues=COUNT(*),@MontoDespues=COALESCE(SUM(L.MontoLiquidado),0)
        FROM dbo.LiquidacionBoleto L JOIN #Boletos B ON B.IdBoleto=L.IdBoleto
        JOIN dbo.Estado E ON E.IdEstado=L.IdEstado WHERE E.Codigo='COMPLETADA';
    IF @RelacionadosReales<>@Relacionados OR @Antes<>@Ya OR @Despues<>@Elegibles
        OR @Despues-@Antes<>@Nuevos OR @MontoDespues-@MontoAntes<>@Monto
        OR @Relacionados<>@Elegibles+(@Relacionados-@Elegibles) OR @Elegibles<>@Nuevos+@Ya
        THROW 71502,'Estado oficial de lote no coincide con cantidades/importes esperados.',1;

END;
GO
IF @@TRANCOUNT<>0 THROW 71506,'Ejecutar sin transaccion ambiental.',1;
DECLARE @Admin INT,@Pais INT,@Municipio INT,@Deporte INT,@Liga INT,@A INT,@B INT,
    @Codigo VARCHAR(12)=LEFT(REPLACE(CONVERT(VARCHAR(36),NEWID()),'-',''),12),
    @Nombre VARCHAR(200),@Correo VARCHAR(150),@Documento VARCHAR(50),@Usuario INT;
SELECT TOP(1) @Admin=U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
    JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO';
IF @Admin IS NULL THROW 71507,'Requiere administrador activo de instalacion.',1;
SELECT @Pais=IdPais FROM dbo.Pais WHERE CodigoISO2='GT' AND Activo=1;
SELECT TOP(1) @Municipio=M.IdMunicipio FROM dbo.Municipio M JOIN dbo.Departamento D
    ON D.IdDepartamento=M.IdDepartamento WHERE D.IdPais=@Pais AND D.Activo=1 AND M.Activo=1;
SELECT @Deporte=IdDeporte FROM dbo.Deporte WHERE Nombre='Futbol' AND Activo=1;
SET @Correo=CONCAT('lote.',@Codigo,'@apuestas.test');SET @Documento=CONCAT('LT-',@Codigo);
EXEC dbo.sp_RegistrarUsuarioCliente 'Prueba','Lote',@Correo,
    '$2a$12$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ123456','2000-01-01','M','55550299',
    'DPI',@Documento,@Pais,@Municipio,NULL,'Prueba local';
SELECT @Usuario=IdUsuario FROM dbo.Usuario WHERE Correo=@Correo;
DECLARE @Aprobada INT=(SELECT E.IdEstado FROM dbo.Estado E JOIN dbo.TipoEstado T
    ON T.IdTipoEstado=E.IdTipoEstado WHERE T.Codigo='VERIFICACION' AND E.Codigo='APROBADA');
-- Solo habilitar el usuario creado aqui, igual que la prueba 06.
UPDATE dbo.Usuario SET CorreoVerificado=1 WHERE IdUsuario=@Usuario;
UPDATE dbo.VerificacionUsuario SET IdEstado=@Aprobada,IdUsuarioRevisor=@Admin,
    FechaInicioRevision=SYSDATETIME(),FechaResolucion=SYSDATETIME() WHERE IdUsuario=@Usuario;
EXEC dbo.sp_SincronizarHabilitacionUsuario @Usuario;
SET @Nombre=CONCAT('Liga lote ',@Codigo);
EXEC dbo.sp_CrearLiga @Admin,@Deporte,@Nombre,@Pais,'127.0.0.1';
SELECT @Liga=IdLiga FROM dbo.Liga WHERE Nombre=@Nombre AND IdDeporte=@Deporte;
SET @Nombre=CONCAT('Lote A ',@Codigo);
EXEC dbo.sp_CrearParticipante @Admin,@Deporte,@Nombre,'EQUIPO',@Pais,'127.0.0.1';
SELECT @A=IdParticipante FROM dbo.Participante WHERE Nombre=@Nombre AND IdDeporte=@Deporte;
SET @Nombre=CONCAT('Lote B ',@Codigo);
EXEC dbo.sp_CrearParticipante @Admin,@Deporte,@Nombre,'EQUIPO',@Pais,'127.0.0.1';
SELECT @B=IdParticipante FROM dbo.Participante WHERE Nombre=@Nombre AND IdDeporte=@Deporte;
DECLARE @E1 INT,@G1 INT,@P1 INT,@N1 INT,@E2 INT,@G2 INT,@P2 INT,@N2 INT,
    @EP INT,@GP INT,@PP INT,@NP INT,@EV INT,@GV INT,@PV INT,@NV INT,
    @ES INT,@GS INT,@PS INT,@NS INT,@EO INT,@GO INT,@PO INT,@NO INT,
    @EA INT,@GA INT,@PA INT,@NA INT;
SET @Nombre=CONCAT('Principal ',@Codigo);
EXEC #CrearEventoLote @Admin,@Liga,@A,@B,@Nombre,@E1 OUTPUT,@G1 OUTPUT,@P1 OUTPUT,@N1 OUTPUT;
SET @Nombre=CONCAT('Compuesto resuelto ',@Codigo);
EXEC #CrearEventoLote @Admin,@Liga,@A,@B,@Nombre,@E2 OUTPUT,@G2 OUTPUT,@P2 OUTPUT,@N2 OUTPUT;
SET @Nombre=CONCAT('Compuesto pendiente ',@Codigo);
EXEC #CrearEventoLote @Admin,@Liga,@A,@B,@Nombre,@EP OUTPUT,@GP OUTPUT,@PP OUTPUT,@NP OUTPUT;
SET @Nombre=CONCAT('Vacio ',@Codigo);
EXEC #CrearEventoLote @Admin,@Liga,@A,@B,@Nombre,@EV OUTPUT,@GV OUTPUT,@PV OUTPUT,@NV OUTPUT;
SET @Nombre=CONCAT('Simple unico ',@Codigo);
EXEC #CrearEventoLote @Admin,@Liga,@A,@B,@Nombre,@ES OUTPUT,@GS OUTPUT,@PS OUTPUT,@NS OUTPUT;
SET @Nombre=CONCAT('Solo compuesto pendiente ',@Codigo);
EXEC #CrearEventoLote @Admin,@Liga,@A,@B,@Nombre,@EO OUTPUT,@GO OUTPUT,@PO OUTPUT,@NO OUTPUT;
SET @Nombre=CONCAT('Cancelado ',@Codigo);
EXEC #CrearEventoLote @Admin,@Liga,@A,@B,@Nombre,@EA OUTPUT,@GA OUTPUT,@PA OUTPUT,@NA OUTPUT;
-- Errores: parametro, evento inexistente y evento no apto. No ocultar errores imprevistos.
BEGIN TRY
    EXEC dbo.sp_LiquidarBoletosEvento @Admin,0;
    THROW 71508,'Se acepto idEvento invalido.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>62040 THROW; END CATCH;
DECLARE @Inexistente INT=2147483647;
IF EXISTS(SELECT 1 FROM dbo.Evento WHERE IdEvento=@Inexistente) THROW 71509,'Elegir otro ID inexistente.',1;
BEGIN TRY
    EXEC dbo.sp_LiquidarBoletosEvento @Admin,@Inexistente;
    THROW 71510,'Se acepto evento inexistente.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>62041 THROW; END CATCH;
BEGIN TRY
    EXEC dbo.sp_LiquidarBoletosEvento @Admin,@E1;
    THROW 71511,'Se acepto evento pendiente.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>62042 THROW; END CATCH;
BEGIN TRY
    EXEC dbo.sp_LiquidarBoletosEvento @Usuario,@E1;
    THROW 71512,'Se acepto usuario cliente.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>62003 THROW; END CATCH;
-- Un administrador suspendido PROPIO; no se altera el administrador semilla.
DECLARE @EstadoUsuarioOriginal INT=(SELECT IdEstado FROM dbo.Usuario WHERE IdUsuario=@Usuario);
DECLARE @RolAdmin INT=(SELECT IdRol FROM dbo.Rol WHERE Nombre='ADMINISTRADOR'),@Suspendido INT;
SELECT @Suspendido=E.IdEstado FROM dbo.Estado E JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado
    WHERE T.Codigo='USUARIO' AND E.Codigo='SUSPENDIDO';
UPDATE dbo.Usuario SET IdRol=@RolAdmin,IdEstado=@Suspendido WHERE IdUsuario=@Usuario;
BEGIN TRY
    EXEC dbo.sp_LiquidarBoletosEvento @Usuario,@E1;
    THROW 71513,'Se acepto administrador suspendido.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>62004 THROW; END CATCH;
UPDATE dbo.Usuario SET IdRol=(SELECT IdRol FROM dbo.Rol WHERE Nombre='USUARIO'),IdEstado=@EstadoUsuarioOriginal WHERE IdUsuario=@Usuario;
EXEC dbo.sp_SincronizarHabilitacionUsuario @Usuario;
DECLARE @Monto DECIMAL(12,2)=(SELECT TRY_CONVERT(DECIMAL(12,2),Valor)
    FROM dbo.ConfiguracionSistema WHERE Clave='MONTO_MINIMO_APUESTA');
DECLARE @PorcentajePrueba DECIMAL(7,4)=(SELECT TRY_CONVERT(DECIMAL(7,4),Valor)
    FROM dbo.ConfiguracionSistema WHERE Clave='COMISION_SERVICIO_PORCENTAJE');
IF @Monto IS NULL OR @Monto<=0 OR @PorcentajePrueba IS NULL OR @PorcentajePrueba<0
    THROW 71514,'Configuracion financiera de prueba invalida.',1;
-- Presupuesto de preparacion; los cargos efectivos los calcula sp_RealizarApuesta.
DECLARE @ComisionPresupuesto DECIMAL(38,2)=ROUND(
    CONVERT(DECIMAL(38,4),@Monto)*CONVERT(DECIMAL(38,4),@PorcentajePrueba)/100,2),
    @SaldoAntesFondo DECIMAL(12,2),@FondoNecesario DECIMAL(38,2),@FondoPrueba DECIMAL(12,2),
    @RefSaldoPrueba UNIQUEIDENTIFIER=NEWID();
IF @Usuario IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.Usuario WHERE IdUsuario=@Usuario AND Correo=@Correo)
    THROW 71525,'El fondo solo puede aplicarse al usuario propio de esta ejecucion.',1;
SELECT @SaldoAntesFondo=SaldoDisponible FROM dbo.Billetera WHERE IdUsuario=@Usuario;
SET @FondoNecesario=9*(@Monto+@ComisionPresupuesto)-@SaldoAntesFondo;
IF @FondoNecesario<2000 SET @FondoNecesario=2000;
IF @SaldoAntesFondo IS NULL OR @FondoNecesario+@SaldoAntesFondo>9999999999.99
    THROW 71526,'Presupuesto de prueba fuera del rango de billetera.',1;
SET @FondoPrueba=CONVERT(DECIMAL(12,2),@FondoNecesario);
EXEC dbo.sp_AjustarSaldoVirtual @Usuario,@Admin,'CREDITO',@FondoPrueba,
    'Fondo para prueba de liquidacion por evento',@RefSaldoPrueba,'127.0.0.1';
IF NOT EXISTS(SELECT 1 FROM dbo.Billetera WHERE IdUsuario=@Usuario
    AND SaldoDisponible=@SaldoAntesFondo+@FondoPrueba
    AND SaldoDisponible>=9*(@Monto+@ComisionPresupuesto))
    THROW 71527,'El ajuste no financio las nueve apuestas y sus comisiones.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.TransaccionFinanciera T
    JOIN dbo.MovimientoBilletera M ON M.IdTransaccion=T.IdTransaccion AND M.IdBilletera=T.IdBilletera
    JOIN dbo.Auditoria A ON A.ReferenciaOperacion=T.ReferenciaOperacion
    WHERE T.ReferenciaOperacion=@RefSaldoPrueba AND T.Monto=@FondoPrueba
      AND A.Accion='AJUSTE_SALDO_CREDITO' AND A.IdUsuario=@Admin)
    THROW 71528,'Falta trazabilidad financiera del fondo de prueba.',1;
DECLARE @Casos TABLE(N INT PRIMARY KEY,Json NVARCHAR(MAX),Resultado VARCHAR(20),Factor INT,IdBoleto INT);
INSERT INTO @Casos VALUES
    (1,CONCAT('[',@G1,']'),'GANADOR',2,NULL),(2,CONCAT('[',@P1,']'),'PERDEDOR',0,NULL),
    (3,CONCAT('[',@N1,']'),'ANULADO',1,NULL),(4,CONCAT('[',@G1,',',@G2,']'),'GANADOR',4,NULL),
    (5,CONCAT('[',@G1,',',@GP,']'),'PENDIENTE',0,NULL),
    (6,CONCAT('[',@G1,']'),'GANADOR',2,NULL),(7,CONCAT('[',@GS,']'),'GANADOR',2,NULL),
    (8,CONCAT('[',@GO,',',@GP,']'),'GANADOR',4,NULL),(9,CONCAT('[',@GA,']'),'ANULADO',1,NULL);
DECLARE @I INT=1,@Json NVARCHAR(MAX),@Ref UNIQUEIDENTIFIER,@Boleto INT;
WHILE @I<=9
BEGIN
    SELECT @Json=Json FROM @Casos WHERE N=@I;SET @Ref=NEWID();
    EXEC dbo.sp_RealizarApuesta @Usuario,@Json,@Monto,@Ref,'127.0.0.1';
    SELECT @Boleto=IdBoleto FROM dbo.Boleto WHERE ReferenciaOperacion=@Ref;
    IF @Boleto IS NULL THROW 71515,'No se encontro boleto creado.',1;
    UPDATE @Casos SET IdBoleto=@Boleto WHERE N=@I;SET @I+=1;
END;
-- Todas las operaciones financieras de preparacion nacen completadas.
IF EXISTS(SELECT 1 FROM dbo.TransaccionFinanciera T
    WHERE (T.ReferenciaOperacion=@RefSaldoPrueba OR T.IdBoleto IN (SELECT IdBoleto FROM @Casos))
      AND (T.FechaProcesamiento IS NULL OR T.FechaSolicitud<>T.FechaProcesamiento))
    THROW 71529,'Fechas de operaciones completadas no comparten el mismo instante.',1;
EXEC #OficializarLote @Admin,@E1,@G1,@P1,@N1;
EXEC #OficializarLote @Admin,@E2,@G2,@P2,@N2;
EXEC #OficializarLote @Admin,@EV,@GV,@PV,@NV;
EXEC #OficializarLote @Admin,@ES,@GS,@PS,@NS;
EXEC #OficializarLote @Admin,@EO,@GO,@PO,@NO;
EXEC dbo.sp_AnularResultadoEvento @IdUsuarioProceso=@Admin,@IdResultadoEvento=NULL,
    @Motivo='Prueba de evento cancelado',@IpOrigen='127.0.0.1',@IdEventoCancelar=@EA;
EXEC #ComprobarLote @Admin,@EV,0,0,0,0,0;
EXEC #ComprobarLote @Admin,@EO,1,0,0,0,0; -- oficial con relacionado pero ninguno listo
IF EXISTS(SELECT 1 FROM dbo.LiquidacionBoleto L JOIN @Casos C ON C.IdBoleto=L.IdBoleto WHERE C.N=8)
    THROW 71524,'Compuesto pendiente fue liquidado parcialmente.',1;
-- Solo se relaciona el compuesto incompleto con EP; aun no hay resultado oficial.
-- La omision se verifica solicitando E1, que SI esta oficial.
SELECT @Boleto=IdBoleto FROM @Casos WHERE N=6;
EXEC dbo.sp_LiquidarBoleto @Admin,@Boleto,'127.0.0.1'; -- contrato individual predeterminado
DECLARE @SaldoU DECIMAL(12,2),@CompU DECIMAL(12,2),@SaldoC DECIMAL(12,2),@CompC DECIMAL(12,2),@Casa INT;
SELECT @Casa=B.IdBilletera FROM dbo.Billetera B JOIN dbo.Usuario U ON U.IdUsuario=B.IdUsuario
    JOIN dbo.Rol R ON R.IdRol=U.IdRol WHERE R.Nombre='CASA';
SELECT @SaldoU=SaldoDisponible,@CompU=SaldoComprometido FROM dbo.Billetera WHERE IdUsuario=@Usuario;
SELECT @SaldoC=SaldoDisponible,@CompC=SaldoComprometido FROM dbo.Billetera WHERE IdBilletera=@Casa;
DECLARE @Reserva DECIMAL(12,2)=(SELECT SUM(B.ReservaCasaPendiente) FROM dbo.Boleto B
    JOIN @Casos C ON C.IdBoleto=B.IdBoleto WHERE C.N BETWEEN 1 AND 4),
    @Comision DECIMAL(12,2)=(SELECT B.ComisionServicio FROM dbo.Boleto B JOIN @Casos C
        ON C.IdBoleto=B.IdBoleto WHERE C.N=3),@Esperado DECIMAL(38,2)=7*@Monto;
EXEC #ComprobarLote @Admin,@E1,6,5,4,1,@Esperado;
IF EXISTS(SELECT 1 FROM @Casos C JOIN dbo.Boleto B ON B.IdBoleto=C.IdBoleto
    LEFT JOIN dbo.LiquidacionBoleto L ON L.IdBoleto=B.IdBoleto
    WHERE C.N<=6 AND (B.Resultado<>C.Resultado OR (C.N<>5 AND
        (L.IdLiquidacion IS NULL OR L.MontoLiquidado<>C.Factor*@Monto OR B.ReservaCasaPendiente<>0))
        OR (C.N=5 AND (L.IdLiquidacion IS NOT NULL OR B.ReservaCasaPendiente<>B.ReservaCasaInicial))))
    THROW 71516,'Resultado, reserva o compuesto omitido incorrecto.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Billetera WHERE IdUsuario=@Usuario
    AND SaldoDisponible=@SaldoU+@Esperado+@Comision AND SaldoComprometido=@CompU-4*@Monto)
    THROW 71517,'Saldos del usuario incorrectos.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Billetera WHERE IdBilletera=@Casa
    AND SaldoDisponible=@SaldoC+@Reserva-3*@Monto-@Comision AND SaldoComprometido=@CompC-@Reserva)
    THROW 71518,'Saldos y reserva CASA incorrectos.',1;
IF (SELECT COUNT(*) FROM dbo.Auditoria A JOIN dbo.LiquidacionBoleto L ON L.IdLiquidacion=A.IdRegistro
    JOIN @Casos C ON C.IdBoleto=L.IdBoleto WHERE A.TablaAfectada='LiquidacionBoleto'
    AND A.Accion='BOLETO_LIQUIDADO' AND C.N<=6)<>5
    THROW 71519,'Auditoria de liquidacion incorrecta.',1;
-- Reconcilia TODOS los movimientos de esta solicitud con sus transacciones.
IF EXISTS(SELECT 1 FROM dbo.TransaccionFinanciera T JOIN @Casos C ON C.IdBoleto=T.IdBoleto
    LEFT JOIN dbo.MovimientoBilletera M ON M.IdTransaccion=T.IdTransaccion
    WHERE M.IdMovimiento IS NULL OR M.IdBilletera<>T.IdBilletera)
    THROW 71520,'Transaccion sin movimiento correspondiente.',1;
SELECT B.* INTO #SaldoAntesReplay FROM dbo.Billetera B WHERE B.IdUsuario=@Usuario OR B.IdBilletera=@Casa;
SELECT L.* INTO #LiquidacionAntesReplay FROM dbo.LiquidacionBoleto L JOIN @Casos C ON C.IdBoleto=L.IdBoleto;
SELECT T.* INTO #TransaccionAntesReplay FROM dbo.TransaccionFinanciera T JOIN @Casos C ON C.IdBoleto=T.IdBoleto;
SELECT M.* INTO #MovimientoAntesReplay FROM dbo.MovimientoBilletera M JOIN #TransaccionAntesReplay T ON T.IdTransaccion=M.IdTransaccion;
DECLARE @AuditoriaAntes BIGINT=(SELECT COUNT_BIG(*) FROM dbo.Auditoria);
EXEC #ComprobarLote @Admin,@E1,6,5,0,5,0; -- segunda ejecucion completa
IF EXISTS(SELECT * FROM dbo.Billetera WHERE IdUsuario=@Usuario OR IdBilletera=@Casa EXCEPT SELECT * FROM #SaldoAntesReplay)
    OR EXISTS(SELECT L.* FROM dbo.LiquidacionBoleto L JOIN @Casos C ON C.IdBoleto=L.IdBoleto EXCEPT SELECT * FROM #LiquidacionAntesReplay)
    OR EXISTS(SELECT T.* FROM dbo.TransaccionFinanciera T JOIN @Casos C ON C.IdBoleto=T.IdBoleto EXCEPT SELECT * FROM #TransaccionAntesReplay)
    OR EXISTS(SELECT M.* FROM dbo.MovimientoBilletera M JOIN dbo.TransaccionFinanciera T ON T.IdTransaccion=M.IdTransaccion
        JOIN @Casos C ON C.IdBoleto=T.IdBoleto EXCEPT SELECT * FROM #MovimientoAntesReplay)
    OR (SELECT COUNT_BIG(*) FROM dbo.Auditoria)<>@AuditoriaAntes
    THROW 71521,'Replay modifico billetera, pago, movimiento, liquidacion o auditoria.',1;
SET @Esperado=2*@Monto;
EXEC #ComprobarLote @Admin,@ES,1,1,1,0,@Esperado;
EXEC #ComprobarLote @Admin,@ES,1,1,0,1,0;
-- Terminar el evento pendiente permite continuar el boleto omitido sin parcialidad.
EXEC #OficializarLote @Admin,@EP,@GP,@PP,@NP;
SET @Esperado=4*@Monto;
EXEC #ComprobarLote @Admin,@E1,6,6,1,5,@Esperado;
EXEC #ComprobarLote @Admin,@E1,6,6,0,6,0;
EXEC #ComprobarLote @Admin,@EO,1,1,1,0,@Esperado;
EXEC #ComprobarLote @Admin,@EO,1,1,0,1,0;
SET @Esperado=@Monto;
EXEC #ComprobarLote @Admin,@EA,1,1,1,0,@Esperado; -- resultado ANULADO y devolucion completa
EXEC #ComprobarLote @Admin,@EA,1,1,0,1,0;
IF EXISTS(SELECT IdBoleto FROM dbo.LiquidacionBoleto GROUP BY IdBoleto HAVING COUNT(*)>1)
    THROW 71522,'Liquidacion duplicada.',1;
IF EXISTS(SELECT 1 FROM dbo.Billetera WHERE SaldoDisponible<0 OR SaldoComprometido<0)
    THROW 71523,'Saldo negativo.',1;
PRINT 'Aserciones de datos: compuestos, saldos, reservas, auditoria e idempotencia OK.';
PRINT 'Comparar ademas cada resumen y detalle emitido con el ESPERADO precedente.';
PRINT 'Datos conservados para inspeccion. Descartar la base LOCAL de pruebas al finalizar.';
GO


