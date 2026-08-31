/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS
   SQL SERVER 2022 / AZURE SQL

   ARCHIVO:
   05_VISTAS/02_AuditoriaTriggers.sql

   OBJETIVO:
   Cerrar la capa definitiva de auditoría sin duplicar los
   registros que ya generan los procedimientos almacenados.

   INCLUYE:
   - Vista general de auditoría.
   - Protección del historial de Auditoria.
   - Protección del historial de MovimientoBilletera.
   - Protección contra eliminación de TransaccionFinanciera.
   - Auditoría automática de cambios en ConfiguracionSistema.
   - Protección contra eliminación de configuraciones.

   DECISION DE DISEÑO:
   Los procedimientos almacenados ya escriben explícitamente en
   dbo.Auditoria para las operaciones críticas. Por esa razón NO
   se crean triggers genéricos sobre Usuario, Billetera, Boleto,
   ResultadoEvento, etc., ya que producirían auditoría duplicada.

   Los triggers de este archivo se reservan para:
   1. proteger historiales que deben ser inmutables;
   2. registrar cambios de configuración que pueden realizarse
      administrativamente fuera de los flujos transaccionales.

   COMPATIBILIDAD:
   SQL Server 2022 / Azure SQL.
   ============================================================ */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


/* ============================================================
   1. VISTA GENERAL DE AUDITORIA

   No contiene contraseñas, TokenHash ni otra información
   sensible de autenticación.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_AuditoriaSistema
AS
SELECT
    A.IdAuditoria,
    A.FechaAccion,

    A.IdUsuario,
    U.Correo AS Usuario,

    R.Nombre AS RolUsuario,

    A.Accion,
    A.TablaAfectada,
    A.IdRegistro,
    A.ReferenciaOperacion,
    A.IpOrigen,
    A.Descripcion

FROM dbo.Auditoria AS A

LEFT JOIN dbo.Usuario AS U
    ON U.IdUsuario = A.IdUsuario

LEFT JOIN dbo.Rol AS R
    ON R.IdRol = U.IdRol;
GO


/* ============================================================
   2. PROTEGER HISTORIAL DE AUDITORIA

   Auditoria es append-only:
   - INSERT permitido.
   - UPDATE prohibido.
   - DELETE prohibido.

   Los procedimientos del sistema solamente INSERTAN registros,
   por lo que este trigger no interfiere con los flujos normales.
   ============================================================ */

CREATE OR ALTER TRIGGER dbo.tr_Auditoria_ProtegerHistorial
ON dbo.Auditoria
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    THROW 64001,
          'El historial de Auditoria es inmutable. No se permiten UPDATE ni DELETE.',
          1;
END;
GO


/* ============================================================
   3. PROTEGER MOVIMIENTOS DE BILLETERA

   MovimientoBilletera representa snapshots financieros:
   - saldo anterior;
   - saldo posterior.

   Una vez creado, un movimiento no debe alterarse ni eliminarse.
   Las correcciones financieras futuras deben realizarse mediante
   una NUEVA TransaccionFinanciera + MovimientoBilletera.
   ============================================================ */

CREATE OR ALTER TRIGGER dbo.tr_MovimientoBilletera_ProtegerHistorial
ON dbo.MovimientoBilletera
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    THROW 64002,
          'MovimientoBilletera es un historial financiero inmutable. Registre una nueva operación para corregir saldos.',
          1;
END;
GO


/* ============================================================
   4. PROTEGER TRANSACCIONES FINANCIERAS CONTRA DELETE

   Se permite UPDATE porque el modelo contempla estados como:
   PENDIENTE -> EN_PROCESO -> COMPLETADA/FALLIDA.

   Sin embargo, una TransaccionFinanciera registrada no debe
   eliminarse físicamente.
   ============================================================ */

CREATE OR ALTER TRIGGER dbo.tr_TransaccionFinanciera_ProhibirEliminacion
ON dbo.TransaccionFinanciera
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    THROW 64003,
          'No se permite eliminar TransaccionFinanciera. El historial financiero debe conservarse.',
          1;
END;
GO


/* ============================================================
   5. AUDITAR CAMBIOS DE CONFIGURACION

   ConfiguracionSistema puede ser modificada por administración.
   Como actualmente no existe un procedimiento exclusivo para
   modificar configuración, este trigger garantiza trazabilidad.

   IdUsuario queda NULL porque una modificación realizada
   directamente a nivel de SQL Server no permite identificar con
   seguridad al IdUsuario de la aplicación.

   La identidad técnica de la conexión se conserva en
   Descripcion mediante ORIGINAL_LOGIN().
   ============================================================ */

CREATE OR ALTER TRIGGER dbo.tr_ConfiguracionSistema_AuditarCambios
ON dbo.ConfiguracionSistema
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Auditoria
    (
        IdUsuario,
        Accion,
        TablaAfectada,
        IdRegistro,
        ReferenciaOperacion,
        IpOrigen,
        Descripcion
    )
    SELECT
        NULL,
        'CONFIGURACION_MODIFICADA',
        'ConfiguracionSistema',
        I.IdConfiguracion,
        NULL,
        NULL,
        CONCAT
        (
            'Clave=',
            I.Clave,
            '. ValorAnterior=',
            COALESCE(D.Valor, 'NULL'),
            '. ValorNuevo=',
            COALESCE(I.Valor, 'NULL'),
            '. LoginSQL=',
            ORIGINAL_LOGIN(),
            '.'
        )
    FROM inserted AS I
    INNER JOIN deleted AS D
        ON D.IdConfiguracion = I.IdConfiguracion
    WHERE
        ISNULL(I.Valor, '') <> ISNULL(D.Valor, '')
        OR ISNULL(I.Descripcion, '') <> ISNULL(D.Descripcion, '');
END;
GO


/* ============================================================
   6. PROTEGER CONFIGURACION CONTRA DELETE

   Las claves de configuración forman parte del contrato del
   sistema. Si una ya no debe utilizarse, debe corregirse el
   diseño explícitamente; no eliminarse durante operación normal.
   ============================================================ */

CREATE OR ALTER TRIGGER dbo.tr_ConfiguracionSistema_ProhibirEliminacion
ON dbo.ConfiguracionSistema
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    THROW 64004,
          'No se permite eliminar claves de ConfiguracionSistema durante la operación normal.',
          1;
END;
GO


/* ============================================================
   7. VERIFICACION DE COMPONENTES
   ============================================================ */

SELECT
    S.name AS Esquema,
    V.name AS Vista
FROM sys.views AS V
INNER JOIN sys.schemas AS S
    ON S.schema_id = V.schema_id
WHERE S.name = 'dbo'
  AND V.name = 'vw_AuditoriaSistema';
GO


SELECT
    OBJECT_SCHEMA_NAME(T.parent_id) AS Esquema,
    OBJECT_NAME(T.parent_id) AS Tabla,
    T.name AS NombreTrigger,
    T.is_disabled AS Deshabilitado
FROM sys.triggers AS T
WHERE T.parent_id IN
(
    OBJECT_ID('dbo.Auditoria'),
    OBJECT_ID('dbo.MovimientoBilletera'),
    OBJECT_ID('dbo.TransaccionFinanciera'),
    OBJECT_ID('dbo.ConfiguracionSistema')
)
AND T.name IN
(
    'tr_Auditoria_ProtegerHistorial',
    'tr_MovimientoBilletera_ProtegerHistorial',
    'tr_TransaccionFinanciera_ProhibirEliminacion',
    'tr_ConfiguracionSistema_AuditarCambios',
    'tr_ConfiguracionSistema_ProhibirEliminacion'
)
ORDER BY
    Tabla,
    NombreTrigger;
GO


PRINT '=======================================================';
PRINT ' AUDITORIA Y TRIGGERS DEFINITIVOS CREADOS / VERIFICADOS';
PRINT '=======================================================';
GO  