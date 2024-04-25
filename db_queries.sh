# ==============================================================================
# The first step to delete by date
# ==============================================================================
# Materialize SQL View as main DETER table
CREATE_DETER_MAIN="CREATE TABLE "$TABLE_TO_CLEAN" AS SELECT * FROM public.sdr_alerta_view;"

# apply make valid to prepare geometries of TABLE_TO_CLEAN table to vectorial operations
TABLE_TO_CLEAN_MAKE_VALID="UPDATE $TABLE_TO_CLEAN SET $GEOM_COLUMN=ST_MakeValid($GEOM_COLUMN) WHERE ST_IsValid($GEOM_COLUMN) = false;"
# create new table to put removable features using filter by date
REMOVABLE_TABLE="CREATE TABLE "$TABLE_TO_CLEAN"_removables_$CURRENT_PRODES_YEAR AS "
REMOVABLE_TABLE=$REMOVABLE_TABLE"SELECT * FROM $TABLE_TO_CLEAN WHERE $DATE_COLUMN <= $PRODES_DATE_LIMIT;"
# delete features using filter by date
DELETE_BY_DATE="DELETE FROM $TABLE_TO_CLEAN WHERE $DATE_COLUMN <= $PRODES_DATE_LIMIT;"
# copy the feature candidates to the temporary table by intersects with PRODES mask
CREATE_TEMP_CANDIDATE="CREATE TABLE "$TABLE_TO_CLEAN"_tmp AS "
CREATE_TEMP_CANDIDATE=$CREATE_TEMP_CANDIDATE"SELECT a.* FROM $TABLE_TO_CLEAN as a "
CREATE_TEMP_CANDIDATE=$CREATE_TEMP_CANDIDATE"WHERE a.$TABLE_TO_CLEAN_KEY in ( "
CREATE_TEMP_CANDIDATE=$CREATE_TEMP_CANDIDATE"SELECT tb1.$TABLE_TO_CLEAN_KEY FROM "
CREATE_TEMP_CANDIDATE=$CREATE_TEMP_CANDIDATE"$TABLE_TO_CLEAN as tb1, $PRODES_TABLE as tb2 "
CREATE_TEMP_CANDIDATE=$CREATE_TEMP_CANDIDATE"WHERE (tb1.$GEOM_COLUMN && tb2.geom) AND ST_Intersects(st_buffer(tb1.$GEOM_COLUMN,-$BUFFER), tb2.geom));"

# Delete original feature candidates from TABLE_TO_CLEAN
DELETE_BY_INTERSECT="DELETE FROM $TABLE_TO_CLEAN as tb1 USING $PRODES_TABLE as tb2 "
DELETE_BY_INTERSECT=$DELETE_BY_INTERSECT"WHERE (tb1.$GEOM_COLUMN && tb2.geom) AND ST_Intersects(st_buffer(tb1.$GEOM_COLUMN,-$BUFFER), tb2.geom);"

# ==============================================================================
# The second step to delete or keep by intersect and difference
# ==============================================================================
# separate the fractions of intersecting geometries between candidate alerts and mask.
INTER_CREATE="CREATE TABLE "$TABLE_TO_CLEAN"_inter_tmp AS ( "
INTER_CREATE=$INTER_CREATE" WITH inter_tmp AS ( "
INTER_CREATE=$INTER_CREATE" 	SELECT tb1.*, CASE WHEN ST_CoveredBy(tb1.$GEOM_COLUMN, tb2.geom)  THEN ST_Multi(ST_MakeValid(tb1.$GEOM_COLUMN))  "
INTER_CREATE=$INTER_CREATE" 	ELSE ST_Multi(ST_CollectionExtract(ST_Intersection(st_buffer(tb1.$GEOM_COLUMN,$BUFFER), st_buffer(tb2.geom,$BUFFER)), 3)) END AS geom_inter "
INTER_CREATE=$INTER_CREATE" 	FROM "$TABLE_TO_CLEAN"_tmp as tb1, $PRODES_TABLE as tb2 WHERE (tb1.$GEOM_COLUMN && tb2.geom) AND ST_Intersects(tb1.$GEOM_COLUMN, tb2.geom) "
INTER_CREATE=$INTER_CREATE" ), "
INTER_CREATE=$INTER_CREATE" inter_tmp_group AS ( "
INTER_CREATE=$INTER_CREATE" 	SELECT $TABLE_TO_CLEAN_KEY, ST_Multi(ST_CollectionExtract(ST_Collect(geom_inter),3)) as geom_inter FROM inter_tmp "
INTER_CREATE=$INTER_CREATE" 	GROUP BY $TABLE_TO_CLEAN_KEY "
INTER_CREATE=$INTER_CREATE" ) "
INTER_CREATE=$INTER_CREATE" SELECT b.*, a.geom_inter "
INTER_CREATE=$INTER_CREATE" FROM inter_tmp_group as a, "$TABLE_TO_CLEAN"_tmp as b "
INTER_CREATE=$INTER_CREATE" WHERE a.$TABLE_TO_CLEAN_KEY=b.$TABLE_TO_CLEAN_KEY "
INTER_CREATE=$INTER_CREATE" );"

# Make the difference between the temporary candidates table and temporary intersection table
DIFF_CREATE="CREATE TABLE "$TABLE_TO_CLEAN"_diff_tmp AS SELECT tmp.*, "
DIFF_CREATE=$DIFF_CREATE"ST_Multi(ST_CollectionExtract(ST_Difference(st_buffer(tmp.$GEOM_COLUMN,$BUFFER), "
DIFF_CREATE=$DIFF_CREATE"st_buffer(inter.geom_inter,$BUFFER)), 3)) AS geom_diff "
DIFF_CREATE=$DIFF_CREATE"FROM "$TABLE_TO_CLEAN"_tmp as tmp, "$TABLE_TO_CLEAN"_inter_tmp as inter "
DIFF_CREATE=$DIFF_CREATE"WHERE tmp.$TABLE_TO_CLEAN_KEY = inter.$TABLE_TO_CLEAN_KEY;"

# delete old geometry column from temporary intersection table and rename the new geom_diff to original name
DIFF_FIX_GEOM_COL="ALTER TABLE "$TABLE_TO_CLEAN"_diff_tmp DROP COLUMN $GEOM_COLUMN;"
DIFF_FIX_GEOM_COL=$DIFF_FIX_GEOM_COL" ALTER TABLE "$TABLE_TO_CLEAN"_diff_tmp RENAME geom_diff TO $GEOM_COLUMN;"

# delete old geometry column from temporary difference table and rename the new geom_inter to original name
INTER_FIX_GEOM_COL="ALTER TABLE "$TABLE_TO_CLEAN"_inter_tmp DROP COLUMN $GEOM_COLUMN;"
INTER_FIX_GEOM_COL=$INTER_FIX_GEOM_COL" ALTER TABLE "$TABLE_TO_CLEAN"_inter_tmp RENAME geom_inter TO $GEOM_COLUMN;"

# ==============================================================================
# The third step to delete from final deter tables
# ==============================================================================
# delete all degradations from sdr_alerta
DELETE_DEGRAD_ON_FINAL="DELETE FROM $DETER_ORIGINAL_TABLE WHERE uuid NOT IN (SELECT uuid FROM $TABLE_TO_CLEAN);"
# delete all degradations from sdr_alerta_deforestation_mask
DELETE_DEFORE_ON_FINAL="DELETE FROM "$DETER_ORIGINAL_TABLE"_deforestation_mask WHERE uuid NOT IN (SELECT uuid FROM $TABLE_TO_CLEAN);"

# ==============================================================================
# The last step to drop temporary tables
# ==============================================================================
# the end: drop temporary tables.
DROP_TMPS="DROP TABLE "$TABLE_TO_CLEAN"_tmp;"
DROP_TMPS=$DROP_TMPS" DROP TABLE "$TABLE_TO_CLEAN"_diff_tmp;"
DROP_TMPS=$DROP_TMPS" DROP TABLE "$TABLE_TO_CLEAN"_inter_tmp;"
DROP_TMPS=$DROP_TMPS" DROP TABLE "$TABLE_TO_CLEAN";"

# auxiliar SQLs
DISABLE_TRIGGERS="ALTER TABLE $DETER_ORIGINAL_TABLE DISABLE TRIGGER add_uuid_sdr_alerta;"
DISABLE_TRIGGERS=$DISABLE_TRIGGERS" ALTER TABLE $DETER_ORIGINAL_TABLE DISABLE TRIGGER copy_degradations_removed;"
DISABLE_TRIGGERS=$DISABLE_TRIGGERS" ALTER TABLE $DETER_ORIGINAL_TABLE DISABLE TRIGGER copy_new_degradation_on_insert;"
DISABLE_TRIGGERS=$DISABLE_TRIGGERS" ALTER TABLE $DETER_ORIGINAL_TABLE DISABLE TRIGGER copy_new_degradation_on_update;"
DISABLE_TRIGGERS=$DISABLE_TRIGGERS" ALTER TABLE $DETER_ORIGINAL_TABLE DISABLE TRIGGER move_audited_deforestations;"

ENABLE_TRIGGERS="ALTER TABLE $DETER_ORIGINAL_TABLE ENABLE TRIGGER add_uuid_sdr_alerta;"
ENABLE_TRIGGERS=$ENABLE_TRIGGERS" ALTER TABLE $DETER_ORIGINAL_TABLE ENABLE TRIGGER copy_degradations_removed;"
ENABLE_TRIGGERS=$ENABLE_TRIGGERS" ALTER TABLE $DETER_ORIGINAL_TABLE ENABLE TRIGGER copy_new_degradation_on_insert;"
ENABLE_TRIGGERS=$ENABLE_TRIGGERS" ALTER TABLE $DETER_ORIGINAL_TABLE ENABLE TRIGGER copy_new_degradation_on_update;"
ENABLE_TRIGGERS=$ENABLE_TRIGGERS" ALTER TABLE $DETER_ORIGINAL_TABLE ENABLE TRIGGER move_audited_deforestations;"