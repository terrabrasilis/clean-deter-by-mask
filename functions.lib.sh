# Script functions ===================================================
backupDatabase(){
  if [[ $ONLY_PRINT_SQL = false ]] && [[ $BACKUP_DB = true ]]; then
    COMPRESSION="9"
    BACKUP_OPTIONS="$PG_CON -b -C -F c -Z $COMPRESSION"
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
    fi
  fi
}

# import shapefile
importSHP(){
  SHP_DIR=$1
  SHP_NAME=$2
  SHP_NAME_AND_DIR="$SHP_DIR/$SHP_NAME.zip"
  
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
      exit
    fi
  else
    echo "Print only is enable." >> $LOGFILE
  fi

  DELETE_UNUSED_CLASS="DELETE FROM $PRODES_TABLE WHERE class_name<>'d$CURRENT_PRODES_CLASS';"
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
  RENAME_GEOM_COL="ALTER TABLE "$PRODES_TABLE"_dumped RENAME geom_dump TO geom;"
  execQuery "$RENAME_GEOM_COL"
  RENAME_DUMP="ALTER TABLE "$PRODES_TABLE"_dumped TO "$PRODES_TABLE";"
  execQuery "$RENAME_DUMP"

  MAKE_VALID="UPDATE $PRODES_TABLE SET geom=ST_MakeValid(geom) WHERE ST_IsValid(geom) = false;"
  execQuery "$MAKE_VALID"
}