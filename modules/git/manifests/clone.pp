# git::clone
#
# Allows cloning of any git repository in a file tree
#
# = Example
# git::clone { 'example':
#     directory => '/path/to/location/on/server',
#     origin => 'http://example/example.git',
#     branch => 'example2',
# }
#
define git::clone(
    $directory,
    $origin=undef,
    $branch='',
    $ssh='',
    $ensure='present',
    $owner='root',
    $group='root',
    $timeout='300',
    $depth='full',
    $recurse_submodules=false,
    $mode='0755',
    $umask='022',
) {

    case $ensure {
        'absent': {
            # make sure $directory does not exist
            file { $directory:
                ensure  => 'absent',
                recurse => true,
                force   => true,
            }
        }

        # otherwise clone the repository
        default: {
            $recurse_submodules_arg = $recurse_submodules ? {
                true    => '--recurse-submodules ',
                default => '',
            }
            # if branch was specified
            if !empty($branch) {
                $brancharg = "-b ${branch} "
            }
            # else don't checkout a non-default branch
            else {
                $brancharg = ''
            }
            if !empty($ssh) {
                $env = "GIT_SSH=${ssh}"
            } else {
                $env = undef
            }

            $deptharg = $depth ?  {
                'full'  => '',
                default => " --depth=${depth}"
            }

            $git = '/usr/bin/git'

            # clone the repository
            exec { "git_clone_${title}":
                command     => "${git} clone ${recurse_submodules_arg}${brancharg}${origin}${deptharg} ${directory}",
                provider    => shell,
                logoutput   => on_failure,
                cwd         => '/tmp',
                environment => $env,
                creates     => "${directory}/.git/config",
                user        => $owner,
                group       => $group,
                umask       => $umask,
                timeout     => $timeout,
                path        => '/usr/bin:/bin',
                require     => Package['git'],
            }

            if (!defined(File[$directory])) {
                file { $directory:
                    ensure => 'directory',
                    owner  => $owner,
                    group  => $group,
                    before => Exec["git_clone_${title}"],
                }
            }

            if !empty($branch) {
                if $ensure == 'latest' {
                    exec { "git_checkout_${title}":
                        cwd         => $directory,
                        command     => "${git} checkout ${branch}",
                        provider    => shell,
                        environment => $env,
                        unless      => "${git} rev-parse --abbrev-ref HEAD | grep ${branch}",
                        user        => $owner,
                        group       => $group,
                        umask       => $umask,
                        path        => '/usr/bin:/bin',
                        require     => Exec["git_clone_${title}"],
                        before      => Exec["git_pull_${title}"],
                    }
                } 
                else {
                    exec { "git_checkout_${title}":
                        cwd         => $directory,
                        command     => "${git} checkout ${branch}",
                        provider    => shell,
                        environment => $env,
                        unless      => "${git} rev-parse --abbrev-ref HEAD | grep ${branch}",
                        user        => $owner,
                        group       => $group,
                        umask       => $umask,
                        path        => '/usr/bin:/bin',
                        require     => Exec["git_clone_${title}"],
                    }
                }
            }


            # pull if $ensure == latest and if there are changes to merge in.
            if $ensure == 'latest' {
                exec { "git_pull_${title}":
                    cwd       => $directory,
                    command   => "${git} pull ${recurse_submodules_arg}--quiet${deptharg}",
                    provider  => shell,
                    logoutput => on_failure,
                    # git diff --quiet will exit 1 (return false)
                    #  if there are differences
                    unless    => "${git} fetch && /usr/bin/git diff --quiet remotes/origin/HEAD",
                    user      => $owner,
                    group     => $group,
                    umask     => $umask,
                    path      => '/usr/bin:/bin',
                    require   => Exec["git_clone_${title}"],
                }
                # If we want submodules up to date, then we need
                # to run git submodule update --init after
                # git pull is run.
                if $recurse_submodules {
                    exec { "git_submodule_update_${title}":
                        command     => "${git} submodule update --init --recursive",
                        provider    => shell,
                        cwd         => $directory,
                        environment => $env,
                        refreshonly => true,
                        user        => $owner,
                        group       => $group,
                        umask       => $umask,
                        path        => '/usr/bin:/bin',
                        subscribe   => Exec["git_pull_${title}"],
                    }
                }
            }

        }
    }
}
