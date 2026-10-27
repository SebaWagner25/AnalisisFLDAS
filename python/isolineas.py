#!/usr/bin/env python3
"""
Mapas con isolíneas a partir de los NetCDF procesados con CDO (paso 5).
Uso (correr desde la raíz del proyecto, después de cdo/<variable>.sh):
    python python/isolineas.py --variable pp
    python python/isolineas.py --variable pp et t ts      (varias a la vez)
Variables disponibles: pp, et, t, ts, ts_10_40, ts_40_100, ts_100_200,
                       hs_0_10, hs_10_40, hs_40_100, hs_100_200

Por cada variable guarda en output/mapas/isolineas/<variable>/:
    estacion_verano.png ... estacion_primavera.png   media histórica de cada estación del año
    anual_media.png                                   media de todos los años
    anual_AAAA.png                                    un mapa por año
Las 4 estaciones comparten la escala de colores, y los mapas anuales también,
para que se puedan comparar entre sí.
"""

import os
import argparse
import xarray as xr
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import cartopy.crs as ccrs
import cartopy.io.shapereader as shpreader
from shapely.geometry import box


# --- CONFIGURACIÓN ---
# Unidades de los archivos que deja CDO, título y paleta de colores de cada variable
# (las unidades guardadas dentro de los .nc son las originales de FLDAS, por eso se ponen acá)
VARIABLES = {
    #  variable      título                                  unidad estacional  unidad anual  paleta
    "pp":         ("Precipitación",                          "mm/estación",     "mm/año",     "GnBu"),
    "et":         ("Evapotranspiración",                     "mm/estación",     "mm/año",     "YlGn"),
    "t":          ("Temperatura del aire",                   "°C",              "°C",         "RdYlBu_r"),
    "ts":         ("Temperatura de suelo 0-10 cm",           "°C",              "°C",         "RdYlBu_r"),
    "ts_10_40":   ("Temperatura de suelo 10-40 cm",          "°C",              "°C",         "RdYlBu_r"),
    "ts_40_100":  ("Temperatura de suelo 40-100 cm",         "°C",              "°C",         "RdYlBu_r"),
    "ts_100_200": ("Temperatura de suelo 100-200 cm",        "°C",              "°C",         "RdYlBu_r"),
    "hs_0_10":    ("Humedad de suelo 0-10 cm",               "m³/m³",           "m³/m³",      "YlGnBu"),
    "hs_10_40":   ("Humedad de suelo 10-40 cm",              "m³/m³",           "m³/m³",      "YlGnBu"),
    "hs_40_100":  ("Humedad de suelo 40-100 cm",             "m³/m³",           "m³/m³",      "YlGnBu"),
    "hs_100_200": ("Humedad de suelo 100-200 cm",            "m³/m³",           "m³/m³",      "YlGnBu"),
}

ESTACIONES = {"verano": "Verano", "otonio": "Otoño", "invierno": "Invierno", "primavera": "Primavera"}

# Zona del mapa (lon mín, lon máx, lat mín, lat máx)
EXTENSION = [-67.5, -64.8, -36.1, -31.7]

# Límites políticos (shapefiles en data/shp/; si no están, el mapa se hace igual sin ellos)
#   archivo                          grosor de línea
SHAPEFILES = [
    ("data/shp/departamento.shp",    0.3),
    ("data/shp/provincia.shp",       1.0),
]


# --- FUNCIONES ---
def leer_limites():
    """Lee los shapefiles UNA sola vez y se queda solo con la parte dentro de la
    zona del mapa (son de todo el país y muy pesados; dibujarlos enteros en cada
    mapa hace que el script sea muy lento)."""
    zona = box(EXTENSION[0] - 1, EXTENSION[2] - 1, EXTENSION[1] + 1, EXTENSION[3] + 1)
    limites = []
    for shp, grosor in SHAPEFILES:
        if not os.path.exists(shp):
            print(f"ATENCIÓN: no se encontró {shp} -> los mapas se hacen sin esos límites")
            continue
        geometrias = [g.intersection(zona) for g in shpreader.Reader(shp).geometries()
                      if g.intersects(zona)]
        limites.append((geometrias, grosor))
    return limites


def leer(variable, periodo):
    """Lee data/nc/<variable>/<variable>_<periodo>.nc y devuelve el campo (tiempo, lat, lon)."""
    ds = xr.open_dataset(f"data/nc/{variable}/{variable}_{periodo}.nc")
    nombre = [v for v in ds.data_vars if "lat" in ds[v].dims][0]   # saltea time_bnds
    return ds[nombre]


def niveles(campos):
    """Niveles comunes a todos los mapas de un grupo: ~10 para los colores
    y el doble para las isolíneas."""
    minimo = min(float(c.min()) for c in campos)
    maximo = max(float(c.max()) for c in campos)
    colores = mticker.MaxNLocator(10).tick_values(minimo, maximo)
    lineas = mticker.MaxNLocator(20).tick_values(minimo, maximo)
    return colores, lineas


def mapa(campo, titulo, unidad, paleta, niv, archivo):
    """Un mapa: colores rellenos + isolíneas con su valor + límites políticos."""
    niv_colores, niv_lineas = niv
    fig = plt.figure(figsize=(8, 9))
    ax = plt.axes(projection=ccrs.PlateCarree())
    ax.set_extent(EXTENSION, crs=ccrs.PlateCarree())

    relleno = ax.contourf(campo.lon, campo.lat, campo, levels=niv_colores,
                          cmap=paleta, extend="both", transform=ccrs.PlateCarree())
    lineas = ax.contour(campo.lon, campo.lat, campo, levels=niv_lineas,
                        colors="darkslategray", linewidths=0.5, transform=ccrs.PlateCarree())
    ax.clabel(lineas, inline=True, fontsize=8, fmt="%g")

    for geometrias, grosor in LIMITES:
        ax.add_geometries(geometrias, ccrs.PlateCarree(),
                          edgecolor="black", facecolor="none", linewidth=grosor)

    grilla = ax.gridlines(draw_labels=True, linewidth=0.5, color="gray", alpha=0.5, linestyle="--")
    grilla.xlocator = mticker.FixedLocator(range(-68, -64))
    grilla.ylocator = mticker.FixedLocator(range(-36, -31))
    grilla.top_labels = grilla.right_labels = False

    plt.colorbar(relleno, ax=ax, shrink=0.8, label=unidad)
    plt.title(titulo, fontweight="bold")
    fig.savefig(archivo, dpi=150, bbox_inches="tight")
    plt.close(fig)


def isolineas(variable):
    titulo, unidad_est, unidad_anual, paleta = VARIABLES[variable]
    salida = f"output/mapas/isolineas/{variable}"
    os.makedirs(salida, exist_ok=True)
    print(f"=== {titulo} ===")

    # 1. Media histórica de cada estación del año (misma escala para las 4)
    estaciones = {e: leer(variable, e).isel(time=0) for e in ESTACIONES}
    niv = niveles(estaciones.values())
    for e, campo in estaciones.items():
        mapa(campo, f"{titulo} - {ESTACIONES[e]}", unidad_est, paleta, niv,
             f"{salida}/estacion_{e}.png")

    # 2. Media de todos los años y un mapa por año (misma escala para todos)
    anual = leer(variable, "anual")
    media = anual.mean("time")
    mapa(media, f"{titulo} - Media anual", unidad_anual, paleta, niveles([media]),
         f"{salida}/anual_media.png")

    niv = niveles([anual])
    for anio, campo in zip(anual.time.dt.year.values, anual):
        mapa(campo, f"{titulo} - {anio}", unidad_anual, paleta, niv,
             f"{salida}/anual_{anio}.png")

    print(f"  Listo. Mapas en {salida}")


# --- PROGRAMA PRINCIPAL ---
parser = argparse.ArgumentParser(description="Mapas con isolíneas de los NetCDF de CDO")
parser.add_argument("--variable", required=True, nargs="+", choices=VARIABLES.keys(),
                    help="Una o más variables: " + ", ".join(VARIABLES))
args = parser.parse_args()

LIMITES = leer_limites()

for variable in args.variable:
    isolineas(variable)
