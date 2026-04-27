#!/bin/bash
# Procesamiento CDO - Precipitación
# Uso: bash cdo/pp.sh (correr desde la raíz del proyecto)

VAR="data/nc/pp"

# 1. Renombrar coordenadas
cdo chname,x,lon,y,lat $VAR/precipitacion.nc $VAR/pp_coords.nc

# 2. Convertir unidades (kg/m²/s → mm/mes)
cdo mulc,86400 -muldpm $VAR/pp_coords.nc $VAR/pp_mm.nc

# 3. Eliminar estaciones incompletas
cdo seldate,1982-03-01,2024-11-01 $VAR/pp_mm.nc $VAR/pp_filtrado.nc

# 4. Acumulado anual
cdo yearsum $VAR/pp_mm.nc $VAR/pp_anual.nc

# 5. Acumulado estacional por año
cdo seassum $VAR/pp_filtrado.nc $VAR/pp_estacional.nc

# 6. Medias históricas por estación
cdo timmean -select,season=DJF $VAR/pp_estacional.nc $VAR/pp_verano.nc
cdo timmean -select,season=MAM $VAR/pp_estacional.nc $VAR/pp_otonio.nc
cdo timmean -select,season=JJA $VAR/pp_estacional.nc $VAR/pp_invierno.nc
cdo timmean -select,season=SON $VAR/pp_estacional.nc $VAR/pp_primavera.nc

# Eliminar archivos intermedios
rm $VAR/pp_coords.nc $VAR/pp_filtrado.nc $VAR/pp_estacional.nc

echo "Listo. Archivos generados en $VAR"