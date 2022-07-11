# Script CONF option ==================================================
# To Database configurations, edit the pgconfig or create it based on pgconfig.example
if [ ! -f ./pgconfig ]; then
  cp ./pgconfig.example ./pgconfig
fi
. ./pgconfig

# year reference PRODES YYYY
CURRENT_PRODES_YEAR="2021"
# the name of ZIP file without extension
SHP_PRODES="yearly_deforestation"

# used to delete polygons of production table
# or move polygons from current to history table of terrabrasilis
PRODES_DATE_LIMIT="'$CURRENT_PRODES_YEAR-07-31'"
PRODES_TABLE=$SHP_PRODES"_"$CURRENT_PRODES_YEAR

# name of schema and table to clean
TABLE_TO_CLEAN="deter" # FM - PRODUCTION
#TABLE_TO_CLEAN="sdr_alerta" # DETER AMZ - PRODUCTION
#TABLE_TO_CLEAN="sdr_alerta" # DETER CERRADO - PRODUCTION

# name of column used to mark rows as removable
TABLE_TO_CLEAN_KEY="id" # FM - PRODUCTION
#TABLE_TO_CLEAN_KEY="object_id" # DETER AMZ - PRODUCTION
#TABLE_TO_CLEAN_KEY="object_id" # DETER CERRADO - PRODUCTION

# name of column to filter by PRODES date limit
DATE_COLUMN="(image_date)::date" # FM - PRODUCTION
#DATE_COLUMN="(data_img)::date" # DETER AMZ - PRODUCTION
#DATE_COLUMN="date" # DETER CERRADO - PRODUCTION

# name of geometry column of TABLE_TO_CLEAN
GEOM_COLUMN="geom" # FM - PRODUCTION
#GEOM_COLUMN="ogr_geometry" # DETER AMZ - PRODUCTION
#GEOM_COLUMN="geom" # DETER CERRADO - PRODUCTION

# name of area column of TABLE_TO_CLEAN
AREA_COLUMN="areatotalk" # FM - PRODUCTION
#AREA_COLUMN="area" # DETER AMZ - PRODUCTION
#AREA_COLUMN="area" # DETER CERRADO - PRODUCTION

# name of "class name" column of TABLE_TO_CLEAN
CLASSNAME_COLUMN="classname" # FM - PRODUCTION
#CLASSNAME_COLUMN="class_name" # DETER AMZ - PRODUCTION
#CLASSNAME_COLUMN="class_name" # DETER CERRADO - PRODUCTION

# the result table to use as a mask into production
RESULT_MASK_TABLE=$TABLE_TO_CLEAN"_mask_"$CURRENT_PRODES_YEAR

# used to store the data that will be clean (terrabrasilis only)
HISTORY_TABLE="deter_history"
HISTORY_COLS="gid, classname, quadrant, orbitpoint, date, date_audit, lot, sensor, satellite, areatotalkm, areamunkm, areauckm, county, uf, uc, publish_month"
