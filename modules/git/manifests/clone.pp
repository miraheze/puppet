# git::clone
#
# Allows cloning of any git repository in a file tree
#
# = Example
# git::clone { 'example':
#     directory => '/path/to/location/on/server',
#     origin => 'http://example/example',
#     branch => 'example2',
# }
#
define git::clone(
    String  $directory,
    String  $origin = '',
    String  $branch = '',
    String  $revision = '',
    String  $ssh = '',
    String  $ensure = 'present',
    String  $owner = 'root',
    String  $group = 'root',
    String  $timeout = '600',
    String  $depth = 'full',
    Boolean $recurse_submodules = false,
    Boolean $shallow_submodules = false,
    String  $mode = '0755',
    String  $umask = '022',
    Boolean $allow_unrelated_histories = false,
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

            $shallow_submodules_arg = $shallow_submodules ? {
                true    => '--shallow-submodules ',
                default => '',
            }

            # if branch was specified
            if !empty($branch) {
                $brancharg = "-b ${branch} "
            } else {
                # else don't checkout a non-default branch
                $brancharg = ''
            }

            if !empty($ssh) {
                $env = "GIT_SSH_COMMAND=${ssh}"
            } else {
                $env = undef
            }

            $deptharg = $depth ?  {
                'full'  => '',
                default => " --depth=${depth}"
            }

            $allow_unrelated_histories_arg = $allow_unrelated_histories ?  {
                true    => '--allow-unrelated-histories',
                default => ''
            }

            $git = '/usr/bin/git'

            # clone the repository
            exec { "git_clone_${title}":
                command     => "${git} clone ${recurse_submodules_arg}${shallow_submodules_arg}${brancharg}${origin}${deptharg} ${allow_unrelated_histories_arg} ${directory}",
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

            if !empty($branch) or !empty($revision) {
                # Only unshallow when the repository is still shallow, because
                # git errors out when asked to unshallow a complete repository.
                $fetch_command = "if [ \"$(${git} rev-parse --is-shallow-repository)\" = true ]; then ${git} fetch --all --tags --unshallow; else ${git} fetch --all --tags; fi"
                # Fetch first so a new tag or branch is known before checking it out.
                $branch_fetch_command = "${git} fetch --all --tags${deptharg}"
                $submodule_command = $recurse_submodules ? {
                    true    => " && ${git} submodule update --init --recursive",
                    default => '',
                }
                $checkout_command = $revision ? {
                    ''      => "${branch_fetch_command} && ${git} checkout ${branch}${submodule_command}",
                    default => "${fetch_command} && ${git} checkout ${revision}${submodule_command}",
                }
                # A tag checkout is a detached HEAD, so also compare against the tags at HEAD.
                $is_current_revision = $revision ? {
                    ''      => "${git} rev-parse --abbrev-ref HEAD | grep -qxF ${branch} || ${git} tag --points-at HEAD | grep -qxF ${branch}",
                    default => "${git} rev-parse HEAD | grep -q ^${revision}",
                }
                if $ensure == 'latest' {
                    exec { "git_checkout_${title}":
                        cwd         => $directory,
                        command     => $checkout_command,
                        provider    => shell,
                        environment => $env,
                        unless      => $is_current_revision,
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
                        command     => $checkout_command,
                        provider    => shell,
                        environment => $env,
                        unless      => $is_current_revision,
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
                $remote_to_check = $branch ? {
                    ''      => 'remotes/origin/HEAD',
                    default => "remotes/origin/${branch}",
                }
                exec { "git_pull_${title}":
                    cwd         => $directory,
                    command     => "${git} pull ${recurse_submodules_arg}--quiet${deptharg} ${allow_unrelated_histories_arg}",
                    provider    => shell,
                    logoutput   => on_failure,
                    environment => $env,
                    # git diff --quiet will exit 1 (return false)
                    #  if there are differences
                    unless      => "${git} fetch && /usr/bin/git diff --quiet ${remote_to_check}",
                    user        => $owner,
                    group       => $group,
                    umask       => $umask,
                    path        => '/usr/bin:/bin',
                    require     => Exec["git_clone_${title}"],
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

            $revision_ensure = $revision ? {
                ''      => absent,
                default => present,
            }

            file { "${directory}/.git/hooks/post-merge":
                ensure  => $revision_ensure,
                content => "#!/bin/bash\n${git} reset --hard ${revision}\n",
                owner   => $owner,
                group   => $group,
                mode    => '0755',
            }
        }
    }
}
