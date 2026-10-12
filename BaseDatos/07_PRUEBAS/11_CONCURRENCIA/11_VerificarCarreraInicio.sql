SET NOCOUNT ON;
DECLARE @Evento INT,@Usuario INT,@Casa INT,@Ref UNIQUEIDENTIFIER,@Saldo DECIMAL(12,2),@Monto DECIMAL(12,2);
SELECT @Evento=IdEvento,@Usuario=IdUsuarioPrueba,@Casa=IdBilleteraCasa,@Ref=ReferenciaA,
 @Saldo=SaldoInicialUsuario,@Monto=MontoApuesta FROM dbo.PruebaConcurrenciaContexto WHERE IdContexto=1;
IF @Evento IS NULL THROW 75405,'Falta contexto.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Evento EV JOIN dbo.Estado E ON E.IdEstado=EV.IdEstado WHERE EV.IdEvento=@Evento AND E.Codigo='EN_VIVO')
 THROW 75406,'El inicio no se completo.',1;
DECLARE @Cantidad INT=(SELECT COUNT(*) FROM dbo.Boleto WHERE ReferenciaOperacion=@Ref),
 @Comision DECIMAL(12,2)=(SELECT ISNULL(SUM(ComisionServicio),0) FROM dbo.Boleto WHERE ReferenciaOperacion=@Ref);
IF @Cantidad>1 THROW 75407,'Boleto duplicado.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Billetera WHERE IdUsuario=@Usuario
 AND SaldoDisponible=@Saldo-(@Monto*@Cantidad)-@Comision AND SaldoComprometido=@Monto*@Cantidad)
 THROW 75408,'Saldo no corresponde al resultado de la carrera.',1;
IF EXISTS(SELECT 1 FROM dbo.Boleto B JOIN dbo.Auditoria A ON A.TablaAfectada='Boleto' AND A.IdRegistro=B.IdBoleto AND A.Accion='APUESTA_REGISTRADA'
 JOIN dbo.Auditoria I ON I.TablaAfectada='Evento' AND I.IdRegistro=@Evento AND I.Accion='SIMULACION_INICIADA'
 WHERE B.ReferenciaOperacion=@Ref AND A.IdAuditoria>I.IdAuditoria)
 THROW 75409,'Se registro una apuesta despues del inicio.',1;
IF (SELECT SaldoComprometido FROM dbo.Billetera WHERE IdBilletera=@Casa)
  <>(SELECT ISNULL(SUM(ReservaCasaPendiente),0) FROM dbo.Boleto WHERE IdBilleteraCasaReserva=@Casa)
 THROW 75410,'Reserva CASA inconsistente.',1;
SELECT @Cantidad AS ApuestasAceptadasAntesDelInicio;
PRINT 'Carrera verificada. El evento queda EN_VIVO para revision; cancelarlo y liquidar despues.';
