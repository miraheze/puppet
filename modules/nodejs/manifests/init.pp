# class: nodejs
class nodejs {
    ensure_resource_duplicate('package', 'nodejs', {
        'ensure'   => installed,
    })
}
