/* Creamos la base de datos*/
IF DB_ID('VentasDW') IS NULL
BEGIN
    CREATE DATABASE VentasDW;
END

-- Usamos la Base de Datos VentasDW
USE VentasDW

-- Definir la estructura de las tablas
-- DIM_CATEGORY  (5 filas — catálogo de categorías)

CREATE TABLE dbo.DIM_CATEGORY (
    ID_CATEGORY   INT             NOT NULL,
    CATEGORY      VARCHAR(60)     NOT NULL,
    CONSTRAINT PK_DIM_CATEGORY PRIMARY KEY (ID_CATEGORY)
);

-- DIM_CALENDAR  (156 filas — una fila por semana)
CREATE TABLE dbo.DIM_CALENDAR (
    WEEK          VARCHAR(5)      NOT NULL,   -- ej. '01-21'
    YEAR          SMALLINT        NOT NULL,
    MONTH         TINYINT         NOT NULL,
    WEEK_NUMBER   TINYINT         NOT NULL,
    [DATE]        DATE            NOT NULL,
    CONSTRAINT PK_DIM_CALENDAR PRIMARY KEY (WEEK)
);

-- DIM_SEGMENT  (53 filas — combinaciones de atributos por categoría)
CREATE TABLE dbo.DIM_SEGMENT (
    SEGMENT_ID    INT IDENTITY(1,1) NOT NULL,
    CATEGORY      INT             NOT NULL,
    ATTR1         VARCHAR(20)     NULL,
    ATTR2         VARCHAR(20)     NULL,
    ATTR3         VARCHAR(20)     NULL,
    [FORMAT]      VARCHAR(15)     NULL,
    SEGMENT       VARCHAR(20)     NULL,
    CONSTRAINT PK_DIM_SEGMENT PRIMARY KEY (SEGMENT_ID),
    CONSTRAINT FK_SEGMENT_CATEGORY FOREIGN KEY (CATEGORY)
        REFERENCES dbo.DIM_CATEGORY (ID_CATEGORY)
);

-- DIM_PRODUCT  (505 filas — catálogo de productos)
CREATE TABLE dbo.DIM_PRODUCT (
    PRODUCT_ID        INT IDENTITY(1,1) NOT NULL,
    ITEM              VARCHAR(20)   NOT NULL,
    MANUFACTURER      VARCHAR(30)   NULL,
    BRAND             VARCHAR(30)   NULL,
    ITEM_DESCRIPTION  VARCHAR(120)  NULL,
    CATEGORY          INT           NULL,
    [FORMAT]          VARCHAR(15)   NULL,
    ATTR1             VARCHAR(20)   NULL,
    ATTR2             VARCHAR(20)   NULL,
    ATTR3             VARCHAR(20)   NULL,
    CONSTRAINT PK_DIM_PRODUCT PRIMARY KEY (PRODUCT_ID),
    CONSTRAINT UQ_DIM_PRODUCT_ITEM UNIQUE (ITEM),
    CONSTRAINT FK_PRODUCT_CATEGORY FOREIGN KEY (CATEGORY)
        REFERENCES dbo.DIM_CATEGORY (ID_CATEGORY)
);

-- FACT_SALES  (~122,002 filas — hechos de venta semanal por producto/región)
CREATE TABLE dbo.FACT_SALES (
    SALE_ID                      BIGINT IDENTITY(1,1) NOT NULL,
    WEEK                         VARCHAR(5)      NOT NULL,
    ITEM_CODE                    VARCHAR(20)     NOT NULL,
    TOTAL_UNIT_SALES             DECIMAL(14,3)   NULL,
    TOTAL_VALUE_SALES            DECIMAL(16,3)   NULL,
    TOTAL_UNIT_AVG_WEEKLY_SALES  DECIMAL(14,3)   NULL,
    REGION                       VARCHAR(35)     NULL,
    CONSTRAINT PK_FACT_SALES PRIMARY KEY (SALE_ID),
    CONSTRAINT FK_FACT_WEEK FOREIGN KEY (WEEK)
        REFERENCES dbo.DIM_CALENDAR (WEEK),
    CONSTRAINT FK_FACT_ITEM FOREIGN KEY (ITEM_CODE)
        REFERENCES dbo.DIM_PRODUCT (ITEM)
);

-- Importar los datos de los archivos a las tablas

-- Pasar el archivo DIM_CATEGORY.CSV a la tabla dbo.DIM_CATEGORY
BULK INSERT dbo.DIM_CATEGORY
FROM 'C:\Users\zrgv\OneDrive\Documentos\Cientifico de datos ebac\Modulo 42\proyecto\DIM_CATEGORY.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

select * from dbo.DIM_CATEGORY

-- habilitar las consultas distribuidas en tu instancia de SQL Server ejecutando estas líneas
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;

-- pasar los datos del archivo DIM_CALENDAR.xlsx a la tabla dbo.DIM_CALENDAR


INSERT INTO dbo.DIM_CALENDAR (WEEK, YEAR, MONTH, WEEK_NUMBER, DATE)
SELECT WEEK, YEAR, MONTH, WEEK_NUMBER, DATE 
FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0', 
    'Excel 12.0 Xml;Database=D:\proyecto\DIM_CALENDAR.xlsx;HDR=YES', 
    'SELECT * FROM [Sheet1$]'
);
/* como no se pudo pasar los datos de los archivos xlsx a las tablas por problemas de versiones del SSMS y de Excel, así como de los
controladores se opto por gurardar los archivos .xlsx como .csv*/
-- Pasar el archivo DIM_CATEGORY.CSV a la tabla dbo.DIM_CATEGORY
-- 1. Le indicas el formato de fecha del archivo (dmy = día, mes, año)
SET DATEFORMAT dmy; 
-- 2. Ejecutas tu carga normal
BULK INSERT dbo.DIM_CALENDAR
FROM 'D:\proyecto\DIM_CALENDAR.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',', -- Asegúrate si es ',' o ';'
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);
select * from dbo.DIM_CALENDAR

/* Crear la vista dbo.vw_DIM_PRODUCT_LOAD, para que sql genere los IDs automáticamente
despues realizamos el BULK INSEERT apuntando a la vista */
CREATE VIEW dbo.vw_DIM_PRODUCT_Load AS
SELECT 
    MANUFACTURER,
    BRAND,
    ITEM,
    ITEM_DESCRIPTION,
    CATEGORY,
    FORMAT,
    ATTR1,
    ATTR2,
    ATTR3
FROM dbo.DIM_PRODUCT;

-- crear la tabla intermedia (sin restricciones UNIQUE ni IDENTITY)
CREATE TABLE dbo.STG_DIM_PRODUCT (
    MANUFACTURER VARCHAR(255),
    BRAND VARCHAR(255),
    ITEM VARCHAR(255),
    ITEM_DESCRIPTION VARCHAR(255),
    CATEGORY VARCHAR(255),
    FORMAT VARCHAR(255),
    ATTR1 VARCHAR(255),
    ATTR2 VARCHAR(255),
    ATTR3 VARCHAR(255)
);

-- Hacer el BULK INSERT directo a la tabla intermedia:
TRUNCATE TABLE dbo.STG_DIM_PRODUCT; -- Limpia cargas previas

BULK INSERT dbo.STG_DIM_PRODUCT
FROM 'D:\proyecto\DIM_PRODUCT.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2
);

/* Insertar en la tabla final eliminando los duplicados de ITEM:Aquí decides qué hacer con los N/A. 
Si quieres ignorar los duplicados y quedarte solo con el primero que encuentre, ejecutas esto:
*/

WITH CTE_Productos_Unicos AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY ITEM ORDER BY (SELECT NULL)) as RowNum
    FROM dbo.STG_DIM_PRODUCT
)
INSERT INTO dbo.DIM_PRODUCT (MANUFACTURER, BRAND, ITEM, ITEM_DESCRIPTION, CATEGORY, FORMAT, ATTR1, ATTR2, ATTR3)
SELECT MANUFACTURER, BRAND, ITEM, ITEM_DESCRIPTION, CATEGORY, FORMAT, ATTR1, ATTR2, ATTR3
FROM CTE_Productos_Unicos
WHERE RowNum = 1; -- Solo inserta el primer 'N/A' o duplicado y descarta el resto

select * from dbo.DIM_PRODUCT


-- Pasar el archivo FACT_SALES.csv a la tabla dbo.FACT_SALES
-- Creamos la vista de la tabla FACT_SALES, por que no podemos insertar los datos del archivo csv directamente a la tabla
CREATE VIEW dbo.VW_FACT_SALES_BULK AS
SELECT 
    WEEK, 
    ITEM_CODE, 
    TOTAL_UNIT_SALES, 
    TOTAL_VALUE_SALES, 
    TOTAL_UNIT_AVG_WEEKLY_SALES, 
    REGION
FROM dbo.FACT_SALES;

-- insertamos los valores del archivo cvs a la vista
/*BULK INSERT dbo.VW_FACT_SALES_BULK
FROM 'D:\proyecto\FACT_SALES.csv'
WITH (
    DATAFILETYPE = 'char',   -- Cambiamos FORMAT='CSV' por lectura nativa de caracteres
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',    -- Si este falla, prueba con '\r\n' o '0x0a'
    TABLOCK
);*/

--select * from dbo.VW_FACT_SALES_BULK
/* Crear la tabla de paso (Staging)Esta tabla aceptará los textos con todo y comillas sin quejarse de los 
tamaños ni tipos de datos.*/

CREATE TABLE dbo.STG_FACT_SALES (
    WEEK VARCHAR(50),
    ITEM_CODE VARCHAR(100),
    TOTAL_UNIT_SALES VARCHAR(50),
    TOTAL_VALUE_SALES VARCHAR(50),
    TOTAL_UNIT_AVG_WEEKLY_SALES VARCHAR(50),
    REGION VARCHAR(250)
);

/*  Cargar el CSV en la tabla de pasoEjecuta el BULK INSERT apuntando a esta nueva tabla. 
Como las columnas son amplias, no tendrás errores de truncado: */

TRUNCATE TABLE dbo.STG_FACT_SALES; -- Limpia la tabla por si acaso

BULK INSERT dbo.STG_FACT_SALES
FROM 'd:proyecto\FACT_SALES.csv'
WITH (
    DATAFILETYPE = 'char',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n', -- Si este falla, usa '\r\n'
    TABLOCK
);

/* Pasar los datos limpios a tu tabla final (dbo.FACT_SALES)Ahora ejecutamos un INSERT INTO tradicional. 
Aquí usamos REPLACE para eliminar las comillas dobles de los textos (dejando "34-22" como un limpio 34-22 de 5 caracteres) 
y dejamos que SQL Server convierta automáticamente los números decimales:*/

INSERT INTO dbo.FACT_SALES (
    WEEK, 
    ITEM_CODE, 
    TOTAL_UNIT_SALES, 
    TOTAL_VALUE_SALES, 
    TOTAL_UNIT_AVG_WEEKLY_SALES, 
    REGION
)
SELECT 
    REPLACE(WEEK, '"', '') AS WEEK,
    REPLACE(ITEM_CODE, '"', '') AS ITEM_CODE,
    -- Quitamos las comillas antes de convertirlos a números:
    CAST(REPLACE(TOTAL_UNIT_SALES, '"', '') AS DECIMAL(14,3)),
    CAST(REPLACE(TOTAL_VALUE_SALES, '"', '') AS DECIMAL(16,3)),
    CAST(REPLACE(TOTAL_UNIT_AVG_WEEKLY_SALES, '"', '') AS DECIMAL(14,3)),
    REPLACE(REGION, '"', '') AS REGION
FROM dbo.STG_FACT_SALES;

select * from dbo.FACT_SALES

-- Pasar los datos del archivo DIM_SEGMENT.csv a la tabla dbo.DIM_SEGMENT
-- 1. Creamos una tabla temporal con la estructura EXACTA del archivo CSV
CREATE TABLE #TempCSV (
    CATEGORY VARCHAR(50),
    ATTR1 VARCHAR(150),
    ATTR2 VARCHAR(150),
    ATTR3 VARCHAR(150),
    FORMAT VARCHAR(100),
    SEGMENT VARCHAR(100)
);

-- Importamos el archivo (ahora entrará sin errores porque todo es VARCHAR)
BULK INSERT #TempCSV
FROM 'D:\proyecto\DIM_SEGMENT.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001' -- Mantiene tildes o eñes si las hay
);

/* Insertamos los datos en dbo.DIM_SEGMENT mapeando cada columna a su lugar correcto 
Aquí se puede usar CAST o CONVERT si CATEGORY en la tabla real es un INT */

INSERT INTO dbo.DIM_SEGMENT(CATEGORY, ATTR1, ATTR2, ATTR3, FORMAT, SEGMENT)
SELECT 
    CAST(CATEGORY AS INT), -- Convierte el '1' de texto a número entero
    ATTR1,
    ATTR2,
    ATTR3,
    FORMAT,
    SEGMENT
FROM #TempCSV;

-- CONSULTAS BÁSICAS DE VERIFICACIÓN
-- Conteo de filas cargadas por tabla
SELECT 'DIM_CATEGORY' AS TABLA, COUNT(*) AS FILAS FROM dbo.DIM_CATEGORY
UNION ALL
SELECT 'DIM_CALENDAR', COUNT(*) FROM dbo.DIM_CALENDAR
UNION ALL
SELECT 'DIM_SEGMENT', COUNT(*) FROM dbo.DIM_SEGMENT
UNION ALL
SELECT 'DIM_PRODUCT', COUNT(*) FROM dbo.DIM_PRODUCT
UNION ALL
SELECT 'FACT_SALES', COUNT(*) FROM dbo.FACT_SALES;

-- Vista rápida de cada tabla (primeras 10 filas)
SELECT TOP 10 * FROM dbo.DIM_CATEGORY;
SELECT TOP 10 * FROM dbo.DIM_CALENDAR;
SELECT TOP 10 * FROM dbo.DIM_SEGMENT;
SELECT TOP 10 * FROM dbo.DIM_PRODUCT;
SELECT TOP 10 * FROM dbo.FACT_SALES;

-- Verificación de integridad: valores en FACT_SALES sin coincidencia
--     en las dimensiones (deberían regresar 0 filas si la carga fue correcta)
SELECT DISTINCT f.WEEK
FROM dbo.FACT_SALES f
LEFT JOIN dbo.DIM_CALENDAR c ON f.WEEK = c.WEEK
WHERE c.WEEK IS NULL;

SELECT DISTINCT f.ITEM_CODE
FROM dbo.FACT_SALES f
LEFT JOIN dbo.DIM_PRODUCT p ON f.ITEM_CODE = p.ITEM
WHERE p.ITEM IS NULL;

-- Rango de fechas y regiones cargadas (control de coherencia)
SELECT MIN([DATE]) AS FECHA_MIN, MAX([DATE]) AS FECHA_MAX FROM dbo.DIM_CALENDAR;
SELECT DISTINCT REGION FROM dbo.FACT_SALES ORDER BY REGION;

-- UNIONES ENTRE TABLAS PARA OBTENER INSIGHTS

-- Ventas totales (unidades y valor) por CATEGORÍA
SELECT
    cat.CATEGORY                         AS CATEGORIA,
    SUM(f.TOTAL_UNIT_SALES)              AS UNIDADES_VENDIDAS,
    SUM(f.TOTAL_VALUE_SALES)             AS VENTA_TOTAL
FROM dbo.FACT_SALES f
JOIN dbo.DIM_PRODUCT p  ON f.ITEM_CODE = p.ITEM
JOIN dbo.DIM_CATEGORY cat ON p.CATEGORY = cat.ID_CATEGORY
GROUP BY cat.CATEGORY
ORDER BY VENTA_TOTAL DESC;

-- Ventas totales por REGIÓN
SELECT
    f.REGION                             AS REGION,
    SUM(f.TOTAL_UNIT_SALES)              AS UNIDADES_VENDIDAS,
    SUM(f.TOTAL_VALUE_SALES)             AS VENTA_TOTAL
FROM dbo.FACT_SALES f
GROUP BY f.REGION
ORDER BY VENTA_TOTAL DESC;

-- Ventas por PERIODO (año y mes, usando el calendario)
SELECT
    c.YEAR                               AS ANIO,
    c.MONTH                              AS MES,
    SUM(f.TOTAL_UNIT_SALES)              AS UNIDADES_VENDIDAS,
    SUM(f.TOTAL_VALUE_SALES)             AS VENTA_TOTAL
FROM dbo.FACT_SALES f
JOIN dbo.DIM_CALENDAR c ON f.WEEK = c.WEEK
GROUP BY c.YEAR, c.MONTH
ORDER BY ANIO, MES;

-- Cruce completo: CATEGORÍA x REGIÓN x PERIODO (las 3 dimensiones pedidas)
SELECT
    cat.CATEGORY                         AS CATEGORIA,
    f.REGION                             AS REGION,
    c.YEAR                                AS ANIO,
    c.MONTH                               AS MES,
    SUM(f.TOTAL_UNIT_SALES)               AS UNIDADES_VENDIDAS,
    SUM(f.TOTAL_VALUE_SALES)              AS VENTA_TOTAL
FROM dbo.FACT_SALES f
JOIN dbo.DIM_PRODUCT p    ON f.ITEM_CODE = p.ITEM
JOIN dbo.DIM_CATEGORY cat ON p.CATEGORY   = cat.ID_CATEGORY
JOIN dbo.DIM_CALENDAR c   ON f.WEEK       = c.WEEK
GROUP BY cat.CATEGORY, f.REGION, c.YEAR, c.MONTH
ORDER BY ANIO, MES, VENTA_TOTAL DESC;

-- Top 10 productos por venta en valor (con marca y fabricante)
SELECT TOP 10
    p.ITEM                               AS CODIGO_PRODUCTO,
    p.BRAND                              AS MARCA,
    p.MANUFACTURER                       AS FABRICANTE,
    cat.CATEGORY                         AS CATEGORIA,
    SUM(f.TOTAL_VALUE_SALES)             AS VENTA_TOTAL
FROM dbo.FACT_SALES f
JOIN dbo.DIM_PRODUCT p    ON f.ITEM_CODE = p.ITEM
JOIN dbo.DIM_CATEGORY cat ON p.CATEGORY  = cat.ID_CATEGORY
GROUP BY p.ITEM, p.BRAND, p.MANUFACTURER, cat.CATEGORY
ORDER BY VENTA_TOTAL DESC;

-- Ventas por SEGMENTO (uniendo producto y segmento por sus atributos comunes)
SELECT
    s.SEGMENT                            AS SEGMENTO,
    SUM(f.TOTAL_UNIT_SALES)              AS UNIDADES_VENDIDAS,
    SUM(f.TOTAL_VALUE_SALES)             AS VENTA_TOTAL
FROM dbo.FACT_SALES f
JOIN dbo.DIM_PRODUCT p ON f.ITEM_CODE = p.ITEM
JOIN dbo.DIM_SEGMENT s
    ON  p.CATEGORY = s.CATEGORY
    AND p.ATTR1    = s.ATTR1
    AND p.ATTR2    = s.ATTR2
    AND p.ATTR3    = s.ATTR3
    AND p.[FORMAT] = s.[FORMAT]
GROUP BY s.SEGMENT
ORDER BY VENTA_TOTAL DESC;

-- Evolución semanal de venta total (para graficar tendencia)
SELECT
    c.[DATE]                             AS FECHA_SEMANA,
    c.WEEK                               AS SEMANA,
    SUM(f.TOTAL_VALUE_SALES)             AS VENTA_TOTAL
FROM dbo.FACT_SALES f
JOIN dbo.DIM_CALENDAR c ON f.WEEK = c.WEEK
GROUP BY c.[DATE], c.WEEK
ORDER BY c.[DATE];
