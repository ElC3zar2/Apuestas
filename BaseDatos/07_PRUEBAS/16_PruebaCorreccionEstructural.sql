/* Ejecutar COMPLETO en SSMS, tras instalacion limpia, sin transaccion ambiental
   y sin otras sesiones escribiendo. NO incluido en el instalador.
   Datos propios CE16 + GUID; cada caso revierte todo, incluso ante THROW.
   Los procedimientos de negocio pueden hacer ROLLBACK total: por eso cada
   negativo reconstruye su fixture y verifica el codigo exacto por separado.
   Exploracion devuelve varios ResultSet: un auxiliar ejecuta el cuerpo SQL
   oficial en un batch parametrizado y agrega aserciones sobre tablas temporales.
   No altera los procedimientos permanentes ni duplica su clasificacion.
   No ejecutar automaticamente contra la base local. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 THROW 71600,'Ejecutar sin transaccion ambiental.',1;
IF OBJECT_ID('tempdb..#BaseCE16','P') IS NOT NULL DROP PROCEDURE #BaseCE16;
IF OBJECT_ID('tempdb..#ExploracionCE16','P') IS NOT NULL DROP PROCEDURE #ExploracionCE16;
GO
CREATE PROCEDURE #BaseCE16
 @Admin INT,@Liga INT OUTPUT,@Evento INT OUTPUT,@A INT OUTPUT,@B INT OUTPUT,
 @Ajeno INT OUTPUT,@OtroDeporte INT OUTPUT,@Conv INT OUTPUT,@Prim INT OUTPUT,@Marc INT OUTPUT
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Deporte INT=(SELECT TOP(1) IdDeporte FROM dbo.Deporte WHERE Activo=1
   AND UnidadMarcador IS NOT NULL AND PermiteMarcadorFinal=1 AND PermitePrimeraAnotacion=1 ORDER BY IdDeporte),
 @Deporte2 INT,@Nombre VARCHAR(150),@Prefijo VARCHAR(80)=CONCAT('CE16 ñ á ü ',NEWID()),
 @Fecha DATETIME2=DATEADD(DAY,3,SYSDATETIME()),@Liga2 INT;
 SELECT TOP(1) @Deporte2=IdDeporte FROM dbo.Deporte WHERE Activo=1 AND IdDeporte<>@Deporte ORDER BY IdDeporte;
 IF @Deporte IS NULL OR @Deporte2 IS NULL THROW 71601,'Requiere deportes iniciales con capacidades y otro deporte.',1;
 SET @Nombre=CONCAT(@Prefijo,' L1');
 EXEC dbo.sp_CrearLiga @Admin,@Deporte,@Nombre;
 SELECT @Liga=IdLiga FROM dbo.Liga WHERE Nombre=@Nombre AND IdDeporte=@Deporte;
 SET @Nombre=CONCAT(@Prefijo,' L2');
 EXEC dbo.sp_CrearLiga @Admin,@Deporte,@Nombre;
 SELECT @Liga2=IdLiga FROM dbo.Liga WHERE Nombre=@Nombre AND IdDeporte=@Deporte;
 SET @Nombre=CONCAT(@Prefijo,' A');
 EXEC dbo.sp_CrearParticipante @Admin,@Deporte,@Nombre,'EQUIPO';
 SELECT @A=IdParticipante FROM dbo.Participante WHERE Nombre=@Nombre AND IdDeporte=@Deporte;
 SET @Nombre=CONCAT(@Prefijo,' B');
 EXEC dbo.sp_CrearParticipante @Admin,@Deporte,@Nombre,'EQUIPO';
 SELECT @B=IdParticipante FROM dbo.Participante WHERE Nombre=@Nombre AND IdDeporte=@Deporte;
 SET @Nombre=CONCAT(@Prefijo,' Ajeno');
 EXEC dbo.sp_CrearParticipante @Admin,@Deporte,@Nombre,'EQUIPO';
 SELECT @Ajeno=IdParticipante FROM dbo.Participante WHERE Nombre=@Nombre AND IdDeporte=@Deporte;
 SET @Nombre=CONCAT(@Prefijo,' Otro deporte');
 EXEC dbo.sp_CrearParticipante @Admin,@Deporte2,@Nombre,'ATLETA';
 SELECT @OtroDeporte=IdParticipante FROM dbo.Participante WHERE Nombre=@Nombre AND IdDeporte=@Deporte2;
 EXEC dbo.sp_AsociarParticipanteLiga @Admin,@Liga,@A;
 EXEC dbo.sp_AsociarParticipanteLiga @Admin,@Liga,@B;
 EXEC dbo.sp_AsociarParticipanteLiga @Admin,@Liga2,@Ajeno;
 SET @Nombre=CONCAT(@Prefijo,' Evento');
 EXEC dbo.sp_CrearEvento @IdUsuarioProceso=@Admin,@IdLiga=@Liga,@Nombre=@Nombre,
   @FechaInicio=@Fecha,@EsSimulado=1;
 SELECT @Evento=IdEvento FROM dbo.Evento WHERE IdLiga=@Liga AND Nombre=@Nombre;
 EXEC dbo.sp_AgregarParticipanteEvento @Admin,@Evento,@A,1,1;
 EXEC dbo.sp_AgregarParticipanteEvento @Admin,@Evento,@B,2,0;
 EXEC dbo.sp_CrearMercado @IdUsuarioProceso=@Admin,@IdEvento=@Evento,@Nombre='Forma C';
 SELECT @Conv=IdMercado FROM dbo.Mercado WHERE IdEvento=@Evento AND TipoMercado='CONVENCIONAL';
 EXEC dbo.sp_CrearMercado @IdUsuarioProceso=@Admin,@IdEvento=@Evento,@Nombre='Forma P',@TipoMercado='PRIMERA_ANOTACION';
 SELECT @Prim=IdMercado FROM dbo.Mercado WHERE IdEvento=@Evento AND TipoMercado='PRIMERA_ANOTACION';
 EXEC dbo.sp_CrearMercado @IdUsuarioProceso=@Admin,@IdEvento=@Evento,@Nombre='Forma M',@TipoMercado='MARCADOR_FINAL';
 SELECT @Marc=IdMercado FROM dbo.Mercado WHERE IdEvento=@Evento AND TipoMercado='MARCADOR_FINAL';
END;
GO
CREATE PROCEDURE #ExploracionCE16 @Evento INT,@Estado VARCHAR(40)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Deporte INT=(SELECT L.IdDeporte FROM dbo.Evento E JOIN dbo.Liga L ON L.IdLiga=E.IdLiga WHERE E.IdEvento=@Evento),
 @Sql NVARCHAR(MAX)=OBJECT_DEFINITION(OBJECT_ID('dbo.sp_ObtenerEventosExploracion')),
 @Detalle NVARCHAR(MAX)=OBJECT_DEFINITION(OBJECT_ID('dbo.sp_ObtenerDetalleEventoExploracion')),
 @Marca NVARCHAR(100)=N'SELECT * FROM #EventosExploracion',@Pos INT;
 IF @Sql IS NULL OR @Detalle IS NULL OR CHARINDEX(@Marca,@Sql)=0
   THROW 71620,'No se pudo instrumentar el contrato oficial de exploracion.',1;
 SET @Sql=SUBSTRING(@Sql,CHARINDEX('BEGIN',@Sql),LEN(@Sql));
 SET @Sql=REPLACE(@Sql,@Marca,N'
 IF @Vista=''TODOS'' AND NOT EXISTS(SELECT 1 FROM #EventosExploracion WHERE IdEvento=@EsperadoEvento
   AND EstadoEvento=@EsperadoEstado AND EstadoVisual=@EsperadoEstado)
   THROW 71621,''TODOS no conserva el estado pendiente/final del evento.'',1;
 IF @Vista=''FINALIZADOS'' AND EXISTS(SELECT 1 FROM #EventosExploracion WHERE EstadoEvento<>''FINALIZADO''
   OR EstadoVisual<>''FINALIZADO'') THROW 71622,''FINALIZADOS incluyo un evento pendiente.'',1;
 IF @Vista=''FINALIZADOS'' AND @EsperadoEstado=''FINALIZADO'' AND NOT EXISTS
   (SELECT 1 FROM #EventosExploracion WHERE IdEvento=@EsperadoEvento)
   THROW 71623,''FINALIZADOS no devuelve el evento oficial.'',1;
 '+@Marca);
 EXEC sys.sp_executesql @Sql,
   N'@IdDeporte INT,@Vista VARCHAR(20),@HorasPrevia INT,@Cantidad INT,@EsperadoEvento INT,@EsperadoEstado VARCHAR(40)',
   @Deporte,'TODOS',24,500,@Evento,@Estado;
 EXEC sys.sp_executesql @Sql,
   N'@IdDeporte INT,@Vista VARCHAR(20),@HorasPrevia INT,@Cantidad INT,@EsperadoEvento INT,@EsperadoEstado VARCHAR(40)',
   @Deporte,'FINALIZADOS',24,500,@Evento,@Estado;
 SET @Detalle=SUBSTRING(@Detalle,CHARINDEX('BEGIN',@Detalle),LEN(@Detalle));
 SET @Pos=CHARINDEX('FROM dbo.Evento AS EV',@Detalle);
 IF @Pos=0 THROW 71624,'No se pudo capturar el encabezado oficial del detalle.',1;
 SET @Detalle=STUFF(@Detalle,@Pos,0,N'INTO #DetalleCE16 ');
 SET @Detalle+=N'
 IF NOT EXISTS(SELECT 1 FROM #DetalleCE16 WHERE IdEvento=@IdEvento AND EstadoEvento=@EsperadoEstado
   AND EstadoVisual=@EsperadoEstado) THROW 71625,''Detalle no conserva el estado pendiente/final.'',1;';
 EXEC sys.sp_executesql @Detalle,N'@IdEvento INT,@HorasPrevia INT,@EsperadoEstado VARCHAR(40)',@Evento,24,@Estado;
END;
GO
DECLARE @Admin INT=(SELECT TOP(1) U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' ORDER BY U.IdUsuario),
 @Caso INT=1,@Esperado INT,@Recibido INT,@Liga INT,@Evento INT,@A INT,@B INT,@Ajeno INT,@Otro INT,
 @Conv INT,@Prim INT,@Marc INT,@R INT,@SA INT,@SB INT,@SN INT,@SP INT,@SM INT,
 @Ref UNIQUEIDENTIFIER,@X INT,@Y INT,@J INT,@N INT,@Mercado INT,
 @Antes BIGINT,@TransAntes BIGINT,@MovAntes BIGINT,@ResolucionAntes INT,@Error NVARCHAR(2048),@Usuario INT,@Json NVARCHAR(MAX),@Monto DECIMAL(12,2);
IF @Admin IS NULL THROW 71602,'Requiere administrador inicial activo.',1;
WHILE @Caso<=20
BEGIN
 SET @Recibido=0;
 SET @Esperado=CASE @Caso WHEN 2 THEN 76603 WHEN 3 THEN 76606 WHEN 4 THEN 76606
   WHEN 5 THEN 76010 WHEN 6 THEN 76010 WHEN 7 THEN 76010 WHEN 8 THEN 76010
   WHEN 19 THEN 2627 WHEN 20 THEN 59043 WHEN 13 THEN 61024 WHEN 14 THEN 61024 WHEN 15 THEN 76607 ELSE 0 END;
 BEGIN TRY
  BEGIN TRANSACTION;
  EXEC #BaseCE16 @Admin,@Liga OUTPUT,@Evento OUTPUT,@A OUTPUT,@B OUTPUT,@Ajeno OUTPUT,@Otro OUTPUT,
    @Conv OUTPUT,@Prim OUTPUT,@Marc OUTPUT;
  IF @Caso=1
  BEGIN
   EXEC dbo.sp_AsociarParticipanteLiga @Admin,@Liga,@A;
   IF (SELECT COUNT(*) FROM dbo.LigaParticipante WHERE IdLiga=@Liga AND IdParticipante=@A)<>1
     THROW 71603,'Asociacion repetida genero duplicados.',1;
   IF (SELECT COUNT(*) FROM dbo.LigaParticipante LP JOIN dbo.Participante P ON P.IdParticipante=LP.IdParticipante
     JOIN dbo.Liga L ON L.IdLiga=LP.IdLiga WHERE LP.IdLiga=@Liga AND LP.Activo=1 AND P.Activo=1
       AND L.Activo=1 AND L.IdDeporte=P.IdDeporte)<>2
     THROW 71604,'Consulta por liga no devuelve exactamente A/B.',1;
   IF EXISTS(SELECT 1 FROM dbo.LigaParticipante WHERE IdLiga=@Liga AND IdParticipante=@Ajeno)
     THROW 71605,'Consulta por liga mezclo participantes.',1;
   EXEC dbo.sp_DesasociarParticipanteLiga @Admin,@Liga,@A;
   IF EXISTS(SELECT 1 FROM dbo.LigaParticipante WHERE IdLiga=@Liga AND IdParticipante=@A AND Activo=1)
     OR NOT EXISTS(SELECT 1 FROM dbo.EventoParticipante WHERE IdEvento=@Evento AND IdParticipante=@A)
     THROW 71606,'Desasociacion no conserva disponibilidad e historial correctamente.',1;
   EXEC dbo.sp_AsociarParticipanteLiga @Admin,@Liga,@A;
   IF NOT EXISTS(SELECT 1 FROM dbo.LigaParticipante WHERE IdLiga=@Liga AND IdParticipante=@A AND Activo=1)
     THROW 71607,'No reactivo la asociacion.',1;
  END;
  IF @Caso=2 EXEC dbo.sp_AsociarParticipanteLiga @Admin,@Liga,@Otro;
  IF @Caso=3 EXEC dbo.sp_AgregarParticipanteEvento @Admin,@Evento,@Ajeno,3;
  IF @Caso=4
  BEGIN
   EXEC dbo.sp_AsociarParticipanteLiga @Admin,@Liga,@Ajeno;
   EXEC dbo.sp_DesasociarParticipanteLiga @Admin,@Liga,@Ajeno;
   EXEC dbo.sp_AgregarParticipanteEvento @Admin,@Evento,@Ajeno,3;
  END;
  IF @Caso=5 EXEC dbo.sp_CrearSeleccion @IdUsuarioProceso=@Admin,@IdMercado=@Conv,@Nombre='Ajeno',@IdParticipante=@Ajeno;
  IF @Caso=6 EXEC dbo.sp_CrearSeleccion @IdUsuarioProceso=@Admin,@IdMercado=@Prim,@Nombre='Sin participante';
  IF @Caso=7 EXEC dbo.sp_CrearSeleccion @IdUsuarioProceso=@Admin,@IdMercado=@Prim,@Nombre='Ajeno',@IdParticipante=@Ajeno;
  IF @Caso=8 EXEC dbo.sp_CrearSeleccion @IdUsuarioProceso=@Admin,@IdMercado=@Marc,@Nombre='Asociada',@IdParticipante=@A;
  IF @Caso=19 INSERT dbo.LigaParticipante(IdLiga,IdParticipante) VALUES(@Liga,@A);
  IF @Caso=20 EXEC dbo.sp_AgregarParticipanteEvento @Admin,@Evento,@Otro,3;
  IF @Caso BETWEEN 9 AND 18
  BEGIN
   -- Etiquetas deliberadamente ajenas al resultado: nunca se comparan nombres.
   EXEC dbo.sp_CrearSeleccion @IdUsuarioProceso=@Admin,@IdMercado=@Conv,@Nombre='Opcion X',@IdParticipante=@A;
   EXEC dbo.sp_CrearSeleccion @IdUsuarioProceso=@Admin,@IdMercado=@Conv,@Nombre='Opcion Y',@IdParticipante=@B;
   IF @Caso NOT IN(13,17)
     EXEC dbo.sp_CrearSeleccion @IdUsuarioProceso=@Admin,@IdMercado=@Conv,@Nombre='Opcion Z';
   IF @Caso=14 EXEC dbo.sp_CrearSeleccion @IdUsuarioProceso=@Admin,@IdMercado=@Conv,@Nombre='Otra neutral';
   EXEC dbo.sp_CrearSeleccion @IdUsuarioProceso=@Admin,@IdMercado=@Prim,@Nombre='X',@IdParticipante=@A;
   EXEC dbo.sp_CrearSeleccion @IdUsuarioProceso=@Admin,@IdMercado=@Prim,@Nombre='Y',@IdParticipante=@B;
   EXEC dbo.sp_CrearSeleccion @IdUsuarioProceso=@Admin,@IdMercado=@Marc,@Nombre='Generica';
   SELECT @SA=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@Conv AND IdParticipante=@A;
   SELECT @SB=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@Conv AND IdParticipante=@B;
   SET @SN=NULL;
   SELECT @SN=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@Conv AND Nombre='Opcion Z';
   SELECT @SP=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@Prim AND IdParticipante=@B;
   SELECT @SM=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@Marc;
   -- Registrar cuotas por el contrato oficial antes de publicar.
   DECLARE selecciones CURSOR LOCAL FAST_FORWARD FOR SELECT IdSeleccion FROM dbo.Seleccion WHERE IdEvento=@Evento;
   OPEN selecciones;FETCH NEXT FROM selecciones INTO @J;
   WHILE @@FETCH_STATUS=0
   BEGIN
    EXEC dbo.sp_RegistrarCuota @IdUsuarioProceso=@Admin,@IdSeleccion=@J,@Valor=2;
    FETCH NEXT FROM selecciones INTO @J;
   END;
   CLOSE selecciones;DEALLOCATE selecciones;
   EXEC dbo.sp_CambiarEstadoEvento @Admin,@Evento,'PROGRAMADO';
   -- Abrir mercados por contrato; permite agregar boletos desde SSMS si se amplian escenarios.
   EXEC dbo.sp_CambiarEstadoMercado @Admin,@Conv,'ABIERTO';
   EXEC dbo.sp_CambiarEstadoMercado @Admin,@Prim,'ABIERTO';
   EXEC dbo.sp_CambiarEstadoMercado @Admin,@Marc,'ABIERTO';
   IF @Caso=9
   BEGIN
    SELECT @Monto=TRY_CONVERT(DECIMAL(12,2),Valor) FROM dbo.ConfiguracionSistema WHERE Clave='MONTO_MINIMO_APUESTA';
    SELECT TOP(1) @Usuario=U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
      JOIN dbo.Estado E ON E.IdEstado=U.IdEstado JOIN dbo.Billetera B ON B.IdUsuario=U.IdUsuario
      CROSS APPLY(SELECT TOP(1) EV.Codigo FROM dbo.VerificacionUsuario V JOIN dbo.Estado EV ON EV.IdEstado=V.IdEstado
        WHERE V.IdUsuario=U.IdUsuario ORDER BY V.IdVerificacion DESC) V
      WHERE R.Nombre='USUARIO' AND E.Codigo='ACTIVO' AND U.CorreoVerificado=1 AND V.Codigo='APROBADA'
        AND B.SaldoDisponible>=@Monto*10
        AND NOT EXISTS(SELECT 1 FROM dbo.RestriccionUsuario RU WHERE RU.IdUsuario=U.IdUsuario AND RU.Activa=1)
      ORDER BY U.IdUsuario;
    IF @Usuario IS NULL OR @Monto IS NULL THROW 71626,'Requiere un usuario oficial verificado con saldo para tres boletos.',1;
    SET @Ref=NEWID();SET @Json=CONCAT('[',@SA,']');
    EXEC dbo.sp_RealizarApuesta @IdUsuario=@Usuario,@SeleccionesJson=@Json,@Monto=@Monto,@ReferenciaOperacion=@Ref;
    SET @Ref=NEWID();SET @Json=CONCAT('[',@SP,']');
    EXEC dbo.sp_RealizarApuesta @IdUsuario=@Usuario,@SeleccionesJson=@Json,@Monto=@Monto,@ReferenciaOperacion=@Ref;
    SET @Ref=NEWID();SET @Json=CONCAT('[',@SM,']');
    EXEC dbo.sp_RealizarApuesta @IdUsuario=@Usuario,@SeleccionesJson=@Json,@Monto=@Monto,@ReferenciaOperacion=@Ref,
      @PronosticoA=3,@PronosticoB=1;
   END;
   EXEC dbo.sp_IniciarSimulacionEvento @Admin,@Evento;
   SET @X=CASE WHEN @Caso=11 THEN 1 ELSE 3 END;
   SET @Y=CASE WHEN @Caso IN(12,13) THEN 3 WHEN @Caso=11 THEN 3 ELSE 1 END;
   -- Valores unitarios validos tambien para GOL. B anota primero.
   SET @J=0;
   WHILE @J<@Y
   BEGIN
    SET @Ref=NEWID();
    EXEC dbo.sp_RegistrarIncidenciaEvento @Admin,@Evento,'ANOTACION',@Ref,@B,1;
    SET @J+=1;
   END;
   SET @J=0;
   WHILE @J<@X
   BEGIN
    SET @Ref=NEWID();
    EXEC dbo.sp_RegistrarIncidenciaEvento @Admin,@Evento,'ANOTACION',@Ref,@A,1;
    SET @J+=1;
   END;
   EXEC dbo.sp_FinalizarSimulacionEvento @Admin,@Evento;
   SELECT @R=IdResultado FROM dbo.ResultadoEvento WHERE IdEvento=@Evento;
   IF @R IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.Evento EV JOIN dbo.Estado E ON E.IdEstado=EV.IdEstado
       WHERE EV.IdEvento=@Evento AND E.Codigo='PENDIENTE_RESULTADO')
     THROW 71608,'Cierre no dejo resultado pendiente.',1;
   IF @Caso=9 EXEC #ExploracionCE16 @Evento,'PENDIENTE_RESULTADO';
   IF @Caso IN(15,16)
   BEGIN
    DECLARE @Manual VARCHAR(20)=CASE WHEN @Caso=15 THEN 'PERDIDA' ELSE 'GANADA' END;
    EXEC dbo.sp_ResolverSeleccion @IdUsuarioProceso=@Admin,@IdResultadoEvento=@R,@IdSeleccion=@SA,
      @Resultado=@Manual,@Observacion='Resolucion manual a conservar';
    SELECT @ResolucionAntes=IdResolucion FROM dbo.ResolucionSeleccion WHERE IdSeleccion=@SA;
   END;
   IF @Caso=18
   BEGIN
    -- Repeticion interna antes de oficializar: conserva filas existentes del mismo resultado.
    EXEC dbo.sp_ResolverApuestasModalidadEvento @Admin,@R;
    SELECT @N=COUNT(*) FROM dbo.ResolucionSeleccion WHERE IdResultadoEvento=@R;
    EXEC dbo.sp_ResolverApuestasModalidadEvento @Admin,@R;
    IF @N<>(SELECT COUNT(*) FROM dbo.ResolucionSeleccion WHERE IdResultadoEvento=@R)
      THROW 71609,'Resolucion repetida genero filas adicionales.',1;
   END;
   SELECT IdBilletera,SaldoDisponible,SaldoComprometido INTO #SaldosCE16 FROM dbo.Billetera;
   SELECT @Antes=COUNT_BIG(*) FROM dbo.LiquidacionBoleto;
   SELECT @TransAntes=COUNT_BIG(*) FROM dbo.TransaccionFinanciera;
   SELECT @MovAntes=COUNT_BIG(*) FROM dbo.MovimientoBilletera;
   EXEC dbo.sp_OficializarResultadoEvento @Admin,@R;
   IF @Esperado=0
   BEGIN
    IF NOT EXISTS(SELECT 1 FROM dbo.ResultadoEvento R JOIN dbo.Estado E ON E.IdEstado=R.IdEstado
       WHERE R.IdResultado=@R AND E.Codigo='OFICIAL')
       OR NOT EXISTS(SELECT 1 FROM dbo.Evento EV JOIN dbo.Estado E ON E.IdEstado=EV.IdEstado
       WHERE EV.IdEvento=@Evento AND E.Codigo='FINALIZADO')
      THROW 71610,'No oficializo resultado/evento.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.ResolucionSeleccion WHERE IdSeleccion=@SA AND IdResultadoEvento=@R
      AND Resultado=CASE WHEN @X>@Y THEN 'GANADA' ELSE 'PERDIDA' END)
       OR NOT EXISTS(SELECT 1 FROM dbo.ResolucionSeleccion WHERE IdSeleccion=@SB AND IdResultadoEvento=@R
      AND Resultado=CASE WHEN @Y>@X THEN 'GANADA' ELSE 'PERDIDA' END)
      THROW 71611,'Resolucion A/B incorrecta.',1;
    IF @SN IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.ResolucionSeleccion WHERE IdSeleccion=@SN AND IdResultadoEvento=@R
       AND Resultado=CASE WHEN @X=@Y THEN 'GANADA' ELSE 'PERDIDA' END)
      THROW 71612,'Neutral incorrecta.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.ResolucionSeleccion WHERE IdSeleccion=@SP AND Resultado='GANADA' AND IdResultadoEvento=@R)
      THROW 71613,'Primera anotacion dejo de resolverse desde incidencias.',1;
    IF EXISTS(SELECT 1 FROM dbo.ResolucionSeleccion WHERE IdSeleccion=@SM)
      THROW 71614,'Marcador final no debe resolver la seleccion generica.',1;
    IF EXISTS(SELECT 1 FROM dbo.Mercado M JOIN dbo.Estado E ON E.IdEstado=M.IdEstado
      WHERE M.IdEvento=@Evento AND E.Codigo<>'LIQUIDADO')
      THROW 71615,'Mercados no liquidados deportivamente.',1;
    IF @Antes<>(SELECT COUNT_BIG(*) FROM dbo.LiquidacionBoleto)
       OR @TransAntes<>(SELECT COUNT_BIG(*) FROM dbo.TransaccionFinanciera)
       OR @MovAntes<>(SELECT COUNT_BIG(*) FROM dbo.MovimientoBilletera)
      THROW 71616,'Oficializacion genero operaciones financieras.',1;
    IF EXISTS(SELECT IdBilletera,SaldoDisponible,SaldoComprometido FROM #SaldosCE16
       EXCEPT SELECT IdBilletera,SaldoDisponible,SaldoComprometido FROM dbo.Billetera)
      OR EXISTS(SELECT IdBilletera,SaldoDisponible,SaldoComprometido FROM dbo.Billetera
       EXCEPT SELECT IdBilletera,SaldoDisponible,SaldoComprometido FROM #SaldosCE16)
      THROW 71629,'Oficializacion modifico saldos o reservas de billetera.',1;
    IF @Caso=16 AND NOT EXISTS(SELECT 1 FROM dbo.ResolucionSeleccion WHERE IdResolucion=@ResolucionAntes
      AND Observacion='Resolucion manual a conservar' AND Resultado='GANADA')
      THROW 71617,'Sobrescribio resolucion valida existente.',1;
    IF @Caso=9
    BEGIN
     IF NOT EXISTS(SELECT 1 FROM dbo.DetalleBoleto D WHERE D.IdSeleccion=@SM AND D.ClasificacionAcierto='EXACTO'
       AND D.Resultado='GANADA' AND D.CuotaLiquidacion=D.CuotaAplicada)
       THROW 71627,'Marcador final no clasifico el pronostico exacto.',1;
     IF EXISTS(SELECT 1 FROM dbo.Boleto B JOIN dbo.DetalleBoleto D ON D.IdBoleto=B.IdBoleto
       JOIN dbo.Seleccion S ON S.IdSeleccion=D.IdSeleccion JOIN dbo.Estado E ON E.IdEstado=B.IdEstado
       WHERE S.IdEvento=@Evento AND (E.Codigo<>'PENDIENTE' OR B.ReservaCasaPendiente<>B.ReservaCasaInicial))
       THROW 71628,'Oficializacion liquido boletos o libero reservas.',1;
     EXEC #ExploracionCE16 @Evento,'FINALIZADO';
    END;
    EXEC dbo.sp_OficializarResultadoEvento @Admin,@R;
   END;
  END;
  IF XACT_STATE()<>0 ROLLBACK;
 END TRY
 BEGIN CATCH
  SET @Recibido=ERROR_NUMBER();SET @Error=ERROR_MESSAGE();
  IF CURSOR_STATUS('local','selecciones')>=0 CLOSE selecciones;
  IF CURSOR_STATUS('local','selecciones')>-3 DEALLOCATE selecciones;
  IF XACT_STATE()<>0 ROLLBACK;
  IF @Recibido<>@Esperado THROW;
 END CATCH;
 IF @Recibido<>@Esperado
 BEGIN
  SET @Error=CONCAT('Caso ',@Caso,': esperaba ',@Esperado,'; recibio ',@Recibido,'.');
  THROW 71618,@Error,1;
 END;
 PRINT CONCAT('PASS CE16 caso ',@Caso,'; codigo ',@Recibido,'; datos revertidos.');
 SET @Caso+=1;
END;
/* Verificacion adicional nominal del contrato, ademas de las aserciones
   funcionales de #ExploracionCE16 ejecutadas en el caso 9. */
DECLARE @Lista NVARCHAR(MAX)=OBJECT_DEFINITION(OBJECT_ID('dbo.sp_ObtenerEventosExploracion')),
 @Detalle NVARCHAR(MAX)=OBJECT_DEFINITION(OBJECT_ID('dbo.sp_ObtenerDetalleEventoExploracion'));
IF @Lista IS NULL OR @Detalle IS NULL
 OR @Lista NOT LIKE '%WHEN EE.Codigo = ''PENDIENTE_RESULTADO'' THEN ''PENDIENTE_RESULTADO''%'
 OR @Detalle NOT LIKE '%WHEN EE.Codigo = ''PENDIENTE_RESULTADO'' THEN ''PENDIENTE_RESULTADO''%'
 OR @Lista NOT LIKE '%@Vista = ''FINALIZADOS''%AND EE.Codigo = ''FINALIZADO''%'
 THROW 71619,'Contrato visual o filtro FINALIZADOS incorrecto.',1;
PRINT 'PASS CE16 contrato visual: PENDIENTE_RESULTADO distinto de FINALIZADO; FINALIZADOS solo oficiales.';
DROP PROCEDURE #BaseCE16;
DROP PROCEDURE #ExploracionCE16;
PRINT 'CE16: 20 casos funcionales y contrato visual OK. Sin datos persistidos.';
GO
