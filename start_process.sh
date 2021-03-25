#!/bin/bash
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
# copy by rule of area difference to removables table (use the AREA_RULE on options.sh to change this value)
execQuery "$COPY_TO_REMOVABLES"
# clean temporary table
execQuery "$DELETE_FROM_TMP"
# clean temporary intersection table
execQuery "$DELETE_FROM_INTER_TMP"
# make difference
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

# drop intermediate tables
ONLY_PRINT_SQL=true
execQuery "$DROP_TMPS"
