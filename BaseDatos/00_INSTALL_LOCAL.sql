/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   INSTALADOR DEFINITIVO LOCAL

   ARCHIVO:
   BaseDatos/00_INSTALL_LOCAL.sql

   EJECUCION:
   Abrir CMD dentro de la carpeta BaseDatos y ejecutar:

   sqlcmd -S localhost -E -b -i "00_INSTALL_LOCAL.sql"

   IMPORTANTE:
   - Las rutas son relativas.
   - NO modificar rutas según cada computadora.
   - NO incluye scripts de prueba.
   - Las pruebas se ejecutan manualmente después.
   ============================================================ */

:On Error exit


PRINT '=======================================================';
PRINT ' PLATAFORMA APUESTAS - INSTALACION LOCAL';
PRINT '=======================================================';
PRINT '';
GO


/* ============================================================
   PASO 1
   CREAR BASE DE DATOS
   ============================================================ */

PRINT '-------------------------------------------------------';
PRINT ' PASO 1 - CREANDO BASE DE DATOS';
PRINT '-------------------------------------------------------';
GO

USE master;
GO

:r .\01_DB\01_CrearBaseDatos.sql

GO


/* ============================================================
   CAMBIAR A PlataformaApuestas
   ============================================================ */

USE PlataformaApuestas;
GO

PRINT '';
PRINT 'Base de datos actual:';
SELECT DB_NAME() AS BaseDatosActual;
GO


/* ============================================================
   PASO 2
   CREAR TABLAS
   ============================================================ */

PRINT '';
PRINT '-------------------------------------------------------';
PRINT ' PASO 2 - CREANDO TABLAS';
PRINT '-------------------------------------------------------';
GO

:r .\01_DB\02_CrearTablas.sql

GO


/* ============================================================
   PASO 3
   CONFIGURACION DEL SISTEMA
   ============================================================ */

PRINT '';
PRINT '-------------------------------------------------------';
PRINT ' PASO 3 - CONFIGURANDO SISTEMA';
PRINT '-------------------------------------------------------';
GO


PRINT '3.1 ConfiguracionSistema...';
GO

:r .\02_CONFIGURACION\01_ConfiguracionSistema.sql

GO


PRINT '3.2 Roles...';
GO

:r .\02_CONFIGURACION\02_Roles.sql

GO


PRINT '3.3 Estados...';
GO

:r .\02_CONFIGURACION\03_Estados.sql

GO


PRINT '3.4 Paises...';
GO

:r .\02_CONFIGURACION\04_Paises.sql

GO


PRINT '3.5 Departamentos de Guatemala...';
GO

:r .\02_CONFIGURACION\05_DepartamentosGuatemala.sql

GO


PRINT '3.6 Municipios de Guatemala...';
GO

:r .\02_CONFIGURACION\06_MunicipiosGuatemala.sql

GO


PRINT '3.7 Tipos de transaccion...';
GO

:r .\02_CONFIGURACION\07_TiposTransaccion.sql

GO


PRINT '3.8 Datos iniciales...';
GO

:r .\02_CONFIGURACION\08_DatosIniciales.sql

GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO
/* ============================================================
   PASO 4
   PROCEDIMIENTOS ALMACENADOS
   ============================================================ */

PRINT '';
PRINT '-------------------------------------------------------';
PRINT ' PASO 4 - CREANDO PROCEDIMIENTOS ALMACENADOS';
PRINT '-------------------------------------------------------';
GO


PRINT '4.1 Registro de usuarios...';
GO

:r .\03_PROCEDIMIENTOS\01_RegistroUsuario.sql

GO


PRINT '4.2 Seguridad de usuarios...';
GO

:r .\03_PROCEDIMIENTOS\02_SeguridadUsuario.sql

GO


PRINT '4.3 Billetera...';
GO

:r .\03_PROCEDIMIENTOS\03_Billetera.sql

GO


PRINT '4.4 Eventos y mercados...';
GO

:r .\03_PROCEDIMIENTOS\04_EventosMercados.sql

GO


PRINT '4.5 Apuestas...';
GO

:r .\03_PROCEDIMIENTOS\05_Apuestas.sql

GO


PRINT '4.6 Resultados...';
GO

:r .\03_PROCEDIMIENTOS\06_Resultados.sql

GO


PRINT '4.7 Liquidacion...';
GO

:r .\03_PROCEDIMIENTOS\07_Liquidacion.sql

GO


PRINT '4.8 Administracion de usuarios...';
GO

:r .\03_PROCEDIMIENTOS\08_AdministracionUsuario.sql

GO


/* ============================================================
   PASO 5
   INDICES
   ============================================================ */

PRINT '';
PRINT '-------------------------------------------------------';
PRINT ' PASO 5 - CREANDO INDICES';
PRINT '-------------------------------------------------------';
GO

:r .\04_INDICES\01_Indices.sql

GO


/* ============================================================
   PASO 6
   VISTAS
   ============================================================ */

PRINT '';
PRINT '-------------------------------------------------------';
PRINT ' PASO 6 - CREANDO VISTAS';
PRINT '-------------------------------------------------------';
GO

:r .\05_VISTAS\01_Vistas.sql

GO


/* ============================================================
   PASO 7
   AUDITORIA Y TRIGGERS
   ============================================================ */

PRINT '';
PRINT '-------------------------------------------------------';
PRINT ' PASO 7 - CONFIGURANDO AUDITORIA';
PRINT '-------------------------------------------------------';
GO

:r .\06_AUDITORIA\01_AuditoriaTriggers.sql

GO


/* ============================================================
   PASO 8
   VALIDACION ESTRUCTURAL
   ============================================================ */

PRINT '';
PRINT '-------------------------------------------------------';
PRINT ' PASO 8 - VALIDANDO INSTALACION';
PRINT '-------------------------------------------------------';
GO


DECLARE @CantidadTablas INT;
DECLARE @CantidadProcedimientos INT;
DECLARE @CantidadVistas INT;
DECLARE @CantidadTriggers INT;


SELECT
    @CantidadTablas = COUNT(*)
FROM sys.tables
WHERE schema_id = SCHEMA_ID('dbo');


SELECT
    @CantidadProcedimientos = COUNT(*)
FROM sys.procedures
WHERE schema_id = SCHEMA_ID('dbo');


SELECT
    @CantidadVistas = COUNT(*)
FROM sys.views
WHERE schema_id = SCHEMA_ID('dbo');


SELECT
    @CantidadTriggers = COUNT(*)
FROM sys.triggers
WHERE parent_id <> 0;


PRINT '';
PRINT 'Componentes encontrados:';

PRINT 'Tablas: '
    + CONVERT(VARCHAR(10), @CantidadTablas);

PRINT 'Procedimientos: '
    + CONVERT(VARCHAR(10), @CantidadProcedimientos);

PRINT 'Vistas: '
    + CONVERT(VARCHAR(10), @CantidadVistas);

PRINT 'Triggers: '
    + CONVERT(VARCHAR(10), @CantidadTriggers);

PRINT '';


/* ============================================================
   VALIDACIONES
   ============================================================ */

IF @CantidadTablas <> 30
BEGIN
    THROW 65001,
          'ERROR DE INSTALACION: deben existir exactamente 30 tablas.',
          1;
END;


IF @CantidadProcedimientos <> 47
BEGIN
    THROW 65002,
          'ERROR DE INSTALACION: deben existir exactamente 47 procedimientos.',
          1;
END;


IF @CantidadVistas <> 11
BEGIN
    THROW 65003,
          'ERROR DE INSTALACION: deben existir exactamente 11 vistas.',
          1;
END;


IF @CantidadTriggers <> 5
BEGIN
    THROW 65004,
          'ERROR DE INSTALACION: deben existir exactamente 5 triggers.',
          1;
END;


/* ============================================================
   VALIDAR DATOS FUNDAMENTALES
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Pais
    WHERE CodigoISO2 = 'GT'
)
BEGIN
    THROW 65005,
          'ERROR DE INSTALACION: Guatemala no fue cargada.',
          1;
END;


IF
(
    SELECT COUNT(*)
    FROM dbo.Departamento AS D
    INNER JOIN dbo.Pais AS P
        ON P.IdPais = D.IdPais
    WHERE P.CodigoISO2 = 'GT'
) <> 22
BEGIN
    THROW 65006,
          'ERROR DE INSTALACION: deben existir 22 departamentos de Guatemala.',
          1;
END;


IF
(
    SELECT COUNT(*)
    FROM dbo.Municipio AS M
    INNER JOIN dbo.Departamento AS D
        ON D.IdDepartamento = M.IdDepartamento
    INNER JOIN dbo.Pais AS P
        ON P.IdPais = D.IdPais
    WHERE P.CodigoISO2 = 'GT'
) <> 340
BEGIN
    THROW 65007,
          'ERROR DE INSTALACION: deben existir 340 municipios de Guatemala.',
          1;
END;


IF
(
    SELECT COUNT(*)
    FROM dbo.Rol
    WHERE Nombre IN
    (
        'ADMINISTRADOR',
        'OPERADOR_EVENTOS',
        'CAJERO',
        'AUDITOR',
        'USUARIO',
        'CASA'
    )
) <> 6
BEGIN
    THROW 65008,
          'ERROR DE INSTALACION: faltan roles del sistema.',
          1;
END;


IF
(
    SELECT COUNT(*)
    FROM dbo.Deporte
    WHERE Nombre IN
    (
        'Futbol',
        'Baloncesto',
        'Beisbol',
        'Tenis'
    )
) <> 4
BEGIN
    THROW 65009,
          'ERROR DE INSTALACION: faltan deportes iniciales.',
          1;
END;


/* ============================================================
   VALIDAR CASA
   ============================================================ */

IF
(
    SELECT COUNT(*)

    FROM dbo.Usuario AS U

    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol

    WHERE R.Nombre = 'CASA'
) <> 1
BEGIN
    THROW 65010,
          'ERROR DE INSTALACION: debe existir exactamente una cuenta CASA.',
          1;
END;


IF
(
    SELECT COUNT(*)

    FROM dbo.Billetera AS B

    INNER JOIN dbo.Usuario AS U
        ON U.IdUsuario = B.IdUsuario

    INNER JOIN dbo.Rol AS R
        ON R.IdRol = U.IdRol

    WHERE R.Nombre = 'CASA'
) <> 1
BEGIN
    THROW 65011,
          'ERROR DE INSTALACION: CASA debe poseer exactamente una billetera.',
          1;
END;


/* ============================================================
   VALIDAR INDICES CRITICOS
   ============================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'UX_PerfilUsuario_Documento'
)
BEGIN
    THROW 65012,
          'ERROR DE INSTALACION: falta UX_PerfilUsuario_Documento.',
          1;
END;


IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'UX_Cuota_Seleccion_Activa'
)
BEGIN
    THROW 65013,
          'ERROR DE INSTALACION: falta UX_Cuota_Seleccion_Activa.',
          1;
END;


/* ============================================================
   RESULTADO FINAL
   ============================================================ */

PRINT '';
PRINT '=======================================================';
PRINT ' INSTALACION LOCAL COMPLETADA CORRECTAMENTE';
PRINT '=======================================================';
PRINT '';
PRINT '30 tablas                OK';
PRINT '47 procedimientos        OK';
PRINT '11 vistas                OK';
PRINT '5 triggers               OK';
PRINT '22 departamentos         OK';
PRINT '340 municipios           OK';
PRINT '4 deportes               OK';
PRINT 'CASA                      OK';
PRINT 'Indices criticos          OK';
PRINT '';
PRINT 'SIGUIENTE PASO:';
PRINT 'Ejecutar 07_PRUEBAS\01_VerificarInstalacion.sql';
PRINT '';
PRINT '=======================================================';
GO