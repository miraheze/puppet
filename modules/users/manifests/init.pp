# class: user

class users(
    Variant[Array, String] $groups = [],
    Array[String] $always_groups = ['ops'],
) {
    $module_path = get_module_path($module_name)
    $data = loadyaml("${module_path}/data/data.yaml")
    $uinfo = $data['users']
    $users = keys($uinfo)

    # making sure to include always_groups
    $all_groups = concat($always_groups, $groups)

    # this custom function eliminates the need for virtual users
    $user_set = unique_users($data, $all_groups)

    users::hashgroup { $all_groups:
        phash  => $data,
        before => Users::Hashuser[$user_set],
    }

    users::hashuser { $user_set:
        phash  => $data,
        before => Users::Groupmembers[$all_groups],
    }

    users::groupmembers { $all_groups:
        phash => $data,
    }

    # Ensure ordering of resources
    Users::Hashuser<| |> -> Users::Groupmembers<| |>
}
