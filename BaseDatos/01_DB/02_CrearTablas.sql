/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   SQL SERVER 2022 / AZURE SQL

   ARCHIVO:
   01_DB/02_CrearTablas.sql

   OBJETIVO:
   Crear la estructura definitiva normalizada del sistema.

   IMPORTANTE:
   - No contiene USE para mantener compatibilidad con Azure SQL.
   - Debe ejecutarse conectado a PlataformaApuestas.
   - Los nombres de las tablas se manejan en singular.
   ============================================================ */


/* ============================================================
   1. ROL
   ============================================================ */

IF OBJECT_ID('dbo.Rol', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Rol
    (
        IdRol INT IDENTITY(1,1) NOT NULL,
        Nombre VARCHAR(50) NOT NULL,
        Descripcion VARCHAR(200) NULL,

        Activo BIT NOT NULL
            CONSTRAINT DF_Rol_Activo DEFAULT 1,

        CONSTRAINT PK_Rol PRIMARY KEY (IdRol),
        CONSTRAINT UQ_Rol_Nombre UNIQUE (Nombre)
    );

    PRINT 'Tabla Rol creada.';
END;
GO


/* ============================================================
   2. PAIS
   ============================================================ */

IF OBJECT_ID('dbo.Pais', 'U') IS NULL
BEGIN

    CREATE TABLE dbo.Pais
    (
        IdPais INT IDENTITY(1,1) NOT NULL,

        CodigoISO2 CHAR(2) NOT NULL,
        CodigoISO3 CHAR(3) NOT NULL,

        Nombre NVARCHAR(100) NOT NULL,

        CodigoTelefonico VARCHAR(15) NULL,

        BanderaEmoji NVARCHAR(8) NULL,

        Activo BIT NOT NULL
            CONSTRAINT DF_Pais_Activo
            DEFAULT (1),

        CONSTRAINT PK_Pais
            PRIMARY KEY (IdPais),

        CONSTRAINT UQ_Pais_CodigoISO2
            UNIQUE (CodigoISO2),

        CONSTRAINT UQ_Pais_CodigoISO3
            UNIQUE (CodigoISO3),

        CONSTRAINT UQ_Pais_Nombre
            UNIQUE (Nombre)
    );


    PRINT 'Tabla Pais creada.';

END
ELSE
BEGIN

    PRINT 'Tabla Pais ya existe.';

END;
GO


/* ============================================================
   3. DEPARTAMENTO
   ============================================================ */

IF OBJECT_ID('dbo.Departamento', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Departamento
    (
        IdDepartamento INT IDENTITY(1,1) NOT NULL,
        IdPais INT NOT NULL,
        Nombre VARCHAR(100) NOT NULL,

        Activo BIT NOT NULL
            CONSTRAINT DF_Departamento_Activo DEFAULT 1,

        CONSTRAINT PK_Departamento
            PRIMARY KEY (IdDepartamento),

        CONSTRAINT FK_Departamento_Pais
            FOREIGN KEY (IdPais)
            REFERENCES dbo.Pais(IdPais),

        CONSTRAINT UQ_Departamento_Pais_Nombre
            UNIQUE (IdPais, Nombre)
    );

    PRINT 'Tabla Departamento creada.';
END;
GO


/* ============================================================
   4. MUNICIPIO
   ============================================================ */

IF OBJECT_ID('dbo.Municipio', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Municipio
    (
        IdMunicipio INT IDENTITY(1,1) NOT NULL,
        IdDepartamento INT NOT NULL,
        Nombre VARCHAR(100) NOT NULL,

        Activo BIT NOT NULL
            CONSTRAINT DF_Municipio_Activo DEFAULT 1,

        CONSTRAINT PK_Municipio
            PRIMARY KEY (IdMunicipio),

        CONSTRAINT FK_Municipio_Departamento
            FOREIGN KEY (IdDepartamento)
            REFERENCES dbo.Departamento(IdDepartamento),

        CONSTRAINT UQ_Municipio_Departamento_Nombre
            UNIQUE (IdDepartamento, Nombre)
    );

    PRINT 'Tabla Municipio creada.';
END;
GO


/* ============================================================
   5. TIPO ESTADO
   ============================================================ */

IF OBJECT_ID('dbo.TipoEstado', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TipoEstado
    (
        IdTipoEstado INT IDENTITY(1,1) NOT NULL,
        Codigo VARCHAR(40) NOT NULL,
        Nombre VARCHAR(100) NOT NULL,
        Descripcion VARCHAR(250) NULL,

        CONSTRAINT PK_TipoEstado
            PRIMARY KEY (IdTipoEstado),

        CONSTRAINT UQ_TipoEstado_Codigo
            UNIQUE (Codigo)
    );

    PRINT 'Tabla TipoEstado creada.';
END;
GO


/* ============================================================
   6. ESTADO
   ============================================================ */

IF OBJECT_ID('dbo.Estado', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Estado
    (
        IdEstado INT IDENTITY(1,1) NOT NULL,
        IdTipoEstado INT NOT NULL,

        Codigo VARCHAR(40) NOT NULL,
        Nombre VARCHAR(100) NOT NULL,
        Descripcion VARCHAR(250) NULL,

        Orden SMALLINT NOT NULL
            CONSTRAINT DF_Estado_Orden DEFAULT 1,

        Activo BIT NOT NULL
            CONSTRAINT DF_Estado_Activo DEFAULT 1,

        CONSTRAINT PK_Estado
            PRIMARY KEY (IdEstado),

        CONSTRAINT FK_Estado_TipoEstado
            FOREIGN KEY (IdTipoEstado)
            REFERENCES dbo.TipoEstado(IdTipoEstado),

        CONSTRAINT UQ_Estado_Tipo_Codigo
            UNIQUE (IdTipoEstado, Codigo),

        CONSTRAINT CK_Estado_Orden
            CHECK (Orden > 0)
    );

    PRINT 'Tabla Estado creada.';
END;
GO


/* ============================================================
   7. USUARIO
   Cuenta de acceso al sistema.
   Los datos personales se separan en PerfilUsuario.
   ============================================================ */

IF OBJECT_ID('dbo.Usuario', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Usuario
    (
        IdUsuario INT IDENTITY(1,1) NOT NULL,
        IdRol INT NOT NULL,
        IdEstado INT NOT NULL,

        Correo VARCHAR(150) NOT NULL,
        Contrasena VARCHAR(255) NOT NULL,

        CorreoVerificado BIT NOT NULL
            CONSTRAINT DF_Usuario_CorreoVerificado DEFAULT 0,

        IntentosFallidos TINYINT NOT NULL
            CONSTRAINT DF_Usuario_IntentosFallidos DEFAULT 0,

        BloqueadoHasta DATETIME2 NULL,
        UltimoAcceso DATETIME2 NULL,

        FechaRegistro DATETIME2 NOT NULL
            CONSTRAINT DF_Usuario_FechaRegistro
            DEFAULT SYSDATETIME(),

        VersionFila ROWVERSION NOT NULL,

        CONSTRAINT PK_Usuario
            PRIMARY KEY (IdUsuario),

        CONSTRAINT UQ_Usuario_Correo
            UNIQUE (Correo),

        CONSTRAINT FK_Usuario_Rol
            FOREIGN KEY (IdRol)
            REFERENCES dbo.Rol(IdRol),

        CONSTRAINT FK_Usuario_Estado
            FOREIGN KEY (IdEstado)
            REFERENCES dbo.Estado(IdEstado)
    );

    PRINT 'Tabla Usuario creada.';
END;
GO


/* ============================================================
   8. PERFIL USUARIO
   Datos personales del cliente.
   ============================================================ */

IF OBJECT_ID('dbo.PerfilUsuario', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PerfilUsuario
    (
        IdUsuario INT NOT NULL,

        Nombre VARCHAR(100) NOT NULL,
        Apellido VARCHAR(100) NOT NULL,

        FechaNacimiento DATE NOT NULL,

        Genero CHAR(1) NOT NULL,

        Telefono VARCHAR(25) NOT NULL,

        TipoDocumento VARCHAR(20) NOT NULL,
        NumeroDocumento VARCHAR(50) NOT NULL,

        IdPais INT NOT NULL,
        IdMunicipio INT NULL,

        CiudadExterior VARCHAR(120) NULL,

        Direccion VARCHAR(250) NOT NULL,

        FechaActualizacion DATETIME2 NOT NULL
            CONSTRAINT DF_PerfilUsuario_FechaActualizacion
            DEFAULT SYSDATETIME(),

        CONSTRAINT PK_PerfilUsuario
            PRIMARY KEY (IdUsuario),

        CONSTRAINT FK_PerfilUsuario_Usuario
            FOREIGN KEY (IdUsuario)
            REFERENCES dbo.Usuario(IdUsuario),

        CONSTRAINT FK_PerfilUsuario_Pais
            FOREIGN KEY (IdPais)
            REFERENCES dbo.Pais(IdPais),

        CONSTRAINT FK_PerfilUsuario_Municipio
            FOREIGN KEY (IdMunicipio)
            REFERENCES dbo.Municipio(IdMunicipio),

        CONSTRAINT CK_PerfilUsuario_Genero
            CHECK (Genero IN ('M', 'F')),

        CONSTRAINT CK_PerfilUsuario_TipoDocumento
            CHECK
            (
                TipoDocumento IN
                (
                    'DPI',
                    'PASAPORTE',
                    'OTRO'
                )
            ),

        /* Guatemala usa municipio.
           Extranjero utiliza CiudadExterior.
           Nunca ambos simultaneamente. */
        CONSTRAINT CK_PerfilUsuario_Ubicacion
            CHECK
            (
                (IdMunicipio IS NOT NULL AND CiudadExterior IS NULL)
                OR
                (IdMunicipio IS NULL AND CiudadExterior IS NOT NULL)
            )
    );

    PRINT 'Tabla PerfilUsuario creada.';
END;
GO


/* ============================================================
   9. VERIFICACION USUARIO
   ============================================================ */

IF OBJECT_ID('dbo.VerificacionUsuario', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.VerificacionUsuario
    (
        IdVerificacion INT IDENTITY(1,1) NOT NULL,
        IdUsuario INT NOT NULL,
        IdEstado INT NOT NULL,

        IdUsuarioRevisor INT NULL,

        FechaSolicitud DATETIME2 NOT NULL
            CONSTRAINT DF_VerificacionUsuario_FechaSolicitud
            DEFAULT SYSDATETIME(),

        FechaInicioRevision DATETIME2 NULL,
        FechaResolucion DATETIME2 NULL,

        Observacion VARCHAR(500) NULL,

        CONSTRAINT PK_VerificacionUsuario
            PRIMARY KEY (IdVerificacion),

        CONSTRAINT FK_VerificacionUsuario_Usuario
            FOREIGN KEY (IdUsuario)
            REFERENCES dbo.Usuario(IdUsuario),

        CONSTRAINT FK_VerificacionUsuario_Estado
            FOREIGN KEY (IdEstado)
            REFERENCES dbo.Estado(IdEstado),

        CONSTRAINT FK_VerificacionUsuario_Revisor
            FOREIGN KEY (IdUsuarioRevisor)
            REFERENCES dbo.Usuario(IdUsuario),

        CONSTRAINT CK_VerificacionUsuario_Fechas
            CHECK
            (
                FechaResolucion IS NULL
                OR FechaResolucion >= FechaSolicitud
            )
    );

    PRINT 'Tabla VerificacionUsuario creada.';
END;
GO


/* ============================================================
   10. RESTRICCION USUARIO
   Permite restringir apuestas sin impedir login.
   ============================================================ */

IF OBJECT_ID('dbo.RestriccionUsuario', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.RestriccionUsuario
    (
        IdRestriccion INT IDENTITY(1,1) NOT NULL,

        IdUsuario INT NOT NULL,
        IdUsuarioRegistro INT NOT NULL,

        TipoRestriccion VARCHAR(30) NOT NULL,
        Motivo VARCHAR(500) NOT NULL,

        FechaInicio DATETIME2 NOT NULL
            CONSTRAINT DF_RestriccionUsuario_FechaInicio
            DEFAULT SYSDATETIME(),

        FechaFin DATETIME2 NULL,

        Activa BIT NOT NULL
            CONSTRAINT DF_RestriccionUsuario_Activa DEFAULT 1,

        FechaRegistro DATETIME2 NOT NULL
            CONSTRAINT DF_RestriccionUsuario_FechaRegistro
            DEFAULT SYSDATETIME(),

        CONSTRAINT PK_RestriccionUsuario
            PRIMARY KEY (IdRestriccion),

        CONSTRAINT FK_RestriccionUsuario_Usuario
            FOREIGN KEY (IdUsuario)
            REFERENCES dbo.Usuario(IdUsuario),

        CONSTRAINT FK_RestriccionUsuario_UsuarioRegistro
            FOREIGN KEY (IdUsuarioRegistro)
            REFERENCES dbo.Usuario(IdUsuario),

        CONSTRAINT CK_RestriccionUsuario_Tipo
            CHECK
            (
                TipoRestriccion IN
                (
                    'APOSTAR',
                    'TODAS_OPERACIONES'
                )
            ),

        CONSTRAINT CK_RestriccionUsuario_Fechas
            CHECK
            (
                FechaFin IS NULL
                OR FechaFin >= FechaInicio
            )
    );

    PRINT 'Tabla RestriccionUsuario creada.';
END;
GO


/* ============================================================
   11. TOKEN SEGURIDAD
   ============================================================ */

IF OBJECT_ID('dbo.TokenSeguridad', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TokenSeguridad
    (
        IdToken INT IDENTITY(1,1) NOT NULL,
        IdUsuario INT NOT NULL,

        TipoToken VARCHAR(30) NOT NULL,

        TokenHash CHAR(64) NOT NULL,

        FechaCreacion DATETIME2 NOT NULL
            CONSTRAINT DF_TokenSeguridad_FechaCreacion
            DEFAULT SYSDATETIME(),

        FechaExpiracion DATETIME2 NOT NULL,

        FechaUso DATETIME2 NULL,

        CONSTRAINT PK_TokenSeguridad
            PRIMARY KEY (IdToken),

        CONSTRAINT FK_TokenSeguridad_Usuario
            FOREIGN KEY (IdUsuario)
            REFERENCES dbo.Usuario(IdUsuario),

        CONSTRAINT UQ_TokenSeguridad_TokenHash
            UNIQUE (TokenHash),

        CONSTRAINT CK_TokenSeguridad_Tipo
            CHECK
            (
                TipoToken IN
                (
                    'VERIFICACION_CORREO',
                    'RECUPERACION_CONTRASENA'
                )
            ),

        CONSTRAINT CK_TokenSeguridad_Expiracion
            CHECK (FechaExpiracion > FechaCreacion),

        CONSTRAINT CK_TokenSeguridad_FechaUso
            CHECK
            (
                FechaUso IS NULL
                OR FechaUso >= FechaCreacion
            )
    );

    PRINT 'Tabla TokenSeguridad creada.';
END;
GO


/* ============================================================
   12. DEPORTE
   ============================================================ */

IF OBJECT_ID('dbo.Deporte', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Deporte
    (
        IdDeporte INT IDENTITY(1,1) NOT NULL,
        Nombre VARCHAR(100) NOT NULL,
        Descripcion VARCHAR(250) NULL,

        Activo BIT NOT NULL
            CONSTRAINT DF_Deporte_Activo DEFAULT 1,

        CONSTRAINT PK_Deporte PRIMARY KEY (IdDeporte),
        CONSTRAINT UQ_Deporte_Nombre UNIQUE (Nombre)
    );

    PRINT 'Tabla Deporte creada.';
END;
GO


/* ============================================================
   13. LIGA
   ============================================================ */

IF OBJECT_ID('dbo.Liga', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Liga
    (
        IdLiga INT IDENTITY(1,1) NOT NULL,
        IdDeporte INT NOT NULL,

        /* NULL permite ligas internacionales. */
        IdPais INT NULL,

        Nombre VARCHAR(150) NOT NULL,

        Activo BIT NOT NULL
            CONSTRAINT DF_Liga_Activo DEFAULT 1,

        CONSTRAINT PK_Liga PRIMARY KEY (IdLiga),

        CONSTRAINT FK_Liga_Deporte
            FOREIGN KEY (IdDeporte)
            REFERENCES dbo.Deporte(IdDeporte),

        CONSTRAINT FK_Liga_Pais
            FOREIGN KEY (IdPais)
            REFERENCES dbo.Pais(IdPais),

        CONSTRAINT UQ_Liga_Deporte_Nombre
            UNIQUE (IdDeporte, Nombre)
    );

    PRINT 'Tabla Liga creada.';
END;
GO


/* ============================================================
   14. PARTICIPANTE
   ============================================================ */

IF OBJECT_ID('dbo.Participante', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Participante
    (
        IdParticipante INT IDENTITY(1,1) NOT NULL,
        IdDeporte INT NOT NULL,

        IdPais INT NULL,

        Nombre VARCHAR(150) NOT NULL,
        TipoParticipante VARCHAR(30) NOT NULL,

        Activo BIT NOT NULL
            CONSTRAINT DF_Participante_Activo DEFAULT 1,

        CONSTRAINT PK_Participante
            PRIMARY KEY (IdParticipante),

        CONSTRAINT FK_Participante_Deporte
            FOREIGN KEY (IdDeporte)
            REFERENCES dbo.Deporte(IdDeporte),

        CONSTRAINT FK_Participante_Pais
            FOREIGN KEY (IdPais)
            REFERENCES dbo.Pais(IdPais),

        CONSTRAINT CK_Participante_Tipo
            CHECK
            (
                TipoParticipante IN
                (
                    'EQUIPO',
                    'ATLETA'
                )
            )
    );

    PRINT 'Tabla Participante creada.';
END;
GO


/* ============================================================
   15. EVENTO
   ============================================================ */

IF OBJECT_ID('dbo.Evento', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Evento
    (
        IdEvento INT IDENTITY(1,1) NOT NULL,
        IdLiga INT NOT NULL,
        IdEstado INT NOT NULL,

        Nombre VARCHAR(200) NOT NULL,

        FechaInicio DATETIME2 NOT NULL,
        FechaFin DATETIME2 NULL,

        FechaCreacion DATETIME2 NOT NULL
            CONSTRAINT DF_Evento_FechaCreacion
            DEFAULT SYSDATETIME(),

        VersionFila ROWVERSION NOT NULL,

        CONSTRAINT PK_Evento PRIMARY KEY (IdEvento),

        CONSTRAINT FK_Evento_Liga
            FOREIGN KEY (IdLiga)
            REFERENCES dbo.Liga(IdLiga),

        CONSTRAINT FK_Evento_Estado
            FOREIGN KEY (IdEstado)
            REFERENCES dbo.Estado(IdEstado),

        CONSTRAINT CK_Evento_Fechas
            CHECK
            (
                FechaFin IS NULL
                OR FechaFin > FechaInicio
            )
    );

    PRINT 'Tabla Evento creada.';
END;
GO


/* ============================================================
   16. EVENTO PARTICIPANTE
   ============================================================ */

IF OBJECT_ID('dbo.EventoParticipante', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EventoParticipante
    (
        IdEventoParticipante INT IDENTITY(1,1) NOT NULL,

        IdEvento INT NOT NULL,
        IdParticipante INT NOT NULL,

        OrdenParticipante TINYINT NOT NULL,

        EsLocal BIT NULL,

        CONSTRAINT PK_EventoParticipante
            PRIMARY KEY (IdEventoParticipante),

        CONSTRAINT FK_EventoParticipante_Evento
            FOREIGN KEY (IdEvento)
            REFERENCES dbo.Evento(IdEvento),

        CONSTRAINT FK_EventoParticipante_Participante
            FOREIGN KEY (IdParticipante)
            REFERENCES dbo.Participante(IdParticipante),

        CONSTRAINT UQ_EventoParticipante_Evento_Participante
            UNIQUE (IdEvento, IdParticipante),

        CONSTRAINT UQ_EventoParticipante_Orden
            UNIQUE (IdEvento, OrdenParticipante),

        CONSTRAINT CK_EventoParticipante_Orden
            CHECK (OrdenParticipante > 0)
    );

    PRINT 'Tabla EventoParticipante creada.';
END;
GO


/* ============================================================
   17. MERCADO
   ============================================================ */

IF OBJECT_ID('dbo.Mercado', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Mercado
    (
        IdMercado INT IDENTITY(1,1) NOT NULL,

        IdEvento INT NOT NULL,
        IdEstado INT NOT NULL,

        Nombre VARCHAR(150) NOT NULL,
        Descripcion VARCHAR(250) NULL,

        FechaCreacion DATETIME2 NOT NULL
            CONSTRAINT DF_Mercado_FechaCreacion
            DEFAULT SYSDATETIME(),

        CONSTRAINT PK_Mercado PRIMARY KEY (IdMercado),

        CONSTRAINT FK_Mercado_Evento
            FOREIGN KEY (IdEvento)
            REFERENCES dbo.Evento(IdEvento),

        CONSTRAINT FK_Mercado_Estado
            FOREIGN KEY (IdEstado)
            REFERENCES dbo.Estado(IdEstado)
    );

    PRINT 'Tabla Mercado creada.';
END;
GO


/* ============================================================
   18. SELECCION
   ============================================================ */

IF OBJECT_ID('dbo.Seleccion', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Seleccion
    (
        IdSeleccion INT IDENTITY(1,1) NOT NULL,
        IdMercado INT NOT NULL,

        Nombre VARCHAR(150) NOT NULL,

        Activo BIT NOT NULL
            CONSTRAINT DF_Seleccion_Activo DEFAULT 1,

        CONSTRAINT PK_Seleccion PRIMARY KEY (IdSeleccion),

        CONSTRAINT FK_Seleccion_Mercado
            FOREIGN KEY (IdMercado)
            REFERENCES dbo.Mercado(IdMercado),

        CONSTRAINT UQ_Seleccion_Mercado_Nombre
            UNIQUE (IdMercado, Nombre)
    );

    PRINT 'Tabla Seleccion creada.';
END;
GO


/* ============================================================
   19. CUOTA
   Histórico de cuotas.
   ============================================================ */

IF OBJECT_ID('dbo.Cuota', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Cuota
    (
        IdCuota INT IDENTITY(1,1) NOT NULL,
        IdSeleccion INT NOT NULL,

        Valor DECIMAL(10,4) NOT NULL,

        FechaInicio DATETIME2 NOT NULL
            CONSTRAINT DF_Cuota_FechaInicio
            DEFAULT SYSDATETIME(),

        FechaFin DATETIME2 NULL,

        Activo BIT NOT NULL
            CONSTRAINT DF_Cuota_Activo DEFAULT 1,

        CONSTRAINT PK_Cuota PRIMARY KEY (IdCuota),

        CONSTRAINT FK_Cuota_Seleccion
            FOREIGN KEY (IdSeleccion)
            REFERENCES dbo.Seleccion(IdSeleccion),

        CONSTRAINT CK_Cuota_Valor
            CHECK (Valor > 1),

        CONSTRAINT CK_Cuota_Fechas
            CHECK
            (
                FechaFin IS NULL
                OR FechaFin > FechaInicio
            )
    );

    PRINT 'Tabla Cuota creada.';
END;
GO


/* ============================================================
   20. RESULTADO EVENTO
   ============================================================ */

IF OBJECT_ID('dbo.ResultadoEvento', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ResultadoEvento
    (
        IdResultado INT IDENTITY(1,1) NOT NULL,

        IdEvento INT NOT NULL,
        IdEstado INT NOT NULL,
        IdUsuarioRegistro INT NOT NULL,

        ResultadoTexto VARCHAR(250) NOT NULL,
        Observacion VARCHAR(500) NULL,

        FechaRegistro DATETIME2 NOT NULL
            CONSTRAINT DF_ResultadoEvento_FechaRegistro
            DEFAULT SYSDATETIME(),

        CONSTRAINT PK_ResultadoEvento
            PRIMARY KEY (IdResultado),

        CONSTRAINT UQ_ResultadoEvento_Evento
            UNIQUE (IdEvento),

        CONSTRAINT FK_ResultadoEvento_Evento
            FOREIGN KEY (IdEvento)
            REFERENCES dbo.Evento(IdEvento),

        CONSTRAINT FK_ResultadoEvento_Estado
            FOREIGN KEY (IdEstado)
            REFERENCES dbo.Estado(IdEstado),

        CONSTRAINT FK_ResultadoEvento_Usuario
            FOREIGN KEY (IdUsuarioRegistro)
            REFERENCES dbo.Usuario(IdUsuario)
    );

    PRINT 'Tabla ResultadoEvento creada.';
END;
GO


/* ============================================================
   21. RESOLUCION SELECCION
   ============================================================ */

IF OBJECT_ID('dbo.ResolucionSeleccion', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ResolucionSeleccion
    (
        IdResolucion INT IDENTITY(1,1) NOT NULL,

        IdSeleccion INT NOT NULL,
        IdResultadoEvento INT NOT NULL,
        IdUsuarioRegistro INT NOT NULL,

        Resultado VARCHAR(20) NOT NULL,

        FechaResolucion DATETIME2 NOT NULL
            CONSTRAINT DF_ResolucionSeleccion_Fecha
            DEFAULT SYSDATETIME(),

        Observacion VARCHAR(500) NULL,

        CONSTRAINT PK_ResolucionSeleccion
            PRIMARY KEY (IdResolucion),

        CONSTRAINT UQ_ResolucionSeleccion_Seleccion
            UNIQUE (IdSeleccion),

        CONSTRAINT FK_ResolucionSeleccion_Seleccion
            FOREIGN KEY (IdSeleccion)
            REFERENCES dbo.Seleccion(IdSeleccion),

        CONSTRAINT FK_ResolucionSeleccion_ResultadoEvento
            FOREIGN KEY (IdResultadoEvento)
            REFERENCES dbo.ResultadoEvento(IdResultado),

        CONSTRAINT FK_ResolucionSeleccion_Usuario
            FOREIGN KEY (IdUsuarioRegistro)
            REFERENCES dbo.Usuario(IdUsuario),

        CONSTRAINT CK_ResolucionSeleccion_Resultado
            CHECK
            (
                Resultado IN
                (
                    'GANADA',
                    'PERDIDA',
                    'ANULADA'
                )
            )
    );

    PRINT 'Tabla ResolucionSeleccion creada.';
END;
GO


/* ============================================================
   22. BILLETERA
   Saldo exclusivamente virtual.
   ============================================================ */

IF OBJECT_ID('dbo.Billetera', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Billetera
    (
        IdBilletera INT IDENTITY(1,1) NOT NULL,
        IdUsuario INT NOT NULL,

        SaldoDisponible DECIMAL(12,2) NOT NULL
            CONSTRAINT DF_Billetera_SaldoDisponible DEFAULT 0,

        SaldoComprometido DECIMAL(12,2) NOT NULL
            CONSTRAINT DF_Billetera_SaldoComprometido DEFAULT 0,

        FechaCreacion DATETIME2 NOT NULL
            CONSTRAINT DF_Billetera_FechaCreacion
            DEFAULT SYSDATETIME(),

        VersionFila ROWVERSION NOT NULL,

        CONSTRAINT PK_Billetera PRIMARY KEY (IdBilletera),

        CONSTRAINT UQ_Billetera_Usuario
            UNIQUE (IdUsuario),

        CONSTRAINT FK_Billetera_Usuario
            FOREIGN KEY (IdUsuario)
            REFERENCES dbo.Usuario(IdUsuario),

        CONSTRAINT CK_Billetera_SaldoDisponible
            CHECK (SaldoDisponible >= 0),

        CONSTRAINT CK_Billetera_SaldoComprometido
            CHECK (SaldoComprometido >= 0)
    );

    PRINT 'Tabla Billetera creada.';
END;
GO


/* ============================================================
   23. BOLETO
   ============================================================ */

IF OBJECT_ID('dbo.Boleto', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Boleto
    (
        IdBoleto INT IDENTITY(1,1) NOT NULL,

        CodigoBoleto VARCHAR(40) NOT NULL,

        IdUsuario INT NOT NULL,
        IdEstado INT NOT NULL,

        ReferenciaOperacion UNIQUEIDENTIFIER NOT NULL,

        MontoApostado DECIMAL(12,2) NOT NULL,
        CuotaTotal DECIMAL(12,4) NOT NULL,
        GananciaPotencial DECIMAL(12,2) NOT NULL,

        TipoBoleto VARCHAR(20) NOT NULL,

        Resultado VARCHAR(20) NOT NULL
            CONSTRAINT DF_Boleto_Resultado DEFAULT 'PENDIENTE',

        FechaCreacion DATETIME2 NOT NULL
            CONSTRAINT DF_Boleto_FechaCreacion
            DEFAULT SYSDATETIME(),

        FechaLiquidacion DATETIME2 NULL,

        CONSTRAINT PK_Boleto PRIMARY KEY (IdBoleto),

        CONSTRAINT UQ_Boleto_Codigo
            UNIQUE (CodigoBoleto),

        CONSTRAINT UQ_Boleto_Referencia
            UNIQUE (ReferenciaOperacion),

        CONSTRAINT FK_Boleto_Usuario
            FOREIGN KEY (IdUsuario)
            REFERENCES dbo.Usuario(IdUsuario),

        CONSTRAINT FK_Boleto_Estado
            FOREIGN KEY (IdEstado)
            REFERENCES dbo.Estado(IdEstado),

        CONSTRAINT CK_Boleto_Monto
            CHECK (MontoApostado > 0),

        CONSTRAINT CK_Boleto_CuotaTotal
            CHECK (CuotaTotal > 1),

        CONSTRAINT CK_Boleto_GananciaPotencial
            CHECK (GananciaPotencial >= MontoApostado),

        CONSTRAINT CK_Boleto_Tipo
            CHECK
            (
                TipoBoleto IN
                (
                    'SIMPLE',
                    'COMPUESTO'
                )
            ),

        CONSTRAINT CK_Boleto_Resultado
            CHECK
            (
                Resultado IN
                (
                    'PENDIENTE',
                    'GANADOR',
                    'PERDEDOR',
                    'ANULADO'
                )
            ),

        CONSTRAINT CK_Boleto_FechaLiquidacion
            CHECK
            (
                FechaLiquidacion IS NULL
                OR FechaLiquidacion >= FechaCreacion
            )
    );

    PRINT 'Tabla Boleto creada.';
END;
GO


/* ============================================================
   24. DETALLE BOLETO
   ============================================================ */

IF OBJECT_ID('dbo.DetalleBoleto', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DetalleBoleto
    (
        IdDetalle INT IDENTITY(1,1) NOT NULL,

        IdBoleto INT NOT NULL,
        IdSeleccion INT NOT NULL,

        CuotaAplicada DECIMAL(10,4) NOT NULL,

        Resultado VARCHAR(20) NOT NULL
            CONSTRAINT DF_DetalleBoleto_Resultado
            DEFAULT 'PENDIENTE',

        CONSTRAINT PK_DetalleBoleto
            PRIMARY KEY (IdDetalle),

        CONSTRAINT FK_DetalleBoleto_Boleto
            FOREIGN KEY (IdBoleto)
            REFERENCES dbo.Boleto(IdBoleto),

        CONSTRAINT FK_DetalleBoleto_Seleccion
            FOREIGN KEY (IdSeleccion)
            REFERENCES dbo.Seleccion(IdSeleccion),

        CONSTRAINT UQ_DetalleBoleto_Boleto_Seleccion
            UNIQUE (IdBoleto, IdSeleccion),

        CONSTRAINT CK_DetalleBoleto_Cuota
            CHECK (CuotaAplicada > 1),

        CONSTRAINT CK_DetalleBoleto_Resultado
            CHECK
            (
                Resultado IN
                (
                    'PENDIENTE',
                    'GANADA',
                    'PERDIDA',
                    'ANULADA'
                )
            )
    );

    PRINT 'Tabla DetalleBoleto creada.';
END;
GO


/* ============================================================
   25. TIPO TRANSACCION
   Solo saldo virtual.
   ============================================================ */

IF OBJECT_ID('dbo.TipoTransaccion', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TipoTransaccion
    (
        IdTipoTransaccion INT IDENTITY(1,1) NOT NULL,

        Codigo VARCHAR(40) NOT NULL,
        Nombre VARCHAR(100) NOT NULL,
        Descripcion VARCHAR(250) NULL,

        Activo BIT NOT NULL
            CONSTRAINT DF_TipoTransaccion_Activo DEFAULT 1,

        CONSTRAINT PK_TipoTransaccion
            PRIMARY KEY (IdTipoTransaccion),

        CONSTRAINT UQ_TipoTransaccion_Codigo
            UNIQUE (Codigo)
    );

    PRINT 'Tabla TipoTransaccion creada.';
END;
GO


/* ============================================================
   26. TRANSACCION FINANCIERA
   Operaciones de saldo virtual.
   ============================================================ */

IF OBJECT_ID('dbo.TransaccionFinanciera', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TransaccionFinanciera
    (
        IdTransaccion BIGINT IDENTITY(1,1) NOT NULL,

        IdBilletera INT NOT NULL,
        IdTipoTransaccion INT NOT NULL,
        IdEstado INT NOT NULL,

        IdBoleto INT NULL,

        ReferenciaOperacion UNIQUEIDENTIFIER NOT NULL,

        Monto DECIMAL(12,2) NOT NULL,

        FechaSolicitud DATETIME2 NOT NULL
            CONSTRAINT DF_TransaccionFinanciera_FechaSolicitud
            DEFAULT SYSDATETIME(),

        FechaProcesamiento DATETIME2 NULL,

        IdUsuarioProceso INT NULL,

        Descripcion VARCHAR(250) NULL,

        CONSTRAINT PK_TransaccionFinanciera
            PRIMARY KEY (IdTransaccion),

        CONSTRAINT UQ_TransaccionFinanciera_Referencia
            UNIQUE (ReferenciaOperacion),

        CONSTRAINT FK_TransaccionFinanciera_Billetera
            FOREIGN KEY (IdBilletera)
            REFERENCES dbo.Billetera(IdBilletera),

        CONSTRAINT FK_TransaccionFinanciera_Tipo
            FOREIGN KEY (IdTipoTransaccion)
            REFERENCES dbo.TipoTransaccion(IdTipoTransaccion),

        CONSTRAINT FK_TransaccionFinanciera_Estado
            FOREIGN KEY (IdEstado)
            REFERENCES dbo.Estado(IdEstado),

        CONSTRAINT FK_TransaccionFinanciera_Boleto
            FOREIGN KEY (IdBoleto)
            REFERENCES dbo.Boleto(IdBoleto),

        CONSTRAINT FK_TransaccionFinanciera_UsuarioProceso
            FOREIGN KEY (IdUsuarioProceso)
            REFERENCES dbo.Usuario(IdUsuario),

        CONSTRAINT CK_TransaccionFinanciera_Monto
            CHECK (Monto > 0),

        CONSTRAINT CK_TransaccionFinanciera_Fechas
            CHECK
            (
                FechaProcesamiento IS NULL
                OR FechaProcesamiento >= FechaSolicitud
            )
    );

    PRINT 'Tabla TransaccionFinanciera creada.';
END;
GO


/* ============================================================
   27. MOVIMIENTO BILLETERA
   Solo registra operaciones ya aplicadas.
   ============================================================ */

IF OBJECT_ID('dbo.MovimientoBilletera', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.MovimientoBilletera
    (
        IdMovimiento BIGINT IDENTITY(1,1) NOT NULL,

        IdBilletera INT NOT NULL,
        IdTransaccion BIGINT NOT NULL,

        SaldoDisponibleAnterior DECIMAL(12,2) NOT NULL,
        SaldoDisponiblePosterior DECIMAL(12,2) NOT NULL,

        SaldoComprometidoAnterior DECIMAL(12,2) NOT NULL,
        SaldoComprometidoPosterior DECIMAL(12,2) NOT NULL,

        FechaMovimiento DATETIME2 NOT NULL
            CONSTRAINT DF_MovimientoBilletera_FechaMovimiento
            DEFAULT SYSDATETIME(),

        CONSTRAINT PK_MovimientoBilletera
            PRIMARY KEY (IdMovimiento),

        CONSTRAINT UQ_MovimientoBilletera_Transaccion
            UNIQUE (IdTransaccion),

        CONSTRAINT FK_MovimientoBilletera_Billetera
            FOREIGN KEY (IdBilletera)
            REFERENCES dbo.Billetera(IdBilletera),

        CONSTRAINT FK_MovimientoBilletera_Transaccion
            FOREIGN KEY (IdTransaccion)
            REFERENCES dbo.TransaccionFinanciera(IdTransaccion),

        CONSTRAINT CK_MovimientoBilletera_Saldos
            CHECK
            (
                SaldoDisponibleAnterior >= 0
                AND SaldoDisponiblePosterior >= 0
                AND SaldoComprometidoAnterior >= 0
                AND SaldoComprometidoPosterior >= 0
            )
    );

    PRINT 'Tabla MovimientoBilletera creada.';
END;
GO


/* ============================================================
   28. LIQUIDACION BOLETO
   ============================================================ */

IF OBJECT_ID('dbo.LiquidacionBoleto', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.LiquidacionBoleto
    (
        IdLiquidacion BIGINT IDENTITY(1,1) NOT NULL,

        IdBoleto INT NOT NULL,
        IdEstado INT NOT NULL,

        /* Puede ser NULL cuando la liquidacion no genera
           movimiento financiero, por ejemplo una perdida. */
        IdTransaccion BIGINT NULL,

        MontoLiquidado DECIMAL(12,2) NOT NULL,

        FechaCreacion DATETIME2 NOT NULL
            CONSTRAINT DF_LiquidacionBoleto_FechaCreacion
            DEFAULT SYSDATETIME(),

        FechaInicioProceso DATETIME2 NULL,
        FechaFinalizacion DATETIME2 NULL,

        IdUsuarioProceso INT NULL,

        Observacion VARCHAR(500) NULL,

        CONSTRAINT PK_LiquidacionBoleto
            PRIMARY KEY (IdLiquidacion),

        CONSTRAINT UQ_LiquidacionBoleto_Boleto
            UNIQUE (IdBoleto),

        CONSTRAINT FK_LiquidacionBoleto_Boleto
            FOREIGN KEY (IdBoleto)
            REFERENCES dbo.Boleto(IdBoleto),

        CONSTRAINT FK_LiquidacionBoleto_Estado
            FOREIGN KEY (IdEstado)
            REFERENCES dbo.Estado(IdEstado),

        CONSTRAINT FK_LiquidacionBoleto_Transaccion
            FOREIGN KEY (IdTransaccion)
            REFERENCES dbo.TransaccionFinanciera(IdTransaccion),

        CONSTRAINT FK_LiquidacionBoleto_UsuarioProceso
            FOREIGN KEY (IdUsuarioProceso)
            REFERENCES dbo.Usuario(IdUsuario),

        CONSTRAINT CK_LiquidacionBoleto_Monto
            CHECK (MontoLiquidado >= 0),

        CONSTRAINT CK_LiquidacionBoleto_Fechas
            CHECK
            (
                (FechaInicioProceso IS NULL
                    OR FechaInicioProceso >= FechaCreacion)
                AND
                (FechaFinalizacion IS NULL
                    OR FechaFinalizacion >= FechaCreacion)
            )
    );

    PRINT 'Tabla LiquidacionBoleto creada.';
END;
GO


/* ============================================================
   29. AUDITORIA
   ============================================================ */

IF OBJECT_ID('dbo.Auditoria', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Auditoria
    (
        IdAuditoria BIGINT IDENTITY(1,1) NOT NULL,

        IdUsuario INT NULL,

        Accion VARCHAR(100) NOT NULL,

        TablaAfectada VARCHAR(100) NULL,
        IdRegistro BIGINT NULL,

        ReferenciaOperacion UNIQUEIDENTIFIER NULL,

        IpOrigen VARCHAR(45) NULL,

        Descripcion VARCHAR(500) NULL,

        FechaAccion DATETIME2 NOT NULL
            CONSTRAINT DF_Auditoria_FechaAccion
            DEFAULT SYSDATETIME(),

        CONSTRAINT PK_Auditoria
            PRIMARY KEY (IdAuditoria),

        CONSTRAINT FK_Auditoria_Usuario
            FOREIGN KEY (IdUsuario)
            REFERENCES dbo.Usuario(IdUsuario)
    );

    PRINT 'Tabla Auditoria creada.';
END;
GO


/* ============================================================
   30. CONFIGURACION SISTEMA
   ============================================================ */

IF OBJECT_ID('dbo.ConfiguracionSistema', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ConfiguracionSistema
    (
        IdConfiguracion INT IDENTITY(1,1) NOT NULL,

        Clave VARCHAR(100) NOT NULL,
        Valor VARCHAR(150) NOT NULL,
        Descripcion VARCHAR(250) NULL,

        FechaModificacion DATETIME2 NOT NULL
            CONSTRAINT DF_ConfiguracionSistema_FechaModificacion
            DEFAULT SYSDATETIME(),

        CONSTRAINT PK_ConfiguracionSistema
            PRIMARY KEY (IdConfiguracion),

        CONSTRAINT UQ_ConfiguracionSistema_Clave
            UNIQUE (Clave)
    );

    PRINT 'Tabla ConfiguracionSistema creada.';
END;
GO


PRINT '=======================================================';
PRINT ' 30 TABLAS DE PlataformaApuestas VERIFICADAS / CREADAS';
PRINT '=======================================================';
GO