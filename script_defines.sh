# Script defines =============================================
export PGPASSWORD
PG_CON_BKP="-U $PG_USER -h $HOST -p $PG_PORT"
PG_CON="-d $PG_DATABASE $PG_CON_BKP"
PG_BIN="/usr/local/bin"
BASE_DIR=$(pwd)
ACT_DATE=$(date '+%d_%m_%y')
LOGFILE="$BASE_DIR/stack_trace_$ACT_DATE.log"
SQLFILE="$BASE_DIR/print_queries_$ACT_DATE.sql"

# restart output files content
echo "" > "$SQLFILE" # clean SQL output file
echo "" > "$LOGFILE" # clean previous log file
