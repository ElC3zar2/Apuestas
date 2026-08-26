/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS
   ARCHIVO: 02_CONFIGURACION/01_ConfiguracionSistema.sql

   Configuraciones generales modificables sin alterar
   la estructura de la base de datos.
   ============================================================ */

USE PlataformaApuestas;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM ConfiguracionSistema
    WHERE Clave = 'SALDO_INICIAL_USUARIO'
)
BEGIN

    INSERT INTO ConfiguracionSistema
    (
        Clave,
        Valor,
        Descripcion
    )
    VALUES
    (
        'SALDO_INICIAL_USUARIO',
        '500.00',
        'Saldo inicial asignado automáticamente a nuevos usuarios'
    );

    PRINT 'Configuracion SALDO_INICIAL_USUARIO creada.';
END
ELSE
BEGIN
    PRINT 'Configuracion SALDO_INICIAL_USUARIO ya existe.';
END;
GO

/*SALDO INICIAL CASA*/
IF NOT EXISTS
(
    SELECT 1
    FROM ConfiguracionSistema
    WHERE Clave = 'SALDO_INICIAL_CASA'
)
BEGIN

    INSERT INTO ConfiguracionSistema
    (
        Clave,
        Valor,
        Descripcion
    )
    VALUES
    (
        'SALDO_INICIAL_CASA',
        '100000.00',
        'Capital inicial asignado a la cuenta interna de la casa'
    );

    PRINT 'Configuracion SALDO_INICIAL_CASA creada.';
END
ELSE
BEGIN
    PRINT 'Configuracion SALDO_INICIAL_CASA ya existe.';
END;
GO