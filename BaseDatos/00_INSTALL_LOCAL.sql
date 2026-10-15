/* PlataformaApuestas: INSTALACION LIMPIA LOCAL.
   No migra bases anteriores. No borra datos ni crea escenarios demo.
   Ejecutar SQLCMD con directorio de trabajo BaseDatos:
   sqlcmd -S ".\SQLEXPRESS" -E -b -f 65001 -i ".\00_INSTALL_LOCAL.sql"
   Las inclusiones :r usan rutas relativas directas con ambas comillas.
   No usan sustitucion de variables; no cambiar el directorio durante la ejecucion.
   En SSMS las rutas relativas dependen del proceso: preferir SQLCMD desde BaseDatos.
   AZURE: conectar previamente a la base vacia; LOCAL: requiere permiso CREATE DATABASE. */
:On Error exit
USE master;
GO
:r ".\01_DB\01_CrearBaseDatos.sql"
USE PlataformaApuestas;
GO

IF OBJECT_ID('dbo.Usuario','U') IS NOT NULL
    THROW 77000,'Se requiere una base limpia. El instalador no migra una base existente.',1;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
SET XACT_ABORT ON;
GO
:r ".\01_DB\02_CrearTablas.sql"
GO
:r ".\02_CONFIGURACION\01_ConfiguracionSistema.sql"
GO
:r ".\02_CONFIGURACION\02_Roles.sql"
GO
:r ".\02_CONFIGURACION\03_Estados.sql"
GO
:r ".\02_CONFIGURACION\04_Paises.sql"
GO
:r ".\02_CONFIGURACION\05_DepartamentosGuatemala.sql"
GO
:r ".\02_CONFIGURACION\06_MunicipiosGuatemala.sql"
GO
:r ".\02_CONFIGURACION\07_TiposTransaccion.sql"
GO
:r ".\02_CONFIGURACION\08_DatosIniciales.sql"
GO
:r ".\03_PROCEDIMIENTOS\01_RegistroUsuario.sql"
GO
:r ".\03_PROCEDIMIENTOS\02_SeguridadUsuario.sql"
GO
:r ".\03_PROCEDIMIENTOS\03_Billetera.sql"
GO
:r ".\03_PROCEDIMIENTOS\04_EventosMercados.sql"
GO
:r ".\03_PROCEDIMIENTOS\05_Apuestas.sql"
GO
:r ".\03_PROCEDIMIENTOS\06_Resultados.sql"
GO
:r ".\03_PROCEDIMIENTOS\07_Liquidacion.sql"
GO
:r ".\03_PROCEDIMIENTOS\08_AdministracionUsuario.sql"
GO
:r ".\03_PROCEDIMIENTOS\09_AnaliticaUsuario.sql"
GO
:r ".\03_PROCEDIMIENTOS\10_ExploracionEventos.sql"
GO
:r ".\03_PROCEDIMIENTOS\11_AnaliticaAdministrativa.sql"
GO
:r ".\03_PROCEDIMIENTOS\12_SimulacionModalidades.sql"
GO
:r ".\02_CONFIGURACION\09_DATOS_INICIALES_OFICIALES.sql"
GO
:r ".\04_INDICES\01_Indices.sql"
GO
:r ".\05_VISTAS\01_Vistas.sql"
GO
:r ".\06_AUDITORIA\01_AuditoriaTriggers.sql"
GO
:r ".\01_DB\03_VerificarModelo.sql"
GO
PRINT 'Instalacion limpia LOCAL completada y validada.';
GO

