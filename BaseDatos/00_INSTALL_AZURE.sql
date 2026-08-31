/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   INSTALADOR COMPLETO - AZURE SQL

   IMPORTANTE:
   - La base PlataformaApuestas debe existir previamente.
   - sqlcmd debe conectarse directamente a PlataformaApuestas.
   - Ejecutar desde la carpeta BaseDatos.
   ============================================================ */

:On Error exit

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


PRINT '=======================================================';
PRINT ' INSTALACION AZURE - PLATAFORMA APUESTAS';
PRINT '=======================================================';
GO


/* ============================================================
   1. TABLAS
   ============================================================ */

PRINT '';
PRINT '1. CREANDO TABLAS...';
:r .\01_DB\02_CrearTablas.sql
GO


/* ============================================================
   2. CONFIGURACION Y CATALOGOS
   ============================================================ */

PRINT '';
PRINT '2. CONFIGURACION DEL SISTEMA...';
:r .\02_CONFIGURACION\01_ConfiguracionSistema.sql
GO

PRINT '';
PRINT '3. ROLES...';
:r .\02_CONFIGURACION\02_Roles.sql
GO

PRINT '';
PRINT '4. ESTADOS...';
:r .\02_CONFIGURACION\03_Estados.sql
GO

PRINT '';
PRINT '5. PAISES...';
:r .\02_CONFIGURACION\04_Paises.sql
GO

PRINT '';
PRINT '6. DEPARTAMENTOS DE GUATEMALA...';
:r .\02_CONFIGURACION\05_DepartamentosGuatemala.sql
GO

PRINT '';
PRINT '7. MUNICIPIOS DE GUATEMALA...';
:r .\02_CONFIGURACION\06_MunicipiosGuatemala.sql
GO

PRINT '';
PRINT '8. TIPOS DE TRANSACCION...';
:r .\02_CONFIGURACION\07_TiposTransaccion.sql
GO

PRINT '';
PRINT '9. DATOS INICIALES...';
:r .\02_CONFIGURACION\08_DatosIniciales.sql
GO


/* ============================================================
   CONFIGURACION OBLIGATORIA PARA PROCEDIMIENTOS E INDICES
   ============================================================ */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO


/* ============================================================
   3. PROCEDIMIENTOS
   ============================================================ */

PRINT '';
PRINT '10. PROCEDIMIENTO DE REGISTRO...';
:r .\03_PROCEDIMIENTOS\01_RegistroUsuario.sql
GO

PRINT '';
PRINT '11. SEGURIDAD DE USUARIO...';
:r .\03_PROCEDIMIENTOS\02_SeguridadUsuario.sql
GO

PRINT '';
PRINT '12. BILLETERA...';
:r .\03_PROCEDIMIENTOS\03_Billetera.sql
GO

PRINT '';
PRINT '13. EVENTOS Y MERCADOS...';
:r .\03_PROCEDIMIENTOS\04_EventosMercados.sql
GO

PRINT '';
PRINT '14. APUESTAS...';
:r .\03_PROCEDIMIENTOS\05_Apuestas.sql
GO

PRINT '';
PRINT '15. RESULTADOS...';
:r .\03_PROCEDIMIENTOS\06_Resultados.sql
GO

PRINT '';
PRINT '16. LIQUIDACION...';
:r .\03_PROCEDIMIENTOS\07_Liquidacion.sql
GO

PRINT '';
PRINT '17. ADMINISTRACION DE USUARIO...';
:r .\03_PROCEDIMIENTOS\08_AdministracionUsuario.sql
GO


/* ============================================================
   4. INDICES
   ============================================================ */

PRINT '';
PRINT '18. INDICES...';
:r .\04_INDICES\01_Indices.sql
GO


/* ============================================================
   5. VISTAS
   ============================================================ */

PRINT '';
PRINT '19. VISTAS...';
:r .\05_VISTAS\01_Vistas.sql
GO


/* ============================================================
   6. AUDITORIA
   ============================================================ */

PRINT '';
PRINT '20. AUDITORIA Y TRIGGERS...';
:r .\06_AUDITORIA\01_AuditoriaTriggers.sql
GO


PRINT '';
PRINT '=======================================================';
PRINT ' INSTALACION AZURE COMPLETADA CORRECTAMENTE';
PRINT '=======================================================';
GO