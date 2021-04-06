#!/bin/bash
# get start time
start=`date +%s`

# To Database configurations, edit the pgconfig or create it based on pgconfig.example
# Loading DB main configurations
. ./db_main_conf.sh
# Script MAIN option =========================================
. ./options.sh
# Script defines =============================================
. ./script_defines.sh
# Import functions ===========================================
. ./functions.lib.sh
# Import SQLs ================================================
. ./db_queries.sh

# Script body ================================================
# Use the BACKUP_DB on options.sh to change this behaviour
# backup database before proceed
backupDatabase

# Use the ONLY_PRINT_SQL on options.sh to change this behaviour
# unzip, import and clean deforestation data
#ONLY_PRINT_SQL=true
importSHP $BASE_DIR $SHP_PRODES
#ONLY_PRINT_SQL=false

# disable trigger
execQuery "$DISABLE_TRIGGER"
# make valid geometries into TABLE_TO_CLEAN
execQuery "$TABLE_TO_CLEAN_MAKE_VALID"
# new table with removables by date from TABLE_TO_CLEAN
execQuery "$REMOVABLE_TABLE"
# Delete removables by date from TABLE_TO_CLEAN
execQuery "$DELETE_BY_DATE"
# To apart the intersect data between TABLE_TO_CLEAN and PRODES_TABLE
execQuery "$CREATE_TEMP_CANDIDATE"
# Delete removable candidates by intersect from TABLE_TO_CLEAN
execQuery "$DELETE_BY_INTERSECT"

# make intersection with prodes
execQuery "$INTER_CREATE"
# make the difference between the original alerts and the intersection fractions.
execQuery "$DIFF_CREATE"

# -------------------------------------------------------
# These two steps are necessary to copy data between
# tables because the column names must be the same
# -------------------------------------------------------
# change column name to original name on difference table
execQuery "$DIFF_FIX_GEOM_COL"
# change column name to original name on intersection table
execQuery "$INTER_FIX_GEOM_COL"
# copy fraction by intersection to removables table
# and fractions by difference to production table
moveResultsToTargetTables
# -------------------------------------------------------
# enable trigger
execQuery "$ENABLE_TRIGGER"

# drop intermediate tables
# execQuery "$DROP_TMPS"

# print duration of script execution
end=`date +%s`
let deltatime=end-start
let hours=deltatime/3600
let minutes=(deltatime/60)%60
let seconds=deltatime%60
printf "Time spent: %d:%02d:%02d\n" $hours $minutes $second