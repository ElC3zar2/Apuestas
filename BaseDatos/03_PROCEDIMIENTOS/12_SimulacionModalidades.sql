/* Simulacion manual y modalidades. UTC en todos los nuevos tiempos tecnicos.
   Los 300 segundos son visuales: no hay scheduler ni finalizacion automatica. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.sp_IniciarSimulacionEvento
 @IdUsuarioProceso INT,@IdEvento INT,@IpOrigen VARCHAR(45)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 EXEC dbo.sp_ValidarPermisoEventos @IdUsuarioProceso;
 BEGIN TRY
  BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;

  DECLARE @Estado VARCHAR(40),@Sim BIT,@Inicio DATETIME2;
  SELECT @Estado=E.Codigo,@Sim=EV.EsSimulado,@Inicio=EV.FechaInicioRealUtc
  FROM dbo.Evento EV WITH(UPDLOCK,HOLDLOCK) JOIN dbo.Estado E ON E.IdEstado=EV.IdEstado WHERE EV.IdEvento=@IdEvento;
  IF @Estado='EN_VIVO' AND @Inicio IS NOT NULL
  BEGIN COMMIT; SELECT @IdEvento AS IdEvento,CAST(1 AS BIT) AS SinCambios; RETURN; END;
  IF @Estado IS NULL OR @Estado<>'PROGRAMADO' OR @Sim<>1
    THROW 76201,'Se requiere una simulacion PROGRAMADA.',1;
  IF (SELECT COUNT(*) FROM dbo.EventoParticipante WHERE IdEvento=@IdEvento)<>2
     OR (SELECT COUNT(*) FROM dbo.EventoParticipante WHERE IdEvento=@IdEvento AND OrdenParticipante IN(1,2))<>2
    THROW 76202,'La simulacion requiere exactamente participantes A y B.',1;
  IF EXISTS(SELECT 1 FROM dbo.IncidenciaEvento WHERE IdEvento=@IdEvento)
    THROW 76203,'La simulacion ya posee historial y no puede reiniciarse.',1;
  DECLARE @Vivo INT=(SELECT E.IdEstado FROM dbo.Estado E JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado
                    WHERE T.Codigo='EVENTO' AND E.Codigo='EN_VIVO' AND E.Activo=1),
          @Cerrado INT=(SELECT E.IdEstado FROM dbo.Estado E JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado
                    WHERE T.Codigo='MERCADO' AND E.Codigo='CERRADO' AND E.Activo=1);
  UPDATE dbo.Evento SET IdEstado=@Vivo,FechaInicioRealUtc=SYSUTCDATETIME() WHERE IdEvento=@IdEvento;
  UPDATE dbo.EventoParticipante SET MarcadorActual=0 WHERE IdEvento=@IdEvento;
  UPDATE M SET IdEstado=@Cerrado FROM dbo.Mercado M JOIN dbo.Estado E ON E.IdEstado=M.IdEstado
    WHERE M.IdEvento=@IdEvento AND E.Codigo IN('BORRADOR','ABIERTO','SUSPENDIDO');
  UPDATE C SET Activo=0,FechaFin=CASE WHEN SYSDATETIME()>C.FechaInicio THEN SYSDATETIME() ELSE DATEADD(NANOSECOND,100,C.FechaInicio) END
    FROM dbo.Cuota C JOIN dbo.Seleccion S ON S.IdSeleccion=C.IdSeleccion WHERE S.IdEvento=@IdEvento AND C.Activo=1;
  INSERT dbo.Auditoria(IdUsuario,Accion,TablaAfectada,IdRegistro,IpOrigen,Descripcion)
    VALUES(@IdUsuarioProceso,'SIMULACION_INICIADA','Evento',@IdEvento,@IpOrigen,'Inicio manual; apuestas cerradas.');
  COMMIT;
  SELECT @IdEvento AS IdEvento,CAST(0 AS BIT) AS SinCambios;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarIncidenciaEvento
 @IdUsuarioProceso INT,@IdEvento INT,@TipoIncidencia VARCHAR(25),@ReferenciaOperacion UNIQUEIDENTIFIER,
 @IdParticipante INT=NULL,@ValorAnotacion INT=NULL,@Descripcion VARCHAR(500)=NULL,@IpOrigen VARCHAR(45)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @IdEvento IS NULL OR @IdEvento<=0 THROW 76221,'IdEvento es obligatorio y positivo.',1;
 EXEC dbo.sp_ValidarPermisoEventos @IdUsuarioProceso;
 SET @TipoIncidencia=UPPER(LTRIM(RTRIM(@TipoIncidencia)));
 IF @ReferenciaOperacion IS NULL OR @TipoIncidencia IS NULL
    OR @TipoIncidencia NOT IN('ANOTACION','FALTA','TARJETA_AMARILLA','TARJETA_ROJA','OTRA')
    THROW 76204,'Referencia y tipo de incidencia validos son obligatorios.',1;
 BEGIN TRY
  BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;

  DECLARE @Existente BIGINT;
  SELECT @Existente=IdIncidencia FROM dbo.IncidenciaEvento WITH(UPDLOCK,HOLDLOCK) WHERE ReferenciaOperacion=@ReferenciaOperacion;
  IF @Existente IS NOT NULL
  BEGIN
    IF EXISTS(SELECT 1 FROM dbo.IncidenciaEvento WHERE IdIncidencia=@Existente AND
      (IdEvento<>@IdEvento OR TipoIncidencia<>@TipoIncidencia OR ISNULL(IdParticipante,-1)<>ISNULL(@IdParticipante,-1)
       OR ISNULL(ValorAnotacion,-1)<>ISNULL(@ValorAnotacion,-1) OR ISNULL(Descripcion,'')<>ISNULL(@Descripcion,'')
       OR IdUsuarioRegistro<>@IdUsuarioProceso))
       THROW 76205,'La referencia ya identifica otra incidencia.',1;
    COMMIT; SELECT @Existente AS IdIncidencia,CAST(1 AS BIT) AS SolicitudIdempotente; RETURN;
  END;
  DECLARE @Estado VARCHAR(40),@Inicio DATETIME2,@Unidad VARCHAR(15),@Sim BIT,@Ahora DATETIME2=SYSUTCDATETIME();
  SELECT @Estado=E.Codigo,@Inicio=EV.FechaInicioRealUtc,@Sim=EV.EsSimulado,@Unidad=D.UnidadMarcador
    FROM dbo.Evento EV WITH(UPDLOCK,HOLDLOCK) JOIN dbo.Estado E ON E.IdEstado=EV.IdEstado
    JOIN dbo.Liga L ON L.IdLiga=EV.IdLiga JOIN dbo.Deporte D ON D.IdDeporte=L.IdDeporte WHERE EV.IdEvento=@IdEvento;
  IF @Estado IS NULL OR @Estado<>'EN_VIVO' OR @Inicio IS NULL OR @Sim<>1
    THROW 76206,'Solo se registran incidencias en simulaciones EN_VIVO.',1;
  IF @IdParticipante IS NOT NULL AND NOT EXISTS
      (SELECT 1 FROM dbo.EventoParticipante WHERE IdEvento=@IdEvento AND IdParticipante=@IdParticipante)
    THROW 76207,'El participante no pertenece al evento.',1;
  IF (@TipoIncidencia='ANOTACION' AND (@IdParticipante IS NULL OR @ValorAnotacion IS NULL OR @ValorAnotacion<=0))
     OR (@TipoIncidencia<>'ANOTACION' AND @ValorAnotacion IS NOT NULL)
    THROW 76208,'Anotacion requiere participante y valor positivo; otras incidencias no suman.',1;
  IF @TipoIncidencia='ANOTACION' AND
    ((@Unidad='GOL' AND @ValorAnotacion<>1) OR (@Unidad='PUNTO' AND @ValorAnotacion NOT IN(1,2,3)))
    THROW 76209,'Valor de anotacion incompatible con el deporte.',1;
  IF @TipoIncidencia IN('TARJETA_AMARILLA','TARJETA_ROJA') AND ISNULL(@Unidad,'')<>'GOL'
    THROW 76210,'Las tarjetas solo se habilitan inicialmente para futbol.',1;
  DECLARE @Secuencia INT=(SELECT ISNULL(MAX(Secuencia),0)+1 FROM dbo.IncidenciaEvento WITH(UPDLOCK,HOLDLOCK) WHERE IdEvento=@IdEvento);
  INSERT dbo.IncidenciaEvento(IdEvento,Secuencia,ReferenciaOperacion,TipoIncidencia,IdParticipante,ValorAnotacion,
    SegundoSimulacion,FechaRegistroUtc,Descripcion,IdUsuarioRegistro)
  VALUES(@IdEvento,@Secuencia,@ReferenciaOperacion,@TipoIncidencia,@IdParticipante,@ValorAnotacion,
    CASE WHEN @Ahora<@Inicio THEN 0 ELSE DATEDIFF(SECOND,@Inicio,@Ahora) END,@Ahora,@Descripcion,@IdUsuarioProceso);
  DECLARE @IdIncidencia BIGINT=SCOPE_IDENTITY();
  IF @TipoIncidencia='ANOTACION'
    UPDATE dbo.EventoParticipante SET MarcadorActual=ISNULL(MarcadorActual,0)+@ValorAnotacion
    WHERE IdEvento=@IdEvento AND IdParticipante=@IdParticipante;
  /* UPDATE deliberado: refresca ROWVERSION del agregado Evento. */
  UPDATE dbo.Evento SET EsSimulado=EsSimulado WHERE IdEvento=@IdEvento;
  INSERT dbo.Auditoria(IdUsuario,Accion,TablaAfectada,IdRegistro,ReferenciaOperacion,IpOrigen,Descripcion)
    VALUES(@IdUsuarioProceso,'INCIDENCIA_REGISTRADA','IncidenciaEvento',@IdIncidencia,@ReferenciaOperacion,@IpOrigen,
      CONCAT('Evento=',@IdEvento,'; secuencia=',@Secuencia,'; tipo=',@TipoIncidencia));
  COMMIT; SELECT @IdIncidencia AS IdIncidencia,CAST(0 AS BIT) AS SolicitudIdempotente;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_AnularIncidenciaEvento
 @IdUsuarioProceso INT,@IdIncidencia BIGINT,@Motivo VARCHAR(500),@IpOrigen VARCHAR(45)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 EXEC dbo.sp_ValidarPermisoEventos @IdUsuarioProceso;
 IF NULLIF(LTRIM(RTRIM(@Motivo)),'') IS NULL THROW 76211,'Motivo obligatorio.',1;
 BEGIN TRY
  BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;

  DECLARE @IdEvento INT,@Anulada BIT,@Estado VARCHAR(40);
  SELECT @IdEvento=IdEvento,@Anulada=EsAnulada FROM dbo.IncidenciaEvento WITH(UPDLOCK,HOLDLOCK) WHERE IdIncidencia=@IdIncidencia;
  IF @IdEvento IS NULL THROW 76212,'Incidencia inexistente.',1;
  IF @Anulada=1 BEGIN COMMIT; SELECT @IdIncidencia AS IdIncidencia,CAST(1 AS BIT) AS SinCambios; RETURN; END;
  SELECT @Estado=E.Codigo FROM dbo.Evento EV WITH(UPDLOCK,HOLDLOCK) JOIN dbo.Estado E ON E.IdEstado=EV.IdEstado WHERE EV.IdEvento=@IdEvento;
  IF @Estado NOT IN('EN_VIVO','PENDIENTE_RESULTADO')
    THROW 76213,'No se corrigen incidencias de un evento oficializado o cancelado.',1;
  IF EXISTS(SELECT 1 FROM dbo.DetalleBoleto D JOIN dbo.Seleccion S ON S.IdSeleccion=D.IdSeleccion
     JOIN dbo.LiquidacionBoleto L ON L.IdBoleto=D.IdBoleto WHERE S.IdEvento=@IdEvento)
    THROW 76214,'Existen liquidaciones; no se permite corregir el historial deportivo.',1;
  UPDATE dbo.IncidenciaEvento SET EsAnulada=1,MotivoAnulacion=@Motivo,IdUsuarioAnulacion=@IdUsuarioProceso,FechaAnulacionUtc=SYSUTCDATETIME()
    WHERE IdIncidencia=@IdIncidencia;
  UPDATE EP SET MarcadorActual=CONVERT(INT,ISNULL(A.Total,0))
    FROM dbo.EventoParticipante EP OUTER APPLY
      (SELECT SUM(CONVERT(BIGINT,I.ValorAnotacion)) Total FROM dbo.IncidenciaEvento I
       WHERE I.IdEvento=EP.IdEvento AND I.IdParticipante=EP.IdParticipante AND I.TipoIncidencia='ANOTACION' AND I.EsAnulada=0) A
    WHERE EP.IdEvento=@IdEvento;
  UPDATE dbo.Evento SET EsSimulado=EsSimulado WHERE IdEvento=@IdEvento;
  UPDATE R SET MarcadorFinalA=A.MarcadorActual,MarcadorFinalB=B.MarcadorActual,
    IdIncidenciaPrimeraAnotacion=(SELECT TOP(1) IdIncidencia FROM dbo.IncidenciaEvento
      WHERE IdEvento=@IdEvento AND TipoIncidencia='ANOTACION' AND EsAnulada=0 ORDER BY Secuencia),
    ResultadoTexto=CONCAT(A.MarcadorActual,'-',B.MarcadorActual)
  FROM dbo.ResultadoEvento R JOIN dbo.EventoParticipante A ON A.IdEvento=R.IdEvento AND A.OrdenParticipante=1
    JOIN dbo.EventoParticipante B ON B.IdEvento=R.IdEvento AND B.OrdenParticipante=2 WHERE R.IdEvento=@IdEvento;
  INSERT dbo.Auditoria(IdUsuario,Accion,TablaAfectada,IdRegistro,IpOrigen,Descripcion)
    VALUES(@IdUsuarioProceso,'INCIDENCIA_ANULADA','IncidenciaEvento',@IdIncidencia,@IpOrigen,@Motivo);
  COMMIT; SELECT @IdIncidencia AS IdIncidencia,CAST(0 AS BIT) AS SinCambios;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_FinalizarSimulacionEvento
 @IdUsuarioProceso INT,@IdEvento INT,@IpOrigen VARCHAR(45)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 EXEC dbo.sp_ValidarPermisoEventos @IdUsuarioProceso;
 BEGIN TRY
  BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;

  DECLARE @Estado VARCHAR(40),@Sim BIT;
  SELECT @Estado=E.Codigo,@Sim=EV.EsSimulado FROM dbo.Evento EV WITH(UPDLOCK,HOLDLOCK)
    JOIN dbo.Estado E ON E.IdEstado=EV.IdEstado WHERE EV.IdEvento=@IdEvento;
  IF @Estado IN('PENDIENTE_RESULTADO','FINALIZADO') AND @Sim=1
  BEGIN COMMIT; SELECT @IdEvento AS IdEvento,CAST(1 AS BIT) AS SinCambios; RETURN; END;
  IF @Estado IS NULL OR @Estado<>'EN_VIVO' OR @Sim<>1 THROW 76215,'Se requiere simulacion EN_VIVO.',1;
  DECLARE @Pendiente INT=(SELECT E.IdEstado FROM dbo.Estado E JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado
      WHERE T.Codigo='EVENTO' AND E.Codigo='PENDIENTE_RESULTADO' AND E.Activo=1);
  UPDATE dbo.Evento SET IdEstado=@Pendiente,FechaFinRealUtc=SYSUTCDATETIME() WHERE IdEvento=@IdEvento;
  DECLARE @Texto VARCHAR(250);
  SELECT @Texto=CONCAT(A.MarcadorActual,'-',B.MarcadorActual)
    FROM dbo.EventoParticipante A JOIN dbo.EventoParticipante B ON B.IdEvento=A.IdEvento AND B.OrdenParticipante=2
    WHERE A.IdEvento=@IdEvento AND A.OrdenParticipante=1;
  EXEC dbo.sp_RegistrarResultadoEvento @IdUsuarioProceso,@IdEvento,@Texto,NULL,@IpOrigen;
  INSERT dbo.Auditoria(IdUsuario,Accion,TablaAfectada,IdRegistro,IpOrigen,Descripcion)
    VALUES(@IdUsuarioProceso,'SIMULACION_FINALIZADA','Evento',@IdEvento,@IpOrigen,'Fin manual; pendiente de oficializacion.');
  COMMIT; SELECT @IdEvento AS IdEvento,CAST(0 AS BIT) AS SinCambios;
 END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_ObtenerEstadoSimulacionEvento @IdEvento INT
AS
BEGIN
 SET NOCOUNT ON;
 SELECT EV.IdEvento,EV.Nombre,E.Codigo AS EstadoEvento,EV.EsSimulado,EV.DuracionSimulacionSegundos,
   EV.FechaInicioRealUtc,EV.FechaFinRealUtc,EV.VersionFila,
   CASE WHEN EV.FechaInicioRealUtc IS NULL THEN 0 ELSE
     DATEDIFF(SECOND,EV.FechaInicioRealUtc,COALESCE(EV.FechaFinRealUtc,SYSUTCDATETIME())) END AS SegundosTranscurridos,
   CAST(CASE WHEN EV.FechaInicioRealUtc IS NOT NULL AND
     DATEDIFF(SECOND,EV.FechaInicioRealUtc,COALESCE(EV.FechaFinRealUtc,SYSUTCDATETIME()))>=EV.DuracionSimulacionSegundos
     THEN 1 ELSE 0 END AS BIT) AS TiempoVisualCumplido,
   P.IdIncidencia AS IdPrimeraAnotacion,P.IdParticipante AS IdPrimerParticipanteAnotador
 FROM dbo.Evento EV JOIN dbo.Estado E ON E.IdEstado=EV.IdEstado
 OUTER APPLY(SELECT TOP(1) I.IdIncidencia,I.IdParticipante FROM dbo.IncidenciaEvento I
    WHERE I.IdEvento=EV.IdEvento AND I.TipoIncidencia='ANOTACION' AND I.EsAnulada=0 ORDER BY I.Secuencia) P
 WHERE EV.IdEvento=@IdEvento;
 SELECT EP.OrdenParticipante,EP.IdParticipante,P.Nombre,EP.MarcadorActual
 FROM dbo.EventoParticipante EP JOIN dbo.Participante P ON P.IdParticipante=EP.IdParticipante WHERE EP.IdEvento=@IdEvento ORDER BY EP.OrdenParticipante;
 SELECT IdIncidencia,Secuencia,TipoIncidencia,IdParticipante,ValorAnotacion,SegundoSimulacion,FechaRegistroUtc,
   Descripcion,EsAnulada,MotivoAnulacion,FechaAnulacionUtc,VersionFila
 FROM dbo.IncidenciaEvento WHERE IdEvento=@IdEvento ORDER BY Secuencia;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_ResolverApuestasModalidadEvento @IdUsuarioProceso INT,@IdResultadoEvento INT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 EXEC dbo.sp_ValidarPermisoEventos @IdUsuarioProceso;
 IF @@TRANCOUNT=0 THROW 76216,'Resolucion interna: requiere la transaccion de oficializacion.',1;
 DECLARE @Evento INT,@A INT,@B INT,@Primero INT,@Estado VARCHAR(40);
 SELECT @Evento=R.IdEvento,@A=R.MarcadorFinalA,@B=R.MarcadorFinalB,@Estado=E.Codigo
 FROM dbo.ResultadoEvento R WITH(UPDLOCK,HOLDLOCK) JOIN dbo.Estado E ON E.IdEstado=R.IdEstado WHERE R.IdResultado=@IdResultadoEvento;
 IF @Estado IS NULL OR @Estado NOT IN('PENDIENTE','CORREGIDO') THROW 76217,'Resultado no disponible para resolver.',1;
 IF EXISTS(SELECT 1 FROM dbo.Mercado WHERE IdEvento=@Evento AND TipoMercado<>'CONVENCIONAL') AND (@A IS NULL OR @B IS NULL)
    THROW 76218,'Las modalidades requieren marcador final estructurado.',1;
 IF EXISTS(SELECT 1 FROM dbo.DetalleBoleto DB JOIN dbo.Seleccion S ON S.IdSeleccion=DB.IdSeleccion
   JOIN dbo.LiquidacionBoleto LB ON LB.IdBoleto=DB.IdBoleto WHERE S.IdEvento=@Evento)
    THROW 76219,'No se recalculan apuestas con liquidaciones existentes.',1;
 SELECT TOP(1) @Primero=IdParticipante FROM dbo.IncidenciaEvento
 WHERE IdEvento=@Evento AND TipoIncidencia='ANOTACION' AND EsAnulada=0 ORDER BY Secuencia;
 /* Convencional: forma A/B o A/B/neutral, exclusivamente con marcador
    estructurado y capacidad deportiva. Los nombres nunca deciden resultados. */
 DECLARE @PA INT,@PB INT;
 SELECT @PA=IdParticipante FROM dbo.EventoParticipante WHERE IdEvento=@Evento AND OrdenParticipante=1;
 SELECT @PB=IdParticipante FROM dbo.EventoParticipante WHERE IdEvento=@Evento AND OrdenParticipante=2;
 DECLARE @Automaticas TABLE(IdSeleccion INT PRIMARY KEY,Resultado VARCHAR(20) NOT NULL);
 IF @A IS NOT NULL AND @B IS NOT NULL AND @PA IS NOT NULL AND @PB IS NOT NULL AND @PA<>@PB
    AND (SELECT COUNT(*) FROM dbo.EventoParticipante WHERE IdEvento=@Evento)=2
    AND EXISTS(SELECT 1 FROM dbo.Evento EV JOIN dbo.Liga L ON L.IdLiga=EV.IdLiga
      JOIN dbo.Deporte D ON D.IdDeporte=L.IdDeporte WHERE EV.IdEvento=@Evento AND D.PermiteMarcadorFinal=1
      AND D.UnidadMarcador IS NOT NULL)
 BEGIN
  ;WITH Formas AS (
   SELECT M.IdMercado,COUNT(*) AS Total,
     SUM(CASE WHEN S.IdParticipante=@PA THEN 1 ELSE 0 END) AS A,
     SUM(CASE WHEN S.IdParticipante=@PB THEN 1 ELSE 0 END) AS B,
     SUM(CASE WHEN S.IdParticipante IS NULL THEN 1 ELSE 0 END) AS Neutral
   FROM dbo.Mercado M JOIN dbo.Estado E ON E.IdEstado=M.IdEstado
   JOIN dbo.Seleccion S ON S.IdMercado=M.IdMercado AND S.Activo=1
   WHERE M.IdEvento=@Evento AND M.TipoMercado='CONVENCIONAL' AND E.Codigo IN('CERRADO','LIQUIDADO')
   GROUP BY M.IdMercado
  )
  INSERT @Automaticas(IdSeleccion,Resultado)
  SELECT S.IdSeleccion,CASE WHEN (@A>@B AND S.IdParticipante=@PA)
       OR (@B>@A AND S.IdParticipante=@PB)
       OR (@A=@B AND S.IdParticipante IS NULL) THEN 'GANADA' ELSE 'PERDIDA' END
  FROM Formas F JOIN dbo.Seleccion S ON S.IdMercado=F.IdMercado AND S.Activo=1
  WHERE F.A=1 AND F.B=1 AND ((F.Total=2 AND F.Neutral=0 AND @A<>@B) OR (F.Total=3 AND F.Neutral=1))
    AND NOT EXISTS(SELECT 1 FROM dbo.Seleccion X WHERE X.IdMercado=F.IdMercado AND X.Activo=1
      AND (X.IdEvento<>@Evento OR (X.IdParticipante IS NOT NULL AND NOT EXISTS
        (SELECT 1 FROM dbo.EventoParticipante EP WHERE EP.IdEvento=@Evento AND EP.IdParticipante=X.IdParticipante))));
  IF EXISTS(SELECT 1 FROM @Automaticas A JOIN dbo.ResolucionSeleccion R WITH(UPDLOCK,HOLDLOCK)
    ON R.IdSeleccion=A.IdSeleccion
    WHERE R.Resultado<>A.Resultado OR R.IdResultadoEvento<>@IdResultadoEvento)
    THROW 76607,'Resolucion convencional existente incompatible con el resultado.',1;
  INSERT dbo.ResolucionSeleccion(IdSeleccion,IdResultadoEvento,IdUsuarioRegistro,Resultado,Observacion)
  SELECT A.IdSeleccion,@IdResultadoEvento,@IdUsuarioProceso,A.Resultado,'Calculado desde participantes y marcador estructurados.'
  FROM @Automaticas A WHERE NOT EXISTS(SELECT 1 FROM dbo.ResolucionSeleccion R WHERE R.IdSeleccion=A.IdSeleccion);
 END;
 /* La resolucion de primera anotacion es comun a la seleccion. */
 UPDATE RS SET Resultado=CASE WHEN E.Codigo='ANULADO' OR @Primero IS NULL THEN 'ANULADA'
              WHEN S.IdParticipante=@Primero THEN 'GANADA' ELSE 'PERDIDA' END,
       IdResultadoEvento=@IdResultadoEvento,IdUsuarioRegistro=@IdUsuarioProceso,FechaResolucion=SYSDATETIME()
 FROM dbo.ResolucionSeleccion RS JOIN dbo.Seleccion S ON S.IdSeleccion=RS.IdSeleccion
 JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado JOIN dbo.Estado E ON E.IdEstado=M.IdEstado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='PRIMERA_ANOTACION';
 INSERT dbo.ResolucionSeleccion(IdSeleccion,IdResultadoEvento,IdUsuarioRegistro,Resultado,Observacion)
 SELECT S.IdSeleccion,@IdResultadoEvento,@IdUsuarioProceso,
   CASE WHEN E.Codigo='ANULADO' OR @Primero IS NULL THEN 'ANULADA'
        WHEN S.IdParticipante=@Primero THEN 'GANADA' ELSE 'PERDIDA' END,'Calculado desde incidencias validas.'
 FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado JOIN dbo.Estado E ON E.IdEstado=M.IdEstado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='PRIMERA_ANOTACION'
   AND NOT EXISTS(SELECT 1 FROM dbo.ResolucionSeleccion R WHERE R.IdSeleccion=S.IdSeleccion);
 /* Marcador: la clasificacion pertenece a cada pronostico, nunca a la seleccion generica. */
 UPDATE DB SET ClasificacionAcierto=X.Clase,
   Resultado=CASE WHEN X.Clase='ANULADO' THEN 'ANULADA' WHEN X.Clase='NO_ACIERTO' THEN 'PERDIDA' ELSE 'GANADA' END,
   CuotaLiquidacion=CASE X.Clase WHEN 'ANULADO' THEN 1 WHEN 'NO_ACIERTO' THEN 0 WHEN 'EXACTO' THEN DB.CuotaAplicada ELSE DB.CuotaResultadoAplicada END
 FROM dbo.DetalleBoleto DB JOIN dbo.Seleccion S ON S.IdSeleccion=DB.IdSeleccion
 JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado JOIN dbo.Estado E ON E.IdEstado=M.IdEstado
 CROSS APPLY(SELECT CASE WHEN E.Codigo='ANULADO' THEN 'ANULADO'
   WHEN DB.PronosticoA=@A AND DB.PronosticoB=@B THEN 'EXACTO'
   WHEN SIGN(CONVERT(BIGINT,DB.PronosticoA)-DB.PronosticoB)=SIGN(CONVERT(BIGINT,@A)-@B) THEN 'RESULTADO'
   ELSE 'NO_ACIERTO' END AS Clase) X
 WHERE M.IdEvento=@Evento AND DB.TipoMercadoAplicado='MARCADOR_FINAL';
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_ObtenerConciliacionCasa @IdUsuarioSolicitante INT
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol JOIN dbo.Estado E ON E.IdEstado=U.IdEstado
    JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado
    WHERE U.IdUsuario=@IdUsuarioSolicitante AND R.Nombre IN('ADMINISTRADOR','AUDITOR','CAJERO') AND E.Codigo='ACTIVO' AND T.Codigo='USUARIO')
    THROW 76220,'Sin permiso para consultar conciliacion.',1;
 SELECT B.IdBilletera,B.SaldoDisponible,B.SaldoComprometido,ISNULL(X.Reservas,0) AS ReservasBoletos,
   B.SaldoComprometido-ISNULL(X.Reservas,0) AS Diferencia,
   ISNULL(X.FueraPendiente,0) AS ReservasFueraDePendiente
 FROM dbo.Billetera B JOIN dbo.Usuario U ON U.IdUsuario=B.IdUsuario JOIN dbo.Rol R ON R.IdRol=U.IdRol
 OUTER APPLY(SELECT SUM(CONVERT(DECIMAL(38,2),BO.ReservaCasaPendiente)) Reservas,
   SUM(CASE WHEN BO.Resultado<>'PENDIENTE' AND BO.ReservaCasaPendiente>0 THEN 1 ELSE 0 END) FueraPendiente
   FROM dbo.Boleto BO WHERE BO.IdBilleteraCasaReserva=B.IdBilletera) X WHERE R.Nombre='CASA';
END;
GO
