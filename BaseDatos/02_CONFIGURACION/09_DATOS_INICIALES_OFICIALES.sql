/* ============================================================================
   PLATAFORMA APUESTAS
   09_DATOS_INICIALES_OFICIALES.sql

   Carga permanente para la instalacion final/Gigabyte.

   Incluye:
   - valida 5 ADMINISTRADORES + CASA creados por 08_DatosIniciales.sql
   - conserva los 4 deportes oficiales
   - crea 6 usuarios USUARIO de prueba permanentes
   - acredita Q2,000.00 una sola vez a cada usuario de prueba
   - crea ligas y participantes reconocibles
   - crea eventos listos para pruebas de USUARIO y ADMIN
   - NO crea apuestas ni boletos automaticamente

   Contrasena de los seis usuarios de prueba: Admin123!

   Re-ejecutable. No usa IDs fijos de catalogos.
   Ejecutar despues de 08_DatosIniciales.sql y de los procedimientos.
   ============================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    /* 0. Dependencias */
    IF OBJECT_ID('dbo.sp_RegistrarUsuarioCliente','P') IS NULL THROW 78001,'Falta sp_RegistrarUsuarioCliente.',1;
    IF OBJECT_ID('dbo.sp_CrearTokenSeguridad','P') IS NULL THROW 78002,'Falta sp_CrearTokenSeguridad.',1;
    IF OBJECT_ID('dbo.sp_VerificarCorreoConToken','P') IS NULL THROW 78003,'Falta sp_VerificarCorreoConToken.',1;
    IF OBJECT_ID('dbo.sp_AprobarVerificacionUsuario','P') IS NULL THROW 78004,'Falta sp_AprobarVerificacionUsuario.',1;
    IF OBJECT_ID('dbo.sp_SincronizarHabilitacionUsuario','P') IS NULL THROW 78005,'Falta sp_SincronizarHabilitacionUsuario.',1;
    IF OBJECT_ID('dbo.sp_AjustarSaldoVirtual','P') IS NULL THROW 78006,'Falta sp_AjustarSaldoVirtual.',1;
    IF OBJECT_ID('dbo.sp_CrearLiga','P') IS NULL THROW 78007,'Falta sp_CrearLiga.',1;
    IF OBJECT_ID('dbo.sp_CrearParticipante','P') IS NULL THROW 78008,'Falta sp_CrearParticipante.',1;
    IF OBJECT_ID('dbo.sp_CrearEvento','P') IS NULL THROW 78009,'Falta sp_CrearEvento.',1;
    IF OBJECT_ID('dbo.sp_AgregarParticipanteEvento','P') IS NULL THROW 78010,'Falta sp_AgregarParticipanteEvento.',1;
    IF OBJECT_ID('dbo.sp_CrearMercado','P') IS NULL THROW 78011,'Falta sp_CrearMercado.',1;
    IF OBJECT_ID('dbo.sp_CrearSeleccion','P') IS NULL THROW 78012,'Falta sp_CrearSeleccion.',1;
    IF OBJECT_ID('dbo.sp_RegistrarCuota','P') IS NULL THROW 78013,'Falta sp_RegistrarCuota.',1;
    IF OBJECT_ID('dbo.sp_CambiarEstadoEvento','P') IS NULL THROW 78014,'Falta sp_CambiarEstadoEvento.',1;
    IF OBJECT_ID('dbo.sp_CambiarEstadoMercado','P') IS NULL THROW 78015,'Falta sp_CambiarEstadoMercado.',1;

    DECLARE @Admin INT,
            @PaisGT INT,@PaisES INT,@PaisUS INT,
            @Futbol INT,@Baloncesto INT,@Beisbol INT,@Tenis INT;

    SELECT TOP(1) @Admin=U.IdUsuario
    FROM dbo.Usuario U
    JOIN dbo.Rol R ON R.IdRol=U.IdRol
    JOIN dbo.Estado E ON E.IdEstado=U.IdEstado
    JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado AND T.Codigo='USUARIO'
    WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO'
    ORDER BY U.IdUsuario;

    IF @Admin IS NULL THROW 78016,'Ejecute primero 08_DatosIniciales.sql: falta un ADMINISTRADOR ACTIVO.',1;

    IF (
        SELECT COUNT(*)
        FROM dbo.Usuario U
        JOIN dbo.Rol R ON R.IdRol=U.IdRol
        WHERE R.Nombre='ADMINISTRADOR'
          AND U.Correo IN (
             'gabriel@apuestas.local','wilson@apuestas.local','otto@apuestas.local',
             'kevin@apuestas.local','fernando@apuestas.local'
          )
    ) <> 5
        THROW 78017,'Faltan administradores oficiales de 08_DatosIniciales.sql.',1;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
        WHERE U.Correo='casa@apuestas.local' AND R.Nombre='CASA'
    )
        THROW 78018,'Falta la cuenta CASA oficial.',1;

    SELECT @PaisGT=IdPais FROM dbo.Pais WHERE CodigoISO2='GT' AND Activo=1;
    SELECT @PaisES=IdPais FROM dbo.Pais WHERE CodigoISO2='ES' AND Activo=1;
    SELECT @PaisUS=IdPais FROM dbo.Pais WHERE CodigoISO2='US' AND Activo=1;

    SELECT @Futbol=IdDeporte FROM dbo.Deporte WHERE Nombre='Futbol' AND Activo=1;
    SELECT @Baloncesto=IdDeporte FROM dbo.Deporte WHERE Nombre='Baloncesto' AND Activo=1;
    SELECT @Beisbol=IdDeporte FROM dbo.Deporte WHERE Nombre='Beisbol' AND Activo=1;
    SELECT @Tenis=IdDeporte FROM dbo.Deporte WHERE Nombre='Tenis' AND Activo=1;

    IF @PaisGT IS NULL OR @PaisES IS NULL OR @PaisUS IS NULL
        THROW 78019,'Faltan GT/ES/US en dbo.Pais.',1;
    IF @Futbol IS NULL OR @Baloncesto IS NULL OR @Beisbol IS NULL OR @Tenis IS NULL
        THROW 78020,'Faltan deportes oficiales.',1;

    /* 1. Usuarios de prueba permanentes */
    DECLARE @Municipios TABLE(Orden INT IDENTITY(1,1) PRIMARY KEY, IdMunicipio INT NOT NULL);
    INSERT @Municipios(IdMunicipio)
    SELECT TOP(6) M.IdMunicipio
    FROM dbo.Municipio M
    JOIN dbo.Departamento D ON D.IdDepartamento=M.IdDepartamento
    WHERE D.IdPais=@PaisGT AND D.Activo=1 AND M.Activo=1
    ORDER BY D.Nombre,M.Nombre;

    IF (SELECT COUNT(*) FROM @Municipios)<6
        THROW 78021,'Se requieren al menos seis municipios activos de Guatemala.',1;

    DECLARE @Hash VARCHAR(255)='$2a$12$y9tVQWGEeVH776CzAefsBeWONBLgTevtif6lKl8VcJlEvM2IL3zCK';

    DECLARE @Usuarios TABLE(
        Orden INT PRIMARY KEY, Nombre VARCHAR(100), Apellido VARCHAR(100),
        Correo VARCHAR(150), Fecha DATE, Genero CHAR(1), Telefono VARCHAR(25),
        Documento VARCHAR(50), Direccion VARCHAR(250), IdMunicipio INT,
        RefSaldo UNIQUEIDENTIFIER
    );

    INSERT @Usuarios
    SELECT V.Orden,V.Nombre,V.Apellido,V.Correo,V.Fecha,V.Genero,V.Telefono,V.Documento,
           V.Direccion,M.IdMunicipio,V.RefSaldo
    FROM (VALUES
      (1,'Ana','Lopez','cliente.ana@apuestas.test',CONVERT(DATE,'1998-04-12'),'F','+50255510001','2999999990001','Zona prueba 1, Guatemala',CONVERT(UNIQUEIDENTIFIER,'D1000000-0000-0000-0000-000000000001')),
      (2,'Carlos','Mendez','cliente.carlos@apuestas.test',CONVERT(DATE,'1995-08-23'),'M','+50255510002','2999999990002','Zona prueba 2, Guatemala',CONVERT(UNIQUEIDENTIFIER,'D1000000-0000-0000-0000-000000000002')),
      (3,'Sofia','Morales','cliente.sofia@apuestas.test',CONVERT(DATE,'2000-02-17'),'F','+50255510003','2999999990003','Zona prueba 3, Guatemala',CONVERT(UNIQUEIDENTIFIER,'D1000000-0000-0000-0000-000000000003')),
      (4,'Mateo','Castillo','cliente.mateo@apuestas.test',CONVERT(DATE,'1997-11-05'),'M','+50255510004','2999999990004','Zona prueba 4, Guatemala',CONVERT(UNIQUEIDENTIFIER,'D1000000-0000-0000-0000-000000000004')),
      (5,'Lucia','Ramirez','cliente.lucia@apuestas.test',CONVERT(DATE,'1994-06-30'),'F','+50255510005','2999999990005','Zona prueba 5, Guatemala',CONVERT(UNIQUEIDENTIFIER,'D1000000-0000-0000-0000-000000000005')),
      (6,'Diego','Herrera','cliente.diego@apuestas.test',CONVERT(DATE,'1999-09-14'),'M','+50255510006','2999999990006','Zona prueba 6, Guatemala',CONVERT(UNIQUEIDENTIFIER,'D1000000-0000-0000-0000-000000000006'))
    ) V(Orden,Nombre,Apellido,Correo,Fecha,Genero,Telefono,Documento,Direccion,RefSaldo)
    JOIN @Municipios M ON M.Orden=V.Orden;

    DECLARE @O INT,@Nom VARCHAR(100),@Ape VARCHAR(100),@Correo VARCHAR(150),@Fecha DATE,
            @Gen CHAR(1),@Tel VARCHAR(25),@Doc VARCHAR(50),@Dir VARCHAR(250),
            @Mun INT,@RefSaldo UNIQUEIDENTIFIER,@IdU INT,@IdVer INT,@EstVer VARCHAR(40),@Token CHAR(64);

    DECLARE cU CURSOR LOCAL FAST_FORWARD FOR
    SELECT Orden,Nombre,Apellido,Correo,Fecha,Genero,Telefono,Documento,Direccion,IdMunicipio,RefSaldo
    FROM @Usuarios ORDER BY Orden;
    OPEN cU;
    FETCH NEXT FROM cU INTO @O,@Nom,@Ape,@Correo,@Fecha,@Gen,@Tel,@Doc,@Dir,@Mun,@RefSaldo;

    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @IdU=NULL; SET @IdVer=NULL; SET @EstVer=NULL; SET @Token=NULL;
        SELECT @IdU=IdUsuario FROM dbo.Usuario WHERE Correo=@Correo;

        IF @IdU IS NULL
        BEGIN
            EXEC dbo.sp_RegistrarUsuarioCliente
              @Nombre=@Nom,@Apellido=@Ape,@Correo=@Correo,@Contrasena=@Hash,
              @FechaNacimiento=@Fecha,@Genero=@Gen,@Telefono=@Tel,@TipoDocumento='DPI',
              @NumeroDocumento=@Doc,@IdPais=@PaisGT,@IdMunicipio=@Mun,
              @CiudadExterior=NULL,@Direccion=@Dir;
            SELECT @IdU=IdUsuario FROM dbo.Usuario WHERE Correo=@Correo;
        END;

        IF @IdU IS NULL THROW 78022,'No fue posible crear/localizar un usuario de prueba.',1;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
            WHERE U.IdUsuario=@IdU AND R.Nombre='USUARIO'
        ) THROW 78023,'Un correo de prueba existe con rol distinto de USUARIO.',1;

        IF EXISTS(SELECT 1 FROM dbo.Usuario WHERE IdUsuario=@IdU AND CorreoVerificado=0)
        BEGIN
            SET @Token=CONVERT(CHAR(64),CONVERT(VARCHAR(64),
                HASHBYTES('SHA2_256',CONCAT('OFICIAL-',@Correo,'-',CONVERT(VARCHAR(36),NEWID()))),2));
            EXEC dbo.sp_CrearTokenSeguridad @Correo=@Correo,@TipoToken='VERIFICACION_CORREO',@TokenHash=@Token;
            EXEC dbo.sp_VerificarCorreoConToken @TokenHash=@Token;
        END;

        SELECT TOP(1) @IdVer=V.IdVerificacion,@EstVer=E.Codigo
        FROM dbo.VerificacionUsuario V
        JOIN dbo.Estado E ON E.IdEstado=V.IdEstado
        JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado AND T.Codigo='VERIFICACION'
        WHERE V.IdUsuario=@IdU ORDER BY V.IdVerificacion DESC;

        IF @IdVer IS NULL THROW 78024,'Usuario de prueba sin registro de verificacion.',1;

        IF @EstVer IN('PENDIENTE','EN_REVISION')
            EXEC dbo.sp_AprobarVerificacionUsuario
              @IdUsuarioProceso=@Admin,@IdVerificacion=@IdVer,
              @Observacion='Usuario permanente de prueba del entorno academico.',@IpOrigen='127.0.0.1';
        ELSE IF @EstVer<>'APROBADA'
            THROW 78025,'Usuario de prueba con verificacion incompatible.',1;

        EXEC dbo.sp_SincronizarHabilitacionUsuario @IdUsuario=@IdU;

        EXEC dbo.sp_AjustarSaldoVirtual
          @IdUsuarioObjetivo=@IdU,@IdUsuarioProceso=@Admin,@Operacion='CREDITO',
          @Monto=2000.00,@Motivo='Capital virtual inicial permanente para pruebas oficiales.',
          @ReferenciaOperacion=@RefSaldo,@IpOrigen='127.0.0.1';

        FETCH NEXT FROM cU INTO @O,@Nom,@Ape,@Correo,@Fecha,@Gen,@Tel,@Doc,@Dir,@Mun,@RefSaldo;
    END;
    CLOSE cU; DEALLOCATE cU;


    /* 2. Ligas oficiales */
    DECLARE @Ligas TABLE(
        Codigo VARCHAR(30) PRIMARY KEY, IdDeporte INT NOT NULL, IdPais INT NULL,
        Nombre VARCHAR(150) NOT NULL, IdLiga INT NULL
    );

    INSERT @Ligas(Codigo,IdDeporte,IdPais,Nombre) VALUES
      ('FUT_ES',@Futbol,@PaisES,'LALIGA EA SPORTS'),
      ('FUT_GT',@Futbol,@PaisGT,'Liga Nacional de Guatemala'),
      ('BAL_NBA',@Baloncesto,@PaisUS,'NBA'),
      ('BEI_MLB',@Beisbol,@PaisUS,'MLB'),
      ('TEN_ATP',@Tenis,NULL,'ATP Tour'),
      ('TEN_WTA',@Tenis,NULL,'WTA Tour');

    DECLARE @LC VARCHAR(30),@LD INT,@LP INT,@LN VARCHAR(150),@LID INT;
    DECLARE cL CURSOR LOCAL FAST_FORWARD FOR SELECT Codigo,IdDeporte,IdPais,Nombre FROM @Ligas;
    OPEN cL; FETCH NEXT FROM cL INTO @LC,@LD,@LP,@LN;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @LID=NULL;
        SELECT @LID=IdLiga FROM dbo.Liga WHERE IdDeporte=@LD AND Nombre=@LN;
        IF @LID IS NULL
        BEGIN
            EXEC dbo.sp_CrearLiga @IdUsuarioProceso=@Admin,@IdDeporte=@LD,@Nombre=@LN,@IdPais=@LP,@IpOrigen='127.0.0.1';
            SELECT @LID=IdLiga FROM dbo.Liga WHERE IdDeporte=@LD AND Nombre=@LN;
        END;
        UPDATE @Ligas SET IdLiga=@LID WHERE Codigo=@LC;
        FETCH NEXT FROM cL INTO @LC,@LD,@LP,@LN;
    END;
    CLOSE cL; DEALLOCATE cL;

    /* 3. Participantes oficiales */
    DECLARE @Participantes TABLE(
        Codigo VARCHAR(40) PRIMARY KEY, IdDeporte INT NOT NULL, CodigoPais CHAR(2) NULL,
        Nombre VARCHAR(150) NOT NULL, Tipo VARCHAR(30) NOT NULL, IdParticipante INT NULL
    );

    /* LALIGA: clubes reconocibles de la temporada 2026/27. */
    INSERT @Participantes VALUES
      ('ES_ATH',@Futbol,'ES','Athletic Club','EQUIPO',NULL),
      ('ES_ATM',@Futbol,'ES','Atlético de Madrid','EQUIPO',NULL),
      ('ES_OSA',@Futbol,'ES','CA Osasuna','EQUIPO',NULL),
      ('ES_CEL',@Futbol,'ES','Celta','EQUIPO',NULL),
      ('ES_ALA',@Futbol,'ES','Deportivo Alavés','EQUIPO',NULL),
      ('ES_ELC',@Futbol,'ES','Elche CF','EQUIPO',NULL),
      ('ES_BAR',@Futbol,'ES','FC Barcelona','EQUIPO',NULL),
      ('ES_GET',@Futbol,'ES','Getafe CF','EQUIPO',NULL),
      ('ES_LEV',@Futbol,'ES','Levante UD','EQUIPO',NULL),
      ('ES_MAL',@Futbol,'ES','Málaga CF','EQUIPO',NULL),
      ('ES_RAC',@Futbol,'ES','R. Racing Club','EQUIPO',NULL),
      ('ES_RAY',@Futbol,'ES','Rayo Vallecano','EQUIPO',NULL),
      ('ES_DEP',@Futbol,'ES','RC Deportivo','EQUIPO',NULL),
      ('ES_ESP',@Futbol,'ES','RCD Espanyol de Barcelona','EQUIPO',NULL),
      ('ES_BET',@Futbol,'ES','Real Betis','EQUIPO',NULL),
      ('ES_RMA',@Futbol,'ES','Real Madrid','EQUIPO',NULL),
      ('ES_RSO',@Futbol,'ES','Real Sociedad','EQUIPO',NULL),
      ('ES_SEV',@Futbol,'ES','Sevilla FC','EQUIPO',NULL),
      ('ES_VAL',@Futbol,'ES','Valencia CF','EQUIPO',NULL),
      ('ES_VIL',@Futbol,'ES','Villarreal CF','EQUIPO',NULL);

    /* Liga Nacional de Guatemala, Apertura 2026. */
    INSERT @Participantes VALUES
      ('GT_ANT',@Futbol,'GT','Antigua GFC','EQUIPO',NULL),
      ('GT_AUR',@Futbol,'GT','Aurora FC','EQUIPO',NULL),
      ('GT_COB',@Futbol,'GT','Cobán Imperial','EQUIPO',NULL),
      ('GT_COM',@Futbol,'GT','Comunicaciones','EQUIPO',NULL),
      ('GT_GUA',@Futbol,'GT','Guastatoya','EQUIPO',NULL),
      ('GT_MAL',@Futbol,'GT','Malacateco','EQUIPO',NULL),
      ('GT_MAR',@Futbol,'GT','Marquense','EQUIPO',NULL),
      ('GT_MIX',@Futbol,'GT','Mixco','EQUIPO',NULL),
      ('GT_MUN',@Futbol,'GT','Municipal','EQUIPO',NULL),
      ('GT_SNP',@Futbol,'GT','San Pedro','EQUIPO',NULL),
      ('GT_SUC',@Futbol,'GT','Suchitepéquez','EQUIPO',NULL),
      ('GT_XEL',@Futbol,'GT','Xelajú','EQUIPO',NULL);

    /* NBA: equipos muy conocidos. */
    INSERT @Participantes VALUES
      ('NBA_LAL',@Baloncesto,'US','Los Angeles Lakers','EQUIPO',NULL),
      ('NBA_BOS',@Baloncesto,'US','Boston Celtics','EQUIPO',NULL),
      ('NBA_GSW',@Baloncesto,'US','Golden State Warriors','EQUIPO',NULL),
      ('NBA_CHI',@Baloncesto,'US','Chicago Bulls','EQUIPO',NULL),
      ('NBA_MIA',@Baloncesto,'US','Miami Heat','EQUIPO',NULL),
      ('NBA_DAL',@Baloncesto,'US','Dallas Mavericks','EQUIPO',NULL),
      ('NBA_MIL',@Baloncesto,'US','Milwaukee Bucks','EQUIPO',NULL),
      ('NBA_NYK',@Baloncesto,'US','New York Knicks','EQUIPO',NULL);

    /* MLB: equipos muy conocidos. */
    INSERT @Participantes VALUES
      ('MLB_NYY',@Beisbol,'US','New York Yankees','EQUIPO',NULL),
      ('MLB_LAD',@Beisbol,'US','Los Angeles Dodgers','EQUIPO',NULL),
      ('MLB_BOS',@Beisbol,'US','Boston Red Sox','EQUIPO',NULL),
      ('MLB_CHC',@Beisbol,'US','Chicago Cubs','EQUIPO',NULL),
      ('MLB_HOU',@Beisbol,'US','Houston Astros','EQUIPO',NULL),
      ('MLB_ATL',@Beisbol,'US','Atlanta Braves','EQUIPO',NULL),
      ('MLB_NYM',@Beisbol,'US','New York Mets','EQUIPO',NULL),
      ('MLB_PHI',@Beisbol,'US','Philadelphia Phillies','EQUIPO',NULL);

    /* Tenis: atletas muy reconocibles. */
    INSERT @Participantes VALUES
      ('ATP_ALC',@Tenis,'ES','Carlos Alcaraz','ATLETA',NULL),
      ('ATP_SIN',@Tenis,'IT','Jannik Sinner','ATLETA',NULL),
      ('ATP_DJO',@Tenis,'RS','Novak Djokovic','ATLETA',NULL),
      ('ATP_ZVE',@Tenis,'DE','Alexander Zverev','ATLETA',NULL),
      ('ATP_FRI',@Tenis,'US','Taylor Fritz','ATLETA',NULL),
      ('ATP_MED',@Tenis,'RU','Daniil Medvedev','ATLETA',NULL),
      ('WTA_SAB',@Tenis,'BY','Aryna Sabalenka','ATLETA',NULL),
      ('WTA_SWI',@Tenis,'PL','Iga Swiatek','ATLETA',NULL),
      ('WTA_GAU',@Tenis,'US','Coco Gauff','ATLETA',NULL),
      ('WTA_RYB',@Tenis,'KZ','Elena Rybakina','ATLETA',NULL),
      ('WTA_PEG',@Tenis,'US','Jessica Pegula','ATLETA',NULL),
      ('WTA_AND',@Tenis,'RU','Mirra Andreeva','ATLETA',NULL);

    DECLARE @PC VARCHAR(40),@PD INT,@PISO CHAR(2),@PN VARCHAR(150),@PT VARCHAR(30),@PIDPais INT,@PID INT;
    DECLARE cP CURSOR LOCAL FAST_FORWARD FOR
      SELECT Codigo,IdDeporte,CodigoPais,Nombre,Tipo FROM @Participantes ORDER BY Codigo;
    OPEN cP; FETCH NEXT FROM cP INTO @PC,@PD,@PISO,@PN,@PT;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @PIDPais=NULL; SET @PID=NULL;
        IF @PISO IS NOT NULL
            SELECT @PIDPais=IdPais FROM dbo.Pais WHERE CodigoISO2=@PISO AND Activo=1;

        SELECT TOP(1) @PID=IdParticipante
        FROM dbo.Participante
        WHERE IdDeporte=@PD AND Nombre=@PN AND TipoParticipante=@PT
        ORDER BY IdParticipante;

        IF @PID IS NULL
        BEGIN
            EXEC dbo.sp_CrearParticipante
              @IdUsuarioProceso=@Admin,@IdDeporte=@PD,@Nombre=@PN,
              @TipoParticipante=@PT,@IdPais=@PIDPais,@IpOrigen='127.0.0.1';

            SELECT TOP(1) @PID=IdParticipante
            FROM dbo.Participante
            WHERE IdDeporte=@PD AND Nombre=@PN AND TipoParticipante=@PT
            ORDER BY IdParticipante;
        END;

        UPDATE @Participantes SET IdParticipante=@PID WHERE Codigo=@PC;
        FETCH NEXT FROM cP INTO @PC,@PD,@PISO,@PN,@PT;
    END;
    CLOSE cP; DEALLOCATE cP;


    /* 4. Eventos oficiales para pruebas de USUARIO y ADMIN */
    DECLARE @Eventos TABLE(
        Codigo VARCHAR(40) PRIMARY KEY, CodigoLiga VARCHAR(30) NOT NULL,
        Nombre VARCHAR(200) NOT NULL, DiasInicio INT NOT NULL, DuracionHoras INT NOT NULL,
        PA VARCHAR(40) NOT NULL, PB VARCHAR(40) NOT NULL,
        EsSimulado BIT NOT NULL, Publicar BIT NOT NULL, CrearMercados BIT NOT NULL,
        IdEvento INT NULL
    );

    INSERT @Eventos VALUES
      ('EV_ES_CLASICO','FUT_ES','OFICIAL - Real Madrid vs FC Barcelona',2,2,'ES_RMA','ES_BAR',1,1,1,NULL),
      ('EV_ES_ATM_SEV','FUT_ES','OFICIAL - Atlético de Madrid vs Sevilla FC',4,2,'ES_ATM','ES_SEV',1,1,1,NULL),
      ('EV_GT_CLASICO','FUT_GT','OFICIAL - Municipal vs Comunicaciones',3,2,'GT_MUN','GT_COM',1,1,1,NULL),
      ('EV_GT_XEL_ANT','FUT_GT','OFICIAL - Xelajú vs Antigua GFC',5,2,'GT_XEL','GT_ANT',1,1,1,NULL),
      ('EV_NBA_LAL_BOS','BAL_NBA','OFICIAL - Los Angeles Lakers vs Boston Celtics',3,3,'NBA_LAL','NBA_BOS',1,1,1,NULL),
      ('EV_MLB_NYY_LAD','BEI_MLB','OFICIAL - New York Yankees vs Los Angeles Dodgers',4,4,'MLB_NYY','MLB_LAD',1,1,1,NULL),
      ('EV_ATP_ALC_SIN','TEN_ATP','OFICIAL - Carlos Alcaraz vs Jannik Sinner',6,4,'ATP_ALC','ATP_SIN',0,1,1,NULL),
      ('EV_WTA_SAB_SWI','TEN_WTA','OFICIAL - Aryna Sabalenka vs Iga Swiatek',7,4,'WTA_SAB','WTA_SWI',0,1,1,NULL),

      /* Queda BORRADOR y sin mercados para pruebas del panel ADMIN. */
      ('EV_ADMIN_BOR','FUT_ES','OFICIAL ADMIN - Athletic Club vs Valencia CF',8,2,'ES_ATH','ES_VAL',1,0,0,NULL);

    DECLARE @EC VARCHAR(40),@ELC VARCHAR(30),@EN VARCHAR(200),@Dias INT,@Horas INT,
            @EPA VARCHAR(40),@EPB VARCHAR(40),@Sim BIT,@Publicar BIT,@CrearMerc BIT,
            @ELiga INT,@EDeporte INT,@EID INT,@AID INT,@BID INT,@ANom VARCHAR(150),@BNom VARCHAR(150),
            @Inicio DATETIME2,@Fin DATETIME2,@MConv INT,@MMarc INT,@MPrim INT,
            @SelA INT,@SelB INT,@SelE INT,@SelM INT,@MAbrir INT,@DuracionSimulacion INT;

    DECLARE cE CURSOR LOCAL FAST_FORWARD FOR
      SELECT Codigo,CodigoLiga,Nombre,DiasInicio,DuracionHoras,PA,PB,EsSimulado,Publicar,CrearMercados
      FROM @Eventos ORDER BY DiasInicio,Codigo;

    OPEN cE;
    FETCH NEXT FROM cE INTO @EC,@ELC,@EN,@Dias,@Horas,@EPA,@EPB,@Sim,@Publicar,@CrearMerc;

    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @EID=NULL;
        SELECT @ELiga=IdLiga,@EDeporte=IdDeporte FROM @Ligas WHERE Codigo=@ELC;
        SELECT @AID=IdParticipante,@ANom=Nombre FROM @Participantes WHERE Codigo=@EPA;
        SELECT @BID=IdParticipante,@BNom=Nombre FROM @Participantes WHERE Codigo=@EPB;

        SELECT @EID=IdEvento FROM dbo.Evento WHERE IdLiga=@ELiga AND Nombre=@EN;

        IF @EID IS NULL
        BEGIN
            SET @Inicio=DATEADD(HOUR,19,CAST(DATEADD(DAY,@Dias,CAST(SYSDATETIME() AS DATE)) AS DATETIME2));
            SET @Fin=DATEADD(HOUR,@Horas,@Inicio);

            SET @DuracionSimulacion=CASE WHEN @Sim=1 THEN 300 ELSE NULL END;

            EXEC dbo.sp_CrearEvento
              @IdUsuarioProceso=@Admin,@IdLiga=@ELiga,@Nombre=@EN,@FechaInicio=@Inicio,@FechaFin=@Fin,
              @IpOrigen='127.0.0.1',@EsSimulado=@Sim,
              @DuracionSimulacionSegundos=@DuracionSimulacion;

            SELECT @EID=IdEvento FROM dbo.Evento WHERE IdLiga=@ELiga AND Nombre=@EN;

            EXEC dbo.sp_AgregarParticipanteEvento
              @IdUsuarioProceso=@Admin,@IdEvento=@EID,@IdParticipante=@AID,
              @OrdenParticipante=1,@EsLocal=1,@IpOrigen='127.0.0.1';

            EXEC dbo.sp_AgregarParticipanteEvento
              @IdUsuarioProceso=@Admin,@IdEvento=@EID,@IdParticipante=@BID,
              @OrdenParticipante=2,@EsLocal=0,@IpOrigen='127.0.0.1';

            IF @CrearMerc=1
            BEGIN
                /* Mercado convencional */
                EXEC dbo.sp_CrearMercado
                  @IdUsuarioProceso=@Admin,@IdEvento=@EID,@Nombre='Ganador del evento',
                  @Descripcion='Mercado convencional principal para pruebas.',
                  @IpOrigen='127.0.0.1',@TipoMercado='CONVENCIONAL';

                SELECT @MConv=IdMercado FROM dbo.Mercado
                WHERE IdEvento=@EID AND Nombre='Ganador del evento';

                EXEC dbo.sp_CrearSeleccion
                  @IdUsuarioProceso=@Admin,@IdMercado=@MConv,@Nombre=@ANom,@IpOrigen='127.0.0.1';
                SELECT @SelA=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@MConv AND Nombre=@ANom;
                EXEC dbo.sp_RegistrarCuota
                  @IdUsuarioProceso=@Admin,@IdSeleccion=@SelA,@Valor=1.90,@IpOrigen='127.0.0.1';

                EXEC dbo.sp_CrearSeleccion
                  @IdUsuarioProceso=@Admin,@IdMercado=@MConv,@Nombre=@BNom,@IpOrigen='127.0.0.1';
                SELECT @SelB=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@MConv AND Nombre=@BNom;
                EXEC dbo.sp_RegistrarCuota
                  @IdUsuarioProceso=@Admin,@IdSeleccion=@SelB,@Valor=1.90,@IpOrigen='127.0.0.1';

                IF @EDeporte=@Futbol
                BEGIN
                    EXEC dbo.sp_CrearSeleccion
                      @IdUsuarioProceso=@Admin,@IdMercado=@MConv,@Nombre='Empate',@IpOrigen='127.0.0.1';
                    SELECT @SelE=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@MConv AND Nombre='Empate';
                    EXEC dbo.sp_RegistrarCuota
                      @IdUsuarioProceso=@Admin,@IdSeleccion=@SelE,@Valor=3.10,@IpOrigen='127.0.0.1';
                END;

                /* Marcador final + primera anotacion: solo eventos simulados habilitados. */
                IF @Sim=1
                BEGIN
                    EXEC dbo.sp_CrearMercado
                      @IdUsuarioProceso=@Admin,@IdEvento=@EID,@Nombre='Marcador final',
                      @Descripcion='Pronostico exacto o resultado del marcador.',
                      @IpOrigen='127.0.0.1',@TipoMercado='MARCADOR_FINAL';

                    SELECT @MMarc=IdMercado FROM dbo.Mercado
                    WHERE IdEvento=@EID AND TipoMercado='MARCADOR_FINAL';

                    EXEC dbo.sp_CrearSeleccion
                      @IdUsuarioProceso=@Admin,@IdMercado=@MMarc,@Nombre='Pronostico marcador',@IpOrigen='127.0.0.1';
                    SELECT @SelM=IdSeleccion FROM dbo.Seleccion WHERE IdMercado=@MMarc;

                    /* NULL usa configuracion oficial: exacto x3.00 / resultado x1.50. */
                    EXEC dbo.sp_RegistrarCuota
                      @IdUsuarioProceso=@Admin,@IdSeleccion=@SelM,@Valor=NULL,
                      @IpOrigen='127.0.0.1',@ValorResultado=NULL;

                    EXEC dbo.sp_CrearMercado
                      @IdUsuarioProceso=@Admin,@IdEvento=@EID,@Nombre='Primera anotacion',
                      @Descripcion='Participante que realiza la primera anotacion valida.',
                      @IpOrigen='127.0.0.1',@TipoMercado='PRIMERA_ANOTACION';

                    SELECT @MPrim=IdMercado FROM dbo.Mercado
                    WHERE IdEvento=@EID AND TipoMercado='PRIMERA_ANOTACION';

                    EXEC dbo.sp_CrearSeleccion
                      @IdUsuarioProceso=@Admin,@IdMercado=@MPrim,@Nombre=@ANom,
                      @IpOrigen='127.0.0.1',@IdParticipante=@AID;
                    SELECT @SelA=IdSeleccion FROM dbo.Seleccion
                    WHERE IdMercado=@MPrim AND IdParticipante=@AID;
                    EXEC dbo.sp_RegistrarCuota
                      @IdUsuarioProceso=@Admin,@IdSeleccion=@SelA,@Valor=NULL,@IpOrigen='127.0.0.1';

                    EXEC dbo.sp_CrearSeleccion
                      @IdUsuarioProceso=@Admin,@IdMercado=@MPrim,@Nombre=@BNom,
                      @IpOrigen='127.0.0.1',@IdParticipante=@BID;
                    SELECT @SelB=IdSeleccion FROM dbo.Seleccion
                    WHERE IdMercado=@MPrim AND IdParticipante=@BID;
                    EXEC dbo.sp_RegistrarCuota
                      @IdUsuarioProceso=@Admin,@IdSeleccion=@SelB,@Valor=NULL,@IpOrigen='127.0.0.1';
                END;

                IF @Publicar=1
                BEGIN
                    EXEC dbo.sp_CambiarEstadoEvento
                      @IdUsuarioProceso=@Admin,@IdEvento=@EID,@NuevoEstado='PROGRAMADO',
                      @Motivo='Publicacion inicial oficial para pruebas.',@IpOrigen='127.0.0.1';

                    DECLARE cMA CURSOR LOCAL FAST_FORWARD FOR
                      SELECT M.IdMercado
                      FROM dbo.Mercado M
                      JOIN dbo.Estado E ON E.IdEstado=M.IdEstado
                      JOIN dbo.TipoEstado T ON T.IdTipoEstado=E.IdTipoEstado AND T.Codigo='MERCADO'
                      WHERE M.IdEvento=@EID AND E.Codigo='BORRADOR'
                      ORDER BY M.IdMercado;

                    OPEN cMA; FETCH NEXT FROM cMA INTO @MAbrir;
                    WHILE @@FETCH_STATUS=0
                    BEGIN
                        EXEC dbo.sp_CambiarEstadoMercado
                          @IdUsuarioProceso=@Admin,@IdMercado=@MAbrir,@NuevoEstado='ABIERTO',
                          @Motivo='Apertura inicial oficial para pruebas.',@IpOrigen='127.0.0.1';
                        FETCH NEXT FROM cMA INTO @MAbrir;
                    END;
                    CLOSE cMA; DEALLOCATE cMA;
                END;
            END;
        END;

        UPDATE @Eventos SET IdEvento=@EID WHERE Codigo=@EC;
        FETCH NEXT FROM cE INTO @EC,@ELC,@EN,@Dias,@Horas,@EPA,@EPB,@Sim,@Publicar,@CrearMerc;
    END;
    CLOSE cE; DEALLOCATE cE;

    /* 5. Validacion final */
    IF EXISTS(SELECT 1 FROM @Usuarios P LEFT JOIN dbo.Usuario U ON U.Correo=P.Correo WHERE U.IdUsuario IS NULL)
        THROW 78030,'Validacion final: falta usuario de prueba.',1;
    IF EXISTS(SELECT 1 FROM @Ligas WHERE IdLiga IS NULL)
        THROW 78031,'Validacion final: falta liga oficial.',1;
    IF EXISTS(SELECT 1 FROM @Participantes WHERE IdParticipante IS NULL)
        THROW 78032,'Validacion final: falta participante oficial.',1;
    IF EXISTS(SELECT 1 FROM @Eventos WHERE IdEvento IS NULL)
        THROW 78033,'Validacion final: falta evento oficial.',1;

    COMMIT TRANSACTION;

    PRINT '=======================================================';
    PRINT ' DATOS INICIALES OFICIALES CARGADOS CORRECTAMENTE';
    PRINT '=======================================================';
    PRINT ' Administradores oficiales: 5';
    PRINT ' CASA: conservada';
    PRINT ' Usuarios de prueba: 6';
    PRINT ' Saldo inicial unico por usuario de prueba: Q2,000.00';
    PRINT ' Ligas: LALIGA, Liga Nacional GT, NBA, MLB, ATP, WTA';
    PRINT ' Eventos PROGRAMADOS listos para usuario: 8';
    PRINT ' Evento BORRADOR listo para admin: 1';
    PRINT ' Apuestas/boletos precargados: 0';
    PRINT '=======================================================';

    SELECT R.Nombre AS Rol,U.Correo,E.Codigo AS EstadoUsuario,U.CorreoVerificado,
           B.SaldoDisponible,B.SaldoComprometido
    FROM dbo.Usuario U
    JOIN dbo.Rol R ON R.IdRol=U.IdRol
    JOIN dbo.Estado E ON E.IdEstado=U.IdEstado
    LEFT JOIN dbo.Billetera B ON B.IdUsuario=U.IdUsuario
    WHERE U.Correo IN (
      'gabriel@apuestas.local','wilson@apuestas.local','otto@apuestas.local',
      'kevin@apuestas.local','fernando@apuestas.local','casa@apuestas.local',
      'cliente.ana@apuestas.test','cliente.carlos@apuestas.test','cliente.sofia@apuestas.test',
      'cliente.mateo@apuestas.test','cliente.lucia@apuestas.test','cliente.diego@apuestas.test'
    )
    ORDER BY R.Nombre,U.Correo;

    SELECT D.Nombre AS Deporte,L.Nombre AS Liga,L.Activo
    FROM dbo.Liga L JOIN dbo.Deporte D ON D.IdDeporte=L.IdDeporte
    WHERE L.Nombre IN('LALIGA EA SPORTS','Liga Nacional de Guatemala','NBA','MLB','ATP Tour','WTA Tour')
    ORDER BY D.Nombre,L.Nombre;

    SELECT EV.IdEvento,EV.Nombre,D.Nombre AS Deporte,L.Nombre AS Liga,
           EE.Codigo AS EstadoEvento,EV.EsSimulado,EV.DuracionSimulacionSegundos,EV.FechaInicio
    FROM dbo.Evento EV
    JOIN dbo.Liga L ON L.IdLiga=EV.IdLiga
    JOIN dbo.Deporte D ON D.IdDeporte=L.IdDeporte
    JOIN dbo.Estado EE ON EE.IdEstado=EV.IdEstado
    WHERE EV.Nombre LIKE 'OFICIAL%'
    ORDER BY EV.IdEvento;

END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
