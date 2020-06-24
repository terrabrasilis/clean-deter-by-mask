#!/bin/bash
# Loading DB main configurations
. ./db_main_conf.sh
. ./db_queries.sh

# Script defines =============================================
. ./script_defines.sh

# Script body ================================================
# backup database before proceed
backupDatabase

# unzip, import and clean deforestation data
importSHP $BASE_DIR $SHP_PRODES
execQuery "$TABLE_TO_CLEAN_MAKE_VALID"

if [ $IS_PRODUCTION = false ]; then
# Publication script body (terrabrasilis only) ===============
  # copy by date
  execQuery "$HIST_COPY_BY_DATE"
  # create tmp with intersection result
  execQuery "$HIST_CREATE_TMP"
  # delete by date
  execQuery "$DELETE_BY_DATE"
  # delete by intersect
  execQuery "$DELETE_BY_INTERSECT"

  # to send the result of intersection to history we should update the areas by LOIs (UF, MUN, UCs)
  echo "WARNING: miss send the result of intersection to history table"
  echo "Look for "$TABLE_TO_CLEAN"_inter_tmp"

else
# Script body production =====================================
  # delete by date
  execQuery "$DELETE_BY_DATE"
  # make difference
  execQuery "$DIFF_CREATE_TEMP"
  execQuery "$DIFF_CREATE"
  execQuery "$DIFF_FIX_GEOM_COL"
  execQuery "$DIFF_UPDATE_AREA"
  execQuery "$DIFF_DELETE_SMALLS"
  # delete by intersect
  execQuery "$DELETE_BY_INTERSECT"
  # send difference back to production table 
  execQuery "$COPY_DIFF"

fi
