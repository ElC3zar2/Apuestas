/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   02_CONFIGURACION/02_Roles.sql

   OBJETIVO:
   Cargar los roles funcionales utilizados por el sistema.

   IMPORTANTE:
   - No utiliza USE para mantener compatibilidad con Azure SQL.
   - Es re-ejecutable.
   - No modifica roles existentes.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY

    BEGIN TRANSACTION;

    /* ========================================================
       ADMINISTRADOR
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Rol
        WHERE Nombre = 'ADMINISTRADOR'
    )
    BEGIN
        INSERT INTO dbo.Rol
        (
            Nombre,
            Descripcion,
            Activo
        )
        VALUES
        (
            'ADMINISTRADOR',
            'Acceso administrativo general a la plataforma.',
            1
        );
    END;


    /* ========================================================
       OPERADOR DE EVENTOS
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Rol
        WHERE Nombre = 'OPERADOR_EVENTOS'
    )
    BEGIN
        INSERT INTO dbo.Rol
        (
            Nombre,
            Descripcion,
            Activo
        )
        VALUES
        (
            'OPERADOR_EVENTOS',
            'Administra eventos deportivos, mercados, selecciones, cuotas y resultados.',
            1
        );
    END;


    /* ========================================================
       CAJERO
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Rol
        WHERE Nombre = 'CAJERO'
    )
    BEGIN
        INSERT INTO dbo.Rol
        (
            Nombre,
            Descripcion,
            Activo
        )
        VALUES
        (
            'CAJERO',
            'Gestiona operaciones administrativas autorizadas relacionadas con saldo virtual.',
            1
        );
    END;


    /* ========================================================
       AUDITOR
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Rol
        WHERE Nombre = 'AUDITOR'
    )
    BEGIN
        INSERT INTO dbo.Rol
        (
            Nombre,
            Descripcion,
            Activo
        )
        VALUES
        (
            'AUDITOR',
            'Consulta información de auditoría, operaciones y trazabilidad del sistema.',
            1
        );
    END;


    /* ========================================================
       USUARIO
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Rol
        WHERE Nombre = 'USUARIO'
    )
    BEGIN
        INSERT INTO dbo.Rol
        (
            Nombre,
            Descripcion,
            Activo
        )
        VALUES
        (
            'USUARIO',
            'Cliente final autorizado para utilizar las funciones de la plataforma de apuestas.',
            1
        );
    END;


    /* ========================================================
       CASA
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Rol
        WHERE Nombre = 'CASA'
    )
    BEGIN
        INSERT INTO dbo.Rol
        (
            Nombre,
            Descripcion,
            Activo
        )
        VALUES
        (
            'CASA',
            'Cuenta interna que representa a la casa dentro del sistema de apuestas.',
            1
        );
    END;


    COMMIT TRANSACTION;

    PRINT 'Roles cargados correctamente.';

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO