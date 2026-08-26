:On Error exit

PRINT '=======================================================';
PRINT ' PLATAFORMA DE APUESTAS DEPORTIVAS';
PRINT ' INSTALACION DE BASE DE DATOS';
PRINT '=======================================================';
PRINT '';
GO

PRINT 'FASE 1 - Creando base de datos...';
:r D:\programacion\PlataformaApuestasNuevo\BaseDatos\01_DB\01_CrearBaseDatos.sql

PRINT 'FASE 1 - Creando tablas...';
:r D:\programacion\PlataformaApuestasNuevo\BaseDatos\01_DB\02_CrearTablas.sql

PRINT 'FASE 2 - Configuracion del sistema...';
:r D:\programacion\PlataformaApuestasNuevo\BaseDatos\02_CONFIGURACION\01_ConfiguracionSistema.sql

PRINT 'FASE 2 - Roles...';
:r D:\programacion\PlataformaApuestasNuevo\BaseDatos\02_CONFIGURACION\02_Roles.sql

PRINT 'FASE 2 - Datos iniciales...';
:r D:\programacion\PlataformaApuestasNuevo\BaseDatos\02_CONFIGURACION\03_DatosIniciales.sql

PRINT 'FASE 3 - Procedimientos almacenados...';
:r D:\programacion\PlataformaApuestasNuevo\BaseDatos\03_PROCEDIMIENTOS\01_RegistroUsuario.sql

PRINT 'FASE 4 - Indices...';
:r D:\programacion\PlataformaApuestasNuevo\BaseDatos\04_INDICES\01_Indices.sql

PRINT '';
PRINT '=======================================================';
PRINT ' INSTALACION COMPLETADA';
PRINT ' Base de datos: PlataformaApuestas';
PRINT '=======================================================';
GO

