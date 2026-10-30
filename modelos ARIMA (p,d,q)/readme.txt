Como actividad de este módulo, vas analizar una serie de tiempo con datos históricos para ajustarla de forma óptima a un modelo Box-Jenkins ARIMA(p,d,q)

¡Buena suerte!

Paso a paso:

    Considera nuevamente la información histórica de temperaturas promedio por año para la ciudad de Nueva York en el período 1870 -2020.

    (disponibles en el sitio: https://github.com/JoseRaulCastro/EBAC/blob/main/TempNY.csv).

    Determina mediante la gráfica de prueba de Dickey-Fuller si los datos son estacionarios considerando una base de entrenamiento del 90% del total. En caso negativo, aplica tantas diferencias como sea necesario para alcanzar la estacionariedad y comenta al respecto.

    Obtén los parámetros óptimos mediante el índice de información de Akaike (a partir del resultado anterior), compara al menos 6 combinaciones diferentes de parámetros p, d y q en el modelo general ARIMA(p, d, q).

    Haz una gráfica (al resultado óptimo obtenido previamente) que incluya los datos de prueba, los de entrenamiento, y las predicciones puntuales y de intervalo para la base de prueba. 

    Responde a la pregunta: ¿Son confiables sus pronósticos? Justifica tu respuesta con los indicadores del error vistos en este curso.
