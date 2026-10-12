/* Pruebas negativas independientes: cada caso revierte su transaccion. Requiere demo V2. */
SET NOCOUNT ON;
GO
/* No apostar EN_VIVO */

DECLARE @Admin INT=(SELECT TOP(1) U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' ORDER BY U.IdUsuario),
 @Usuario INT=(SELECT IdUsuario FROM dbo.Usuario WHERE Correo='cliente.ana@apuestas.test'),
 @Evento INT=(SELECT IdEvento FROM dbo.Evento WHERE Nombre='DEMO V2 - PROGRAMADO'),
 @Sel INT,@Primera INT,@Ref UNIQUEIDENTIFIER=NEWID(),@Json NVARCHAR(MAX),@Monto DECIMAL(12,2);
SELECT @Sel=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='MARCADOR_FINAL';
SELECT TOP(1) @Primera=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='PRIMERA_ANOTACION' ORDER BY S.IdSeleccion;
SELECT @Monto=TRY_CONVERT(DECIMAL(12,2),Valor) FROM dbo.ConfiguracionSistema WHERE Clave='MONTO_MINIMO_APUESTA';
IF @Sel IS NULL OR @Usuario IS NULL OR @Admin IS NULL THROW 75300,'Requiere demo 01 y 04.',1;
SET @Json=CONCAT('[',@Sel,']');

BEGIN TRY
 BEGIN TRANSACTION;
 
 SELECT @Sel=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado JOIN dbo.Evento EV ON EV.IdEvento=M.IdEvento
 WHERE EV.Nombre='DEMO V2 - EN_VIVO' AND M.TipoMercado='MARCADOR_FINAL';
 SET @Json=CONCAT('[',@Sel,']');
 EXEC dbo.sp_RealizarApuesta @Usuario,@Json,@Monto,@Ref,NULL,2,1;
 IF XACT_STATE()<>0 ROLLBACK;
 THROW 75399,'La operacion debio rechazarse.',1;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 IF ERROR_NUMBER() NOT IN(60040) THROW;
 PRINT 'No apostar EN_VIVO: rechazo correcto';
END CATCH;
GO
/* No combinar modalidades */

DECLARE @Admin INT=(SELECT TOP(1) U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' ORDER BY U.IdUsuario),
 @Usuario INT=(SELECT IdUsuario FROM dbo.Usuario WHERE Correo='cliente.ana@apuestas.test'),
 @Evento INT=(SELECT IdEvento FROM dbo.Evento WHERE Nombre='DEMO V2 - PROGRAMADO'),
 @Sel INT,@Primera INT,@Ref UNIQUEIDENTIFIER=NEWID(),@Json NVARCHAR(MAX),@Monto DECIMAL(12,2);
SELECT @Sel=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='MARCADOR_FINAL';
SELECT TOP(1) @Primera=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='PRIMERA_ANOTACION' ORDER BY S.IdSeleccion;
SELECT @Monto=TRY_CONVERT(DECIMAL(12,2),Valor) FROM dbo.ConfiguracionSistema WHERE Clave='MONTO_MINIMO_APUESTA';
IF @Sel IS NULL OR @Usuario IS NULL OR @Admin IS NULL THROW 75300,'Requiere demo 01 y 04.',1;
SET @Json=CONCAT('[',@Sel,']');

BEGIN TRY
 BEGIN TRANSACTION;
 
 SET @Json=CONCAT('[',@Sel,',',@Primera,']');
 EXEC dbo.sp_RealizarApuesta @Usuario,@Json,@Monto,@Ref,NULL,2,1;
 IF XACT_STATE()<>0 ROLLBACK;
 THROW 75399,'La operacion debio rechazarse.',1;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 IF ERROR_NUMBER() NOT IN(76101) THROW;
 PRINT 'No combinar modalidades: rechazo correcto';
END CATCH;
GO
/* No aceptar sin respaldo CASA */

DECLARE @Admin INT=(SELECT TOP(1) U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' ORDER BY U.IdUsuario),
 @Usuario INT=(SELECT IdUsuario FROM dbo.Usuario WHERE Correo='cliente.ana@apuestas.test'),
 @Evento INT=(SELECT IdEvento FROM dbo.Evento WHERE Nombre='DEMO V2 - PROGRAMADO'),
 @Sel INT,@Primera INT,@Ref UNIQUEIDENTIFIER=NEWID(),@Json NVARCHAR(MAX),@Monto DECIMAL(12,2);
SELECT @Sel=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='MARCADOR_FINAL';
SELECT TOP(1) @Primera=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='PRIMERA_ANOTACION' ORDER BY S.IdSeleccion;
SELECT @Monto=TRY_CONVERT(DECIMAL(12,2),Valor) FROM dbo.ConfiguracionSistema WHERE Clave='MONTO_MINIMO_APUESTA';
IF @Sel IS NULL OR @Usuario IS NULL OR @Admin IS NULL THROW 75300,'Requiere demo 01 y 04.',1;
SET @Json=CONCAT('[',@Sel,']');

BEGIN TRY
 BEGIN TRANSACTION;
 
 DECLARE @Casa INT,@Disponible DECIMAL(12,2),@RefAjuste UNIQUEIDENTIFIER=NEWID();
 SELECT @Casa=U.IdUsuario,@Disponible=B.SaldoDisponible FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Billetera B ON B.IdUsuario=U.IdUsuario WHERE R.Nombre='CASA';
 IF @Disponible>0 EXEC dbo.sp_AjustarSaldoVirtual @Casa,@Admin,'DEBITO',@Disponible,'Prueba sin respaldo.',@RefAjuste;
 EXEC dbo.sp_RealizarApuesta @Usuario,@Json,@Monto,@Ref,NULL,2,1;
 IF XACT_STATE()<>0 ROLLBACK;
 THROW 75399,'La operacion debio rechazarse.',1;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 IF ERROR_NUMBER() NOT IN(76106) THROW;
 PRINT 'No aceptar sin respaldo CASA: rechazo correcto';
END CATCH;
GO
/* No pronostico negativo */

DECLARE @Admin INT=(SELECT TOP(1) U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' ORDER BY U.IdUsuario),
 @Usuario INT=(SELECT IdUsuario FROM dbo.Usuario WHERE Correo='cliente.ana@apuestas.test'),
 @Evento INT=(SELECT IdEvento FROM dbo.Evento WHERE Nombre='DEMO V2 - PROGRAMADO'),
 @Sel INT,@Primera INT,@Ref UNIQUEIDENTIFIER=NEWID(),@Json NVARCHAR(MAX),@Monto DECIMAL(12,2);
SELECT @Sel=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='MARCADOR_FINAL';
SELECT TOP(1) @Primera=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='PRIMERA_ANOTACION' ORDER BY S.IdSeleccion;
SELECT @Monto=TRY_CONVERT(DECIMAL(12,2),Valor) FROM dbo.ConfiguracionSistema WHERE Clave='MONTO_MINIMO_APUESTA';
IF @Sel IS NULL OR @Usuario IS NULL OR @Admin IS NULL THROW 75300,'Requiere demo 01 y 04.',1;
SET @Json=CONCAT('[',@Sel,']');

BEGIN TRY
 BEGIN TRANSACTION;
 EXEC dbo.sp_RealizarApuesta @Usuario,@Json,@Monto,@Ref,NULL,-1,1;
 IF XACT_STATE()<>0 ROLLBACK;
 THROW 75399,'La operacion debio rechazarse.',1;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 IF ERROR_NUMBER() NOT IN(76102) THROW;
 PRINT 'No pronostico negativo: rechazo correcto';
END CATCH;
GO
/* Idempotencia rechaza otro pronostico */

DECLARE @Admin INT=(SELECT TOP(1) U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' ORDER BY U.IdUsuario),
 @Usuario INT=(SELECT IdUsuario FROM dbo.Usuario WHERE Correo='cliente.ana@apuestas.test'),
 @Evento INT=(SELECT IdEvento FROM dbo.Evento WHERE Nombre='DEMO V2 - PROGRAMADO'),
 @Sel INT,@Primera INT,@Ref UNIQUEIDENTIFIER=NEWID(),@Json NVARCHAR(MAX),@Monto DECIMAL(12,2);
SELECT @Sel=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='MARCADOR_FINAL';
SELECT TOP(1) @Primera=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='PRIMERA_ANOTACION' ORDER BY S.IdSeleccion;
SELECT @Monto=TRY_CONVERT(DECIMAL(12,2),Valor) FROM dbo.ConfiguracionSistema WHERE Clave='MONTO_MINIMO_APUESTA';
IF @Sel IS NULL OR @Usuario IS NULL OR @Admin IS NULL THROW 75300,'Requiere demo 01 y 04.',1;
SET @Json=CONCAT('[',@Sel,']');

BEGIN TRY
 BEGIN TRANSACTION;
 
 SET @Ref='A3000000-0000-0000-0000-000000000011';
 EXEC dbo.sp_RealizarApuesta @Usuario,@Json,@Monto,@Ref,NULL,9,9;
 IF XACT_STATE()<>0 ROLLBACK;
 THROW 75399,'La operacion debio rechazarse.',1;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 IF ERROR_NUMBER() NOT IN(76104) THROW;
 PRINT 'Idempotencia rechaza otro pronostico: rechazo correcto';
END CATCH;
GO
/* No finalizar sin oficializar */

DECLARE @Admin INT=(SELECT TOP(1) U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' ORDER BY U.IdUsuario),
 @Usuario INT=(SELECT IdUsuario FROM dbo.Usuario WHERE Correo='cliente.ana@apuestas.test'),
 @Evento INT=(SELECT IdEvento FROM dbo.Evento WHERE Nombre='DEMO V2 - PROGRAMADO'),
 @Sel INT,@Primera INT,@Ref UNIQUEIDENTIFIER=NEWID(),@Json NVARCHAR(MAX),@Monto DECIMAL(12,2);
SELECT @Sel=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='MARCADOR_FINAL';
SELECT TOP(1) @Primera=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='PRIMERA_ANOTACION' ORDER BY S.IdSeleccion;
SELECT @Monto=TRY_CONVERT(DECIMAL(12,2),Valor) FROM dbo.ConfiguracionSistema WHERE Clave='MONTO_MINIMO_APUESTA';
IF @Sel IS NULL OR @Usuario IS NULL OR @Admin IS NULL THROW 75300,'Requiere demo 01 y 04.',1;
SET @Json=CONCAT('[',@Sel,']');

BEGIN TRY
 BEGIN TRANSACTION;
 EXEC dbo.sp_CambiarEstadoEvento @Admin,@Evento,'FINALIZADO';
 IF XACT_STATE()<>0 ROLLBACK;
 THROW 75399,'La operacion debio rechazarse.',1;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 IF ERROR_NUMBER() NOT IN(76013) THROW;
 PRINT 'No finalizar sin oficializar: rechazo correcto';
END CATCH;
GO
/* No editar datos originales de incidencia */

DECLARE @Admin INT=(SELECT TOP(1) U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' ORDER BY U.IdUsuario),
 @Usuario INT=(SELECT IdUsuario FROM dbo.Usuario WHERE Correo='cliente.ana@apuestas.test'),
 @Evento INT=(SELECT IdEvento FROM dbo.Evento WHERE Nombre='DEMO V2 - PROGRAMADO'),
 @Sel INT,@Primera INT,@Ref UNIQUEIDENTIFIER=NEWID(),@Json NVARCHAR(MAX),@Monto DECIMAL(12,2);
SELECT @Sel=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='MARCADOR_FINAL';
SELECT TOP(1) @Primera=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='PRIMERA_ANOTACION' ORDER BY S.IdSeleccion;
SELECT @Monto=TRY_CONVERT(DECIMAL(12,2),Valor) FROM dbo.ConfiguracionSistema WHERE Clave='MONTO_MINIMO_APUESTA';
IF @Sel IS NULL OR @Usuario IS NULL OR @Admin IS NULL THROW 75300,'Requiere demo 01 y 04.',1;
SET @Json=CONCAT('[',@Sel,']');

BEGIN TRY
 BEGIN TRANSACTION;
 
 UPDATE dbo.IncidenciaEvento SET ValorAnotacion=2 WHERE ReferenciaOperacion='B3000000-0000-0000-0000-000000000031';
 IF XACT_STATE()<>0 ROLLBACK;
 THROW 75399,'La operacion debio rechazarse.',1;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 IF ERROR_NUMBER() NOT IN(76502) THROW;
 PRINT 'No editar datos originales de incidencia: rechazo correcto';
END CATCH;
GO
/* No borrar incidencia */

DECLARE @Admin INT=(SELECT TOP(1) U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' ORDER BY U.IdUsuario),
 @Usuario INT=(SELECT IdUsuario FROM dbo.Usuario WHERE Correo='cliente.ana@apuestas.test'),
 @Evento INT=(SELECT IdEvento FROM dbo.Evento WHERE Nombre='DEMO V2 - PROGRAMADO'),
 @Sel INT,@Primera INT,@Ref UNIQUEIDENTIFIER=NEWID(),@Json NVARCHAR(MAX),@Monto DECIMAL(12,2);
SELECT @Sel=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='MARCADOR_FINAL';
SELECT TOP(1) @Primera=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='PRIMERA_ANOTACION' ORDER BY S.IdSeleccion;
SELECT @Monto=TRY_CONVERT(DECIMAL(12,2),Valor) FROM dbo.ConfiguracionSistema WHERE Clave='MONTO_MINIMO_APUESTA';
IF @Sel IS NULL OR @Usuario IS NULL OR @Admin IS NULL THROW 75300,'Requiere demo 01 y 04.',1;
SET @Json=CONCAT('[',@Sel,']');

BEGIN TRY
 BEGIN TRANSACTION;
 
 DELETE FROM dbo.IncidenciaEvento WHERE ReferenciaOperacion='B3000000-0000-0000-0000-000000000031';
 IF XACT_STATE()<>0 ROLLBACK;
 THROW 75399,'La operacion debio rechazarse.',1;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 IF ERROR_NUMBER() NOT IN(76501) THROW;
 PRINT 'No borrar incidencia: rechazo correcto';
END CATCH;
GO
/* No pagar resultado preliminar */

DECLARE @Admin INT=(SELECT TOP(1) U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' ORDER BY U.IdUsuario),
 @Usuario INT=(SELECT IdUsuario FROM dbo.Usuario WHERE Correo='cliente.ana@apuestas.test'),
 @Evento INT=(SELECT IdEvento FROM dbo.Evento WHERE Nombre='DEMO V2 - PROGRAMADO'),
 @Sel INT,@Primera INT,@Ref UNIQUEIDENTIFIER=NEWID(),@Json NVARCHAR(MAX),@Monto DECIMAL(12,2);
SELECT @Sel=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='MARCADOR_FINAL';
SELECT TOP(1) @Primera=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='PRIMERA_ANOTACION' ORDER BY S.IdSeleccion;
SELECT @Monto=TRY_CONVERT(DECIMAL(12,2),Valor) FROM dbo.ConfiguracionSistema WHERE Clave='MONTO_MINIMO_APUESTA';
IF @Sel IS NULL OR @Usuario IS NULL OR @Admin IS NULL THROW 75300,'Requiere demo 01 y 04.',1;
SET @Json=CONCAT('[',@Sel,']');

BEGIN TRY
 BEGIN TRANSACTION;
 
 DECLARE @Boleto INT=(SELECT IdBoleto FROM dbo.Boleto WHERE ReferenciaOperacion='A3000000-0000-0000-0000-000000000041');
 EXEC dbo.sp_LiquidarBoleto @Admin,@Boleto;
 IF XACT_STATE()<>0 ROLLBACK;
 THROW 75399,'La operacion debio rechazarse.',1;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 IF ERROR_NUMBER() NOT IN(62021,76401) THROW;
 PRINT 'No pagar resultado preliminar: rechazo correcto';
END CATCH;
GO
/* No corregir resultado liquidado */

DECLARE @Admin INT=(SELECT TOP(1) U.IdUsuario FROM dbo.Usuario U JOIN dbo.Rol R ON R.IdRol=U.IdRol
 JOIN dbo.Estado E ON E.IdEstado=U.IdEstado WHERE R.Nombre='ADMINISTRADOR' AND E.Codigo='ACTIVO' ORDER BY U.IdUsuario),
 @Usuario INT=(SELECT IdUsuario FROM dbo.Usuario WHERE Correo='cliente.ana@apuestas.test'),
 @Evento INT=(SELECT IdEvento FROM dbo.Evento WHERE Nombre='DEMO V2 - PROGRAMADO'),
 @Sel INT,@Primera INT,@Ref UNIQUEIDENTIFIER=NEWID(),@Json NVARCHAR(MAX),@Monto DECIMAL(12,2);
SELECT @Sel=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='MARCADOR_FINAL';
SELECT TOP(1) @Primera=S.IdSeleccion FROM dbo.Seleccion S JOIN dbo.Mercado M ON M.IdMercado=S.IdMercado
 WHERE M.IdEvento=@Evento AND M.TipoMercado='PRIMERA_ANOTACION' ORDER BY S.IdSeleccion;
SELECT @Monto=TRY_CONVERT(DECIMAL(12,2),Valor) FROM dbo.ConfiguracionSistema WHERE Clave='MONTO_MINIMO_APUESTA';
IF @Sel IS NULL OR @Usuario IS NULL OR @Admin IS NULL THROW 75300,'Requiere demo 01 y 04.',1;
SET @Json=CONCAT('[',@Sel,']');

BEGIN TRY
 BEGIN TRANSACTION;
 
 DECLARE @Resultado INT=(SELECT R.IdResultado FROM dbo.ResultadoEvento R JOIN dbo.Evento EV ON EV.IdEvento=R.IdEvento WHERE EV.Nombre='DEMO V2 - FINALIZADO 2-1');
 EXEC dbo.sp_CorregirResultadoEvento @Admin,@Resultado,'0-0','Prueba de bloqueo tras liquidacion.';
 IF XACT_STATE()<>0 ROLLBACK;
 THROW 75399,'La operacion debio rechazarse.',1;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 IF ERROR_NUMBER() NOT IN(61037) THROW;
 PRINT 'No corregir resultado liquidado: rechazo correcto';
END CATCH;
GO
