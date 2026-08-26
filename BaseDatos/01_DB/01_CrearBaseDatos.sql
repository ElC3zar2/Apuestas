/* ============================================================
   PLATAFORMA DE APUESTAS DEPORTIVAS
   SQL SERVER 2022

   ARCHIVO:
   01_DB/01_CrearBaseDatos.sql

   OBJETIVO:
   Crear la base de datos principal si todavía no existe.
   ============================================================ */

USE master;
GO

IF DB_ID('PlataformaApuestas') IS NULL
BEGIN
    PRINT 'Creando base de datos PlataformaApuestas...';

    CREATE DATABASE PlataformaApuestas;

    PRINT 'Base de datos PlataformaApuestas creada correctamente.';
END
ELSE
BEGIN
    PRINT 'La base de datos PlataformaApuestas ya existe.';
END;
GO