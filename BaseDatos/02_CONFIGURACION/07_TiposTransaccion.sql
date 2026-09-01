/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   02_CONFIGURACION/07_TiposTransaccion.sql

   OBJETIVO:
   Cargar los tipos de transacción utilizados para el manejo
   de saldo virtual dentro de la plataforma.

   IMPORTANTE:
   - El sistema NO maneja dinero real.
   - No utiliza USE para mantener compatibilidad con Azure SQL.
   - Es re-ejecutable.
   - No modifica tipos de transacción existentes.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Tipos TABLE
    (
        Codigo VARCHAR(40) NOT NULL,
        Nombre VARCHAR(100) NOT NULL,
        Descripcion VARCHAR(250) NULL
    );

    INSERT INTO @Tipos
    (
        Codigo,
        Nombre,
        Descripcion
    )
    VALUES
        (
            'CARGA_INICIAL',
            'Carga inicial',
            'Asignación inicial de saldo virtual a una billetera.'
        ),
        (
            'APUESTA',
            'Apuesta',
            'Movimiento de saldo disponible a saldo comprometido al registrar una apuesta.'
        ),
        (
            'PREMIO',
            'Premio',
            'Acreditación de saldo virtual al usuario por un boleto ganador.'
        ),
        (
            'PERDIDA_APUESTA',
            'Pérdida de apuesta',
            'Liberación definitiva del saldo comprometido correspondiente a una apuesta perdedora.'
        ),
        (
            'DEVOLUCION',
            'Devolución',
            'Retorno del saldo virtual comprometido cuando una apuesta es anulada.'
        ),
        (
            'GANANCIA_CASA',
            'Ganancia de la casa',
            'Acreditación de saldo virtual a la cuenta CASA por una apuesta perdida por el usuario.'
        ),
        (
            'PAGO_PREMIO',
            'Pago de premio',
            'Salida de saldo virtual de la cuenta CASA para cubrir el premio de una apuesta ganadora.'
        ),
        (
            'AJUSTE_ADMIN',
            'Ajuste administrativo',
            'Ajuste excepcional de saldo virtual realizado por un usuario autorizado.'
        );

    INSERT INTO dbo.TipoTransaccion
    (
        Codigo,
        Nombre,
        Descripcion,
        Activo
    )
    SELECT
        T.Codigo,
        T.Nombre,
        T.Descripcion,
        1
    FROM @Tipos AS T
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.TipoTransaccion AS TT
        WHERE TT.Codigo = T.Codigo
    );

    COMMIT TRANSACTION;

    PRINT 'Tipos de transaccion cargados correctamente.';

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO