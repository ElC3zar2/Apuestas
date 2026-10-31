/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   SQL SERVER 2022 / AZURE SQL

   ARCHIVO:
   03_PROCEDIMIENTOS/04_EventosMercados.sql

   OBJETIVO:
   Centralizar la administración del catálogo deportivo y la
   construcción operativa de eventos, mercados, selecciones
   y cuotas.

   INCLUYE:
   - Validación de permisos del módulo.
   - Creación y actualización de ligas.
   - Creación y actualización de participantes.
   - Creación y actualización de eventos.
   - Asociación de participantes a eventos.
   - Creación de mercados.
   - Creación de selecciones.
   - Registro histórico de cuotas.
   - Cambios controlados de estado de evento y mercado.

   ROLES AUTORIZADOS:
   - ADMINISTRADOR
   - OPERADOR_EVENTOS

   REGLAS:
   - Las operaciones sensibles quedan auditadas.
   - No se utilizan IdEstado fijos.
   - Los estados se resuelven por TipoEstado + Codigo.
   - Las cuotas mantienen histórico.
   - Registrar una nueva cuota cierra la cuota activa anterior.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* FASE 2: plantilla compacta versionada en ConfiguracionSistema. Sin valores
   iniciales. Auxiliar sin result sets; se invoca dentro del cerrojo comun.
   Clave BETZONE_1X2:<IdDeporte>; JSON v=version, l/x/d=cuotas, h/a=bits. */
CREATE OR ALTER PROCEDURE dbo.sp_LeerPlantillaConvencional1X2
    @IdDeporte INT, @Existe BIT OUTPUT, @Valida BIT OUTPUT,
    @Version UNIQUEIDENTIFIER OUTPUT, @Local DECIMAL(10,4) OUTPUT,
    @Empate DECIMAL(10,4) OUTPUT, @Visitante DECIMAL(10,4) OUTPUT,
    @Habilitada BIT OUTPUT, @Aprobada BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Json VARCHAR(150);
    SELECT @Json=Valor FROM dbo.ConfiguracionSistema WITH (UPDLOCK,HOLDLOCK)
      WHERE Clave=CONCAT('BETZONE_1X2:',@IdDeporte);
    SELECT @Existe=CASE WHEN @Json IS NULL THEN 0 ELSE 1 END,@Valida=0,
      @Version=NULL,@Local=NULL,@Empate=NULL,@Visitante=NULL,@Habilitada=0,@Aprobada=0;
    IF ISJSON(@Json)<>1 OR @Json IS NULL RETURN;
    IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>6
       OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [key] NOT IN ('v','l','x','d','h','a')) RETURN;
    SET @Version=TRY_CONVERT(UNIQUEIDENTIFIER,JSON_VALUE(@Json,'$.v'));
    IF LEN(JSON_VALUE(@Json,'$.v'))<>36 OR @Version IS NULL RETURN;
    IF JSON_VALUE(@Json,'$.h') NOT IN ('0','1') OR JSON_VALUE(@Json,'$.h') IS NULL
       OR JSON_VALUE(@Json,'$.a') NOT IN ('0','1') OR JSON_VALUE(@Json,'$.a') IS NULL RETURN;
    IF EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [key] IN ('l','x','d') AND
      ([value] IS NULL OR [value] LIKE '%[^0-9.]%'
       OR (CHARINDEX('.',[value])>0 AND LEN([value])-CHARINDEX('.',[value])>4)
       OR TRY_CONVERT(DECIMAL(10,4),[value]) IS NULL OR TRY_CONVERT(DECIMAL(10,4),[value])<=1)) RETURN;
    SELECT @Local=TRY_CONVERT(DECIMAL(10,4),JSON_VALUE(@Json,'$.l')),
      @Empate=TRY_CONVERT(DECIMAL(10,4),JSON_VALUE(@Json,'$.x')),
      @Visitante=TRY_CONVERT(DECIMAL(10,4),JSON_VALUE(@Json,'$.d')),
      @Habilitada=CONVERT(BIT,JSON_VALUE(@Json,'$.h')),@Aprobada=CONVERT(BIT,JSON_VALUE(@Json,'$.a'));
    IF @Local IS NOT NULL AND @Empate IS NOT NULL AND @Visitante IS NOT NULL SET @Valida=1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ConsultarPlantillaConvencional1X2
    @IdUsuarioProceso INT, @IdDeporte INT, @IpOrigen VARCHAR(45)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Lock INT;
        EXEC @Lock=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
          @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @Lock<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;
        EXEC dbo.sp_ValidarPermisoEventos @IdUsuarioProceso;
        IF NOT EXISTS(SELECT 1 FROM dbo.Deporte WHERE IdDeporte=@IdDeporte)
          THROW 76710,'El recurso de catalogo no existe.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.Deporte WHERE IdDeporte=@IdDeporte AND Activo=1
          AND Nombre COLLATE Latin1_General_100_CI_AI='Futbol')
          THROW 76701,'El flujo 1X2 requiere el deporte Futbol activo.',1;
        DECLARE @Existe BIT,@Valida BIT,@Version UNIQUEIDENTIFIER,@L DECIMAL(10,4),@X DECIMAL(10,4),@D DECIMAL(10,4),@H BIT,@A BIT;
        EXEC dbo.sp_LeerPlantillaConvencional1X2 @IdDeporte,@Existe OUTPUT,@Valida OUTPUT,
          @Version OUTPUT,@L OUTPUT,@X OUTPUT,@D OUTPUT,@H OUTPUT,@A OUTPUT;
        COMMIT;
        SELECT @IdDeporte AS IdDeporte,CONCAT('BETZONE_1X2:',@IdDeporte) AS IdentidadPlantilla,
          @Existe AS Existe,@Valida AS Valida,CONVERT(VARCHAR(36),@Version) AS VersionPlantilla,
          @L AS CuotaLocal,@X AS CuotaEmpate,@D AS CuotaVisitante,@H AS Habilitada,@A AS Aprobada;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GuardarPlantillaConvencional1X2
    @IdUsuarioProceso INT, @IdDeporte INT, @CuotaLocal DECIMAL(10,4),
    @CuotaEmpate DECIMAL(10,4), @CuotaVisitante DECIMAL(10,4),
    @Habilitada BIT, @Aprobada BIT, @VersionEsperada UNIQUEIDENTIFIER,
    @ReferenciaOperacion UNIQUEIDENTIFIER, @IpOrigen VARCHAR(45)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CuotaLocal IS NULL OR @CuotaEmpate IS NULL OR @CuotaVisitante IS NULL
       OR @CuotaLocal<=1 OR @CuotaEmpate<=1 OR @CuotaVisitante<=1
       OR @Habilitada IS NULL OR @Aprobada IS NULL OR @ReferenciaOperacion IS NULL
      THROW 76700,'Parametros de plantilla invalidos.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Lock INT;
        EXEC @Lock=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
          @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @Lock<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;
        EXEC dbo.sp_ValidarPermisoEventos @IdUsuarioProceso;
        IF NOT EXISTS(SELECT 1 FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
          WHERE U.IdUsuario=@IdUsuarioProceso AND R.Nombre='ADMINISTRADOR')
          THROW 76702,'Solo ADMINISTRADOR puede aprobar o modificar plantillas.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.Deporte WHERE IdDeporte=@IdDeporte)
          THROW 76710,'El recurso de catalogo no existe.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.Deporte WHERE IdDeporte=@IdDeporte AND Activo=1
          AND Nombre COLLATE Latin1_General_100_CI_AI='Futbol')
          THROW 76701,'El flujo 1X2 requiere el deporte Futbol activo.',1;
        DECLARE @Existe BIT,@Valida BIT,@Version UNIQUEIDENTIFIER,@L DECIMAL(10,4),@X DECIMAL(10,4),@D DECIMAL(10,4),@H BIT,@A BIT;
        EXEC dbo.sp_LeerPlantillaConvencional1X2 @IdDeporte,@Existe OUTPUT,@Valida OUTPUT,
          @Version OUTPUT,@L OUTPUT,@X OUTPUT,@D OUTPUT,@H OUTPUT,@A OUTPUT;
        IF (@VersionEsperada IS NULL AND @Existe=1) OR (@VersionEsperada IS NOT NULL
          AND (@Version IS NULL OR @VersionEsperada<>@Version))
          THROW 76703,'La plantilla cambio; consulte su version antes de actualizar.',1;
        IF EXISTS(SELECT 1 FROM dbo.Auditoria WITH (UPDLOCK,HOLDLOCK) WHERE ReferenciaOperacion=@ReferenciaOperacion)
          THROW 76704,'La referencia ya fue utilizada; consulte el resultado antes de otra operacion.',1;
        DECLARE @Clave VARCHAR(100)=CONCAT('BETZONE_1X2:',@IdDeporte);
        DECLARE @Json VARCHAR(MAX)=CONCAT('{"v":"',CONVERT(VARCHAR(36),@ReferenciaOperacion),
          '","l":',@CuotaLocal,',"x":',@CuotaEmpate,',"d":',@CuotaVisitante,',"h":',CONVERT(INT,@Habilitada),',"a":',CONVERT(INT,@Aprobada),'}');
        IF LEN(@Json)>150 THROW 76790,'La plantilla excede el contrato de configuracion.',1;
        UPDATE dbo.ConfiguracionSistema SET Valor=@Json,Descripcion='Plantilla convencional 1X2 de futbol; aprobacion administrativa explicita.',
          FechaModificacion=SYSDATETIME() WHERE Clave=@Clave;
        IF @@ROWCOUNT=0 INSERT dbo.ConfiguracionSistema(Clave,Valor,Descripcion)
          VALUES(@Clave,@Json,'Plantilla convencional 1X2 de futbol; aprobacion administrativa explicita.');
        INSERT dbo.Auditoria(IdUsuario,Accion,TablaAfectada,IdRegistro,ReferenciaOperacion,IpOrigen,Descripcion)
          VALUES(@IdUsuarioProceso,'PLANTILLA_1X2_GUARDADA','ConfiguracionSistema',
            (SELECT IdConfiguracion FROM dbo.ConfiguracionSistema WHERE Clave=@Clave),
            @ReferenciaOperacion,@IpOrigen,CONCAT('Deporte=',@IdDeporte,'; anterior=',CONVERT(VARCHAR(36),@Version),'; nueva=',@Json));
        COMMIT;
        SELECT @IdDeporte AS IdDeporte,@Clave AS IdentidadPlantilla,CAST(1 AS BIT) AS Existe,CAST(1 AS BIT) AS Valida,
          CONVERT(VARCHAR(36),@ReferenciaOperacion) AS VersionPlantilla,@CuotaLocal AS CuotaLocal,
          @CuotaEmpate AS CuotaEmpate,@CuotaVisitante AS CuotaVisitante,@Habilitada AS Habilitada,@Aprobada AS Aprobada;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CrearEventoConvencional1X2
    @IdUsuarioProceso INT, @IdDeporte INT, @IdLiga INT,
    @IdParticipanteLocal INT, @IdParticipanteVisitante INT, @FechaInicio DATETIME2,
    @VersionPlantilla UNIQUEIDENTIFIER, @ReferenciaOperacion UNIQUEIDENTIFIER, @IpOrigen VARCHAR(45)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @IdDeporte IS NULL OR @IdLiga IS NULL OR @IdParticipanteLocal IS NULL OR @IdParticipanteVisitante IS NULL
      OR @IdParticipanteLocal=@IdParticipanteVisitante OR @FechaInicio IS NULL
      OR @VersionPlantilla IS NULL OR @ReferenciaOperacion IS NULL
      THROW 76700,'Parametros de creacion 1X2 invalidos.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Lock INT;
        EXEC @Lock=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
          @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @Lock<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;
        EXEC dbo.sp_ValidarPermisoEventos @IdUsuarioProceso;
        DECLARE @IdEvento INT,@IdMercado INT,@S1 INT,@SX INT,@S2 INT,@Registro VARCHAR(500),@Actor INT,
          @IdAuditoria BIGINT,@IdEventoAuditoria BIGINT,@Recuperada BIT=0;
        SELECT @IdAuditoria=IdAuditoria,@Actor=IdUsuario,@IdEventoAuditoria=IdRegistro,@Registro=Descripcion
          FROM dbo.Auditoria WITH (UPDLOCK,HOLDLOCK) WHERE ReferenciaOperacion=@ReferenciaOperacion
          AND Accion='EVENTO_CONVENCIONAL_1X2' AND TablaAfectada='Evento';
        IF @IdAuditoria IS NOT NULL
        BEGIN
            IF (SELECT COUNT(*) FROM dbo.Auditoria WHERE ReferenciaOperacion=@ReferenciaOperacion)<>1
              OR @Registro IS NULL OR ISJSON(@Registro)<>1 THROW 76790,'Auditoria de creacion inconsistente.',1;
            IF @Actor IS NULL OR @IdEventoAuditoria IS NULL
              OR TRY_CONVERT(INT,JSON_VALUE(@Registro,'$.d')) IS NULL
              OR TRY_CONVERT(INT,JSON_VALUE(@Registro,'$.l')) IS NULL
              OR TRY_CONVERT(INT,JSON_VALUE(@Registro,'$.p')) IS NULL
              OR TRY_CONVERT(INT,JSON_VALUE(@Registro,'$.q')) IS NULL
              OR TRY_CONVERT(DATETIME2,JSON_VALUE(@Registro,'$.f'),126) IS NULL
              OR TRY_CONVERT(UNIQUEIDENTIFIER,JSON_VALUE(@Registro,'$.v')) IS NULL
              THROW 76790,'Identidad auditada incompleta.',1;
            IF @Actor<>@IdUsuarioProceso OR TRY_CONVERT(INT,JSON_VALUE(@Registro,'$.d'))<>@IdDeporte
              OR TRY_CONVERT(INT,JSON_VALUE(@Registro,'$.l'))<>@IdLiga
              OR TRY_CONVERT(INT,JSON_VALUE(@Registro,'$.p'))<>@IdParticipanteLocal
              OR TRY_CONVERT(INT,JSON_VALUE(@Registro,'$.q'))<>@IdParticipanteVisitante
              OR TRY_CONVERT(DATETIME2,JSON_VALUE(@Registro,'$.f'),126)<>@FechaInicio
              OR TRY_CONVERT(UNIQUEIDENTIFIER,JSON_VALUE(@Registro,'$.v'))<>@VersionPlantilla
              THROW 76704,'La referencia pertenece a otra solicitud.',1;
            SET @IdEvento=TRY_CONVERT(INT,@IdEventoAuditoria);
            SET @Recuperada=1;
        END
        ELSE
        BEGIN
            IF EXISTS(SELECT 1 FROM dbo.Auditoria WITH (UPDLOCK,HOLDLOCK) WHERE ReferenciaOperacion=@ReferenciaOperacion)
              THROW 76704,'La referencia pertenece a otra operacion.',1;
            IF NOT EXISTS(SELECT 1 FROM dbo.Deporte WHERE IdDeporte=@IdDeporte)
              OR NOT EXISTS(SELECT 1 FROM dbo.Liga WHERE IdLiga=@IdLiga)
              OR (SELECT COUNT(*) FROM dbo.Participante WHERE IdParticipante IN (@IdParticipanteLocal,@IdParticipanteVisitante))<>2
              THROW 76710,'El recurso de catalogo no existe.',1;
            IF NOT EXISTS(SELECT 1 FROM dbo.Deporte WITH (UPDLOCK,HOLDLOCK) WHERE IdDeporte=@IdDeporte
              AND Activo=1 AND Nombre COLLATE Latin1_General_100_CI_AI='Futbol')
              THROW 76701,'El flujo 1X2 requiere el deporte Futbol activo.',1;
            IF NOT EXISTS(SELECT 1 FROM dbo.Liga WITH (UPDLOCK,HOLDLOCK) WHERE IdLiga=@IdLiga AND IdDeporte=@IdDeporte AND Activo=1)
              THROW 76705,'La liga no existe, esta inactiva o no corresponde al deporte.',1;
            IF (SELECT COUNT(*) FROM dbo.Participante P WITH (UPDLOCK,HOLDLOCK)
              JOIN dbo.LigaParticipante LP WITH (UPDLOCK,HOLDLOCK) ON LP.IdParticipante=P.IdParticipante AND LP.IdLiga=@IdLiga AND LP.Activo=1
              WHERE P.IdParticipante IN (@IdParticipanteLocal,@IdParticipanteVisitante)
                AND P.IdDeporte=@IdDeporte AND P.Activo=1 AND P.TipoParticipante='EQUIPO')<>2
              THROW 76706,'Se requieren dos equipos activos asociados a la liga y deporte.',1;
            DECLARE @Anticipacion INT,@Ahora DATETIME2=CAST(SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'Central America Standard Time' AS DATETIME2);
            SELECT @Anticipacion=TRY_CONVERT(INT,Valor) FROM dbo.ConfiguracionSistema WITH (UPDLOCK,HOLDLOCK)
              WHERE Clave='ANTICIPACION_CIERRE_APUESTA_MIN';
            IF @Anticipacion IS NULL OR @Anticipacion<0 THROW 76790,'Configuracion de cierre invalida.',1;
            IF @FechaInicio<=@Ahora OR DATEDIFF_BIG(SECOND,@Ahora,@FechaInicio)<=CONVERT(BIGINT,@Anticipacion)*60
              THROW 76707,'El horario no permite publicar un evento apto para apuestas.',1;
            IF EXISTS(SELECT 1 FROM dbo.Evento E WITH (UPDLOCK,HOLDLOCK)
              JOIN dbo.EventoParticipante L ON L.IdEvento=E.IdEvento AND L.IdParticipante=@IdParticipanteLocal AND L.OrdenParticipante=1
              JOIN dbo.EventoParticipante V ON V.IdEvento=E.IdEvento AND V.IdParticipante=@IdParticipanteVisitante AND V.OrdenParticipante=2
              WHERE E.IdLiga=@IdLiga AND E.FechaInicio=@FechaInicio AND E.EsSimulado=0)
              OR EXISTS(SELECT 1 FROM dbo.Auditoria WHERE Accion='EVENTO_CONVENCIONAL_1X2' AND TablaAfectada='Evento'
                AND JSON_VALUE(CASE WHEN ISJSON(Descripcion)=1 THEN Descripcion ELSE '{}' END,'$.l')=CONVERT(VARCHAR(10),@IdLiga)
                AND JSON_VALUE(CASE WHEN ISJSON(Descripcion)=1 THEN Descripcion ELSE '{}' END,'$.p')=CONVERT(VARCHAR(10),@IdParticipanteLocal)
                AND JSON_VALUE(CASE WHEN ISJSON(Descripcion)=1 THEN Descripcion ELSE '{}' END,'$.q')=CONVERT(VARCHAR(10),@IdParticipanteVisitante)
                AND TRY_CONVERT(DATETIME2,JSON_VALUE(CASE WHEN ISJSON(Descripcion)=1 THEN Descripcion ELSE '{}' END,'$.f'),126)=@FechaInicio)
              THROW 76708,'Ya existe una creacion equivalente para liga, local, visitante y horario.',1;
            DECLARE @Existe BIT,@Valida BIT,@Version UNIQUEIDENTIFIER,@C1 DECIMAL(10,4),@CX DECIMAL(10,4),@C2 DECIMAL(10,4),@H BIT,@A BIT;
            EXEC dbo.sp_LeerPlantillaConvencional1X2 @IdDeporte,@Existe OUTPUT,@Valida OUTPUT,
              @Version OUTPUT,@C1 OUTPUT,@CX OUTPUT,@C2 OUTPUT,@H OUTPUT,@A OUTPUT;
            IF @Existe=0 OR @Valida=0 OR @H=0 OR @A=0
              THROW 76709,'Configure y apruebe una plantilla 1X2 valida antes de publicar.',1;
            IF @Version<>@VersionPlantilla THROW 76703,'La plantilla cambio; consulte y revise sus cuotas.',1;
            DECLARE @EstadoEvento INT,@EstadoMercado INT;
            SELECT @EstadoEvento=E.IdEstado FROM dbo.Estado E JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado
              WHERE T.Codigo='EVENTO' AND E.Codigo='PROGRAMADO' AND E.Activo=1;
            SELECT @EstadoMercado=E.IdEstado FROM dbo.Estado E JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado
              WHERE T.Codigo='MERCADO' AND E.Codigo='ABIERTO' AND E.Activo=1;
            IF @EstadoEvento IS NULL OR @EstadoMercado IS NULL THROW 76790,'Faltan estados oficiales para publicacion.',1;
            DECLARE @Nombre VARCHAR(200),@NL VARCHAR(150),@NV VARCHAR(150);
            SELECT @NL=Nombre FROM dbo.Participante WHERE IdParticipante=@IdParticipanteLocal;
            SELECT @NV=Nombre FROM dbo.Participante WHERE IdParticipante=@IdParticipanteVisitante;
            SET @Nombre=LEFT(CONCAT(@NL,' vs ',@NV),200);
            INSERT dbo.Evento(IdLiga,IdEstado,Nombre,FechaInicio,EsSimulado) VALUES(@IdLiga,@EstadoEvento,@Nombre,@FechaInicio,0);
            SET @IdEvento=CONVERT(INT,SCOPE_IDENTITY());
            INSERT dbo.EventoParticipante(IdEvento,IdParticipante,OrdenParticipante,EsLocal)
              VALUES(@IdEvento,@IdParticipanteLocal,1,1),(@IdEvento,@IdParticipanteVisitante,2,0);
            INSERT dbo.Mercado(IdEvento,IdEstado,Nombre,Descripcion,TipoMercado)
              VALUES(@IdEvento,@EstadoMercado,'Resultado final — 1X2','1 LOCAL, X EMPATE, 2 VISITANTE','CONVENCIONAL');
            SET @IdMercado=CONVERT(INT,SCOPE_IDENTITY());
            INSERT dbo.Seleccion(IdMercado,IdEvento,IdParticipante,Nombre,Activo)
              VALUES(@IdMercado,@IdEvento,@IdParticipanteLocal,CASE WHEN LEN(@NL)<=146 THEN CONCAT('1 - ',@NL) ELSE '1 - LOCAL' END,1);
            SET @S1=CONVERT(INT,SCOPE_IDENTITY());
            INSERT dbo.Seleccion(IdMercado,IdEvento,IdParticipante,Nombre,Activo) VALUES(@IdMercado,@IdEvento,NULL,'X - Empate',1);
            SET @SX=CONVERT(INT,SCOPE_IDENTITY());
            INSERT dbo.Seleccion(IdMercado,IdEvento,IdParticipante,Nombre,Activo)
              VALUES(@IdMercado,@IdEvento,@IdParticipanteVisitante,CASE WHEN LEN(@NV)<=146 THEN CONCAT('2 - ',@NV) ELSE '2 - VISITANTE' END,1);
            SET @S2=CONVERT(INT,SCOPE_IDENTITY());
            INSERT dbo.Cuota(IdSeleccion,Valor,Activo) VALUES(@S1,@C1,1),(@SX,@CX,1),(@S2,@C2,1);
            SET @Registro=(SELECT @IdDeporte AS d,@IdLiga AS l,@IdParticipanteLocal AS p,@IdParticipanteVisitante AS q,
              CONVERT(VARCHAR(33),@FechaInicio,126) AS f,@IdMercado AS m,@S1 AS s1,@SX AS sx,@S2 AS s2,
              @C1 AS c1,@CX AS cx,@C2 AS c2,CONVERT(VARCHAR(36),@Version) AS v,
              'PROGRAMADO' AS ee,'ABIERTO' AS em FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
            IF LEN(@Registro)>=500 OR ISJSON(@Registro)<>1 THROW 76790,'El resultado no cabe en la auditoria.',1;
            INSERT dbo.Auditoria(IdUsuario,Accion,TablaAfectada,IdRegistro,ReferenciaOperacion,IpOrigen,Descripcion)
              VALUES(@IdUsuarioProceso,'EVENTO_CONVENCIONAL_1X2','Evento',@IdEvento,@ReferenciaOperacion,@IpOrigen,@Registro);
        END;
        /* La salida recupera el snapshot de creacion; disponibilidad y estados actuales
           se consultan aparte. Un reintento no promete que el partido siga abierto. */
        IF @IdEvento IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.Evento WHERE IdEvento=@IdEvento)
          THROW 76790,'El evento auditado no esta disponible.',1;
        SELECT @IdMercado=TRY_CONVERT(INT,JSON_VALUE(@Registro,'$.m')),
          @S1=TRY_CONVERT(INT,JSON_VALUE(@Registro,'$.s1')),@SX=TRY_CONVERT(INT,JSON_VALUE(@Registro,'$.sx')),
          @S2=TRY_CONVERT(INT,JSON_VALUE(@Registro,'$.s2'));
        DECLARE @Salida TABLE(IdEvento INT,IdDeporte INT,IdLiga INT,IdParticipanteLocal INT,IdParticipanteVisitante INT,
          FechaInicio DATETIME2,Nombre VARCHAR(200),Deporte VARCHAR(100),Liga VARCHAR(150),[Local] VARCHAR(150),Visitante VARCHAR(150),
          EstadoEvento VARCHAR(40),IdMercado INT,TipoMercado VARCHAR(30),EstadoMercado VARCHAR(40),
          IdSeleccionLocal INT,IdSeleccionEmpate INT,IdSeleccionVisitante INT,CuotaLocal DECIMAL(10,4),CuotaEmpate DECIMAL(10,4),CuotaVisitante DECIMAL(10,4),
          ReferenciaOperacion VARCHAR(36),IdentidadPlantilla VARCHAR(100),VersionPlantilla VARCHAR(36),SolicitudIdempotente BIT,
          EstadoEventoActual VARCHAR(40),EstadoMercadoActual VARCHAR(40),DisponibleParaApuestas BIT);
        INSERT @Salida SELECT @IdEvento,@IdDeporte,@IdLiga,@IdParticipanteLocal,@IdParticipanteVisitante,@FechaInicio,E.Nombre,D.Nombre,L.Nombre,PL.Nombre,PV.Nombre,
          JSON_VALUE(@Registro,'$.ee'),@IdMercado,M.TipoMercado,JSON_VALUE(@Registro,'$.em'),@S1,@SX,@S2,
          TRY_CONVERT(DECIMAL(10,4),JSON_VALUE(@Registro,'$.c1')),TRY_CONVERT(DECIMAL(10,4),JSON_VALUE(@Registro,'$.cx')),TRY_CONVERT(DECIMAL(10,4),JSON_VALUE(@Registro,'$.c2')),
          CONVERT(VARCHAR(36),@ReferenciaOperacion),CONCAT('BETZONE_1X2:',@IdDeporte),JSON_VALUE(@Registro,'$.v'),@Recuperada,EE.Codigo,EM.Codigo,
          CONVERT(BIT,CASE WHEN EE.Codigo='PROGRAMADO' AND EM.Codigo='ABIERTO'
            AND DATEDIFF_BIG(SECOND,CAST(SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'Central America Standard Time' AS DATETIME2),E.FechaInicio)>
              CONVERT(BIGINT,TRY_CONVERT(INT,(SELECT Valor FROM dbo.ConfiguracionSistema WHERE Clave='ANTICIPACION_CIERRE_APUESTA_MIN')))*60
            AND (SELECT COUNT(*) FROM dbo.Seleccion S WHERE S.IdMercado=M.IdMercado AND S.Activo=1)=3
            AND NOT EXISTS(SELECT 1 FROM dbo.Seleccion S WHERE S.IdMercado=M.IdMercado AND S.Activo=1
              AND (SELECT COUNT(*) FROM dbo.Cuota C WHERE C.IdSeleccion=S.IdSeleccion AND C.Activo=1 AND C.Valor>1)<>1)
            THEN 1 ELSE 0 END)
          FROM dbo.Evento E JOIN dbo.Liga L ON L.IdLiga=@IdLiga JOIN dbo.Deporte D ON D.IdDeporte=@IdDeporte
          JOIN dbo.Participante PL ON PL.IdParticipante=@IdParticipanteLocal JOIN dbo.Participante PV ON PV.IdParticipante=@IdParticipanteVisitante
          JOIN dbo.Mercado M ON M.IdMercado=@IdMercado AND M.IdEvento=E.IdEvento
          JOIN dbo.Estado EE ON EE.IdEstado=E.IdEstado JOIN dbo.Estado EM ON EM.IdEstado=M.IdEstado
          WHERE E.IdEvento=@IdEvento;
        IF @@ROWCOUNT<>1 THROW 76790,'Resultado de creacion inconsistente.',1;
        IF @Recuperada=0 AND EXISTS(SELECT 1 FROM @Salida WHERE DisponibleParaApuestas=0)
          THROW 76707,'El periodo de apuestas cerro durante la preparacion; no se publico el evento.',1;
        COMMIT;
        SELECT * FROM @Salida;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   1. VALIDAR PERMISO DEL MODULO DE EVENTOS

   Procedimiento auxiliar utilizado por los demás procedimientos
   de este archivo.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ValidarPermisoEventos
(
    @IdUsuarioProceso INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @IdUsuarioProceso IS NULL
        THROW 59001, 'IdUsuarioProceso es obligatorio.', 1;

    DECLARE @Rol VARCHAR(50);
    DECLARE @EstadoUsuario VARCHAR(40);

    SELECT
        @Rol = R.Nombre,
        @EstadoUsuario = E.Codigo
    FROM dbo.Usuario AS U
    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol
    INNER JOIN dbo.Estado AS E
        ON E.IdEstado = U.IdEstado
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
       AND TE.Codigo = 'USUARIO'
    WHERE U.IdUsuario = @IdUsuarioProceso;

    IF @Rol IS NULL
        THROW 59002, 'El usuario que procesa la operación no existe.', 1;

    IF @Rol NOT IN ('ADMINISTRADOR', 'OPERADOR_EVENTOS')
        THROW 59003, 'El usuario no tiene permisos para administrar eventos y mercados.', 1;

    IF @EstadoUsuario <> 'ACTIVO'
        THROW 59004, 'El usuario que procesa la operación debe estar ACTIVO.', 1;
END;
GO


/* ============================================================
   2. CREAR LIGA
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CrearLiga
(
    @IdUsuarioProceso INT,
    @IdDeporte INT,
    @Nombre VARCHAR(150),
    @IdPais INT = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @Nombre IS NULL
        THROW 59005, 'El nombre de la liga es obligatorio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Deporte
        WHERE IdDeporte = @IdDeporte
          AND Activo = 1
    )
        THROW 59006, 'El deporte indicado no existe o está inactivo.', 1;

    IF @IdPais IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Pais
           WHERE IdPais = @IdPais
             AND Activo = 1
       )
        THROW 59007, 'El país indicado no existe o está inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;


        IF EXISTS
        (
            SELECT 1
            FROM dbo.Liga WITH (UPDLOCK, HOLDLOCK)
            WHERE IdDeporte = @IdDeporte
              AND Nombre = @Nombre
        )
            THROW 59008, 'Ya existe una liga con ese nombre para el deporte indicado.', 1;

        INSERT INTO dbo.Liga
        (
            IdDeporte,
            IdPais,
            Nombre,
            Activo
        )
        VALUES
        (
            @IdDeporte,
            @IdPais,
            @Nombre,
            1
        );

        DECLARE @IdLiga INT =
            CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'LIGA_CREADA',
            'Liga',
            @IdLiga,
            @IpOrigen,
            CONCAT('Liga creada: ', @Nombre, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            @IdLiga AS IdLiga,
            @IdDeporte AS IdDeporte,
            @IdPais AS IdPais,
            @Nombre AS Nombre,
            CAST(1 AS BIT) AS Activo;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   3. ACTUALIZAR LIGA
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ActualizarLiga
(
    @IdUsuarioProceso INT,
    @IdLiga INT,
    @Nombre VARCHAR(150),
    @IdPais INT = NULL,
    @Activo BIT,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @IdLiga IS NULL
        THROW 59009, 'IdLiga es obligatorio.', 1;

    IF @Nombre IS NULL
        THROW 59010, 'El nombre de la liga es obligatorio.', 1;

    IF @Activo IS NULL
        THROW 59011, 'Activo es obligatorio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    IF @IdPais IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Pais
           WHERE IdPais = @IdPais
             AND Activo = 1
       )
        THROW 59012, 'El país indicado no existe o está inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;


        DECLARE @IdDeporte INT;

        SELECT @IdDeporte = IdDeporte
        FROM dbo.Liga WITH (UPDLOCK, HOLDLOCK)
        WHERE IdLiga = @IdLiga;

        IF @IdDeporte IS NULL
            THROW 59013, 'La liga indicada no existe.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Liga
            WHERE IdDeporte = @IdDeporte
              AND Nombre = @Nombre
              AND IdLiga <> @IdLiga
        )
            THROW 59014, 'Ya existe otra liga con ese nombre para el mismo deporte.', 1;

        IF @Activo = 0
           AND EXISTS
           (
               SELECT 1
               FROM dbo.Evento
               WHERE IdLiga = @IdLiga
           )
            THROW 59015, 'No se puede desactivar una liga que ya tiene eventos registrados.', 1;

        UPDATE dbo.Liga
        SET
            Nombre = @Nombre,
            IdPais = @IdPais,
            Activo = @Activo
        WHERE IdLiga = @IdLiga;

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'LIGA_ACTUALIZADA',
            'Liga',
            @IdLiga,
            @IpOrigen,
            CONCAT('Liga actualizada: ', @Nombre, '. Activo=', @Activo, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            IdLiga,
            IdDeporte,
            IdPais,
            Nombre,
            Activo
        FROM dbo.Liga
        WHERE IdLiga = @IdLiga;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   4. CREAR PARTICIPANTE
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CrearParticipante
(
    @IdUsuarioProceso INT,
    @IdDeporte INT,
    @Nombre VARCHAR(150),
    @TipoParticipante VARCHAR(30),
    @IdPais INT = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @TipoParticipante =
        NULLIF(UPPER(LTRIM(RTRIM(@TipoParticipante))), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @Nombre IS NULL
        THROW 59016, 'El nombre del participante es obligatorio.', 1;

    IF @TipoParticipante IS NULL
       OR @TipoParticipante NOT IN ('EQUIPO', 'ATLETA')
        THROW 59017, 'TipoParticipante debe ser EQUIPO o ATLETA.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Deporte
        WHERE IdDeporte = @IdDeporte
          AND Activo = 1
    )
        THROW 59018, 'El deporte indicado no existe o está inactivo.', 1;

    IF @IdPais IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Pais
           WHERE IdPais = @IdPais
             AND Activo = 1
       )
        THROW 59019, 'El país indicado no existe o está inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;


        IF EXISTS
        (
            SELECT 1
            FROM dbo.Participante WITH (UPDLOCK, HOLDLOCK)
            WHERE IdDeporte = @IdDeporte
              AND Nombre = @Nombre
              AND TipoParticipante = @TipoParticipante
        )
            THROW 59020, 'Ya existe ese participante para el deporte indicado.', 1;

        INSERT INTO dbo.Participante
        (
            IdDeporte,
            IdPais,
            Nombre,
            TipoParticipante,
            Activo
        )
        VALUES
        (
            @IdDeporte,
            @IdPais,
            @Nombre,
            @TipoParticipante,
            1
        );

        DECLARE @IdParticipante INT =
            CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'PARTICIPANTE_CREADO',
            'Participante',
            @IdParticipante,
            @IpOrigen,
            CONCAT('Participante creado: ', @Nombre, ' (', @TipoParticipante, ').')
        );

        COMMIT TRANSACTION;

        SELECT
            @IdParticipante AS IdParticipante,
            @IdDeporte AS IdDeporte,
            @IdPais AS IdPais,
            @Nombre AS Nombre,
            @TipoParticipante AS TipoParticipante,
            CAST(1 AS BIT) AS Activo;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   5. ACTUALIZAR PARTICIPANTE
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ActualizarParticipante
(
    @IdUsuarioProceso INT,
    @IdParticipante INT,
    @Nombre VARCHAR(150),
    @IdPais INT = NULL,
    @Activo BIT,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @IdParticipante IS NULL
        THROW 59021, 'IdParticipante es obligatorio.', 1;

    IF @Nombre IS NULL
        THROW 59022, 'El nombre del participante es obligatorio.', 1;

    IF @Activo IS NULL
        THROW 59023, 'Activo es obligatorio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    IF @IdPais IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.Pais
           WHERE IdPais = @IdPais
             AND Activo = 1
       )
        THROW 59024, 'El país indicado no existe o está inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;


        DECLARE @IdDeporte INT;
        DECLARE @TipoParticipante VARCHAR(30);

        SELECT
            @IdDeporte = IdDeporte,
            @TipoParticipante = TipoParticipante
        FROM dbo.Participante WITH (UPDLOCK, HOLDLOCK)
        WHERE IdParticipante = @IdParticipante;

        IF @IdDeporte IS NULL
            THROW 59025, 'El participante indicado no existe.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Participante
            WHERE IdDeporte = @IdDeporte
              AND Nombre = @Nombre
              AND TipoParticipante = @TipoParticipante
              AND IdParticipante <> @IdParticipante
        )
            THROW 59026, 'Ya existe otro participante con ese nombre para el mismo deporte.', 1;

        IF @Activo = 0
           AND EXISTS
           (
               SELECT 1
               FROM dbo.EventoParticipante
               WHERE IdParticipante = @IdParticipante
           )
            THROW 59027, 'No se puede desactivar un participante que ya está asociado a eventos.', 1;

        UPDATE dbo.Participante
        SET
            Nombre = @Nombre,
            IdPais = @IdPais,
            Activo = @Activo
        WHERE IdParticipante = @IdParticipante;

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'PARTICIPANTE_ACTUALIZADO',
            'Participante',
            @IdParticipante,
            @IpOrigen,
            CONCAT('Participante actualizado: ', @Nombre, '. Activo=', @Activo, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            IdParticipante,
            IdDeporte,
            IdPais,
            Nombre,
            TipoParticipante,
            Activo
        FROM dbo.Participante
        WHERE IdParticipante = @IdParticipante;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   6. CREAR EVENTO
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CrearEvento
(
    @IdUsuarioProceso INT,
    @IdLiga INT,
    @Nombre VARCHAR(200),
    @FechaInicio DATETIME2,
    @FechaFin DATETIME2 = NULL,
    @IpOrigen VARCHAR(45) = NULL,
    @EsSimulado BIT = 0,
    @DuracionSimulacionSegundos INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @Nombre IS NULL
        THROW 59028, 'El nombre del evento es obligatorio.', 1;

    IF @FechaInicio IS NULL
        THROW 59029, 'FechaInicio es obligatoria.', 1;

    IF @FechaFin IS NOT NULL
       AND @FechaFin <= @FechaInicio
        THROW 59030, 'FechaFin debe ser posterior a FechaInicio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Liga
        WHERE IdLiga = @IdLiga
          AND Activo = 1
    )
        THROW 59031, 'La liga indicada no existe o está inactiva.', 1;

    DECLARE @IdEstadoBorrador INT;

    SELECT @IdEstadoBorrador = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'EVENTO'
      AND E.Codigo = 'BORRADOR'
      AND E.Activo = 1;

    IF @IdEstadoBorrador IS NULL
        THROW 59032, 'No existe el estado EVENTO/BORRADOR.', 1;

    IF @EsSimulado=1 AND @DuracionSimulacionSegundos IS NULL
        SELECT @DuracionSimulacionSegundos=TRY_CONVERT(INT,Valor) FROM dbo.ConfiguracionSistema WHERE Clave='DURACION_SIMULACION_SEGUNDOS';
    IF @EsSimulado IS NULL OR (@EsSimulado=1 AND (@DuracionSimulacionSegundos IS NULL OR @DuracionSimulacionSegundos<=0))
       OR (@EsSimulado=0 AND @DuracionSimulacionSegundos IS NOT NULL)
        THROW 76001,'Duracion de simulacion invalida.',1;
    IF @EsSimulado=1 AND NOT EXISTS(SELECT 1 FROM dbo.Liga L JOIN dbo.Deporte D ON D.IdDeporte=L.IdDeporte
        WHERE L.IdLiga=@IdLiga AND D.UnidadMarcador IS NOT NULL)
        THROW 76002,'El deporte no admite esta simulacion de marcador.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;


        INSERT INTO dbo.Evento
        (
            IdLiga,
            IdEstado,
            Nombre,
            FechaInicio,
            FechaFin, EsSimulado, DuracionSimulacionSegundos
        )
        VALUES
        (
            @IdLiga,
            @IdEstadoBorrador,
            @Nombre,
            @FechaInicio,
            @FechaFin, @EsSimulado, @DuracionSimulacionSegundos
        );

        DECLARE @IdEvento INT =
            CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'EVENTO_CREADO',
            'Evento',
            @IdEvento,
            @IpOrigen,
            CONCAT('Evento creado en estado BORRADOR: ', @Nombre, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            @IdEvento AS IdEvento,
            @IdLiga AS IdLiga,
            @IdEstadoBorrador AS IdEstado,
            'BORRADOR' AS EstadoEvento,
            @Nombre AS Nombre,
            @FechaInicio AS FechaInicio,
            @FechaFin AS FechaFin;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   7. ACTUALIZAR EVENTO

   No cambia la liga ni los participantes.
   Se limita a datos descriptivos y fechas.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ActualizarEvento
(
    @IdUsuarioProceso INT,
    @IdEvento INT,
    @Nombre VARCHAR(200),
    @FechaInicio DATETIME2,
    @FechaFin DATETIME2 = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @IdEvento IS NULL
        THROW 59033, 'IdEvento es obligatorio.', 1;

    IF @Nombre IS NULL
        THROW 59034, 'El nombre del evento es obligatorio.', 1;

    IF @FechaInicio IS NULL
        THROW 59035, 'FechaInicio es obligatoria.', 1;

    IF @FechaFin IS NOT NULL
       AND @FechaFin <= @FechaInicio
        THROW 59036, 'FechaFin debe ser posterior a FechaInicio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    BEGIN TRY
        BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;


        DECLARE @EstadoActual VARCHAR(40);

        SELECT @EstadoActual = E.Codigo
        FROM dbo.Evento AS EV WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = EV.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'EVENTO'
        WHERE EV.IdEvento = @IdEvento;

        IF @EstadoActual IS NULL
            THROW 59037, 'El evento indicado no existe.', 1;

        IF @EstadoActual NOT IN ('BORRADOR', 'PROGRAMADO', 'SUSPENDIDO')
            THROW 59038, 'El evento ya no puede modificar sus datos generales en su estado actual.', 1;

        IF EXISTS(SELECT 1 FROM dbo.Evento WHERE IdEvento=@IdEvento AND FechaInicioRealUtc IS NOT NULL)
            THROW 76003,'No se reprograma un evento que ya inicio.',1;
        INSERT dbo.Auditoria(IdUsuario,Accion,TablaAfectada,IdRegistro,IpOrigen,Descripcion)
        SELECT @IdUsuarioProceso,'EVENTO_REPROGRAMADO','Evento',IdEvento,@IpOrigen,
               CONCAT('Inicio anterior=',CONVERT(VARCHAR(33),FechaInicio,126),'; nuevo=',CONVERT(VARCHAR(33),@FechaInicio,126))
        FROM dbo.Evento WHERE IdEvento=@IdEvento AND FechaInicio<>@FechaInicio;
        UPDATE dbo.Evento
        SET
            Nombre = @Nombre,
            FechaInicio = @FechaInicio,
            FechaFin = @FechaFin
        WHERE IdEvento = @IdEvento;

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'EVENTO_ACTUALIZADO',
            'Evento',
            @IdEvento,
            @IpOrigen,
            CONCAT('Evento actualizado: ', @Nombre, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            EV.IdEvento,
            EV.IdLiga,
            EV.IdEstado,
            E.Codigo AS EstadoEvento,
            EV.Nombre,
            EV.FechaInicio,
            EV.FechaFin
        FROM dbo.Evento AS EV
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = EV.IdEstado
        WHERE EV.IdEvento = @IdEvento;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   8. AGREGAR PARTICIPANTE A EVENTO

   Solo se permite mientras el evento está en BORRADOR.
   También valida que participante y liga pertenezcan al mismo
   deporte.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_AgregarParticipanteEvento
(
    @IdUsuarioProceso INT,
    @IdEvento INT,
    @IdParticipante INT,
    @OrdenParticipante TINYINT,
    @EsLocal BIT = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @OrdenParticipante IS NULL OR @OrdenParticipante <= 0
        THROW 59039, 'OrdenParticipante debe ser mayor que cero.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    BEGIN TRY
        BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;


        DECLARE @EstadoEvento VARCHAR(40);
        DECLARE @IdDeporteEvento INT;
        DECLARE @IdDeporteParticipante INT;

        SELECT
            @EstadoEvento = E.Codigo,
            @IdDeporteEvento = L.IdDeporte
        FROM dbo.Evento AS EV WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = EV.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'EVENTO'
        INNER JOIN dbo.Liga AS L
            ON L.IdLiga = EV.IdLiga
        WHERE EV.IdEvento = @IdEvento;

        IF @EstadoEvento IS NULL
            THROW 59040, 'El evento indicado no existe.', 1;

        IF @EstadoEvento <> 'BORRADOR'
            THROW 59041, 'Solo se pueden agregar participantes a un evento en BORRADOR.', 1;

        SELECT @IdDeporteParticipante = IdDeporte
        FROM dbo.Participante
        WHERE IdParticipante = @IdParticipante
          AND Activo = 1;

        IF @IdDeporteParticipante IS NULL
            THROW 59042, 'El participante indicado no existe o está inactivo.', 1;

        IF @IdDeporteParticipante <> @IdDeporteEvento
            THROW 59043, 'El participante no pertenece al mismo deporte que la liga del evento.', 1;

        IF NOT EXISTS(SELECT 1 FROM dbo.LigaParticipante LP WITH(UPDLOCK,HOLDLOCK)
          JOIN dbo.Evento EV ON EV.IdLiga=LP.IdLiga
          WHERE EV.IdEvento=@IdEvento AND LP.IdParticipante=@IdParticipante AND LP.Activo=1)
            THROW 76606,'El participante no tiene asociacion activa con la liga del evento.',1;


        IF EXISTS
        (
            SELECT 1
            FROM dbo.EventoParticipante
            WHERE IdEvento = @IdEvento
              AND IdParticipante = @IdParticipante
        )
            THROW 59044, 'El participante ya está asociado al evento.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.EventoParticipante
            WHERE IdEvento = @IdEvento
              AND OrdenParticipante = @OrdenParticipante
        )
            THROW 59045, 'El orden indicado ya está ocupado por otro participante del evento.', 1;

        IF EXISTS(SELECT 1 FROM dbo.Mercado WHERE IdEvento=@IdEvento AND TipoMercado<>'CONVENCIONAL')
            THROW 76004,'Defina participantes antes de crear mercados de modalidades.',1;
        INSERT INTO dbo.EventoParticipante
        (
            IdEvento,
            IdParticipante,
            OrdenParticipante,
            EsLocal
        )
        VALUES
        (
            @IdEvento,
            @IdParticipante,
            @OrdenParticipante,
            @EsLocal
        );

        DECLARE @IdEventoParticipante INT =
            CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'PARTICIPANTE_AGREGADO_EVENTO',
            'EventoParticipante',
            @IdEventoParticipante,
            @IpOrigen,
            CONCAT('Participante ', @IdParticipante, ' agregado al evento ', @IdEvento, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            @IdEventoParticipante AS IdEventoParticipante,
            @IdEvento AS IdEvento,
            @IdParticipante AS IdParticipante,
            @OrdenParticipante AS OrdenParticipante,
            @EsLocal AS EsLocal;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   9. CREAR MERCADO

   Se permite para eventos:
   BORRADOR, PROGRAMADO o EN_VIVO.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CrearMercado
(
    @IdUsuarioProceso INT,
    @IdEvento INT,
    @Nombre VARCHAR(150),
    @Descripcion VARCHAR(250) = NULL,
    @IpOrigen VARCHAR(45) = NULL,
    @TipoMercado VARCHAR(30) = 'CONVENCIONAL'
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @Nombre IS NULL
        THROW 59046, 'El nombre del mercado es obligatorio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    DECLARE @IdEstadoBorrador INT;

    SELECT @IdEstadoBorrador = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'MERCADO'
      AND E.Codigo = 'BORRADOR'
      AND E.Activo = 1;

    IF @IdEstadoBorrador IS NULL
        THROW 59047, 'No existe el estado MERCADO/BORRADOR.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;


        DECLARE @EstadoEvento VARCHAR(40);

        SELECT @EstadoEvento = E.Codigo
        FROM dbo.Evento AS EV WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = EV.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'EVENTO'
        WHERE EV.IdEvento = @IdEvento;

        IF @EstadoEvento IS NULL
            THROW 59048, 'El evento indicado no existe.', 1;

        IF @EstadoEvento NOT IN ('BORRADOR', 'PROGRAMADO')
            THROW 59049, 'No se pueden crear mercados para el evento en su estado actual.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Mercado
            WHERE IdEvento = @IdEvento
              AND Nombre = @Nombre
        )
            THROW 59050, 'Ya existe un mercado con ese nombre para el evento.', 1;

        SET @TipoMercado=UPPER(LTRIM(RTRIM(@TipoMercado)));
        IF @TipoMercado IS NULL OR @TipoMercado NOT IN ('CONVENCIONAL','MARCADOR_FINAL','PRIMERA_ANOTACION')
            THROW 76005,'TipoMercado invalido.',1;
        IF @TipoMercado<>'CONVENCIONAL'
        BEGIN
            IF NOT EXISTS(SELECT 1 FROM dbo.Evento EV JOIN dbo.Liga L ON L.IdLiga=EV.IdLiga
              JOIN dbo.Deporte D ON D.IdDeporte=L.IdDeporte WHERE EV.IdEvento=@IdEvento AND EV.EsSimulado=1
              AND ((@TipoMercado='MARCADOR_FINAL' AND D.PermiteMarcadorFinal=1)
                OR (@TipoMercado='PRIMERA_ANOTACION' AND D.PermitePrimeraAnotacion=1)))
                THROW 76006,'Modalidad no compatible; requiere evento simulado y deporte habilitado.',1;
            IF (SELECT COUNT(*) FROM dbo.EventoParticipante WHERE IdEvento=@IdEvento)<>2
               OR (SELECT COUNT(*) FROM dbo.EventoParticipante WHERE IdEvento=@IdEvento AND OrdenParticipante IN (1,2))<>2
                THROW 76007,'Se requieren exactamente participantes A y B (orden 1 y 2).',1;
            IF EXISTS(SELECT 1 FROM dbo.Mercado WHERE IdEvento=@IdEvento AND TipoMercado=@TipoMercado)
                THROW 76008,'Ya existe esta modalidad para el evento.',1;
        END;
        INSERT INTO dbo.Mercado
        (
            IdEvento,
            IdEstado,
            Nombre,
            Descripcion, TipoMercado
        )
        VALUES
        (
            @IdEvento,
            @IdEstadoBorrador,
            @Nombre,
            @Descripcion, @TipoMercado
        );

        DECLARE @IdMercado INT =
            CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'MERCADO_CREADO',
            'Mercado',
            @IdMercado,
            @IpOrigen,
            CONCAT('Mercado creado en BORRADOR: ', @Nombre, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            @IdMercado AS IdMercado,
            @IdEvento AS IdEvento,
            @IdEstadoBorrador AS IdEstado,
            'BORRADOR' AS EstadoMercado,
            @Nombre AS Nombre,
            @Descripcion AS Descripcion;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   10. CREAR SELECCION

   Solo se permite mientras el mercado está en BORRADOR.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CrearSeleccion
(
    @IdUsuarioProceso INT,
    @IdMercado INT,
    @Nombre VARCHAR(150),
    @IpOrigen VARCHAR(45) = NULL,
    @IdParticipante INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @Nombre IS NULL
        THROW 59051, 'El nombre de la selección es obligatorio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    BEGIN TRY
        BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;


        DECLARE @EstadoMercado VARCHAR(40);

        SELECT @EstadoMercado = E.Codigo
        FROM dbo.Mercado AS M WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = M.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'MERCADO'
        WHERE M.IdMercado = @IdMercado;

        IF @EstadoMercado IS NULL
            THROW 59052, 'El mercado indicado no existe.', 1;

        IF @EstadoMercado <> 'BORRADOR'
            THROW 59053, 'Solo se pueden crear selecciones en un mercado en BORRADOR.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Seleccion
            WHERE IdMercado = @IdMercado
              AND Nombre = @Nombre
        )
            THROW 59054, 'Ya existe una selección con ese nombre para el mercado.', 1;

        DECLARE @IdEvento INT, @TipoMercado VARCHAR(30);
        SELECT @IdEvento=IdEvento,@TipoMercado=TipoMercado FROM dbo.Mercado WHERE IdMercado=@IdMercado;
        IF @TipoMercado='MARCADOR_FINAL' AND EXISTS(SELECT 1 FROM dbo.Seleccion WHERE IdMercado=@IdMercado)
            THROW 76009,'Marcador final utiliza una unica seleccion generica.',1;
        IF (@TipoMercado='PRIMERA_ANOTACION' AND (@IdParticipante IS NULL OR NOT EXISTS
           (SELECT 1 FROM dbo.EventoParticipante WHERE IdEvento=@IdEvento AND IdParticipante=@IdParticipante)))
           OR (@TipoMercado='MARCADOR_FINAL' AND @IdParticipante IS NOT NULL)
           OR (@TipoMercado='CONVENCIONAL' AND @IdParticipante IS NOT NULL AND NOT EXISTS
             (SELECT 1 FROM dbo.EventoParticipante WHERE IdEvento=@IdEvento AND IdParticipante=@IdParticipante))
            THROW 76010,'Participante incompatible con el mercado.',1;
        INSERT INTO dbo.Seleccion
        (
            IdMercado,
            Nombre,
            Activo, IdEvento, IdParticipante
        )
        VALUES
        (
            @IdMercado,
            @Nombre,
            1, @IdEvento, @IdParticipante
        );

        DECLARE @IdSeleccion INT =
            CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'SELECCION_CREADA',
            'Seleccion',
            @IdSeleccion,
            @IpOrigen,
            CONCAT('Selección creada: ', @Nombre, '.')
        );

        COMMIT TRANSACTION;

        SELECT
            @IdSeleccion AS IdSeleccion,
            @IdMercado AS IdMercado,
            @Nombre AS Nombre,
            CAST(1 AS BIT) AS Activo;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   11. REGISTRAR CUOTA

   - Mantiene histórico de cuotas.
   - Cierra la cuota activa anterior.
   - Puede utilizarse en mercados BORRADOR, ABIERTO o SUSPENDIDO.
   - No permite cuotas para mercados CERRADOS, LIQUIDADOS o ANULADOS.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_RegistrarCuota
(
    @IdUsuarioProceso INT,
    @IdSeleccion INT,
    @Valor DECIMAL(10,4) = NULL,
    @IpOrigen VARCHAR(45) = NULL,
    @ValorResultado DECIMAL(10,4) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');



    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    BEGIN TRY
        BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;


        DECLARE @IdMercado INT;
        DECLARE @EstadoMercado VARCHAR(40);
        DECLARE @SeleccionActiva BIT;

        SELECT
            @IdMercado = S.IdMercado,
            @SeleccionActiva = S.Activo,
            @EstadoMercado = E.Codigo
        FROM dbo.Seleccion AS S
        INNER JOIN dbo.Mercado AS M
            ON M.IdMercado = S.IdMercado
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = M.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'MERCADO'
        WHERE S.IdSeleccion = @IdSeleccion;

        IF @IdMercado IS NULL
            THROW 59056, 'La selección indicada no existe.', 1;

        IF @SeleccionActiva = 0
            THROW 59057, 'La selección indicada está inactiva.', 1;

        IF @EstadoMercado NOT IN ('BORRADOR', 'ABIERTO', 'SUSPENDIDO')
            THROW 59058, 'No se pueden registrar cuotas para el mercado en su estado actual.', 1;

        DECLARE @TipoMercado VARCHAR(30),@EstadoEvento VARCHAR(40);
        SELECT @TipoMercado=M.TipoMercado,@EstadoEvento=E.Codigo
        FROM dbo.Mercado M JOIN dbo.Evento EV ON EV.IdEvento=M.IdEvento JOIN dbo.Estado E ON E.IdEstado=EV.IdEstado
        WHERE M.IdMercado=@IdMercado;
        IF @EstadoEvento NOT IN ('BORRADOR','PROGRAMADO')
            THROW 76011,'No se registran cuotas durante ni despues del evento.',1;
        IF @Valor IS NULL AND @TipoMercado<>'CONVENCIONAL'
            SELECT @Valor=TRY_CONVERT(DECIMAL(10,4),Valor) FROM dbo.ConfiguracionSistema
            WHERE Clave=CASE WHEN @TipoMercado='MARCADOR_FINAL' THEN 'MULTIPLICADOR_MARCADOR_EXACTO_DEFAULT'
                       ELSE 'MULTIPLICADOR_PRIMERA_ANOTACION_DEFAULT' END;
        IF @TipoMercado='MARCADOR_FINAL' AND @ValorResultado IS NULL
            SELECT @ValorResultado=TRY_CONVERT(DECIMAL(10,4),Valor) FROM dbo.ConfiguracionSistema
            WHERE Clave='MULTIPLICADOR_MARCADOR_RESULTADO_DEFAULT';
        IF @Valor IS NULL OR @Valor<=1
            THROW 59055,'La cuota debe ser mayor que 1.',1;
        IF (@TipoMercado='MARCADOR_FINAL' AND (@ValorResultado IS NULL OR @ValorResultado<=1 OR @ValorResultado>=@Valor))
            OR (@TipoMercado<>'MARCADOR_FINAL' AND @ValorResultado IS NOT NULL)
            THROW 76012,'Multiplicadores incompatibles con la modalidad.',1;

        /* Serializar cambios de cuota de la misma selección. */
        DECLARE @IdCuotaAnterior INT;

        SELECT TOP (1)
            @IdCuotaAnterior = IdCuota
        FROM dbo.Cuota WITH (UPDLOCK, HOLDLOCK)
        WHERE IdSeleccion = @IdSeleccion
          AND Activo = 1
        ORDER BY IdCuota DESC;

        DECLARE @Ahora DATETIME2 = SYSDATETIME();

        IF EXISTS(SELECT 1 FROM dbo.Cuota WHERE IdSeleccion=@IdSeleccion AND Activo=1 AND FechaInicio>=@Ahora)
            SELECT @Ahora=DATEADD(NANOSECOND,100,MAX(FechaInicio)) FROM dbo.Cuota WHERE IdSeleccion=@IdSeleccion AND Activo=1;
        UPDATE dbo.Cuota
        SET
            Activo = 0,
            FechaFin = @Ahora
        WHERE IdSeleccion = @IdSeleccion
          AND Activo = 1;

        INSERT INTO dbo.Cuota
        (
            IdSeleccion,
            Valor, ValorResultado,
            FechaInicio,
            FechaFin,
            Activo
        )
        VALUES
        (
            @IdSeleccion,
            @Valor, @ValorResultado,
            @Ahora,
            NULL,
            1
        );

        DECLARE @IdCuota INT =
            CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'CUOTA_REGISTRADA',
            'Cuota',
            @IdCuota,
            @IpOrigen,
            CONCAT
            (
                'Nueva cuota ',
                CONVERT(VARCHAR(30), @Valor),
                ' para selección ',
                @IdSeleccion,
                '. Cuota anterior=',
                COALESCE(CONVERT(VARCHAR(20), @IdCuotaAnterior), 'NULL'),
                '.'
            )
        );

        COMMIT TRANSACTION;

        SELECT
            @IdCuota AS IdCuota,
            @IdSeleccion AS IdSeleccion,
            @Valor AS Valor,
            @Ahora AS FechaInicio,
            CAST(1 AS BIT) AS Activo,
            @IdCuotaAnterior AS IdCuotaAnterior;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   12. CAMBIAR ESTADO DE EVENTO

   TRANSICIONES PERMITIDAS:
   BORRADOR            -> PROGRAMADO, CANCELADO
   PROGRAMADO          -> EN_VIVO, SUSPENDIDO, CANCELADO
   EN_VIVO             -> PENDIENTE_RESULTADO, SUSPENDIDO, CANCELADO
   SUSPENDIDO          -> PROGRAMADO, EN_VIVO, CANCELADO
   PENDIENTE_RESULTADO -> FINALIZADO, CANCELADO

   FINALIZADO y CANCELADO son terminales.
   ============================================================ */

/* FASE 3. Auxiliar interno: sin transaccion propia ni ResultSets.
   El llamador conserva el cerrojo comun, actualiza el evento y confirma todo
   junto. SUSPENSION conserva cuotas; CIERRE nunca reabre estados terminales. */
CREATE OR ALTER PROCEDURE dbo.sp_SincronizarCierreMercadosEvento
    @IdUsuarioProceso INT, @IdEvento INT, @Modo VARCHAR(10), @IpOrigen VARCHAR(45),
    @CantidadMercados INT OUTPUT, @MercadosAjustados INT OUTPUT,
    @CuotasDesactivadas INT OUTPUT, @IncompatiblesRestantes INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT=0 OR XACT_STATE()<>1
       OR ISNULL(APPLOCK_MODE('public','PlataformaApuestas:Operacion','Transaction'),'NoLock')<>'Exclusive'
        THROW 76890,'La sincronizacion requiere transaccion y cerrojo exclusivo de operacion.',1;
    EXEC dbo.sp_ValidarPermisoEventos @IdUsuarioProceso;
    DECLARE @EstadoEvento VARCHAR(40);
    SELECT @EstadoEvento=E.Codigo FROM dbo.Evento EV WITH (UPDLOCK,HOLDLOCK)
      JOIN dbo.Estado E ON E.IdEstado=EV.IdEstado JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado
      WHERE EV.IdEvento=@IdEvento AND T.Codigo='EVENTO';
    IF @EstadoEvento IS NULL OR @Modo IS NULL OR @Modo NOT IN ('CIERRE','SUSPENSION')
       OR (@Modo='CIERRE' AND @EstadoEvento NOT IN ('EN_VIVO','PENDIENTE_RESULTADO','SUSPENDIDO'))
       OR (@Modo='SUSPENSION' AND @EstadoEvento<>'SUSPENDIDO')
        THROW 76890,'Precondicion de sincronizacion de mercados invalida.',1;
    IF EXISTS(SELECT 1 FROM dbo.Mercado M WITH (UPDLOCK,HOLDLOCK)
      JOIN dbo.Estado E ON E.IdEstado=M.IdEstado JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado
      WHERE M.IdEvento=@IdEvento AND (T.Codigo<>'MERCADO'
        OR E.Codigo NOT IN ('BORRADOR','ABIERTO','SUSPENDIDO','CERRADO','LIQUIDADO','ANULADO')))
        THROW 76890,'El evento contiene un estado de mercado no reconocido.',1;
    DECLARE @Destino VARCHAR(40)=CASE WHEN @Modo='CIERRE' THEN 'CERRADO' ELSE 'SUSPENDIDO' END,@IdDestino INT;
    SELECT @IdDestino=E.IdEstado FROM dbo.Estado E JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado
      WHERE T.Codigo='MERCADO' AND E.Codigo=@Destino AND E.Activo=1;
    IF @IdDestino IS NULL THROW 76890,'No existe un estado de mercado activo para sincronizar.',1;
    DECLARE @Ajustados TABLE(IdMercado INT PRIMARY KEY,IdEstadoAnterior INT);
    UPDATE M SET IdEstado=@IdDestino
      OUTPUT inserted.IdMercado,deleted.IdEstado INTO @Ajustados
      FROM dbo.Mercado M WITH (UPDLOCK,HOLDLOCK) JOIN dbo.Estado E ON E.IdEstado=M.IdEstado
      WHERE M.IdEvento=@IdEvento AND ((@Modo='CIERRE' AND E.Codigo IN ('BORRADOR','ABIERTO','SUSPENDIDO'))
        OR (@Modo='SUSPENSION' AND E.Codigo='ABIERTO'));
    SET @MercadosAjustados=@@ROWCOUNT;
    SET @CuotasDesactivadas=0;
    IF @Modo='CIERRE'
    BEGIN
        DECLARE @Ahora DATETIME2=SYSDATETIME();
        UPDATE C SET Activo=0,FechaFin=CASE WHEN C.FechaFin>C.FechaInicio THEN C.FechaFin
          WHEN @Ahora>C.FechaInicio THEN @Ahora ELSE DATEADD(NANOSECOND,100,C.FechaInicio) END
          FROM dbo.Cuota C WITH (UPDLOCK,HOLDLOCK)
          JOIN dbo.Seleccion S ON S.IdSeleccion=C.IdSeleccion JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
          WHERE M.IdEvento=@IdEvento AND C.Activo=1;
        SET @CuotasDesactivadas=@@ROWCOUNT;
    END;
    SELECT @CantidadMercados=COUNT(*) FROM dbo.Mercado WHERE IdEvento=@IdEvento;
    SELECT @IncompatiblesRestantes=COUNT(*) FROM dbo.Mercado M JOIN dbo.Estado E ON E.IdEstado=M.IdEstado
      WHERE M.IdEvento=@IdEvento AND ((@Modo='CIERRE' AND E.Codigo IN ('BORRADOR','ABIERTO','SUSPENDIDO'))
        OR (@Modo='SUSPENSION' AND E.Codigo='ABIERTO'));
    IF @IncompatiblesRestantes<>0 OR (@Modo='CIERRE' AND EXISTS(SELECT 1 FROM dbo.Cuota C
      JOIN dbo.Seleccion S ON S.IdSeleccion=C.IdSeleccion JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
      WHERE M.IdEvento=@IdEvento AND C.Activo=1))
        THROW 76890,'La sincronizacion no consiguio desactivar los mercados y cuotas incompatibles.',1;
    INSERT dbo.Auditoria(IdUsuario,Accion,TablaAfectada,IdRegistro,IpOrigen,Descripcion)
      SELECT @IdUsuarioProceso,'ESTADO_MERCADO_SINCRONIZADO','Mercado',A.IdMercado,@IpOrigen,
        CONCAT('Evento=',@IdEvento,'; estado ',E.Codigo,' -> ',@Destino,'.')
      FROM @Ajustados A JOIN dbo.Estado E ON E.IdEstado=A.IdEstadoAnterior;
    IF @MercadosAjustados>0 OR @CuotasDesactivadas>0
      INSERT dbo.Auditoria(IdUsuario,Accion,TablaAfectada,IdRegistro,IpOrigen,Descripcion)
        VALUES(@IdUsuarioProceso,'CIERRE_MERCADOS_EVENTO','Evento',@IdEvento,@IpOrigen,
          CONCAT('Modo=',@Modo,'; estado evento=',@EstadoEvento,'; mercados ajustados=',@MercadosAjustados,
            '; cuotas desactivadas=',@CuotasDesactivadas,'. Sin modificar resultados ni boletos.'));
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ReconciliarCierreMercadosEvento
    @IdUsuarioProceso INT, @IdEvento INT, @IpOrigen VARCHAR(45)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @IdEvento IS NULL OR @IdEvento<=0 THROW 76800,'IdEvento debe ser positivo.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Lock INT;
        EXEC @Lock=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
          @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @Lock<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;
        EXEC dbo.sp_ValidarPermisoEventos @IdUsuarioProceso;
        IF NOT EXISTS(SELECT 1 FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
          WHERE U.IdUsuario=@IdUsuarioProceso AND R.Nombre='ADMINISTRADOR')
          THROW 76804,'Solo ADMINISTRADOR puede reconciliar mercados historicos.',1;
        DECLARE @Estado VARCHAR(40);
        SELECT @Estado=E.Codigo FROM dbo.Evento EV WITH (UPDLOCK,HOLDLOCK)
          JOIN dbo.Estado E ON E.IdEstado=EV.IdEstado JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado
          WHERE EV.IdEvento=@IdEvento AND T.Codigo='EVENTO';
        IF @Estado IS NULL THROW 76801,'El evento no existe.',1;
        IF @Estado NOT IN ('EN_VIVO','PENDIENTE_RESULTADO')
          THROW 76802,'La reconciliacion solo admite EN_VIVO y PENDIENTE_RESULTADO; otros estados requieren revision manual.',1;
        DECLARE @Cantidad INT,@Cerrados INT,@Cuotas INT,@Restantes INT;
        EXEC dbo.sp_SincronizarCierreMercadosEvento @IdUsuarioProceso,@IdEvento,'CIERRE',@IpOrigen,
          @Cantidad OUTPUT,@Cerrados OUTPUT,@Cuotas OUTPUT,@Restantes OUTPUT;
        IF @Cerrados>0 OR @Cuotas>0
          INSERT dbo.Auditoria(IdUsuario,Accion,TablaAfectada,IdRegistro,IpOrigen,Descripcion)
            VALUES(@IdUsuarioProceso,'MERCADOS_EVENTO_RECONCILIADOS','Evento',@IdEvento,@IpOrigen,
              CONCAT('Estado conservado=',@Estado,'; mercados cerrados=',@Cerrados,'; cuotas desactivadas=',@Cuotas,'.'));
        COMMIT;
        SELECT @IdEvento AS IdEvento,@Estado AS EstadoEvento,@Cantidad AS CantidadMercados,
          @Cerrados AS MercadosCerrados,@Cuotas AS CuotasDesactivadas,@Restantes AS MercadosIncompatiblesRestantes,
          CONVERT(BIT,CASE WHEN @Cerrados=0 AND @Cuotas=0 THEN 1 ELSE 0 END) AS SinCambios;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CambiarEstadoEvento
(
    @IdUsuarioProceso INT,
    @IdEvento INT,
    @NuevoEstado VARCHAR(40),
    @Motivo VARCHAR(250) = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NuevoEstado =
        NULLIF(UPPER(LTRIM(RTRIM(@NuevoEstado))), '');
    SET @Motivo = NULLIF(LTRIM(RTRIM(@Motivo)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @IdEvento IS NULL
        THROW 59059, 'IdEvento es obligatorio.', 1;

    IF @NuevoEstado IS NULL
        THROW 59060, 'NuevoEstado es obligatorio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    IF @NuevoEstado='FINALIZADO'
        THROW 76013,'FINALIZADO solo se establece al oficializar el resultado.',1;
    IF EXISTS(SELECT 1 FROM dbo.Evento WHERE IdEvento=@IdEvento AND EsSimulado=1)
    BEGIN
        IF @NuevoEstado='EN_VIVO'
        BEGIN
            EXEC dbo.sp_IniciarSimulacionEvento @IdUsuarioProceso,@IdEvento,@IpOrigen;
            RETURN;
        END;
        IF @NuevoEstado='PENDIENTE_RESULTADO'
        BEGIN
            EXEC dbo.sp_FinalizarSimulacionEvento @IdUsuarioProceso,@IdEvento,@IpOrigen;
            RETURN;
        END;
        IF @NuevoEstado='SUSPENDIDO'
            THROW 76014,'Pausa y reanudacion de simulaciones fuera de alcance.',1;
    END;
    IF @NuevoEstado='CANCELADO'
    BEGIN
        EXEC dbo.sp_AnularResultadoEvento @IdUsuarioProceso=@IdUsuarioProceso,@IdResultadoEvento=NULL,
          @Motivo=@Motivo,@IpOrigen=@IpOrigen,@IdEventoCancelar=@IdEvento;
        RETURN;
    END;
    DECLARE @IdNuevoEstado INT;

    SELECT @IdNuevoEstado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'EVENTO'
      AND E.Codigo = @NuevoEstado
      AND E.Activo = 1;

    IF @IdNuevoEstado IS NULL
        THROW 59061, 'El nuevo estado de evento no existe o está inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;


        DECLARE @EstadoActual VARCHAR(40);

        SELECT @EstadoActual = E.Codigo
        FROM dbo.Evento AS EV WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS E
            ON E.IdEstado = EV.IdEstado
        INNER JOIN dbo.TipoEstado AS TE
            ON TE.IdTipoEstado = E.IdTipoEstado
           AND TE.Codigo = 'EVENTO'
        WHERE EV.IdEvento = @IdEvento;

        IF @EstadoActual IS NULL
            THROW 59062, 'El evento indicado no existe.', 1;

        /* Un reenvio sin transicion no sustituye la reparacion historica,
           reservada a ADMINISTRADOR por su operacion especifica. */
        IF @EstadoActual=@NuevoEstado AND @EstadoActual IN ('EN_VIVO','PENDIENTE_RESULTADO')
          AND (EXISTS(SELECT 1 FROM dbo.Mercado M JOIN dbo.Estado E ON E.IdEstado=M.IdEstado
            WHERE M.IdEvento=@IdEvento AND E.Codigo IN ('BORRADOR','ABIERTO','SUSPENDIDO'))
          OR EXISTS(SELECT 1 FROM dbo.Cuota C JOIN dbo.Seleccion S ON S.IdSeleccion=C.IdSeleccion
            JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado WHERE M.IdEvento=@IdEvento AND C.Activo=1))
            THROW 76803,'El evento requiere reconciliacion administrativa de sus mercados.',1;

        IF @EstadoActual = @NuevoEstado
        BEGIN
            COMMIT TRANSACTION;

            SELECT
                @IdEvento AS IdEvento,
                @EstadoActual AS EstadoAnterior,
                @NuevoEstado AS EstadoActual,
                CAST(1 AS BIT) AS SinCambios;

            RETURN;
        END;

        IF NOT
        (
            (@EstadoActual = 'BORRADOR'
                AND @NuevoEstado IN ('PROGRAMADO', 'CANCELADO'))
            OR
            (@EstadoActual = 'PROGRAMADO'
                AND @NuevoEstado IN ('EN_VIVO', 'SUSPENDIDO', 'CANCELADO'))
            OR
            (@EstadoActual = 'EN_VIVO'
                AND @NuevoEstado IN ('PENDIENTE_RESULTADO', 'SUSPENDIDO', 'CANCELADO'))
            OR
            (@EstadoActual = 'SUSPENDIDO'
                AND @NuevoEstado IN ('PROGRAMADO', 'EN_VIVO', 'CANCELADO'))
            OR
            (@EstadoActual = 'PENDIENTE_RESULTADO'
                AND @NuevoEstado IN ('FINALIZADO', 'CANCELADO'))
        )
            THROW 59063, 'La transición de estado solicitada para el evento no está permitida.', 1;

        /* Antes de publicar un evento, exigir al menos 2 participantes. */
        IF @NuevoEstado = 'PROGRAMADO'
           AND
           (
               SELECT COUNT(*)
               FROM dbo.EventoParticipante
               WHERE IdEvento = @IdEvento
           ) < 2
            THROW 59064, 'El evento debe tener al menos dos participantes antes de pasar a PROGRAMADO.', 1;

        UPDATE dbo.Evento
        SET IdEstado = @IdNuevoEstado
        WHERE IdEvento = @IdEvento;

        IF @NuevoEstado IN ('EN_VIVO','PENDIENTE_RESULTADO','SUSPENDIDO')
        BEGIN
            DECLARE @ModoSincronizacion VARCHAR(10)=CASE WHEN @NuevoEstado='SUSPENDIDO' AND @EstadoActual='PROGRAMADO'
              THEN 'SUSPENSION' ELSE 'CIERRE' END;
            DECLARE @CantidadMercados INT,@MercadosAjustados INT,@CuotasDesactivadas INT,@IncompatiblesRestantes INT;
            EXEC dbo.sp_SincronizarCierreMercadosEvento @IdUsuarioProceso,@IdEvento,@ModoSincronizacion,@IpOrigen,
              @CantidadMercados OUTPUT,@MercadosAjustados OUTPUT,@CuotasDesactivadas OUTPUT,@IncompatiblesRestantes OUTPUT;
        END;

        /* Al cancelar un evento, impedir nuevas apuestas cerrando
           mercados operativos. No se liquidan aquí; eso corresponde
           al módulo de resultados/liquidación. */
        IF @NuevoEstado = 'CANCELADO'
        BEGIN
            DECLARE @IdMercadoAnulado INT;

            SELECT @IdMercadoAnulado = E.IdEstado
            FROM dbo.Estado AS E
            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
            WHERE TE.Codigo = 'MERCADO'
              AND E.Codigo = 'ANULADO'
              AND E.Activo = 1;

            IF @IdMercadoAnulado IS NULL
                THROW 59065, 'No existe el estado MERCADO/ANULADO.', 1;

            UPDATE M
            SET IdEstado = @IdMercadoAnulado
            FROM dbo.Mercado AS M
            INNER JOIN dbo.Estado AS E
                ON E.IdEstado = M.IdEstado
            INNER JOIN dbo.TipoEstado AS TE
                ON TE.IdTipoEstado = E.IdTipoEstado
               AND TE.Codigo = 'MERCADO'
            WHERE M.IdEvento = @IdEvento
              AND E.Codigo NOT IN ('LIQUIDADO', 'ANULADO');
        END;

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'ESTADO_EVENTO_CAMBIADO',
            'Evento',
            @IdEvento,
            @IpOrigen,
            CONCAT
            (
                'Estado ',
                @EstadoActual,
                ' -> ',
                @NuevoEstado,
                CASE
                    WHEN @Motivo IS NULL THEN ''
                    ELSE CONCAT('. Motivo: ', @Motivo)
                END
            )
        );

        COMMIT TRANSACTION;

        SELECT
            @IdEvento AS IdEvento,
            @EstadoActual AS EstadoAnterior,
            @NuevoEstado AS EstadoActual,
            CAST(0 AS BIT) AS SinCambios;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


/* ============================================================
   13. CAMBIAR ESTADO DE MERCADO

   TRANSICIONES PERMITIDAS:
   BORRADOR   -> ABIERTO, ANULADO
   ABIERTO    -> SUSPENDIDO, CERRADO, ANULADO
   SUSPENDIDO -> ABIERTO, CERRADO, ANULADO
   CERRADO    -> LIQUIDADO, ANULADO

   LIQUIDADO y ANULADO son terminales.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_CambiarEstadoMercado
(
    @IdUsuarioProceso INT,
    @IdMercado INT,
    @NuevoEstado VARCHAR(40),
    @Motivo VARCHAR(250) = NULL,
    @IpOrigen VARCHAR(45) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NuevoEstado =
        NULLIF(UPPER(LTRIM(RTRIM(@NuevoEstado))), '');
    SET @Motivo = NULLIF(LTRIM(RTRIM(@Motivo)), '');
    SET @IpOrigen = NULLIF(LTRIM(RTRIM(@IpOrigen)), '');

    IF @IdMercado IS NULL
        THROW 59066, 'IdMercado es obligatorio.', 1;

    IF @NuevoEstado IS NULL
        THROW 59067, 'NuevoEstado es obligatorio.', 1;

    EXEC dbo.sp_ValidarPermisoEventos
        @IdUsuarioProceso = @IdUsuarioProceso;

    DECLARE @IdNuevoEstado INT;

    SELECT @IdNuevoEstado = E.IdEstado
    FROM dbo.Estado AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.IdTipoEstado = E.IdTipoEstado
    WHERE TE.Codigo = 'MERCADO'
      AND E.Codigo = @NuevoEstado
      AND E.Activo = 1;

    IF @IdNuevoEstado IS NULL
        THROW 59068, 'El nuevo estado de mercado no existe o está inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        /* Cerrojo transaccional comun: serializa mutaciones deportivas/financieras
           de esta plataforma academica y fija el orden frente a inicio/apuesta/liquidacion. */
        DECLARE @CerrojoModelo INT;
        EXEC @CerrojoModelo=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
             @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @CerrojoModelo<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;


        DECLARE @EstadoActual VARCHAR(40);
        DECLARE @EstadoEvento VARCHAR(40);

        SELECT
            @EstadoActual = EM.Codigo,
            @EstadoEvento = EE.Codigo
        FROM dbo.Mercado AS M WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Estado AS EM
            ON EM.IdEstado = M.IdEstado
        INNER JOIN dbo.TipoEstado AS TEM
            ON TEM.IdTipoEstado = EM.IdTipoEstado
           AND TEM.Codigo = 'MERCADO'
        INNER JOIN dbo.Evento AS EV
            ON EV.IdEvento = M.IdEvento
        INNER JOIN dbo.Estado AS EE
            ON EE.IdEstado = EV.IdEstado
        INNER JOIN dbo.TipoEstado AS TEE
            ON TEE.IdTipoEstado = EE.IdTipoEstado
           AND TEE.Codigo = 'EVENTO'
        WHERE M.IdMercado = @IdMercado;

        IF @EstadoActual IS NULL
            THROW 59069, 'El mercado indicado no existe.', 1;

        /* Validar incluso cuando ABIERTO ya figura como estado del mercado. */
        IF @NuevoEstado='ABIERTO' AND @EstadoEvento<>'PROGRAMADO'
            THROW 59071, 'Solo se puede abrir un mercado cuando el evento esta PROGRAMADO.', 1;

        IF @EstadoActual = @NuevoEstado
        BEGIN
            COMMIT TRANSACTION;

            SELECT
                @IdMercado AS IdMercado,
                @EstadoActual AS EstadoAnterior,
                @NuevoEstado AS EstadoActual,
                CAST(1 AS BIT) AS SinCambios;

            RETURN;
        END;

        IF NOT
        (
            (@EstadoActual = 'BORRADOR'
                AND @NuevoEstado IN ('ABIERTO', 'ANULADO'))
            OR
            (@EstadoActual = 'ABIERTO'
                AND @NuevoEstado IN ('SUSPENDIDO', 'CERRADO', 'ANULADO'))
            OR
            (@EstadoActual = 'SUSPENDIDO'
                AND @NuevoEstado IN ('ABIERTO', 'CERRADO', 'ANULADO'))
            OR
            (@EstadoActual = 'CERRADO'
                AND @NuevoEstado IN ('LIQUIDADO', 'ANULADO'))
        )
            THROW 59070, 'La transición de estado solicitada para el mercado no está permitida.', 1;

        IF @NuevoEstado='LIQUIDADO'
            THROW 76015,'LIQUIDADO solo se establece desde oficializacion.',1;
        IF @NuevoEstado = 'ABIERTO'
        BEGIN
            IF @EstadoEvento <> 'PROGRAMADO'
                THROW 59071, 'Solo se puede abrir un mercado cuando el evento esta PROGRAMADO.', 1;

            IF
            (
                SELECT COUNT(*)
                FROM dbo.Seleccion
                WHERE IdMercado = @IdMercado
                  AND Activo = 1
            ) < CASE WHEN (SELECT TipoMercado FROM dbo.Mercado WHERE IdMercado=@IdMercado)='MARCADOR_FINAL' THEN 1 ELSE 2 END
                THROW 59072, 'El mercado debe tener al menos dos selecciones activas antes de abrirse.', 1;

            IF (SELECT TipoMercado FROM dbo.Mercado WHERE IdMercado=@IdMercado)='PRIMERA_ANOTACION'
               AND (SELECT COUNT(DISTINCT IdParticipante) FROM dbo.Seleccion WHERE IdMercado=@IdMercado AND Activo=1)<>2
                THROW 76016,'Primera anotacion requiere dos participantes distintos.',1;
            IF EXISTS
            (
                SELECT 1
                FROM dbo.Seleccion AS S
                WHERE S.IdMercado = @IdMercado
                  AND S.Activo = 1
                  AND NOT EXISTS
                  (
                      SELECT 1
                      FROM dbo.Cuota AS C
                      WHERE C.IdSeleccion = S.IdSeleccion
                        AND C.Activo = 1
                  )
            )
                THROW 59073, 'Todas las selecciones activas deben tener una cuota activa antes de abrir el mercado.', 1;
        END;

        UPDATE dbo.Mercado
        SET IdEstado = @IdNuevoEstado
        WHERE IdMercado = @IdMercado;

        /* Cuando un mercado deja de aceptar apuestas, cerrar
           también sus cuotas activas. */
        IF @NuevoEstado IN ('CERRADO', 'LIQUIDADO', 'ANULADO')
        BEGIN
            UPDATE C
            SET
                Activo = 0,
                FechaFin = COALESCE(C.FechaFin, CASE WHEN SYSDATETIME() > C.FechaInicio THEN SYSDATETIME() ELSE DATEADD(NANOSECOND,100,C.FechaInicio) END)
            FROM dbo.Cuota AS C
            INNER JOIN dbo.Seleccion AS S
                ON S.IdSeleccion = C.IdSeleccion
            WHERE S.IdMercado = @IdMercado
              AND C.Activo = 1;
        END;

        INSERT INTO dbo.Auditoria
        (
            IdUsuario,
            Accion,
            TablaAfectada,
            IdRegistro,
            IpOrigen,
            Descripcion
        )
        VALUES
        (
            @IdUsuarioProceso,
            'ESTADO_MERCADO_CAMBIADO',
            'Mercado',
            @IdMercado,
            @IpOrigen,
            CONCAT
            (
                'Estado ',
                @EstadoActual,
                ' -> ',
                @NuevoEstado,
                CASE
                    WHEN @Motivo IS NULL THEN ''
                    ELSE CONCAT('. Motivo: ', @Motivo)
                END
            )
        );

        COMMIT TRANSACTION;

        SELECT
            @IdMercado AS IdMercado,
            @EstadoActual AS EstadoAnterior,
            @NuevoEstado AS EstadoActual,
            CAST(0 AS BIT) AS SinCambios;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


PRINT '=======================================================';
PRINT ' PROCEDIMIENTOS DE EVENTOS Y MERCADOS CREADOS / ACTUALIZADOS';
PRINT '=======================================================';
GO

CREATE OR ALTER PROCEDURE dbo.sp_AsociarParticipanteLiga
 @IdUsuarioProceso INT, @IdLiga INT, @IdParticipante INT, @IpOrigen VARCHAR(45)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 EXEC dbo.sp_ValidarPermisoEventos @IdUsuarioProceso;
 IF @IdLiga IS NULL OR @IdLiga<=0 OR @IdParticipante IS NULL OR @IdParticipante<=0
   THROW 76600,'Identificadores de asociacion invalidos.',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @Lock INT,@DeporteLiga INT,@DeporteParticipante INT,@LigaActiva BIT,@ParticipanteActivo BIT;
  EXEC @Lock=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
    @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
  IF @Lock<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;
  SELECT @DeporteLiga=IdDeporte,@LigaActiva=Activo FROM dbo.Liga WITH(UPDLOCK,HOLDLOCK) WHERE IdLiga=@IdLiga;
  IF @DeporteLiga IS NULL THROW 76601,'La liga no existe.',1;
  SELECT @DeporteParticipante=IdDeporte,@ParticipanteActivo=Activo FROM dbo.Participante WITH(UPDLOCK,HOLDLOCK)
    WHERE IdParticipante=@IdParticipante;
  IF @DeporteParticipante IS NULL THROW 76602,'El participante no existe.',1;
  IF @DeporteLiga<>@DeporteParticipante THROW 76603,'Liga y participante pertenecen a deportes distintos.',1;
  IF @LigaActiva=0 OR @ParticipanteActivo=0 THROW 76604,'Liga o participante inactivo.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.LigaParticipante WHERE IdLiga=@IdLiga AND IdParticipante=@IdParticipante)
    INSERT dbo.LigaParticipante(IdLiga,IdParticipante,Activo) VALUES(@IdLiga,@IdParticipante,1);
  ELSE
    UPDATE dbo.LigaParticipante SET Activo=1 WHERE IdLiga=@IdLiga AND IdParticipante=@IdParticipante;
  INSERT dbo.Auditoria(IdUsuario,Accion,TablaAfectada,IdRegistro,IpOrigen,Descripcion)
    VALUES(@IdUsuarioProceso,'LIGA_PARTICIPANTE_ASOCIADO','LigaParticipante',@IdLiga,
      NULLIF(LTRIM(RTRIM(@IpOrigen)),''),CONCAT('Liga ',@IdLiga,'; participante ',@IdParticipante,'; activo 1.'));
  COMMIT;
  SELECT @IdLiga AS IdLiga,@IdParticipante AS IdParticipante,CAST(1 AS BIT) AS Activo;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DesasociarParticipanteLiga
 @IdUsuarioProceso INT, @IdLiga INT, @IdParticipante INT, @IpOrigen VARCHAR(45)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 EXEC dbo.sp_ValidarPermisoEventos @IdUsuarioProceso;
 IF @IdLiga IS NULL OR @IdLiga<=0 OR @IdParticipante IS NULL OR @IdParticipante<=0
   THROW 76600,'Identificadores de asociacion invalidos.',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @Lock INT,@DeporteLiga INT,@DeporteParticipante INT,@LigaActiva BIT,@ParticipanteActivo BIT;
  EXEC @Lock=sys.sp_getapplock @Resource='PlataformaApuestas:Operacion',
    @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
  IF @Lock<0 THROW 76900,'No fue posible obtener el bloqueo de operacion; reintente.',1;
  SELECT @DeporteLiga=IdDeporte,@LigaActiva=Activo FROM dbo.Liga WITH(UPDLOCK,HOLDLOCK) WHERE IdLiga=@IdLiga;
  IF @DeporteLiga IS NULL THROW 76601,'La liga no existe.',1;
  SELECT @DeporteParticipante=IdDeporte,@ParticipanteActivo=Activo FROM dbo.Participante WITH(UPDLOCK,HOLDLOCK)
    WHERE IdParticipante=@IdParticipante;
  IF @DeporteParticipante IS NULL THROW 76602,'El participante no existe.',1;
  IF @DeporteLiga<>@DeporteParticipante THROW 76603,'Liga y participante pertenecen a deportes distintos.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.LigaParticipante WHERE IdLiga=@IdLiga AND IdParticipante=@IdParticipante)
    THROW 76605,'La asociacion no existe.',1;
  UPDATE dbo.LigaParticipante SET Activo=0 WHERE IdLiga=@IdLiga AND IdParticipante=@IdParticipante;
  INSERT dbo.Auditoria(IdUsuario,Accion,TablaAfectada,IdRegistro,IpOrigen,Descripcion)
    VALUES(@IdUsuarioProceso,'LIGA_PARTICIPANTE_DESASOCIADO','LigaParticipante',@IdLiga,
      NULLIF(LTRIM(RTRIM(@IpOrigen)),''),CONCAT('Liga ',@IdLiga,'; participante ',@IdParticipante,'; activo 0.'));
  COMMIT;
  SELECT @IdLiga AS IdLiga,@IdParticipante AS IdParticipante,CAST(0 AS BIT) AS Activo;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO
