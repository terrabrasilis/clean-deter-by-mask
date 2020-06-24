# Script MAIN option ==================================================
# if the IS_PRODUCTION variable is true, the data will not be copied to the history table
IS_PRODUCTION=true # used on production database
#IS_PRODUCTION=false # used on publishing database

# If print mode is enabled, queries will not be executed
ONLY_PRINT_SQL=true

# To disable database backup change this to false. If print mode is enable, backup is disable by default
BACKUP_DB=true

# Script defines =============================================
export PGPASSWORD
PG_CON_BKP="-U $PG_USER -h $HOST -p $PG_PORT"
PG_CON="-d $PG_DATABASE $PG_CON_BKP"
PG_BIN="/usr/bin"
BASE_DIR=$(pwd)
ACT_DATE=$(date '+%d_%m_%y')
LOGFILE="$BASE_DIR/stack_trace_$ACT_DATE.log"
SQLFILE="$BASE_DIR/print_queries_$ACT_DATE.sql"

# Import functions ===========================================
. ./functions.lib.sh

# restart output files content
echo "" > "$SQLFILE" # clean SQL output file
echo "" > "$LOGFILE" # clean previous log file
