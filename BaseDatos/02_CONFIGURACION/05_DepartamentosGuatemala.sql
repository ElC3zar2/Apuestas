/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS Y PRONOSTICOS

   ARCHIVO:
   02_CONFIGURACION/05_DepartamentosGuatemala.sql

   OBJETIVO:
   Cargar los 22 departamentos de Guatemala.

   IMPORTANTE:
   - Requiere que 04_Paises.sql ya haya cargado Guatemala.
   - No utiliza USE para mantener compatibilidad con Azure SQL.
   - Es re-ejecutable.
   - No depende de IdPais fijos.
   ============================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @IdGuatemala INT;

    SELECT @IdGuatemala = IdPais
    FROM dbo.Pais
    WHERE CodigoISO2 = 'GT';

    IF @IdGuatemala IS NULL
        THROW 52001, 'No existe Guatemala en dbo.Pais. Ejecute primero 04_Paises.sql.', 1;

    DECLARE @Departamentos TABLE
    (
        Nombre VARCHAR(100) NOT NULL
    );

    INSERT INTO @Departamentos (Nombre)
    VALUES
        (N'Alta Verapaz'),
        (N'Baja Verapaz'),
        (N'Chimaltenango'),
        (N'Chiquimula'),
        (N'El Progreso'),
        (N'Escuintla'),
        (N'Guatemala'),
        (N'Huehuetenango'),
        (N'Izabal'),
        (N'Jalapa'),
        (N'Jutiapa'),
        (N'Petén'),
        (N'Quetzaltenango'),
        (N'Quiché'),
        (N'Retalhuleu'),
        (N'Sacatepéquez'),
        (N'San Marcos'),
        (N'Santa Rosa'),
        (N'Sololá'),
        (N'Suchitepéquez'),
        (N'Totonicapán'),
        (N'Zacapa');

    IF (SELECT COUNT(*) FROM @Departamentos) <> 22
        THROW 52002, 'El catálogo interno debe contener exactamente 22 departamentos.', 1;

    INSERT INTO dbo.Departamento
    (
        IdPais,
        Nombre,
        Activo
    )
    SELECT
        @IdGuatemala,
        D.Nombre,
        1
    FROM @Departamentos AS D
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.Departamento AS DE
        WHERE DE.IdPais = @IdGuatemala
          AND DE.Nombre = D.Nombre
    );

    COMMIT TRANSACTION;

    PRINT '22 departamentos de Guatemala verificados / cargados correctamente.';

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO