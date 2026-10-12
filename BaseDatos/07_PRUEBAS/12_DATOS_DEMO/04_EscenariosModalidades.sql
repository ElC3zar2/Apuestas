/* Escenarios reproducibles V2. Ejecutar DESPUES de 01_DatosDemoRevision.sql.
   Solo demo: usa los clientes ficticios registrados por el flujo existente.
   No se incluye en instaladores. Una transaccion impide escenarios parciales.
   Reejecucion conserva eventos existentes y fechas; no reinicia historiales. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @Admin INT=(SELECT TOP(1) U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
  JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' ORDER BY U.IdUsuario),
  @Usuario INT=(SELECT IdUsuario FROM dbo.Usuario WHERE Correo='cliente.ana@apuestas.test'),
  @Liga INT=(SELECT IdLiga FROM dbo.Liga WHERE Nombre='DEMO IA - Liga Futbol Guatemala'),
  @A INT=(SELECT IdParticipante FROM dbo.Participante WHERE Nombre='DEMO IA - Quetzales FC'),
  @B INT=(SELECT IdParticipante FROM dbo.Participante WHERE Nombre='DEMO IA - Volcanes FC');
 IF @Admin IS NULL OR @Usuario IS NULL OR @Liga IS NULL OR @A IS NULL OR @B IS NULL
   THROW 75100,'Ejecute primero 01_DatosDemoRevision.sql sobre la instalacion completa.',1;
 DECLARE @Escenarios TABLE(N INT PRIMARY KEY,Nombre VARCHAR(200));
 INSERT @Escenarios VALUES
 (1,'DEMO V2 - PROGRAMADO'),(2,'DEMO V2 - PREVIA'),(3,'DEMO V2 - EN_VIVO'),
 (4,'DEMO V2 - PENDIENTE_RESULTADO'),(5,'DEMO V2 - FINALIZADO 2-1'),
 (6,'DEMO V2 - SIN ANOTACIONES'),(7,'DEMO V2 - CANCELADO'),(8,'DEMO V2 - EMPATE 2-2');
 DECLARE @N INT=1,@Nombre VARCHAR(200),@Evento INT,@Fecha DATETIME2,@Mercado INT,@Primera INT,
   @Seleccion INT,@SelA INT,@SelB INT,@Saldo DECIMAL(12,2),@Credito DECIMAL(12,2),
   @Ref UNIQUEIDENTIFIER,@Json NVARCHAR(MAX),@J INT,@Total INT,@PA INT,@PB INT,@Elegida INT,
   @Resultado INT,@Boleto INT,@Inc INT,@IncTotal INT,@Participante INT,@Minimo DECIMAL(12,2);
 SELECT @Minimo=TRY_CONVERT(DECIMAL(12,2),Valor) FROM dbo.ConfiguracionSistema WHERE Clave='MONTO_MINIMO_APUESTA';
 IF @Minimo IS NULL OR @Minimo<=0 THROW 75101,'Monto minimo invalido.',1;
 WHILE @N<=8
 BEGIN
  SELECT @Nombre=Nombre FROM @Escenarios WHERE N=@N;
  SET @Evento=NULL;
  SELECT @Evento=IdEvento FROM dbo.Evento WHERE IdLiga=@Liga AND Nombre=@Nombre;
  IF @Evento IS NULL
  BEGIN
   SELECT @Saldo=SaldoDisponible FROM dbo.Billetera WHERE IdUsuario=@Usuario;
   SET @Credito=(@Minimo*10+100)-@Saldo;
   IF @Credito>0
   BEGIN
    SET @Ref=CONVERT(UNIQUEIDENTIFIER,CONCAT('C3000000-0000-0000-0000-',RIGHT('000000000000'+CONVERT(VARCHAR(12),@N),12)));
    EXEC dbo.sp_AjustarSaldoVirtual @Usuario,@Admin,'CREDITO',@Credito,'Capital ficticio para escenarios demo V2.',@Ref;
   END;
   SET @Fecha=CAST(SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'Central America Standard Time' AS DATETIME2);
   SET @Fecha=DATEADD(MINUTE,CASE WHEN @N=2 THEN 30 ELSE 2880 END,@Fecha);
   EXEC dbo.sp_CrearEvento @IdUsuarioProceso=@Admin,@IdLiga=@Liga,@Nombre=@Nombre,@FechaInicio=@Fecha,@EsSimulado=1;
   SELECT @Evento=IdEvento FROM dbo.Evento WHERE IdLiga=@Liga AND Nombre=@Nombre;
   EXEC dbo.sp_AgregarParticipanteEvento @Admin,@Evento,@A,1,1;
   EXEC dbo.sp_AgregarParticipanteEvento @Admin,@Evento,@B,2,0;
   EXEC dbo.sp_CrearMercado @IdUsuarioProceso=@Admin,@IdEvento=@Evento,@Nombre='Marcador final',@TipoMercado='MARCADOR_FINAL';
   SELECT @Mercado=IdMercado FROM dbo.Mercado WHERE IdEvento=@Evento AND TipoMercado='MARCADOR_FINAL';
   EXEC dbo.sp_CrearSeleccion @Admin,@Mercado,'Pronostico marcador';
   SELECT @Seleccion=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@Mercado;
   EXEC dbo.sp_RegistrarCuota @IdUsuarioProceso=@Admin,@IdSeleccion=@Seleccion;
   EXEC dbo.sp_CrearMercado @IdUsuarioProceso=@Admin,@IdEvento=@Evento,@Nombre='Primera anotacion',@TipoMercado='PRIMERA_ANOTACION';
   SELECT @Primera=IdMercado FROM dbo.Mercado WHERE IdEvento=@Evento AND TipoMercado='PRIMERA_ANOTACION';
   EXEC dbo.sp_CrearSeleccion @IdUsuarioProceso=@Admin,@IdMercado=@Primera,@Nombre='Participante A',@IdParticipante=@A;
   EXEC dbo.sp_CrearSeleccion @IdUsuarioProceso=@Admin,@IdMercado=@Primera,@Nombre='Participante B',@IdParticipante=@B;
   SELECT @SelA=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@Primera AND IdParticipante=@A;
   SELECT @SelB=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@Primera AND IdParticipante=@B;
   EXEC dbo.sp_RegistrarCuota @IdUsuarioProceso=@Admin,@IdSeleccion=@SelA;
   EXEC dbo.sp_RegistrarCuota @IdUsuarioProceso=@Admin,@IdSeleccion=@SelB;
   EXEC dbo.sp_CambiarEstadoEvento @Admin,@Evento,'PROGRAMADO';
   EXEC dbo.sp_CambiarEstadoMercado @Admin,@Mercado,'ABIERTO';
   EXEC dbo.sp_CambiarEstadoMercado @Admin,@Primera,'ABIERTO';
   SET @J=1; SET @Total=CASE WHEN @N IN(5,8) THEN 5 ELSE 2 END;
   WHILE @J<=@Total
   BEGIN
    SET @PA=NULL; SET @PB=NULL;
    SET @Elegida=CASE WHEN @Total=5 AND @J<=3 THEN @Seleccion WHEN @J=1 THEN @Seleccion
      WHEN @Total=5 AND @J=5 THEN @SelB ELSE @SelA END;
    IF @Elegida=@Seleccion
    BEGIN
      SET @PA=CASE WHEN @N=6 THEN 0 WHEN @N=8 AND @J=1 THEN 1 WHEN @J=2 AND @N<>8 THEN 3 WHEN @J=3 THEN 0 ELSE 2 END;
      SET @PB=CASE WHEN @N=6 THEN 0 WHEN @N=8 AND @J=1 THEN 1 WHEN @N=8 OR @J=3 THEN 2 ELSE 1 END;
    END;
    SET @Ref=CONVERT(UNIQUEIDENTIFIER,CONCAT('A3000000-0000-0000-0000-',RIGHT('000000000000'+CONVERT(VARCHAR(12),@N*10+@J),12)));
    SET @Json=CONCAT('[',@Elegida,']');
    EXEC dbo.sp_RealizarApuesta @IdUsuario=@Usuario,@SeleccionesJson=@Json,@Monto=@Minimo,@ReferenciaOperacion=@Ref,
      @PronosticoA=@PA,@PronosticoB=@PB;
    SET @J+=1;
   END;
   IF @N=7
     EXEC dbo.sp_AnularResultadoEvento @IdUsuarioProceso=@Admin,@IdResultadoEvento=NULL,
       @Motivo='Cancelacion de demostracion.',@IdEventoCancelar=@Evento;
   ELSE IF @N>=3
   BEGIN
    EXEC dbo.sp_IniciarSimulacionEvento @Admin,@Evento;
    SET @Inc=1; SET @IncTotal=CASE WHEN @N=6 THEN 0 WHEN @N=3 THEN 1 WHEN @N=8 THEN 4 ELSE 3 END;
    WHILE @Inc<=@IncTotal
    BEGIN
     SET @Participante=CASE WHEN @Inc<=2 THEN @A ELSE @B END;
     SET @Ref=CONVERT(UNIQUEIDENTIFIER,CONCAT('B3000000-0000-0000-0000-',RIGHT('000000000000'+CONVERT(VARCHAR(12),@N*10+@Inc),12)));
     EXEC dbo.sp_RegistrarIncidenciaEvento @Admin,@Evento,'ANOTACION',@Ref,@Participante,1;
     SET @Inc+=1;
    END;
    IF @N>=4
    BEGIN
     EXEC dbo.sp_FinalizarSimulacionEvento @Admin,@Evento;
     SELECT @Resultado=IdResultado FROM dbo.ResultadoEvento WHERE IdEvento=@Evento;
     IF @N>=5 EXEC dbo.sp_OficializarResultadoEvento @Admin,@Resultado;
    END;
   END;
   IF @N>=5
   BEGIN
    SET @J=1;
    WHILE @J<=@Total
    BEGIN
     SET @Ref=CONVERT(UNIQUEIDENTIFIER,CONCAT('A3000000-0000-0000-0000-',RIGHT('000000000000'+CONVERT(VARCHAR(12),@N*10+@J),12)));
     SELECT @Boleto=IdBoleto FROM dbo.Boleto WHERE ReferenciaOperacion=@Ref;
     EXEC dbo.sp_LiquidarBoleto @Admin,@Boleto;
     SET @J+=1;
    END;
   END;
  END;
  SET @N+=1;
 END;
 COMMIT;
 PRINT 'Escenarios V2 preparados. PREVIA es una clasificacion visual, no un estado nuevo.';
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
