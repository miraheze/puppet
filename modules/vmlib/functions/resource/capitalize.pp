# SPDX-License-Identifier: Apache-2.0
# @summery ensure a resource is capitilised correctl
# @param resource
# @example "foo::bar".vmlib::resource_capitalize => Foo::Bar
function vmlib::resource::capitalize (
    VMlib::Resource::Type $resource,
) >> String[1] {
    $resource.split('::').capitalize.join('::')
}