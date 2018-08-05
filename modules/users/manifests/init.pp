# Creates groups, users, and sudo permissions all from yaml for valid passed group name
#
# === Parameters
#
# [*$groups*]
#  Array of valid groups (defined in yaml) to create with associated members
#
# [*$always_groups*]
#  Array of valid groups to always run
#

class users(
    $groups=[],
    $always_groups=['absent', 'ops'],
)
{
    include ::sudo

    $module_path = get_module_path($module_name)
    $base_data = loadyaml("${module_path}/data/data.yaml")
    # Fill the all-users group with all active users
    $data = add_all_users($base_data)

    $uinfo = $data['users']
    $users = keys($uinfo)

    #making sure to include always_groups
    $all_groups = concat($always_groups, $groups)

    #this custom function eliminates the need for virtual users
    $user_set = unique_users($data, $all_groups)

    users::hashgroup { $all_groups:
        before => Users::Hashuser[$user_set],
    }

    users::hashuser { $user_set:
        before => Users::Groupmembers[$all_groups],
    }

    users::groupmembers { $all_groups: }
}
