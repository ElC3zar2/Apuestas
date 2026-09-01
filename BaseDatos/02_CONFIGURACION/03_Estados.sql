/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   02_CONFIGURACION/03_Estados.sql

   OBJETIVO:
   Cargar los tipos de estado y estados funcionales del sistema.

   IMPORTANTE:
   - No utiliza USE para mantener compatibilidad con Azure SQL.
   - Es re-ejecutable.
   - No modifica estados existentes.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    /* ========================================================
       TIPOS DE ESTADO
       ======================================================== */

    DECLARE @Tipos TABLE
    (
        Codigo VARCHAR(40) NOT NULL,
        Nombre VARCHAR(100) NOT NULL,
        Descripcion VARCHAR(250) NULL
    );

    INSERT INTO @Tipos (Codigo, Nombre, Descripcion)
    VALUES
        ('USUARIO', 'Usuario', 'Estados administrativos de las cuentas de usuario.'),
        ('VERIFICACION', 'Verificación de usuario', 'Estados del proceso de revisión y verificación del usuario.'),
        ('EVENTO', 'Evento', 'Estados operativos de los eventos deportivos.'),
        ('MERCADO', 'Mercado', 'Estados operativos de los mercados de apuesta.'),
        ('RESULTADO_EVENTO', 'Resultado de evento', 'Estados administrativos del resultado oficial de un evento.'),
        ('BOLETO', 'Boleto', 'Estados de procesamiento de los boletos de apuesta.'),
        ('TRANSACCION', 'Transacción', 'Estados de las transacciones de saldo virtual.'),
        ('LIQUIDACION', 'Liquidación', 'Estados del proceso de liquidación de boletos.');

    INSERT INTO dbo.TipoEstado
    (
        Codigo,
        Nombre,
        Descripcion
    )
    SELECT
        T.Codigo,
        T.Nombre,
        T.Descripcion
    FROM @Tipos AS T
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.TipoEstado AS TE
        WHERE TE.Codigo = T.Codigo
    );


    /* ========================================================
       ESTADOS
       ======================================================== */

    DECLARE @Estados TABLE
    (
        TipoCodigo VARCHAR(40) NOT NULL,
        Codigo VARCHAR(40) NOT NULL,
        Nombre VARCHAR(100) NOT NULL,
        Descripcion VARCHAR(250) NULL,
        Orden SMALLINT NOT NULL
    );

    INSERT INTO @Estados
    (
        TipoCodigo,
        Codigo,
        Nombre,
        Descripcion,
        Orden
    )
    VALUES
        /* USUARIO */
        ('USUARIO', 'PENDIENTE', 'Pendiente', 'Cuenta creada y pendiente de completar o validar su proceso de habilitación.', 1),
        ('USUARIO', 'ACTIVO', 'Activo', 'Cuenta habilitada para operar según sus permisos y restricciones vigentes.', 2),
        ('USUARIO', 'SUSPENDIDO', 'Suspendido', 'Cuenta suspendida administrativamente de forma temporal.', 3),
        ('USUARIO', 'CERRADO', 'Cerrado', 'Cuenta cerrada y fuera de operación normal.', 4),

        /* VERIFICACION */
        ('VERIFICACION', 'PENDIENTE', 'Pendiente', 'Solicitud de verificación creada y pendiente de revisión.', 1),
        ('VERIFICACION', 'EN_REVISION', 'En revisión', 'Información del usuario actualmente bajo revisión administrativa.', 2),
        ('VERIFICACION', 'APROBADA', 'Aprobada', 'Verificación aprobada por un usuario autorizado.', 3),
        ('VERIFICACION', 'RECHAZADA', 'Rechazada', 'Verificación rechazada por inconsistencias o información insuficiente.', 4),

        /* EVENTO */
        ('EVENTO', 'BORRADOR', 'Borrador', 'Evento creado pero aún no disponible para operación pública.', 1),
        ('EVENTO', 'PROGRAMADO', 'Programado', 'Evento confirmado y pendiente de iniciar.', 2),
        ('EVENTO', 'EN_VIVO', 'En vivo', 'Evento actualmente en desarrollo.', 3),
        ('EVENTO', 'PENDIENTE_RESULTADO', 'Pendiente de resultado', 'Evento finalizado a la espera de registrar o validar su resultado oficial.', 4),
        ('EVENTO', 'FINALIZADO', 'Finalizado', 'Evento finalizado con resultado oficial procesado.', 5),
        ('EVENTO', 'SUSPENDIDO', 'Suspendido', 'Evento interrumpido temporalmente.', 6),
        ('EVENTO', 'CANCELADO', 'Cancelado', 'Evento cancelado definitivamente.', 7),

        /* MERCADO */
        ('MERCADO', 'BORRADOR', 'Borrador', 'Mercado creado pero aún no habilitado para apuestas.', 1),
        ('MERCADO', 'ABIERTO', 'Abierto', 'Mercado disponible para recibir apuestas.', 2),
        ('MERCADO', 'SUSPENDIDO', 'Suspendido', 'Mercado temporalmente bloqueado para nuevas apuestas.', 3),
        ('MERCADO', 'CERRADO', 'Cerrado', 'Mercado cerrado para nuevas apuestas y pendiente de resolución.', 4),
        ('MERCADO', 'LIQUIDADO', 'Liquidado', 'Mercado resuelto y procesado.', 5),
        ('MERCADO', 'ANULADO', 'Anulado', 'Mercado invalidado para efectos de las apuestas.', 6),

        /* RESULTADO_EVENTO */
        ('RESULTADO_EVENTO', 'PENDIENTE', 'Pendiente', 'Resultado registrado de forma preliminar o pendiente de validación.', 1),
        ('RESULTADO_EVENTO', 'OFICIAL', 'Oficial', 'Resultado validado como resultado oficial del evento.', 2),
        ('RESULTADO_EVENTO', 'CORREGIDO', 'Corregido', 'Resultado oficial corregido posteriormente por un usuario autorizado.', 3),
        ('RESULTADO_EVENTO', 'ANULADO', 'Anulado', 'Resultado invalidado administrativamente.', 4),

        /* BOLETO */
        ('BOLETO', 'PENDIENTE', 'Pendiente', 'Boleto registrado y pendiente de resolución.', 1),
        ('BOLETO', 'EN_REVISION', 'En revisión', 'Boleto temporalmente retenido para revisión administrativa o técnica.', 2),
        ('BOLETO', 'LIQUIDADO', 'Liquidado', 'Boleto procesado definitivamente.', 3),
        ('BOLETO', 'ANULADO', 'Anulado', 'Boleto invalidado y procesado según las reglas del sistema.', 4),

        /* TRANSACCION */
        ('TRANSACCION', 'PENDIENTE', 'Pendiente', 'Transacción de saldo virtual registrada y pendiente de procesamiento.', 1),
        ('TRANSACCION', 'EN_PROCESO', 'En proceso', 'Transacción de saldo virtual actualmente en procesamiento.', 2),
        ('TRANSACCION', 'COMPLETADA', 'Completada', 'Transacción aplicada correctamente.', 3),
        ('TRANSACCION', 'FALLIDA', 'Fallida', 'Transacción que no pudo completarse.', 4),
        ('TRANSACCION', 'ANULADA', 'Anulada', 'Transacción cancelada antes de su aplicación definitiva.', 5),

        /* LIQUIDACION */
        ('LIQUIDACION', 'PENDIENTE', 'Pendiente', 'Liquidación creada y pendiente de procesamiento.', 1),
        ('LIQUIDACION', 'EN_PROCESO', 'En proceso', 'Liquidación actualmente en procesamiento.', 2),
        ('LIQUIDACION', 'COMPLETADA', 'Completada', 'Liquidación finalizada correctamente.', 3),
        ('LIQUIDACION', 'FALLIDA', 'Fallida', 'Liquidación que no pudo completarse.', 4),
        ('LIQUIDACION', 'ANULADA', 'Anulada', 'Liquidación invalidada antes de completarse.', 5);


    INSERT INTO dbo.Estado
    (
        IdTipoEstado,
        Codigo,
        Nombre,
        Descripcion,
        Orden,
        Activo
    )
    SELECT
        TE.IdTipoEstado,
        E.Codigo,
        E.Nombre,
        E.Descripcion,
        E.Orden,
        1
    FROM @Estados AS E
    INNER JOIN dbo.TipoEstado AS TE
        ON TE.Codigo = E.TipoCodigo
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.Estado AS ES
        WHERE ES.IdTipoEstado = TE.IdTipoEstado
          AND ES.Codigo = E.Codigo
    );

    COMMIT TRANSACTION;

    PRINT 'Tipos de estado y estados cargados correctamente.';

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO