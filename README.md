-- weekly -> dow in the year: calendar week
-- monthly -> start of the month: 01 of the month
-- yearly -> start of the year that is January 01
-- hourly -> current hour: 01:00:00

needs to adjust queries to start from pg_namespace

### Retention

If you don't need to keep data in older partitions, a retention system is available to automatically drop unneeded child partitions.
By default, they are only uninherited/detached not actually dropped, but that can be configured if desired.
There is also a method available to dump the tables out if they don't need to be in the database anymore but still need to be kept.
To set the retention policy, enter either an interval or integer value into the **retention** column of the **part_config** table.
For time-based partitioning, the interval value will set that any partitions containing only data older than that will be dropped
(including safely handling cases where the retention interval is not a multiple of the partition size). For id-based partitioning,
the integer value will set that any partitions with an id value less than the current maximum id value minus the retention value
will be dropped. For example, if the current max id is 100 and the retention value is 30,
any partitions with id values less than 70 will be dropped.
The current maximum id value at the time the drop function is run is always used.
Keep in mind that for subpartition sets, when a parent table has a child dropped,
if that child table is in turn partitioned, the drop is a CASCADE and ALL child tables down the entire inheritance tree
will be dropped. Also note that a partition set managed by pg_partman must always have at least one child,
so retention will never drop the last child table in a set.

-- Raise note about usage of to_char internally, any character that should not be transformed needs to be escaped with double quotes
internally we use to_char for formatting date/time in the generation of the partition names.

-- outstanding
1. tests for the bash scripts? call the program with the fixtures config and compare the outputs
2. update readme
