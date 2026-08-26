/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS
   SQL SERVER 2022

   ARCHIVO:
   01_DB/02_CrearTablas.sql

   OBJETIVO:
   Crear todas las tablas del sistema.

   CONVENCION:
   Los nombres de las entidades/tablas se manejan en singular.
   ============================================================ */

USE PlataformaApuestas;
GO


/* ============================================================
   1. ROL
   ============================================================ */

IF OBJECT_ID('Rol', 'U') IS NULL
BEGIN

    CREATE TABLE Rol
    (
        IdRol INT IDENTITY(1,1) NOT NULL,

        Nombre VARCHAR(50) NOT NULL,

        Descripcion VARCHAR(200) NULL,

        CONSTRAINT PK_Rol
            PRIMARY KEY (IdRol),

        CONSTRAINT UQ_Rol_Nombre
            UNIQUE (Nombre)
    );

    PRINT 'Tabla Rol creada.';
END;
GO


/* ============================================================
   2. USUARIO
   ============================================================ */

IF OBJECT_ID('Usuario', 'U') IS NULL
BEGIN

    CREATE TABLE Usuario
    (
        IdUsuario INT IDENTITY(1,1) NOT NULL,

        IdRol INT NOT NULL,

        Nombre VARCHAR(100) NOT NULL,

        Apellido VARCHAR(100) NOT NULL,

        Correo VARCHAR(150) NOT NULL,

        Contrasena VARCHAR(255) NOT NULL,

        FechaNacimiento DATE NULL,

        Estado BIT NOT NULL
            CONSTRAINT DF_Usuario_Estado
            DEFAULT 1,

        FechaRegistro DATETIME2 NOT NULL
            CONSTRAINT DF_Usuario_FechaRegistro
            DEFAULT SYSDATETIME(),

        CONSTRAINT PK_Usuario
            PRIMARY KEY (IdUsuario),

        CONSTRAINT UQ_Usuario_Correo
            UNIQUE (Correo),

        CONSTRAINT FK_Usuario_Rol
            FOREIGN KEY (IdRol)
            REFERENCES Rol(IdRol)
    );

    PRINT 'Tabla Usuario creada.';
END;
GO


/* ============================================================
   3. DEPORTE
   ============================================================ */

IF OBJECT_ID('Deporte', 'U') IS NULL
BEGIN

    CREATE TABLE Deporte
    (
        IdDeporte INT IDENTITY(1,1) NOT NULL,

        Nombre VARCHAR(100) NOT NULL,

        Descripcion VARCHAR(250) NULL,

        Estado BIT NOT NULL
            CONSTRAINT DF_Deporte_Estado
            DEFAULT 1,

        CONSTRAINT PK_Deporte
            PRIMARY KEY (IdDeporte),

        CONSTRAINT UQ_Deporte_Nombre
            UNIQUE (Nombre)
    );

    PRINT 'Tabla Deporte creada.';
END;
GO


/* ============================================================
   4. LIGA
   ============================================================ */

IF OBJECT_ID('Liga', 'U') IS NULL
BEGIN

    CREATE TABLE Liga
    (
        IdLiga INT IDENTITY(1,1) NOT NULL,

        IdDeporte INT NOT NULL,

        Nombre VARCHAR(150) NOT NULL,

        Pais VARCHAR(100) NULL,

        Estado BIT NOT NULL
            CONSTRAINT DF_Liga_Estado
            DEFAULT 1,

        CONSTRAINT PK_Liga
            PRIMARY KEY (IdLiga),

        CONSTRAINT FK_Liga_Deporte
            FOREIGN KEY (IdDeporte)
            REFERENCES Deporte(IdDeporte),

        CONSTRAINT UQ_Liga_Deporte_Nombre
            UNIQUE (IdDeporte, Nombre)
    );

    PRINT 'Tabla Liga creada.';
END;
GO


/* ============================================================
   5. PARTICIPANTE
   Puede representar un EQUIPO o un ATLETA.
   ============================================================ */

IF OBJECT_ID('Participante', 'U') IS NULL
BEGIN

    CREATE TABLE Participante
    (
        IdParticipante INT IDENTITY(1,1) NOT NULL,

        IdDeporte INT NOT NULL,

        Nombre VARCHAR(150) NOT NULL,

        TipoParticipante VARCHAR(30) NOT NULL,

        Estado BIT NOT NULL
            CONSTRAINT DF_Participante_Estado
            DEFAULT 1,

        CONSTRAINT PK_Participante
            PRIMARY KEY (IdParticipante),

        CONSTRAINT FK_Participante_Deporte
            FOREIGN KEY (IdDeporte)
            REFERENCES Deporte(IdDeporte),

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
   6. EVENTO
   ============================================================ */

IF OBJECT_ID('Evento', 'U') IS NULL
BEGIN

    CREATE TABLE Evento
    (
        IdEvento INT IDENTITY(1,1) NOT NULL,

        IdLiga INT NOT NULL,

        Nombre VARCHAR(200) NOT NULL,

        FechaInicio DATETIME2 NOT NULL,

        FechaFin DATETIME2 NULL,

        Estado VARCHAR(30) NOT NULL
            CONSTRAINT DF_Evento_Estado
            DEFAULT 'PROGRAMADO',

        CONSTRAINT PK_Evento
            PRIMARY KEY (IdEvento),

        CONSTRAINT FK_Evento_Liga
            FOREIGN KEY (IdLiga)
            REFERENCES Liga(IdLiga),

        CONSTRAINT CK_Evento_Estado
            CHECK
            (
                Estado IN
                (
                    'PROGRAMADO',
                    'EN_VIVO',
                    'FINALIZADO',
                    'CANCELADO'
                )
            )
    );

    PRINT 'Tabla Evento creada.';
END;
GO


/* ============================================================
   7. EVENTO PARTICIPANTE
   ============================================================ */

IF OBJECT_ID('EventoParticipante', 'U') IS NULL
BEGIN

    CREATE TABLE EventoParticipante
    (
        IdEventoParticipante INT IDENTITY(1,1) NOT NULL,

        IdEvento INT NOT NULL,

        IdParticipante INT NOT NULL,

        EsLocal BIT NOT NULL
            CONSTRAINT DF_EventoParticipante_EsLocal
            DEFAULT 0,

        CONSTRAINT PK_EventoParticipante
            PRIMARY KEY (IdEventoParticipante),

        CONSTRAINT FK_EventoParticipante_Evento
            FOREIGN KEY (IdEvento)
            REFERENCES Evento(IdEvento),

        CONSTRAINT FK_EventoParticipante_Participante
            FOREIGN KEY (IdParticipante)
            REFERENCES Participante(IdParticipante),

        CONSTRAINT UQ_EventoParticipante
            UNIQUE
            (
                IdEvento,
                IdParticipante
            )
    );

    PRINT 'Tabla EventoParticipante creada.';
END;
GO


/* ============================================================
   8. MERCADO
   Ejemplo:
   - Ganador del partido
   - Total de goles
   - Total de puntos
   ============================================================ */

IF OBJECT_ID('Mercado', 'U') IS NULL
BEGIN

    CREATE TABLE Mercado
    (
        IdMercado INT IDENTITY(1,1) NOT NULL,

        IdEvento INT NOT NULL,

        Nombre VARCHAR(150) NOT NULL,

        Descripcion VARCHAR(250) NULL,

        Estado BIT NOT NULL
            CONSTRAINT DF_Mercado_Estado
            DEFAULT 1,

        CONSTRAINT PK_Mercado
            PRIMARY KEY (IdMercado),

        CONSTRAINT FK_Mercado_Evento
            FOREIGN KEY (IdEvento)
            REFERENCES Evento(IdEvento)
    );

    PRINT 'Tabla Mercado creada.';
END;
GO


/* ============================================================
   9. SELECCION
   ============================================================ */

IF OBJECT_ID('Seleccion', 'U') IS NULL
BEGIN

    CREATE TABLE Seleccion
    (
        IdSeleccion INT IDENTITY(1,1) NOT NULL,

        IdMercado INT NOT NULL,

        Nombre VARCHAR(150) NOT NULL,

        Estado BIT NOT NULL
            CONSTRAINT DF_Seleccion_Estado
            DEFAULT 1,

        CONSTRAINT PK_Seleccion
            PRIMARY KEY (IdSeleccion),

        CONSTRAINT FK_Seleccion_Mercado
            FOREIGN KEY (IdMercado)
            REFERENCES Mercado(IdMercado)
    );

    PRINT 'Tabla Seleccion creada.';
END;
GO


/* ============================================================
   10. CUOTA
   Se conserva histórico mediante FechaInicio y FechaFin.
   ============================================================ */

IF OBJECT_ID('Cuota', 'U') IS NULL
BEGIN

    CREATE TABLE Cuota
    (
        IdCuota INT IDENTITY(1,1) NOT NULL,

        IdSeleccion INT NOT NULL,

        Valor DECIMAL(10,2) NOT NULL,

        FechaInicio DATETIME2 NOT NULL
            CONSTRAINT DF_Cuota_FechaInicio
            DEFAULT SYSDATETIME(),

        FechaFin DATETIME2 NULL,

        Estado BIT NOT NULL
            CONSTRAINT DF_Cuota_Estado
            DEFAULT 1,

        CONSTRAINT PK_Cuota
            PRIMARY KEY (IdCuota),

        CONSTRAINT FK_Cuota_Seleccion
            FOREIGN KEY (IdSeleccion)
            REFERENCES Seleccion(IdSeleccion),

        CONSTRAINT CK_Cuota_Valor
            CHECK (Valor > 1)
    );

    PRINT 'Tabla Cuota creada.';
END;
GO


/* ============================================================
   11. RESULTADO EVENTO
   ============================================================ */

IF OBJECT_ID('ResultadoEvento', 'U') IS NULL
BEGIN

    CREATE TABLE ResultadoEvento
    (
        IdResultado INT IDENTITY(1,1) NOT NULL,

        IdEvento INT NOT NULL,

        ResultadoTexto VARCHAR(250) NULL,

        FechaRegistro DATETIME2 NOT NULL
            CONSTRAINT DF_ResultadoEvento_FechaRegistro
            DEFAULT SYSDATETIME(),

        CONSTRAINT PK_ResultadoEvento
            PRIMARY KEY (IdResultado),

        CONSTRAINT UQ_ResultadoEvento_Evento
            UNIQUE (IdEvento),

        CONSTRAINT FK_ResultadoEvento_Evento
            FOREIGN KEY (IdEvento)
            REFERENCES Evento(IdEvento)
    );

    PRINT 'Tabla ResultadoEvento creada.';
END;
GO


/* ============================================================
   12. BILLETERA
   ============================================================ */

IF OBJECT_ID('Billetera', 'U') IS NULL
BEGIN

    CREATE TABLE Billetera
    (
        IdBilletera INT IDENTITY(1,1) NOT NULL,

        IdUsuario INT NOT NULL,

        SaldoDisponible DECIMAL(12,2) NOT NULL
            CONSTRAINT DF_Billetera_SaldoDisponible
            DEFAULT 0,

        SaldoComprometido DECIMAL(12,2) NOT NULL
            CONSTRAINT DF_Billetera_SaldoComprometido
            DEFAULT 0,

        FechaCreacion DATETIME2 NOT NULL
            CONSTRAINT DF_Billetera_FechaCreacion
            DEFAULT SYSDATETIME(),

        CONSTRAINT PK_Billetera
            PRIMARY KEY (IdBilletera),

        CONSTRAINT UQ_Billetera_Usuario
            UNIQUE (IdUsuario),

        CONSTRAINT FK_Billetera_Usuario
            FOREIGN KEY (IdUsuario)
            REFERENCES Usuario(IdUsuario),

        CONSTRAINT CK_Billetera_SaldoDisponible
            CHECK (SaldoDisponible >= 0),

        CONSTRAINT CK_Billetera_SaldoComprometido
            CHECK (SaldoComprometido >= 0)
    );

    PRINT 'Tabla Billetera creada.';
END;
GO


/* ============================================================
   13. MOVIMIENTO BILLETERA
   ============================================================ */

IF OBJECT_ID('MovimientoBilletera', 'U') IS NULL
BEGIN

    CREATE TABLE MovimientoBilletera
    (
        IdMovimiento INT IDENTITY(1,1) NOT NULL,

        IdBilletera INT NOT NULL,

        TipoMovimiento VARCHAR(30) NOT NULL,

        Monto DECIMAL(12,2) NOT NULL,

        Descripcion VARCHAR(250) NULL,

        FechaMovimiento DATETIME2 NOT NULL
            CONSTRAINT DF_MovimientoBilletera_Fecha
            DEFAULT SYSDATETIME(),

        CONSTRAINT PK_MovimientoBilletera
            PRIMARY KEY (IdMovimiento),

        CONSTRAINT FK_MovimientoBilletera_Billetera
            FOREIGN KEY (IdBilletera)
            REFERENCES Billetera(IdBilletera),

        CONSTRAINT CK_MovimientoBilletera_Tipo
            CHECK
            (
                TipoMovimiento IN
                (
                    'DEPOSITO',
                    'RETIRO',
                    'APUESTA',
                    'PREMIO',
                    'DEVOLUCION'
                )
            ),

        CONSTRAINT CK_MovimientoBilletera_Monto
            CHECK (Monto > 0)
    );

    PRINT 'Tabla MovimientoBilletera creada.';
END;
GO


/* ============================================================
   14. BOLETO
   ============================================================ */

IF OBJECT_ID('Boleto', 'U') IS NULL
BEGIN

    CREATE TABLE Boleto
    (
        IdBoleto INT IDENTITY(1,1) NOT NULL,

        IdUsuario INT NOT NULL,

        MontoApostado DECIMAL(12,2) NOT NULL,

        CuotaTotal DECIMAL(12,4) NOT NULL,

        GananciaPotencial DECIMAL(12,2) NOT NULL,

        TipoBoleto VARCHAR(20) NOT NULL,

        Estado VARCHAR(30) NOT NULL
            CONSTRAINT DF_Boleto_Estado
            DEFAULT 'PENDIENTE',

        FechaCreacion DATETIME2 NOT NULL
            CONSTRAINT DF_Boleto_FechaCreacion
            DEFAULT SYSDATETIME(),

        FechaLiquidacion DATETIME2 NULL,

        CONSTRAINT PK_Boleto
            PRIMARY KEY (IdBoleto),

        CONSTRAINT FK_Boleto_Usuario
            FOREIGN KEY (IdUsuario)
            REFERENCES Usuario(IdUsuario),

        CONSTRAINT CK_Boleto_Monto
            CHECK (MontoApostado > 0),

        CONSTRAINT CK_Boleto_Cuota
            CHECK (CuotaTotal > 1),

        CONSTRAINT CK_Boleto_Ganancia
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

        CONSTRAINT CK_Boleto_Estado
            CHECK
            (
                Estado IN
                (
                    'PENDIENTE',
                    'GANADOR',
                    'PERDEDOR',
                    'ANULADO'
                )
            )
    );

    PRINT 'Tabla Boleto creada.';
END;
GO


/* ============================================================
   15. DETALLE BOLETO
   Guarda la cuota aplicada al momento de la apuesta.
   ============================================================ */

IF OBJECT_ID('DetalleBoleto', 'U') IS NULL
BEGIN

    CREATE TABLE DetalleBoleto
    (
        IdDetalle INT IDENTITY(1,1) NOT NULL,

        IdBoleto INT NOT NULL,

        IdSeleccion INT NOT NULL,

        CuotaAplicada DECIMAL(10,2) NOT NULL,

        Resultado VARCHAR(20) NOT NULL
            CONSTRAINT DF_DetalleBoleto_Resultado
            DEFAULT 'PENDIENTE',

        CONSTRAINT PK_DetalleBoleto
            PRIMARY KEY (IdDetalle),

        CONSTRAINT FK_DetalleBoleto_Boleto
            FOREIGN KEY (IdBoleto)
            REFERENCES Boleto(IdBoleto),

        CONSTRAINT FK_DetalleBoleto_Seleccion
            FOREIGN KEY (IdSeleccion)
            REFERENCES Seleccion(IdSeleccion),

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
   16. AUDITORIA
   ============================================================ */

IF OBJECT_ID('Auditoria', 'U') IS NULL
BEGIN

    CREATE TABLE Auditoria
    (
        IdAuditoria INT IDENTITY(1,1) NOT NULL,

        IdUsuario INT NULL,

        Accion VARCHAR(100) NOT NULL,

        TablaAfectada VARCHAR(100) NULL,

        IdRegistro INT NULL,

        Descripcion VARCHAR(500) NULL,

        FechaAccion DATETIME2 NOT NULL
            CONSTRAINT DF_Auditoria_Fecha
            DEFAULT SYSDATETIME(),

        CONSTRAINT PK_Auditoria
            PRIMARY KEY (IdAuditoria),

        CONSTRAINT FK_Auditoria_Usuario
            FOREIGN KEY (IdUsuario)
            REFERENCES Usuario(IdUsuario)
    );

    PRINT 'Tabla Auditoria creada.';
END;
GO


/* ============================================================
   17. CONFIGURACION SISTEMA

   Esta tabla no requiere FK.

   Guarda configuraciones globales del sistema como:
   SALDO_INICIAL_USUARIO
   ============================================================ */

IF OBJECT_ID('ConfiguracionSistema', 'U') IS NULL
BEGIN

    CREATE TABLE ConfiguracionSistema
    (
        IdConfiguracion INT IDENTITY(1,1) NOT NULL,

        Clave VARCHAR(100) NOT NULL,

        Valor VARCHAR(100) NOT NULL,

        Descripcion VARCHAR(250) NULL,

        FechaModificacion DATETIME2 NOT NULL
            CONSTRAINT DF_ConfiguracionSistema_Fecha
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
PRINT ' TABLAS DE PlataformaApuestas VERIFICADAS / CREADAS';
PRINT '=======================================================';
GO