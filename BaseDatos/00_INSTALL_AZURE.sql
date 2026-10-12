/* PlataformaApuestas: INSTALACION LIMPIA AZURE.
   No migra bases anteriores. No borra datos ni crea escenarios demo.
   SQLCMD desde BaseDatos: sqlcmd ... -b -i 00_INSTALL_AZURE.sql
   SSMS: activar modo SQLCMD y cambiar RutaBaseDatos por la ruta absoluta local.
   AZURE: conectar previamente a la base vacia; LOCAL: requiere permiso CREATE DATABASE. */
:setvar RutaBaseDatos "."
:On Error exit

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
:r $(RutaBaseDatos)\01_DB\02_CrearTablas.sql
GO
:r $(RutaBaseDatos)\02_CONFIGURACION\01_ConfiguracionSistema.sql
GO
:r $(RutaBaseDatos)\02_CONFIGURACION\02_Roles.sql
GO
:r $(RutaBaseDatos)\02_CONFIGURACION\03_Estados.sql
GO
:r $(RutaBaseDatos)\02_CONFIGURACION\04_Paises.sql
GO
:r $(RutaBaseDatos)\02_CONFIGURACION\05_DepartamentosGuatemala.sql
GO
:r $(RutaBaseDatos)\02_CONFIGURACION\06_MunicipiosGuatemala.sql
GO
:r $(RutaBaseDatos)\02_CONFIGURACION\07_TiposTransaccion.sql
GO
:r $(RutaBaseDatos)\02_CONFIGURACION\08_DatosIniciales.sql
GO
:r $(RutaBaseDatos)\03_PROCEDIMIENTOS\01_RegistroUsuario.sql
GO
:r $(RutaBaseDatos)\03_PROCEDIMIENTOS\02_SeguridadUsuario.sql
GO
:r $(RutaBaseDatos)\03_PROCEDIMIENTOS\03_Billetera.sql
GO
:r $(RutaBaseDatos)\03_PROCEDIMIENTOS\04_EventosMercados.sql
GO
:r $(RutaBaseDatos)\03_PROCEDIMIENTOS\05_Apuestas.sql
GO
:r $(RutaBaseDatos)\03_PROCEDIMIENTOS\06_Resultados.sql
GO
:r $(RutaBaseDatos)\03_PROCEDIMIENTOS\07_Liquidacion.sql
GO
:r $(RutaBaseDatos)\03_PROCEDIMIENTOS\08_AdministracionUsuario.sql
GO
:r $(RutaBaseDatos)\03_PROCEDIMIENTOS\09_AnaliticaUsuario.sql
GO
:r $(RutaBaseDatos)\03_PROCEDIMIENTOS\10_ExploracionEventos.sql
GO
:r $(RutaBaseDatos)\03_PROCEDIMIENTOS\11_AnaliticaAdministrativa.sql
GO
:r $(RutaBaseDatos)\03_PROCEDIMIENTOS\12_SimulacionModalidades.sql
GO
:r $(RutaBaseDatos)\04_INDICES\01_Indices.sql
GO
:r $(RutaBaseDatos)\05_VISTAS\01_Vistas.sql
GO
:r $(RutaBaseDatos)\06_AUDITORIA\01_AuditoriaTriggers.sql
GO
:r $(RutaBaseDatos)\01_DB\03_VerificarModelo.sql
GO
PRINT 'Instalacion limpia AZURE completada y validada.';
GO

