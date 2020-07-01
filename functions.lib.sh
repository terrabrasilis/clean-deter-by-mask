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
    echo "The backup is performed only if the print mode is disabled." >> $LOGFILE
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

  COLS_SQL=$(mountQueryCols "$TABLE_TO_CLEAN")
  # get table column to keep the column order
  COLUMNS1=$(getColumns "$COLS_SQL")
  
  COLS_SQL=$(mountQueryCols "$TABLE_TO_CLEAN"_diff_tmp)
  # get table column to keep the column order
  COLUMNS2=$(getColumns "$COLS_SQL")

  # copy the fractions of difference to TABLE_TO_CLEAN
  INSERT_DIFFS="INSERT INTO "$TABLE_TO_CLEAN" ($COLUMNS1) SELECT $COLUMNS2 FROM "$TABLE_TO_CLEAN"_diff_tmp;"
  # copy diffs to production table
  execQuery "$INSERT_DIFFS"

  COLS_SQL=$(mountQueryCols "$TABLE_TO_CLEAN"_removables)
  # get table column to keep the column order
  COLUMNS1=$(getColumns "$COLS_SQL")
  
  COLS_SQL=$(mountQueryCols "$TABLE_TO_CLEAN"_inter_tmp)
  # get table column to keep the column order
  COLUMNS2=$(getColumns "$COLS_SQL")

  # copy the fractions of intersect to removables table
  INSERT_INTERS="INSERT INTO "$TABLE_TO_CLEAN"_removables ($COLUMNS1) SELECT $COLUMNS2 FROM "$TABLE_TO_CLEAN"_inter_tmp;"
  # copy intersections to removables table
  execQuery "$INSERT_INTERS"
}

getColumns(){
  PG_QUERY=$1
  
  echo "$PG_QUERY" >> "$SQLFILE"
  echo "" >> "$SQLFILE"

  if [ $ONLY_PRINT_SQL = false ]; then
    DATA=($($PG_BIN/psql $PG_CON -t -c "$PG_QUERY"))
    echo "$DATA"
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
  echo "=================================================" >> $LOGFILE
  echo "========== $PRODES_TABLE table is read ==========" >> $LOGFILE
  echo "=================================================" >> $LOGFILE
}