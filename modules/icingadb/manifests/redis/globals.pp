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
# @param redis_bin
#
# @param conf_dir
#
# @param work_dir
#
# @param run_dir
#
# @param log_dir
#
class icingadb::redis::globals (
  String[1]            $package_name,
  String[1]            $service_name,
  String[1]            $user,
  String[1]            $group,
  Stdlib::Absolutepath $redis_bin,
  Stdlib::Absolutepath $conf_dir,
  Stdlib::Absolutepath $work_dir,
  Stdlib::Absolutepath $run_dir,
  Stdlib::Absolutepath $log_dir,
) {
}
