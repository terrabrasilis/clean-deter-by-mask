# The first step to delete by date
# ==============================================================================
# apply make valid to prepare geometries of TABLE_TO_CLEAN table to vectorial operations
TABLE_TO_CLEAN_MAKE_VALID="UPDATE $TABLE_TO_CLEAN SET $GEOM_COLUMN=ST_MakeValid($GEOM_COLUMN) WHERE ST_IsValid($GEOM_COLUMN) = false;"
# create new table to put removable features using filter by date
REMOVABLE_TABLE="CREATE TABLE "$TABLE_TO_CLEAN"_removables AS "
REMOVABLE_TABLE=$REMOVABLE_TABLE"SELECT * FROM $TABLE_TO_CLEAN WHERE $DATE_COLUMN <= $PRODES_DATE_LIMIT;"
# delete features using filter by date
DELETE_BY_DATE="DELETE FROM $TABLE_TO_CLEAN WHERE $DATE_COLUMN <= $PRODES_DATE_LIMIT;"
# copy the feature candidates to the temporary table by intersects with PRODES mask
CREATE_TEMP_CANDIDATE="CREATE TABLE "$TABLE_TO_CLEAN"_tmp AS "
CREATE_TEMP_CANDIDATE=$CREATE_TEMP_CANDIDATE"SELECT a.* FROM $TABLE_TO_CLEAN as a "
CREATE_TEMP_CANDIDATE=$CREATE_TEMP_CANDIDATE"WHERE a.$TABLE_TO_CLEAN_KEY in ( "
CREATE_TEMP_CANDIDATE=$CREATE_TEMP_CANDIDATE"SELECT tb1.$TABLE_TO_CLEAN_KEY FROM "
CREATE_TEMP_CANDIDATE=$CREATE_TEMP_CANDIDATE"$TABLE_TO_CLEAN as tb1, $PRODES_TABLE as tb2 "
CREATE_TEMP_CANDIDATE=$CREATE_TEMP_CANDIDATE"WHERE ST_Intersects(tb1.$GEOM_COLUMN, tb2.geom));"

# Delete original feature candidates from TABLE_TO_CLEAN
DELETE_BY_INTERSECT="DELETE FROM $TABLE_TO_CLEAN as tb1 USING $PRODES_TABLE as tb2 "
DELETE_BY_INTERSECT=$DELETE_BY_INTERSECT"WHERE ST_Intersects(tb1.$GEOM_COLUMN, tb2.geom);"

# The second step to delete or keep by intersect and difference
# ==============================================================================
# separate the fractions of intersecting geometries between candidate alerts and mask.
INTER_CREATE="CREATE TABLE "$TABLE_TO_CLEAN"_inter_tmp AS ( "
INTER_CREATE=$INTER_CREATE" WITH inter_tmp AS ( "
INTER_CREATE=$INTER_CREATE" 	SELECT tb1.*, CASE WHEN ST_CoveredBy(tb1.$GEOM_COLUMN, tb2.geom)  THEN ST_Multi(ST_MakeValid(tb1.$GEOM_COLUMN))  "
INTER_CREATE=$INTER_CREATE" 	ELSE ST_Multi(ST_CollectionExtract(ST_Intersection(st_buffer(tb1.$GEOM_COLUMN,$BUFFER), st_buffer(tb2.geom,$BUFFER)), 3)) END AS geom_inter "
INTER_CREATE=$INTER_CREATE" 	FROM "$TABLE_TO_CLEAN"_tmp as tb1, $PRODES_TABLE as tb2 WHERE ST_Intersects(tb1.$GEOM_COLUMN, tb2.geom) "
INTER_CREATE=$INTER_CREATE" ), "
INTER_CREATE=$INTER_CREATE" inter_tmp_group AS ( "
INTER_CREATE=$INTER_CREATE" 	SELECT $TABLE_TO_CLEAN_KEY, ST_Multi(ST_CollectionExtract(ST_Collect(geom_inter),3)) as geom_inter FROM inter_tmp "
INTER_CREATE=$INTER_CREATE" 	GROUP BY $TABLE_TO_CLEAN_KEY "
INTER_CREATE=$INTER_CREATE" ) "
INTER_CREATE=$INTER_CREATE" SELECT b.*, a.geom_inter "
INTER_CREATE=$INTER_CREATE" FROM inter_tmp_group as a, "$TABLE_TO_CLEAN"_tmp as b "
INTER_CREATE=$INTER_CREATE" WHERE a.$TABLE_TO_CLEAN_KEY=b.$TABLE_TO_CLEAN_KEY "
INTER_CREATE=$INTER_CREATE" );"

# select removables in the temporary candidate table to remove from TABLE_TO_CLEAN
# when the difference between the total alert area and the area resulting from
# the intersection is less than or equal to AREA_RULE (start at 3ha)
SELECT_AREA_RULE="SELECT tmp.$TABLE_TO_CLEAN_KEY "
SELECT_AREA_RULE=$SELECT_AREA_RULE"FROM "$TABLE_TO_CLEAN"_inter_tmp as inter, "$TABLE_TO_CLEAN"_tmp as tmp "
SELECT_AREA_RULE=$SELECT_AREA_RULE"WHERE ( (ST_Area(inter.$GEOM_COLUMN::geography)/10000)-(ST_Area(inter.geom_inter::geography)/10000) )<=$AREA_RULE "
SELECT_AREA_RULE=$SELECT_AREA_RULE"AND inter.$TABLE_TO_CLEAN_KEY = tmp.$TABLE_TO_CLEAN_KEY"

# copy the removables by intersect from temporary candidate table to removables table
COPY_TO_REMOVABLES="WITH list_of_removables AS ($SELECT_AREA_RULE) "
COPY_TO_REMOVABLES=$COPY_TO_REMOVABLES"INSERT INTO "$TABLE_TO_CLEAN"_removables "
COPY_TO_REMOVABLES=$COPY_TO_REMOVABLES"SELECT * FROM "$TABLE_TO_CLEAN"_tmp as tmp "
COPY_TO_REMOVABLES=$COPY_TO_REMOVABLES"WHERE tmp.$TABLE_TO_CLEAN_KEY IN (SELECT * FROM list_of_removables);"

# delete the removables by intersect from temporary candidate table
DELETE_FROM_TMP="WITH list_of_removables AS ($SELECT_AREA_RULE) "
DELETE_FROM_TMP=$DELETE_FROM_TMP"DELETE FROM "$TABLE_TO_CLEAN"_tmp as tmp "
DELETE_FROM_TMP=$DELETE_FROM_TMP"WHERE tmp.$TABLE_TO_CLEAN_KEY IN (SELECT * FROM list_of_removables);"

# delete the removables by intersect from temporary intersection table
DELETE_FROM_INTER_TMP="WITH list_of_removables AS ($SELECT_AREA_RULE) "
DELETE_FROM_INTER_TMP=$DELETE_FROM_INTER_TMP"DELETE FROM "$TABLE_TO_CLEAN"_inter_tmp as tmp "
DELETE_FROM_INTER_TMP=$DELETE_FROM_INTER_TMP"WHERE tmp.$TABLE_TO_CLEAN_KEY IN (SELECT * FROM list_of_removables);"

# Make the difference between the temporary candidates table and temporary intersection table
DIFF_CREATE="CREATE TABLE "$TABLE_TO_CLEAN"_diff_tmp AS SELECT tmp.*, "
DIFF_CREATE=$DIFF_CREATE"ST_Multi(ST_CollectionExtract(ST_Difference(st_buffer(tmp.$GEOM_COLUMN,$BUFFER), st_buffer(inter.geom_inter,$BUFFER)), 3)) AS geom_diff "
DIFF_CREATE=$DIFF_CREATE"FROM "$TABLE_TO_CLEAN"_tmp as tmp, "$TABLE_TO_CLEAN"_inter_tmp as inter "
DIFF_CREATE=$DIFF_CREATE"WHERE tmp.$TABLE_TO_CLEAN_KEY = inter.$TABLE_TO_CLEAN_KEY;"

# delete old geometry column from temporary intersection table and rename the new geom_diff to original name
DIFF_FIX_GEOM_COL="ALTER TABLE "$TABLE_TO_CLEAN"_diff_tmp DROP COLUMN $GEOM_COLUMN;"
DIFF_FIX_GEOM_COL=$DIFF_FIX_GEOM_COL" ALTER TABLE "$TABLE_TO_CLEAN"_diff_tmp RENAME geom_diff TO $GEOM_COLUMN;"

# delete old geometry column from temporary difference table and rename the new geom_inter to original name
INTER_FIX_GEOM_COL="ALTER TABLE "$TABLE_TO_CLEAN"_inter_tmp DROP COLUMN $GEOM_COLUMN;"
INTER_FIX_GEOM_COL=$INTER_FIX_GEOM_COL" ALTER TABLE "$TABLE_TO_CLEAN"_inter_tmp RENAME geom_inter TO $GEOM_COLUMN;"

# the end: drop temporary tables.
DROP_TMPS="DROP TABLE "$TABLE_TO_CLEAN"_tmp;"
DROP_TMPS=$DROP_TMPS"DROP TABLE "$TABLE_TO_CLEAN"_diff_tmp;"
DROP_TMPS=$DROP_TMPS"DROP TABLE "$TABLE_TO_CLEAN"_inter_tmp;"