# @summary resolves every host with any of the given classes into a flat IP array
# @param classes a single class title, or an array of them (OR'd together)
function network::hosts_with_class(Variant[String[1], Array[String[1]]] $classes) >> Array[String[1]] {
    $class_list = $classes =~ Array ? { true => $classes, default => [$classes] }
    $conditions = $class_list.map |$title| { "resources { type = 'Class' and title = '${title}' }" }
    $pql = $conditions.join(' or ')

    vmlib::generate_firewall_ip($pql).split(' ').filter |$ip| { $ip != '' }
}
