#!/usr/bin/env python3
"""
Convierte archivos .tif de FLDAS a formato NetCDF (.nc)
Uso: python tiff_a_cdf.py --variable pp
Variables disponibles: pp, et, hs_0_10, hs_10_40, hs_40_100, hs_100_200
"""

import os
import argparse
import xarray as xr
import rioxarray
import pandas as pd
from glob import glob
import sys


# --- CONFIGURACIÓN DE VARIABLES ---
VARIABLES = {
    "pp": {
        "carpeta":  "FLDAS_Rainf_f_tavg_comp",
        "nombre_nc": "precipitacion"
    },
    "et": {
        "carpeta":  "FLDAS_Evap_tavg_comp",
        "nombre_nc": "evapotranspiracion"
    },
    "hs_0_10": {
        "carpeta":  "FLDAS_SoilMoi00_10cm_tavg_comp",
        "nombre_nc": "humedad_suelo_0_10"
    },
    "hs_10_40": {
        "carpeta":  "FLDAS_SoilMoi10_40cm_tavg_comp",
        "nombre_nc": "humedad_suelo_10_40"
    },
    "hs_40_100": {
        "carpeta":  "FLDAS_SoilMoi40_100cm_tavg_comp",
        "nombre_nc": "humedad_suelo_40_100"
    },
    "hs_100_200": {
        "carpeta":  "FLDAS_SoilMoi100_200cm_tavg_comp",
        "nombre_nc": "humedad_suelo_100_200"
    }
}

# --- ARGUMENTOS ---
parser = argparse.ArgumentParser(description="Convierte .tif de FLDAS a .nc")
parser.add_argument("--variable", required=True, choices=VARIABLES.keys(),
                    help="Variable a procesar: pp, et, hs_0_10, hs_10_40, hs_40_100, hs_100_200")
args = parser.parse_args()

# --- RUTAS ---
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
config          = VARIABLES[args.variable]
carpeta_entrada = os.path.join(ROOT, "data", config["carpeta"])
carpeta_salida  = os.path.join(ROOT, "data", "nc", args.variable)
nombre_nc       = config["nombre_nc"]
archivo_salida  = os.path.join(carpeta_salida, f"{nombre_nc}.nc")

os.makedirs(carpeta_salida, exist_ok=True)

# --- LISTAR ARCHIVOS ---
archivos_crudos = sorted(glob(os.path.join(carpeta_entrada, "*.tif*")))
archivos_tif = [f for f in archivos_crudos 
                if not f.endswith('.xml') and not f.endswith('.ovr')]

if not archivos_tif:
    print(f"Error: No se encontraron archivos .tif en {carpeta_entrada}")
    exit()

print(f"Variable: {args.variable}")
print(f"Archivos encontrados: {len(archivos_tif)}")
print(f"Archivo de salida: {archivo_salida}")

# --- FECHAS ---
fechas = pd.date_range(start="1982-01-01", periods=len(archivos_tif), freq="MS")

# --- PROCESAR ---
datasets = []

for i, archivo in enumerate(archivos_tif):
    try:
        ds = rioxarray.open_rasterio(archivo, masked=True, decode_times=False)
        ds = ds.squeeze(drop=True)

        if 'time' in ds.coords or 'time' in ds.dims:
            ds = ds.drop_vars('time', errors='ignore').drop_dims('time', errors='ignore')

        ds.name = nombre_nc
        ds = ds.expand_dims(time=[fechas[i]])
        datasets.append(ds)

        if (i + 1) % 12 == 0:
            print(f"   -> Procesado: {fechas[i].date()}")

    except Exception as e:
        print(f"Error en {os.path.basename(archivo)}: {e}")

# --- GUARDAR ---
if not datasets:
    print("CRÍTICO: No se procesó ningún archivo.")
else:
    print(f"Uniendo {len(datasets)} archivos...")
    try:
        ds_combinado = xr.concat(datasets, dim="time")
        encoding = {nombre_nc: {"zlib": True, "complevel": 5}}
        ds_combinado.to_netcdf(archivo_salida, encoding=encoding, engine='netcdf4')
        print(f"Guardado en: {archivo_salida}")
    except Exception as e:
        print(f"Error al guardar: {e}")