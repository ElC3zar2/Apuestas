/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS
   ARCHIVO: 02_CONFIGURACION/02_Roles.sql
   ============================================================ */

USE PlataformaApuestas;
GO


IF NOT EXISTS (SELECT 1 FROM Rol WHERE Nombre = 'ADMINISTRADOR')
BEGIN
    INSERT INTO Rol (Nombre, Descripcion)
    VALUES
    (
        'ADMINISTRADOR',
        'Administracion general del sistema'
    );
END;


IF NOT EXISTS (SELECT 1 FROM Rol WHERE Nombre = 'OPERADOR_EVENTOS')
BEGIN
    INSERT INTO Rol (Nombre, Descripcion)
    VALUES
    (
        'OPERADOR_EVENTOS',
        'Gestion de eventos, mercados y resultados deportivos'
    );
END;


IF NOT EXISTS (SELECT 1 FROM Rol WHERE Nombre = 'CAJERO')
BEGIN
    INSERT INTO Rol (Nombre, Descripcion)
    VALUES
    (
        'CAJERO',
        'Gestion autorizada de depositos y retiros'
    );
END;


IF NOT EXISTS (SELECT 1 FROM Rol WHERE Nombre = 'AUDITOR')
BEGIN
    INSERT INTO Rol (Nombre, Descripcion)
    VALUES
    (
        'AUDITOR',
        'Consulta y auditoria de operaciones del sistema'
    );
END;


IF NOT EXISTS (SELECT 1 FROM Rol WHERE Nombre = 'USUARIO')
BEGIN
    INSERT INTO Rol (Nombre, Descripcion)
    VALUES
    (
        'USUARIO',
        'Usuario final autorizado para realizar apuestas'
    );
END;


IF NOT EXISTS (SELECT 1 FROM Rol WHERE Nombre = 'CASA')
BEGIN
    INSERT INTO Rol (Nombre, Descripcion)
    VALUES
    (
        'CASA',
        'Cuenta interna que representa a la casa de apuestas'
    );
END;

GO

PRINT 'Roles del sistema verificados correctamente.';
GO