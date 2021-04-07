# Script MAIN option ==================================================

# If print mode is enabled, queries will not be executed
ONLY_PRINT_SQL=false

# To disable database backup change this to false. If print mode is enable, backup is disable by default
BACKUP_DB=true

# adjust buffer value to perform difference and intersection
# It's necessary to avoid the issues of st_intersection and st_difference
BUFFER="0.000000001"

# Area percentage rule for applying policies based on fractions of difference.
DIFF_RULE_1="0.95"
DIFF_RULE_2="0.3"