# Script CONF option ==================================================
# To Database configurations, got to the pgconfig or create it based on pgconfig.example
if [ ! -f ./pgconfig ]; then
  cp ./pgconfig.example ./pgconfig
fi
. ./pgconfig

# year reference PRODES YYYY
CURRENT_PRODES_CLASS="2019"
# the name of ZIP file without extension
SHP_PRODES="yearly_deforestation"

# used to delete polygons of production table
# or move polygons from current to history table of terrabrasilis
PRODES_DATE_LIMIT="'$CURRENT_PRODES_CLASS-07-31'"
PRODES_TABLE="public."$SHP_PRODES"_"$CURRENT_PRODES_CLASS

# name of schema and table to clean
#TABLE_TO_CLEAN="terrabrasilis.deter_table" # DETER AMZ - TerraBrasilis
#TABLE_TO_CLEAN="terrabrasilis.deter_table" # DETER CERRADO - TerraBrasilis
TABLE_TO_CLEAN="public.sdr_alerta" # DETER AMZ - PRODUCTION
#TABLE_TO_CLEAN="public.sdr_alerta" # DETER CERRADO - PRODUCTION

# name of column to filter by PRODES date limit
#DATE_COLUMN="date" # DETER AMZ - TerraBrasilis
#DATE_COLUMN="date" # DETER CERRADO - TerraBrasilis
DATE_COLUMN="(data_img)::date" # DETER AMZ - PRODUCTION
#DATE_COLUMN="date" # DETER CERRADO - PRODUCTION

# name of geometry column of TABLE_TO_CLEAN
#GEOM_COLUMN="geom" # DETER AMZ - TerraBrasilis
#GEOM_COLUMN="geom" # DETER CERRADO - TerraBrasilis
GEOM_COLUMN="ogr_geometry" # DETER AMZ - PRODUCTION
#GEOM_COLUMN="geom" # DETER CERRADO - PRODUCTION

# name of area column of TABLE_TO_CLEAN
#AREA_COLUMN="area" # DETER AMZ - TerraBrasilis
#AREA_COLUMN="area" # DETER CERRADO - TerraBrasilis
AREA_COLUMN="area" # DETER AMZ - PRODUCTION
#AREA_COLUMN="area" # DETER CERRADO - PRODUCTION

# used to store the data that will be clean (terrabrasilis only)
HISTORY_TABLE="public.deter_history"
HISTORY_COLS="gid, classname, quadrant, orbitpoint, date, date_audit, lot, sensor, satellite, areatotalkm, areamunkm, areauckm, county, uf, uc, publish_month"
