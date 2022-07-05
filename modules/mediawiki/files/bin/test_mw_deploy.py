import argparse
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


def test_check_up_debug_fail() -> None:
    assert not mwd.check_up(nolog=True, Debug='mwtask111', domain='httpstat.us/500', force=True)


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
    assert mwd._construct_git_pull('config') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --quiet'


def test_construct_git_pull_branch() -> None:
    assert mwd._construct_git_pull('config', branch='myfunbranch') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull origin myfunbranch --quiet'


def test_construct_git_pull_branch_sm() -> None:
    assert mwd._construct_git_pull('config', submodules=True, branch='test') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --recurse-submodules origin test --quiet'


def test_get_command_array() -> None:
    assert mwd.get_command_array('sudo -u www-data echo test') == ['sudo', '-u www-data echo test']


def test_run_command() -> None:
    assert mwd.run_command('echo test') == 0


def test_batched_command() -> None:
    assert mwd.run_batch_command(['echo test 1', 'echo test 2'], 'testrun', []) == [0, 0]


def test_get_envinfo() -> None:
    assert mwd.get_environment_info() == {
        'servers':
        [
            'mw101',
            'mw102',
            'mw111',
            'mw112',
            'mw121',
            'mw122',
            'mwtask111',
        ],
        'wikidbname': 'testwiki',
        'wikiurl': 'publictestwiki.com',
    }


def test_get_servers_all() -> None:
    assert mwd.get_server_list(mwd.get_environment_info(), 'all') == [
        'mw101',
        'mw102',
        'mw111',
        'mw112',
        'mw121',
        'mw122',
        'mwtask111',
    ]


def test_get_servers_two() -> None:
    assert mwd.get_server_list(mwd.get_environment_info(), 'mw101,mw111') == ['mw101', 'mw111']


def test_prep() -> None:
    parser = argparse.ArgumentParser()
    args, unknown = parser.parse_known_args()
    del unknown
    args.servers = 'all'
    args.config = False
    args.world = False
    args.landing = False
    args.errorpages = False
    args.files = ''
    args.folders = ''
    args.extensionlist = False
    args.l10n = False
    args.nolog = True
    args.force = False
    args.port = 443
    args.ignoretime = False
    args.pull = False
    args.branch = False
    assert mwd.prep(args) == {'servers': ['mw101', 'mw102', 'mw111', 'mw112', 'mw121', 'mw122', 'mwtask111'], 'doworld': False, 'loginfo': {'servers': 'all', 'files': '', 'folders': '', 'nolog': True, 'port': 443}, 'branch': '', 'nolog': True, 'force': False, 'port': 443, 'ignoretime': False, 'debugurl': 'publictestwiki.com', 'commands': {'stage': [], 'rsync': [], 'postinstall': [], 'rebuild': []}, 'remote': {'paths': [], 'files': []}}


def test_prep_server_nonsense() -> None:
    parser = argparse.ArgumentParser()
    args, unknown = parser.parse_known_args()
    del unknown
    args.servers = 'None'
    args.config = False
    args.world = False
    args.landing = False
    args.errorpages = False
    args.files = ''
    args.folders = ''
    args.extensionlist = False
    args.l10n = False
    args.nolog = True
    args.force = False
    args.port = 443
    args.ignoretime = False
    args.pull = False
    args.branch = False
    failed = False
    try:
        mwd.prep(args)
    except ValueError as e:
        assert str(e) == "None is not a valid server - available servers: ['mw101', 'mw102', 'mw111', 'mw112', 'mw121', 'mw122', 'mwtask111']"
        failed = True
    assert failed


def test_prep_single_server() -> None:
    parser = argparse.ArgumentParser()
    args, unknown = parser.parse_known_args()
    del unknown
    args.servers = 'mw101'
    args.config = False
    args.world = False
    args.landing = False
    args.errorpages = False
    args.files = ''
    args.folders = ''
    args.extensionlist = False
    args.l10n = False
    args.nolog = True
    args.force = False
    args.port = 443
    args.ignoretime = False
    args.pull = False
    args.branch = False
    assert mwd.prep(args) == {'servers': ['mw101'], 'doworld': False, 'loginfo': {'servers': 'mw101', 'files': '', 'folders': '', 'nolog': True, 'port': 443}, 'branch': '', 'nolog': True, 'force': False, 'port': 443, 'ignoretime': False, 'debugurl': 'publictestwiki.com', 'commands': {'stage': [], 'rsync': [], 'postinstall': [], 'rebuild': []}, 'remote': {'paths': [], 'files': []}}


def test_prep_multi_server() -> None:
    parser = argparse.ArgumentParser()
    args, unknown = parser.parse_known_args()
    del unknown
    args.servers = 'mw101,mw102'
    args.config = False
    args.world = False
    args.landing = False
    args.errorpages = False
    args.files = ''
    args.folders = ''
    args.extensionlist = False
    args.l10n = False
    args.nolog = True
    args.force = False
    args.port = 443
    args.ignoretime = False
    args.pull = False
    args.branch = False
    assert mwd.prep(args) == {'servers': ['mw101', 'mw102'], 'doworld': False, 'loginfo': {'servers': 'mw101,mw102', 'files': '', 'folders': '', 'nolog': True, 'port': 443}, 'branch': '', 'nolog': True, 'force': False, 'port': 443, 'ignoretime': False, 'debugurl': 'publictestwiki.com', 'commands': {'stage': [], 'rsync': [], 'postinstall': [], 'rebuild': []}, 'remote': {'paths': [], 'files': []}}


def test_prep_log() -> None:
    parser = argparse.ArgumentParser()
    args, unknown = parser.parse_known_args()
    del unknown
    args.servers = 'all'
    args.config = False
    args.world = False
    args.landing = False
    args.errorpages = False
    args.files = ''
    args.folders = ''
    args.extensionlist = False
    args.l10n = False
    args.nolog = False
    args.force = False
    args.port = 443
    args.ignoretime = False
    args.pull = False
    args.branch = False
    assert mwd.prep(args) == {'servers': ['mw101', 'mw102', 'mw111', 'mw112', 'mw121', 'mw122', 'mwtask111'], 'doworld': False, 'loginfo': {'servers': 'all', 'files': '', 'folders': '', 'port': 443}, 'branch': '', 'nolog': False, 'force': False, 'port': 443, 'ignoretime': False, 'debugurl': 'publictestwiki.com', 'commands': {'stage': [], 'rsync': [], 'postinstall': [], 'rebuild': []}, 'remote': {'paths': [], 'files': []}}


def test_prep_world() -> None:
    parser = argparse.ArgumentParser()
    args, unknown = parser.parse_known_args()
    del unknown
    args.servers = 'all'
    args.config = False
    args.world = True
    args.landing = False
    args.errorpages = False
    args.files = ''
    args.folders = ''
    args.extensionlist = False
    args.l10n = False
    args.nolog = True
    args.force = False
    args.port = 443
    args.ignoretime = False
    args.pull = False
    args.branch = False
    assert mwd.prep(args) == {
        'branch': '',
        'commands': {
            'postinstall': [],
            'rebuild': [
                mwd.WikiCommand(
                    command='MW_INSTALL_PATH=/srv/mediawiki-staging/w /srv/mediawiki-staging/w/extensions/MirahezeMagic/maintenance/rebuildVersionCache.php --save-gitinfo --conf=/srv/mediawiki-staging/config/LocalSettings.php',
                    wiki='testwiki',
                ),
            ],
            'rsync': [
                'sudo -u www-data rsync --update -r --delete --exclude=".*" /srv/mediawiki-staging/w/* /srv/mediawiki/w/',
            ],
            'stage': [
                'sudo -u www-data git -C /srv/mediawiki-staging/w/ pull --recurse-submodules --quiet',
            ],
        },
        'debugurl': 'publictestwiki.com',
        'doworld': True,
        'force': False,
        'ignoretime': False,
        'loginfo': {
            'files': '',
            'folders': '',
            'nolog': True,
            'port': 443,
            'servers': 'all',
            'world': True,
        },
        'nolog': True,
        'port': 443,
        'remote': {
            'files': [],
            'paths': ['/srv/mediawiki/cache/gitinfo/', '/srv/mediawiki/w/'],
        },
        'servers': ['mw101', 'mw102', 'mw111', 'mw112', 'mw121', 'mw122', 'mwtask111'],
    }


def test_prep_landing() -> None:
    parser = argparse.ArgumentParser()
    args, unknown = parser.parse_known_args()
    del unknown
    args.servers = 'all'
    args.config = False
    args.world = False
    args.landing = True
    args.errorpages = False
    args.files = ''
    args.folders = ''
    args.extensionlist = False
    args.l10n = False
    args.nolog = True
    args.force = False
    args.port = 443
    args.ignoretime = False
    args.pull = False
    args.branch = False
    assert mwd.prep(args) == {
        'branch': '',
        'commands': {
            'postinstall': [],
            'rebuild': [],
            'rsync': [
                'sudo -u www-data rsync --update -r --delete --exclude=".*" /srv/mediawiki-staging/landing/* /srv/mediawiki/landing/',
            ],
            'stage': [],
        },
        'debugurl': 'publictestwiki.com',
        'doworld': False,
        'force': False,
        'ignoretime': False,
        'loginfo': {
            'files': '',
            'folders': '',
            'landing': True,
            'nolog': True,
            'port': 443,
            'servers': 'all',
        },
        'nolog': True,
        'port': 443,
        'remote': {
            'files': [],
            'paths': ['/srv/mediawiki/landing/'],
        },
        'servers': ['mw101', 'mw102', 'mw111', 'mw112', 'mw121', 'mw122', 'mwtask111'],
    }


def test_prep_world_extlist() -> None:
    parser = argparse.ArgumentParser()
    args, unknown = parser.parse_known_args()
    del unknown
    args.servers = 'all'
    args.config = False
    args.world = True
    args.landing = False
    args.errorpages = False
    args.files = ''
    args.folders = ''
    args.extensionlist = True
    args.l10n = False
    args.nolog = True
    args.force = False
    args.port = 443
    args.ignoretime = False
    args.pull = False
    args.branch = False
    assert mwd.prep(args) == {
        'branch': '',
        'commands': {
            'postinstall': [],
            'rebuild': [
                mwd.WikiCommand(
                    command='MW_INSTALL_PATH=/srv/mediawiki-staging/w /srv/mediawiki-staging/w/extensions/MirahezeMagic/maintenance/rebuildVersionCache.php --save-gitinfo --conf=/srv/mediawiki-staging/config/LocalSettings.php',
                    wiki='testwiki',
                ),
                mwd.WikiCommand(command='/srv/mediawiki/w/extensions/CreateWiki/maintenance/rebuildExtensionListCache.php', wiki='testwiki'),
            ],
            'rsync': [
                'sudo -u www-data rsync --update -r --delete --exclude=".*" /srv/mediawiki-staging/w/* /srv/mediawiki/w/',
            ],
            'stage': [
                'sudo -u www-data git -C /srv/mediawiki-staging/w/ pull --recurse-submodules --quiet',
            ],
        },
        'debugurl': 'publictestwiki.com',
        'doworld': True,
        'force': False,
        'ignoretime': False,
        'loginfo': {
            'files': '',
            'folders': '',
            'nolog': True,
            'port': 443,
            'servers': 'all',
            'world': True,
            'extensionlist': True,
        },
        'nolog': True,
        'port': 443,
        'remote': {
            'files': ['/srv/mediawiki/cache/extension-list.json'],
            'paths': ['/srv/mediawiki/cache/gitinfo/', '/srv/mediawiki/w/'],
        },
        'servers': ['mw101', 'mw102', 'mw111', 'mw112', 'mw121', 'mw122', 'mwtask111'],
    }


def test_prep_folder_test() -> None:
    parser = argparse.ArgumentParser()
    args, unknown = parser.parse_known_args()
    del unknown
    args.servers = 'all'
    args.config = False
    args.world = False
    args.landing = False
    args.errorpages = False
    args.files = ''
    args.folders = 'test'
    args.extensionlist = False
    args.l10n = False
    args.nolog = True
    args.force = False
    args.port = 443
    args.ignoretime = False
    args.pull = False
    args.branch = False
    assert mwd.prep(args) == {
        'branch': '',
        'commands': {
            'postinstall': [],
            'rebuild': [],
            'rsync': [
                'sudo -u www-data rsync --update -r --delete --exclude=".*" /srv/mediawiki-staging/test/* /srv/mediawiki/test/',
            ],
            'stage': [],
        },
        'debugurl': 'publictestwiki.com',
        'doworld': False,
        'force': False,
        'ignoretime': False,
        'loginfo': {
            'files': '',
            'folders': 'test',
            'nolog': True,
            'port': 443,
            'servers': 'all',
        },
        'nolog': True,
        'port': 443,
        'remote': {
            'files': [],
            'paths': ['/srv/mediawiki/test/'],
        },
        'servers': ['mw101', 'mw102', 'mw111', 'mw112', 'mw121', 'mw122', 'mwtask111'],
    }


def test_prep_file_test() -> None:
    parser = argparse.ArgumentParser()
    args, unknown = parser.parse_known_args()
    del unknown
    args.servers = 'all'
    args.config = False
    args.world = False
    args.landing = False
    args.errorpages = False
    args.files = 'test.txt'
    args.folders = ''
    args.extensionlist = False
    args.l10n = False
    args.nolog = True
    args.force = False
    args.port = 443
    args.ignoretime = False
    args.pull = False
    args.branch = False
    assert mwd.prep(args) == {
        'branch': '',
        'commands': {
            'postinstall': [],
            'rebuild': [],
            'rsync': [
                'sudo -u www-data rsync --update --exclude=".*" /srv/mediawiki-staging/test.txt /srv/mediawiki/test.txt',
            ],
            'stage': [],
        },
        'debugurl': 'publictestwiki.com',
        'doworld': False,
        'force': False,
        'ignoretime': False,
        'loginfo': {
            'files': 'test.txt',
            'folders': '',
            'nolog': True,
            'port': 443,
            'servers': 'all',
        },
        'nolog': True,
        'port': 443,
        'remote': {
            'files': ['/srv/mediawiki/test.txt'],
            'paths': [],
        },
        'servers': ['mw101', 'mw102', 'mw111', 'mw112', 'mw121', 'mw122', 'mwtask111'],
    }


def test_prep_world_l10n() -> None:
    parser = argparse.ArgumentParser()
    args, unknown = parser.parse_known_args()
    del unknown
    args.servers = 'all'
    args.config = False
    args.world = True
    args.landing = False
    args.errorpages = False
    args.files = ''
    args.folders = ''
    args.extensionlist = False
    args.l10n = True
    args.nolog = True
    args.force = False
    args.port = 443
    args.ignoretime = False
    args.pull = False
    args.branch = False
    args.lang = False
    assert mwd.prep(args) == {
        'branch': '',
        'commands': {
            'postinstall': [mwd.WikiCommand(command='/srv/mediawiki/w/maintenance/mergeMessageFileList.php --quiet --output /srv/mediawiki/config/ExtensionMessageFiles.php', wiki='testwiki')],
            'rebuild': [
                mwd.WikiCommand(
                    command='MW_INSTALL_PATH=/srv/mediawiki-staging/w /srv/mediawiki-staging/w/extensions/MirahezeMagic/maintenance/rebuildVersionCache.php --save-gitinfo --conf=/srv/mediawiki-staging/config/LocalSettings.php',
                    wiki='testwiki',
                ),
                mwd.WikiCommand(command='/srv/mediawiki/w/maintenance/rebuildLocalisationCache.php --quiet', wiki='testwiki'),
            ],
            'rsync': [
                'sudo -u www-data rsync --update -r --delete --exclude=".*" /srv/mediawiki-staging/w/* /srv/mediawiki/w/',
            ],
            'stage': [
                'sudo -u www-data git -C /srv/mediawiki-staging/w/ pull --recurse-submodules --quiet',
            ],
        },
        'debugurl': 'publictestwiki.com',
        'doworld': True,
        'force': False,
        'ignoretime': False,
        'loginfo': {
            'files': '',
            'folders': '',
            'nolog': True,
            'port': 443,
            'servers': 'all',
            'world': True,
            'l10n': True,
        },
        'nolog': True,
        'port': 443,
        'remote': {
            'files': [],
            'paths': ['/srv/mediawiki/cache/gitinfo/', '/srv/mediawiki/w/', '/srv/mediawiki/cache/l10n/'],
        },
        'servers': ['mw101', 'mw102', 'mw111', 'mw112', 'mw121', 'mw122', 'mwtask111'],
    }


def test_l10n_no_lang() -> None:
    assert str(mwd._construct_l10n_command(None, 'testwiki')) == 'sudo -u www-data php /srv/mediawiki/w/maintenance/rebuildLocalisationCache.php --quiet --wiki=testwiki'


def test_l10n_one_lang() -> None:
    assert str(mwd._construct_l10n_command('en', 'testwiki')) == 'sudo -u www-data php /srv/mediawiki/w/maintenance/rebuildLocalisationCache.php --lang=en --quiet --wiki=testwiki'


def test_l10n_multi_lang() -> None:
    assert str(mwd._construct_l10n_command('en,es', 'testwiki')) == 'sudo -u www-data php /srv/mediawiki/w/maintenance/rebuildLocalisationCache.php --lang=en,es --quiet --wiki=testwiki'


def test_l10n_bad_lang() -> None:
    failed = False
    try:
        str(mwd._construct_l10n_command('aaaa', 'testwiki'))
    except ValueError as e:
        assert str(e) == 'aaaa is not a valid language.'
        failed = True
    assert failed


def test_pull_only_world() -> None:
    assert mwd._get_git_commands(True, None, None) == ['sudo -u www-data git -C /srv/mediawiki-staging/w/ pull --recurse-submodules --quiet']


def test_pull_array_world() -> None:
    assert mwd._get_git_commands(True, 'landing,config', None) == [
        'sudo -u www-data git -C /srv/mediawiki-staging/landing/ pull --quiet',
        'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --quiet',
        'sudo -u www-data git -C /srv/mediawiki-staging/w/ pull --recurse-submodules --quiet',
    ]


def test_pull_single_world() -> None:
    assert mwd._get_git_commands(True, 'landing', None) == [
        'sudo -u www-data git -C /srv/mediawiki-staging/landing/ pull --quiet',
        'sudo -u www-data git -C /srv/mediawiki-staging/w/ pull --recurse-submodules --quiet',
    ]


def test_pull_array_noworld() -> None:
    assert mwd._get_git_commands(False, 'landing,config', None) == [
        'sudo -u www-data git -C /srv/mediawiki-staging/landing/ pull --quiet',
        'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --quiet',
    ]


def test_pull_single_noworld() -> None:
    assert mwd._get_git_commands(False, 'landing', None) == ['sudo -u www-data git -C /srv/mediawiki-staging/landing/ pull --quiet']


def test_pull_none() -> None:
    assert mwd._get_git_commands(False, None, None) == []


def test_pull_world_fake(capsys) -> None:
    mwd._get_git_commands(True, 'garbage', None)
    captured = capsys.readouterr()
    assert captured.out == 'Failed to pull garbage due to invalid name\n'


def test_pull_noworld_fake(capsys) -> None:
    mwd._get_git_commands(False, 'garbage', None)
    captured = capsys.readouterr()
    assert captured.out == 'Failed to pull garbage due to invalid name\n'
