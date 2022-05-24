import importlib
mwd = importlib.import_module('deploy-mediawiki')


def test_non_zero_ec_only_one_zero() -> None:
    assert not mwd.non_zero_code([0], leave=False)


def test_non_zero_ec_multi_zero() -> None:
    assert not mwd.non_zero_code([0, 0], leave=False)


def test_non_zero_ec_zero_one() -> None:
    assert mwd.non_zero_code([1, 0], leave=False)


def test_non_zero_ec_one_one() -> None:
    assert mwd.non_zero_code([1, 1], leave=False)


def test_non_zero_ec_only_one_one() -> None:
    assert mwd.non_zero_code([1], leave=False)


def test_check_up_no_debug_host() -> None:
    failed = False
    try:
        mwd.check_up(nolog=True)
    except Exception as e:
        assert str(e) == 'Host or Debug must be specified'
        failed = True
    assert failed


def test_check_up_debug() -> None:
    assert mwd.check_up(nolog=True, Debug='mwtask111')


def test_get_staging_path() -> None:
    assert mwd._get_staging_path('world') == '/srv/mediawiki-staging/w/'


def test_get_deployed_path() -> None:
    assert mwd._get_deployed_path('world') == '/srv/mediawiki/w/'


def test_construct_rsync_no_location_local() -> None:
    failed = False
    try:
        mwd._construct_rsync_command(time=False, dest='/srv/mediawiki/w/')
    except Exception as e:
        assert str(e) == 'Location must be specified for local rsync.'
        failed = True
    assert failed


def test_construct_rsync_no_server_remote() -> None:
    failed = False
    try:
        mwd._construct_rsync_command(time=False, dest='/srv/mediawiki/w/', local=False)
    except Exception as e:
        assert str(e) == 'Error constructing command. Either server was missing or /srv/mediawiki/w/ != /srv/mediawiki/w/'
        failed = True
    assert failed


def test_construct_rsync_conflict_options_remote() -> None:
    failed = False
    try:
        mwd._construct_rsync_command(time=False, dest='/srv/mediawiki/w/', location='garbage', local=False, server='test')
    except Exception as e:
        assert str(e) == 'Error constructing command. Either server was missing or garbage != /srv/mediawiki/w/'
        failed = True
    assert failed


def test_construct_rsync_conflict_options_no_server_remote() -> None:
    failed = False
    try:
        mwd._construct_rsync_command(time=False, dest='/srv/mediawiki/w/', location='garbage', local=False)
    except Exception as e:
        assert str(e) == 'Error constructing command. Either server was missing or garbage != /srv/mediawiki/w/'
        failed = True
    assert failed


def test_construct_rsync_local_dir_update() -> None:
    assert mwd._construct_rsync_command(time=False, dest='/srv/mediawiki/w/', location='/home/') == 'sudo -u www-data rsync --update -r --delete --exclude=".*" /home/ /srv/mediawiki/w/'


def test_construct_rsync_local_file_update() -> None:
    assert mwd._construct_rsync_command(time=False, dest='/srv/mediawiki/w/test.txt', location='/home/test.txt', recursive=False) == 'sudo -u www-data rsync --update --exclude=".*" /home/test.txt /srv/mediawiki/w/test.txt'


def test_construct_rsync_remote_dir_update() -> None:
    assert mwd._construct_rsync_command(time=False, dest='/srv/mediawiki/w/', local=False, server='test') == 'sudo -u www-data rsync --update -r --delete -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/w/ www-data@test.miraheze.org:/srv/mediawiki/w/'


def test_construct_rsync_remote_file_update() -> None:
    assert mwd._construct_rsync_command(time=False, dest='/srv/mediawiki/w/test.txt', recursive=False, local=False, server='test') == 'sudo -u www-data rsync --update -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/w/test.txt www-data@test.miraheze.org:/srv/mediawiki/w/test.txt'


def test_construct_rsync_local_dir_time() -> None:
    assert mwd._construct_rsync_command(time=True, dest='/srv/mediawiki/w/', location='/home/') == 'sudo -u www-data rsync --inplace -r --delete --exclude=".*" /home/ /srv/mediawiki/w/'


def test_construct_rsync_local_file_time() -> None:
    assert mwd._construct_rsync_command(time=True, dest='/srv/mediawiki/w/test.txt', location='/home/test.txt', recursive=False) == 'sudo -u www-data rsync --inplace --exclude=".*" /home/test.txt /srv/mediawiki/w/test.txt'


def test_construct_rsync_remote_dir_time() -> None:
    assert mwd._construct_rsync_command(time=True, dest='/srv/mediawiki/w/', local=False, server='test') == 'sudo -u www-data rsync --inplace -r --delete -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/w/ www-data@test.miraheze.org:/srv/mediawiki/w/'


def test_construct_rsync_remote_file_time() -> None:
    assert mwd._construct_rsync_command(time=True, dest='/srv/mediawiki/w/test.txt', recursive=False, local=False, server='test') == 'sudo -u www-data rsync --inplace -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/w/test.txt www-data@test.miraheze.org:/srv/mediawiki/w/test.txt'


def test_construct_git_pull_sm() -> None:
    assert mwd._construct_git_pull('world', submodules=True) == 'sudo -u www-data git -C /srv/mediawiki-staging/w/ pull --recurse-submodules --quiet'


def test_construct_git_pull() -> None:
    assert mwd._construct_git_pull('config') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull  --quiet'


def test_construct_git_pull_branch() -> None:
    assert mwd._construct_git_pull('config', branch='myfunbranch') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --branch=myfunbranch --quiet'


def test_construct_git_pull_branch_sm() -> None:
    assert mwd._construct_git_pull('config', submodules=True, branch='test') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --recurse-submodules --branch=test --quiet'
