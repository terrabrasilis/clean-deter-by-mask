# Script SQLs (terrabrasilis only) ===================================
# Copy geometries by PRODES date limit direct to history table
HIST_COPY_BY_DATE="INSERT INTO $HISTORY_TABLE ($HISTORY_COLS,geom) SELECT $HISTORY_COLS,geom FROM $TABLE_TO_CLEAN WHERE $DATE_COLUMN <= $PRODES_DATE_LIMIT;"

# separate the fractions of intersecting geometries to calculate the areas by LOIs
HIST_CREATE_TMP="CREATE TABLE "$TABLE_TO_CLEAN"_inter_tmp AS"
HIST_CREATE_TMP=$HIST_CREATE_TMP" SELECT tb1.*, "
HIST_CREATE_TMP=$HIST_CREATE_TMP" CASE WHEN ST_CoveredBy(tb1.$GEOM_COLUMN, tb2.geom) "
HIST_CREATE_TMP=$HIST_CREATE_TMP" THEN ST_Multi(ST_MakeValid(tb1.$GEOM_COLUMN)) "
HIST_CREATE_TMP=$HIST_CREATE_TMP" ELSE ST_Multi(ST_CollectionExtract(ST_Intersection(tb1.$GEOM_COLUMN, tb2.geom), 3)) "
HIST_CREATE_TMP=$HIST_CREATE_TMP" END AS geom_inter FROM $TABLE_TO_CLEAN as tb1, "
HIST_CREATE_TMP=$HIST_CREATE_TMP" $PRODES_TABLE as tb2 WHERE ST_Intersects(tb1.$GEOM_COLUMN, tb2.geom);"

# Script SQLs ========================================================
TABLE_TO_CLEAN_MAKE_VALID="UPDATE $TABLE_TO_CLEAN SET $GEOM_COLUMN=ST_MakeValid($GEOM_COLUMN) WHERE ST_IsValid($GEOM_COLUMN) = false;"

DELETE_BY_DATE="DELETE FROM $TABLE_TO_CLEAN WHERE $DATE_COLUMN <= $PRODES_DATE_LIMIT;"

# to remove alerts from DIFF process, we use more than one step
# First: move the feature candidates to the temporary table
DIFF_CREATE_TEMP="CREATE TABLE "$TABLE_TO_CLEAN"_tmp AS SELECT tb1.* FROM $TABLE_TO_CLEAN as tb1, $PRODES_TABLE as tb2 WHERE ST_Intersects(tb1.$GEOM_COLUMN, tb2.geom);"

# Second: make the difference between the temporary table and prodes mask
DIFF_CREATE="CREATE TABLE "$TABLE_TO_CLEAN"_diff_tmp AS"
DIFF_CREATE=$DIFF_CREATE" SELECT * FROM "
DIFF_CREATE=$DIFF_CREATE" (SELECT tb1.*, "
DIFF_CREATE=$DIFF_CREATE" ST_Multi(ST_CollectionExtract(coalesce(st_difference(st_buffer(tb1.$GEOM_COLUMN,0.00001),st_buffer((SELECT ST_Multi(ST_CollectionExtract(st_union(b.geom), 3))::geometry(MultiPolygon,4674) as c_union from "
DIFF_CREATE=$DIFF_CREATE" "$PRODES_TABLE" as b where st_intersects(tb1.$GEOM_COLUMN, b.geom) ),0.00001) ), tb1.$GEOM_COLUMN), 3))::geometry(MultiPolygon,4674) AS geom_diff "
DIFF_CREATE=$DIFF_CREATE" FROM "$TABLE_TO_CLEAN"_tmp AS tb1 ) AS result "
DIFF_CREATE=$DIFF_CREATE" WHERE not st_isempty(result.geom_diff) and ST_GeometryType(result.geom_diff) in ('ST_Polygon','ST_MultiPolygon');"

# delete old geometry column and rename the new geom_diff to old name
DIFF_FIX_GEOM_COL="ALTER TABLE "$TABLE_TO_CLEAN"_diff_tmp DROP COLUMN $GEOM_COLUMN;"
DIFF_FIX_GEOM_COL=$DIFF_FIX_GEOM_COL" ALTER TABLE "$TABLE_TO_CLEAN"_diff_tmp RENAME geom_diff TO $GEOM_COLUMN;"

# Third: update areas and delete small polygons
DIFF_UPDATE_AREA="UPDATE "$TABLE_TO_CLEAN"_diff_tmp SET $AREA_COLUMN=ST_area($GEOM_COLUMN::geography)/1000000;"
DIFF_DELETE_SMALLS="DELETE FROM "$TABLE_TO_CLEAN"_diff_tmp WHERE $AREA_COLUMN<0.001 OR $AREA_COLUMN IS NULL;"

# fourth: delete originals features of TABLE_TO_CLEAN
DELETE_BY_INTERSECT="DELETE FROM $TABLE_TO_CLEAN as tb1 USING $PRODES_TABLE as tb2 WHERE ST_Intersects(tb1.$GEOM_COLUMN, tb2.geom);"

# Fifth: from the temporary table, copy the difference results to TABLE_TO_CLEAN (production only)
COPY_DIFF="INSERT INTO $TABLE_TO_CLEAN SELECT * FROM "$TABLE_TO_CLEAN"_diff_tmp;"

# the end: drop temporary table.
#DIFF_DROP_DIFF="DROP TABLE "$TABLE_TO_CLEAN"_tmp;"
#DIFF_DROP_DIFF="DROP TABLE "$TABLE_TO_CLEAN"_diff_tmp;"