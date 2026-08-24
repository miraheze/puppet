# @summary
#   This class loads the default parameters by doing a hiera lookup.
#
# @param package_name
#
# @param service_name
#
# @param user
#
# @param group
#
# @param conf_dir
#
# @param mysql_db_schema
#
# @param pgsql_db_schema
#
class icingadb::globals (
  String[1]            $package_name,
  String[1]            $service_name,
  String[1]            $user,
  String[1]            $group,
  Stdlib::Absolutepath $conf_dir,
  Stdlib::Absolutepath $mysql_db_schema,
  Stdlib::Absolutepath $pgsql_db_schema,
) {
  $stdlib_version = load_module_metadata('stdlib')['version']
}
