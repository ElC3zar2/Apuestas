:On Error exit

PRINT '=======================================================';
PRINT ' PLATAFORMA DE APUESTAS DEPORTIVAS';
PRINT ' INSTALACION AZURE SQL';
PRINT '=======================================================';
PRINT '';
GO


/* ============================================================
   IMPORTANTE

   Este instalador debe ejecutarse conectado directamente a:

   Servidor:
   apuestasumg.database.windows.net

   Base de datos:
   PlataformaApuestas

   SQLCMD Mode debe estar activado.
   ============================================================ */


/* ============================================================
   FASE 1 - TABLAS
   ============================================================ */

PRINT 'FASE 1 - Creando tablas...';

:r D:\programacion\PlataformaApuestasNuevo\BaseDatos\01_DB\02_CrearTablas.sql


/* ============================================================
   FASE 2 - CONFIGURACION
   ============================================================ */

PRINT 'FASE 2 - Configuracion del sistema...';

:r D:\programacion\PlataformaApuestasNuevo\BaseDatos\02_CONFIGURACION\01_ConfiguracionSistema.sql


PRINT 'FASE 2 - Roles...';

:r D:\programacion\PlataformaApuestasNuevo\BaseDatos\02_CONFIGURACION\02_Roles.sql


PRINT 'FASE 2 - Datos iniciales...';

:r D:\programacion\PlataformaApuestasNuevo\BaseDatos\02_CONFIGURACION\03_DatosIniciales.sql


/* ============================================================
   FASE 3 - PROCEDIMIENTOS
   ============================================================ */

PRINT 'FASE 3 - Procedimientos almacenados...';

:r D:\programacion\PlataformaApuestasNuevo\BaseDatos\03_PROCEDIMIENTOS\01_RegistroUsuario.sql


/* ============================================================
   FASE 4 - INDICES
   ============================================================ */

PRINT 'FASE 4 - Creando indices...';

:r D:\programacion\PlataformaApuestasNuevo\BaseDatos\04_INDICES\01_Indices.sql


PRINT '';
PRINT '=======================================================';
PRINT ' INSTALACION AZURE SQL COMPLETADA';
PRINT ' Base de datos: PlataformaApuestas';
PRINT '=======================================================';
GO