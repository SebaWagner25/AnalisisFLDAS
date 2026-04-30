#!/bin/bash
# Procesamiento CDO - Temperatura del aire cerca de la superficie (Tair_f_tavg)
# Uso: bash cdo/t.sh (correr desde la raíz del proyecto)

VAR="data/nc/t"

# 1. Renombrar coordenadas
cdo chname,x,lon,y,lat $VAR/temperatura.nc $VAR/t_coords.nc

# 2. Convertir unidades (Kelvin → °C)
cdo subc,273.15 $VAR/t_coords.nc $VAR/t_celsius.nc

# 3. Eliminar estaciones incompletas
cdo seldate,1982-03-01,2024-11-01 $VAR/t_celsius.nc $VAR/t_filtrado.nc

# 4. Media anual
cdo yearmean $VAR/t_celsius.nc $VAR/t_anual.nc

# 5. Media estacional por año
cdo seasmean $VAR/t_filtrado.nc $VAR/t_estacional.nc

# 6. Medias históricas por estación
cdo timmean -select,season=DJF $VAR/t_estacional.nc $VAR/t_verano.nc
cdo timmean -select,season=MAM $VAR/t_estacional.nc $VAR/t_otonio.nc
cdo timmean -select,season=JJA $VAR/t_estacional.nc $VAR/t_invierno.nc
cdo timmean -select,season=SON $VAR/t_estacional.nc $VAR/t_primavera.nc

# 7. Climatología mensual
cdo ymonmean $VAR/t_celsius.nc $VAR/t_mensual.nc

# Eliminar archivos intermedios
rm $VAR/t_coords.nc $VAR/t_filtrado.nc $VAR/t_estacional.nc

echo "Listo. Archivos generados en $VAR"
