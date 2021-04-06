# Script functions ===================================================
backupDatabase(){
  if [[ $ONLY_PRINT_SQL = false ]] && [[ $BACKUP_DB = true ]]; then
    COMPRESSION="9"
    BACKUP_OPTIONS="$PG_CON_BKP -b -C -F c -Z $COMPRESSION"
    # backup
    echo $(date '+%c')" -- backing up database $PG_DATABASE" >> $LOGFILE
    if  $PG_BIN/pg_dump $BACKUP_OPTIONS -f $BASE_DIR/$PG_DATABASE-$ACT_DATE.backup $PG_DATABASE
      then
      echo "Database $PG_DATABASE backuped!" >> $LOGFILE
    else
      echo "Database $PG_DATABASE not backuped!" >> $LOGFILE
    fi
  else
    if [[ $BACKUP_DB = false ]]; then
      echo "To perform the backup, the BACKUP_DB option must be enabled." >> $LOGFILE
    else
      if [[ $ONLY_PRINT_SQL = true ]]; then
        echo "The backup is performed only if the print mode is disabled." >> $LOGFILE
      fi
    fi
  fi
}

execQuery(){
  PG_QUERY=$1
  
  echo "$PG_QUERY" >> "$SQLFILE"
  echo "" >> "$SQLFILE"
  
  if [ $ONLY_PRINT_SQL = false ]; then
    if $PG_BIN/psql $PG_CON -c """$PG_QUERY"""
    then
        echo "$PG_QUERY ... OK" >> $LOGFILE
    else
        echo "$PG_QUERY ... FAIL" >> $LOGFILE
        exit 1
    fi
  fi
}

moveResultsToTargetTables(){

  mountQueryCols(){
    SQL="WITH columns AS ( "
    SQL=$SQL"SELECT column_name "
    SQL=$SQL"FROM information_schema.columns "
    SQL=$SQL"WHERE table_name = '"$1"' ORDER  BY 1 "
    SQL=$SQL") "
    SQL=$SQL"SELECT string_agg(column_name, ', ') AS cols "
    SQL=$SQL"FROM columns"
    echo "$SQL"
  }

  mountQueryFractions(){
    # first parameter is class filter ("WHERE class_name IN ('MINERACAO','DESMATAMENTO_CR','DESMATAMENTO_VEG')")
    # second parameter unary operator (">","<",">=","<=")
    # third parameter is percent value operator (between 0 and 1)
    # fourth parameter is the SELECT or DELETE operation over temporary table
    # fifth parameter is the list of column names (col1, col2, col3...)
    SQL="WITH dumps AS ( "
    SQL=$SQL"  SELECT object_id, (st_dump(ogr_geometry)).geom as geom_dum "
    SQL=$SQL"  FROM "$TABLE_TO_CLEAN"_diff_tmp $1 "
    SQL=$SQL"), fractions AS ( "
    SQL=$SQL"  SELECT object_id, COUNT(*) as num_fractions, SUM(st_area(geom_dum::geography))/10000 as area "
    SQL=$SQL"  FROM dumps "
    SQL=$SQL"  GROUP BY 1 "
    SQL=$SQL"  ORDER BY 2 DESC "
    SQL=$SQL") "
    SQL=$SQL"$4 $5 FROM "$TABLE_TO_CLEAN"_tmp "
    SQL=$SQL"WHERE EXISTS( "
    SQL=$SQL"  SELECT object_id "
    SQL=$SQL"  FROM fractions "
    SQL=$SQL"  WHERE object_id="$TABLE_TO_CLEAN"_tmp.object_id "
    SQL=$SQL"  AND area $2 (st_area("$TABLE_TO_CLEAN"_tmp.ogr_geometry::geography)/10000)*$3 "
    SQL=$SQL")"
    echo "$SQL"
  }

  COLS_SQL=$(mountQueryCols "$TABLE_TO_CLEAN")
  # get table column to keep the column order
  TABLE_TO_CLEAN_COLS=$(getColumns "$COLS_SQL")

  # When the difference area is greater than or equal to 95% of the original alert.
  # ------------------------------------------------------------------------------------------
  # copy the alerts to the production table (sdr_alerta).
  INPUT_DATA=$(mountQueryFractions " " ">=" "$DIFF_RULE_1" "SELECT" "$TABLE_TO_CLEAN_COLS")
  RESTORE="INSERT INTO "$TABLE_TO_CLEAN" ($TABLE_TO_CLEAN_COLS) $INPUT_DATA"
  execQuery "$RESTORE"
  # delete the alerts of the temporary table (sdr_alerta_tmp).
  DELETE_FROM=$(mountQueryFractions " " ">=" "$DIFF_RULE_1" "DELETE" " ")
  execQuery "$DELETE_FROM"
  
  # When the difference area is less than or equal to 30% of the original alert.
  # ------------------------------------------------------------------------------------------
  # copy the alerts to the removables table (sdr_alerta_removables).
  INPUT_DATA=$(mountQueryFractions " " "<=" "$DIFF_RULE_2" "SELECT" "$TABLE_TO_CLEAN_COLS")
  REMOVABLES="INSERT INTO "$TABLE_TO_CLEAN"_removables ($TABLE_TO_CLEAN_COLS) $INPUT_DATA"
  execQuery "$REMOVABLES"
  # delete the alerts of the temporary table (sdr_alerta_tmp).
  DELETE_FROM=$(mountQueryFractions " " "<=" "$DIFF_RULE_2" "DELETE" " ")
  execQuery "$DELETE_FROM"

  # When the area of difference is greater than 30% of the original alert and it is deforestation.
  # ------------------------------------------------------------------------------------------
  # copy the alerts to the DETER mask table (sdr_alerta_mask_<year>).
  INPUT_DATA=$(mountQueryFractions "WHERE class_name IN ('MINERACAO','DESMATAMENTO_CR','DESMATAMENTO_VEG')" ">" "$DIFF_RULE_2" "SELECT" "$TABLE_TO_CLEAN_COLS")
  CREATE_MASK="CREATE TABLE $RESULT_MASK_TABLE AS $INPUT_DATA"
  execQuery "$CREATE_MASK"
  # delete the alerts of the temporary table (sdr_alerta_tmp).
  DELETE_FROM=$(mountQueryFractions "WHERE class_name IN ('MINERACAO','DESMATAMENTO_CR','DESMATAMENTO_VEG')" ">" "$DIFF_RULE_2" "DELETE" " ")
  execQuery "$DELETE_FROM"

  # When the area of difference is greater than 30% of the original alert and it is degradation.
  # ------------------------------------------------------------------------------------------
  # copy the alerts to the DETER production table (sdr_alerta).
  INPUT_DATA=$(mountQueryFractions "WHERE class_name NOT IN ('MINERACAO','DESMATAMENTO_CR','DESMATAMENTO_VEG')" ">" "$DIFF_RULE_2" "SELECT" "$TABLE_TO_CLEAN_COLS")
  RESTORE="INSERT INTO "$TABLE_TO_CLEAN" ($TABLE_TO_CLEAN_COLS) $INPUT_DATA"
  execQuery "$RESTORE"
  # delete the alerts of the temporary table (sdr_alerta_tmp).
  DELETE_FROM=$(mountQueryFractions "WHERE class_name NOT IN ('MINERACAO','DESMATAMENTO_CR','DESMATAMENTO_VEG')" ">" "$DIFF_RULE_2" "DELETE" " ")
  execQuery "$DELETE_FROM"

  # The remaining alerts in the temporary table are alerts covered by PRODES deforestation and will be moved to the removable table.
  # ------------------------------------------------------------------------------------------
  # copy the alerts to the removables table (sdr_alerta_removables).
  INPUT_DATA="SELECT $TABLE_TO_CLEAN_COLS FROM "$TABLE_TO_CLEAN"_tmp"
  REMOVABLES="INSERT INTO "$TABLE_TO_CLEAN"_removables ($TABLE_TO_CLEAN_COLS) $INPUT_DATA"
  execQuery "$REMOVABLES"
  # delete the alerts of the temporary table (sdr_alerta_tmp).
  DELETE_FROM="DELETE FROM "$TABLE_TO_CLEAN"_tmp"
  execQuery "$DELETE_FROM"
}

getColumns(){
  PG_QUERY=$1
  
  echo "$PG_QUERY" >> "$SQLFILE"
  echo "" >> "$SQLFILE"

  if [ $ONLY_PRINT_SQL = false ]; then
    DATA=$($PG_BIN/psql $PG_CON -t -c "$PG_QUERY")
    echo $DATA
  else
    echo "Print only is enable." >> $LOGFILE
  fi
}

# import shapefile
importSHP(){
  SHP_DIR=$1
  SHP_NAME=$2
  SHP_NAME_AND_DIR="$SHP_DIR/$SHP_NAME.zip"
  if [ ! -f "$SHP_NAME_AND_DIR" ]; then
    echo "The PRODES deforestation file is missing." >> $LOGFILE
    exit 1
  fi
  if [ $ONLY_PRINT_SQL = false ]; then
    unzip -o -d $SHP_DIR $SHP_NAME_AND_DIR
    SHP2PGSQL_OPTIONS="-c -s 4674:4674 -W 'LATIN1' -g geom"
    if $PG_BIN/shp2pgsql $SHP2PGSQL_OPTIONS $SHP_NAME_AND_DIR $PRODES_TABLE | $PG_BIN/psql $PG_CON
    then
      echo "Import ($SHP_NAME_AND_DIR) ... OK" >> $LOGFILE
      # SHP_NAME=`echo $SHP_NAME | cut -d "." -f 1` # to remove extension .zip from name of file
      rm $SHP_DIR/$SHP_NAME.{dbf,prj,shp,shx}
    else
      echo "Import ($SHP_NAME_AND_DIR) ... FAIL" >> $LOGFILE
      exit 1
    fi
  else
    echo "Print only is enable." >> $LOGFILE
  fi

  echo "=================================================" >> $LOGFILE
  echo "Perform changes over the deforestation mask table" >> $LOGFILE

  DELETE_UNUSED_CLASS="DELETE FROM $PRODES_TABLE WHERE class_name<>'d$CURRENT_PRODES_YEAR';"
  execQuery "$DELETE_UNUSED_CLASS"
  
  # remove small line-like polygons
  CREATE_DUMP="CREATE TABLE "$PRODES_TABLE"_dumped AS"
  CREATE_DUMP=$CREATE_DUMP" SELECT (st_dump(geom)).geom as geom_dump, *"
  CREATE_DUMP=$CREATE_DUMP" FROM "$PRODES_TABLE";"
  execQuery "$CREATE_DUMP"
  DELETE_SMALLS="DELETE FROM "$PRODES_TABLE"_dumped WHERE ST_AREA(geom_dump::geography)<=1;"
  execQuery "$DELETE_SMALLS"
  DROP_ORIGINAL="DROP TABLE "$PRODES_TABLE";"
  execQuery "$DROP_ORIGINAL"
  DISSOLVE="CREATE TABLE "$PRODES_TABLE"_dissolved AS "
  DISSOLVE=$DISSOLVE"SELECT class_name, ST_Union(f.geom_dump) as geom "
  DISSOLVE=$DISSOLVE"FROM "$PRODES_TABLE"_dumped f "
  DISSOLVE=$DISSOLVE"GROUP BY class_name;"
  execQuery "$DISSOLVE"
  DROP_DUMPED="DROP TABLE "$PRODES_TABLE"_dumped;"
  execQuery "$DROP_DUMPED"
  CREATE_FINAL="CREATE TABLE "$PRODES_TABLE" AS "
  CREATE_FINAL=$CREATE_FINAL"SELECT (ST_Dump(geom)).geom as geom, class_name "
  CREATE_FINAL=$CREATE_FINAL"FROM "$PRODES_TABLE"_dissolved;"
  execQuery "$CREATE_FINAL"
  DROP_DISSOLVED="DROP TABLE "$PRODES_TABLE"_dissolved;"
  execQuery "$DROP_DISSOLVED"
  MAKE_VALID="UPDATE $PRODES_TABLE SET geom=ST_MakeValid(geom) WHERE ST_IsValid(geom) = false;"
  execQuery "$MAKE_VALID"
  CREATE_INDEX="CREATE INDEX "$PRODES_TABLE"_geom_index ON $PRODES_TABLE USING gist (geom gist_geometry_ops_nd) TABLESPACE pg_default;"
  execQuery "$CREATE_INDEX"
  echo "=================================================" >> $LOGFILE
  echo "========== $PRODES_TABLE table is read ==========" >> $LOGFILE
  echo "=================================================" >> $LOGFILE
}