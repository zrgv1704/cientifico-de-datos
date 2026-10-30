En esta práctica, cargarás los datos en Python utilizando Pandas, realizarás la limpieza y transformación de los datos, y consolidarás la información en un conjunto de datos listo para el análisis.


Paso a paso:

Cargar las tablas de datos en Pandas:

    Utiliza la función de Pandas para cargar cada tabla de datos desde el archivo csv o xlsx (DIM_CATEGORY, DIM_PRODUCT, DIM_SEGMENT, DIM_CALENDAR, FACT_SALES) en un DataFrame.

       Revisar y entender los datos cargados:

    Realiza una revisión rápida de las primeras filas de cada DataFrame para entender la estructura de los datos y sus principales características. Utiliza métodos como head(), info() y describe() para tener una idea general del contenido de cada tabla.

Realizar la limpieza de datos:

    Corrige posibles inconsistencias en los datos, como errores tipográficos o formatos incorrectos.
    Identifica y maneja valores nulos en cada DataFrame (si es que los hay)
    Identifica si hay duplicados de los DataFrames y en caso de que los haya, eliminalos.

Unir los DataFrames relevantes:

    Realiza uniones entre los DataFrames para consolidar la información. Por ejemplo, une la tabla de productos con las ventas, las categorías y los segmentos.

Aplicar transformaciones necesarias:

    Estandariza los formatos de las columnas, como las fechas o categorías, para asegurar la consistencia en todo el conjunto de datos.
    Realiza cualquier transformación adicional requerida para preparar los datos para el análisis, como la creación de nuevas columnas calculadas o la agrupación de datos.

Guardar el conjunto de datos consolidado:

    Guarda el DataFrame consolidado en un nuevo archivo CSV o Excel para su uso posterior en el análisis.