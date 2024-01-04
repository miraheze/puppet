import os
import mwscript
from unittest.mock import patch


def test_get_command_simple():
    args = mwscript.get_args()
    args.script = 'test.php'
    args.arguments = ['metawiki']
    args.version = '1.39'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/1.39/maintenance/test.php --wiki=metawiki', 'generate': None, 'long': False, 'nolog': False}


def test_get_command_extension():
    args = mwscript.get_args()
    args.script = 'extensions/CheckUser/test.php'
    args.arguments = ['metawiki']
    args.version = '1.39'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/1.39/extensions/CheckUser/maintenance/test.php --wiki=metawiki', 'generate': None, 'long': False, 'nolog': False}


@patch.dict(os.environ, {'LOGNAME': 'test'})
@patch('os.getlogin')
def test_get_command_extension_list(mock_getlogin):
    mock_getlogin.return_value = 'test'
    args = mwscript.get_args()
    args.script = 'test.php'
    args.extension = 'CheckUser'
    args.version = '1.39'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {
        'confirm': False,
        'command': f'sudo -u www-data /usr/local/bin/foreachwikiindblist /home/{os.environ["LOGNAME"]}/CheckUser.json /srv/mediawiki/1.39/maintenance/test.php',
        'generate': 'php /srv/mediawiki/1.39/extensions/MirahezeMagic/maintenance/generateExtensionDatabaseList.php --wiki=loginwiki --extension=CheckUser',
        'long': True,
        'nolog': False,
    }


def test_get_command_all():
    args = mwscript.get_args()
    args.script = 'test.php'
    args.arguments = ['all']
    args.version = '1.39'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.json /srv/mediawiki/1.39/maintenance/test.php', 'generate': None, 'long': True, 'nolog': False}


def test_get_command_beta():
    args = mwscript.get_args()
    args.script = 'test.php'
    args.arguments = ['beta']
    args.version = '1.39'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/beta.json /srv/mediawiki/1.39/maintenance/test.php', 'generate': None, 'long': True, 'nolog': False}


def test_get_command_args():
    args = mwscript.get_args()
    args.script = 'test.php'
    args.arguments = ['metawiki', '--test']
    args.version = '1.39'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/1.39/maintenance/test.php --wiki=metawiki --test', 'generate': None, 'long': False, 'nolog': False}


def test_get_command_subdir():
    args = mwscript.get_args()
    args.script = 'subdir/test.php'
    args.arguments = ['metawiki']
    args.version = '1.39'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/1.39/maintenance/subdir/test.php --wiki=metawiki', 'generate': None, 'long': False, 'nolog': False}


def test_get_command_simple_runner():
    args = mwscript.get_args()
    args.script = 'test.php'
    args.arguments = ['metawiki']
    args.version = '1.40'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/1.40/maintenance/run.php /srv/mediawiki/1.40/maintenance/test.php --wiki=metawiki', 'generate': None, 'long': False, 'nolog': False}


def test_get_command_extension_runner():
    args = mwscript.get_args()
    args.script = 'extensions/CheckUser/test.php'
    args.arguments = ['metawiki']
    args.version = '1.40'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/1.40/maintenance/run.php /srv/mediawiki/1.40/extensions/CheckUser/maintenance/test.php --wiki=metawiki', 'generate': None, 'long': False, 'nolog': False}


@patch.dict(os.environ, {'LOGNAME': 'test'})
@patch('os.getlogin')
def test_get_command_extension_list_runner(mock_getlogin):
    mock_getlogin.return_value = 'test'
    args = mwscript.get_args()
    args.script = 'test.php'
    args.extension = 'CheckUser'
    args.version = '1.40'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {
        'confirm': False,
        'command': f'sudo -u www-data /usr/local/bin/foreachwikiindblist /home/{os.environ["LOGNAME"]}/CheckUser.json /srv/mediawiki/1.40/maintenance/run.php /srv/mediawiki/1.40/maintenance/test.php',
        'generate': 'php /srv/mediawiki/1.40/maintenance/run.php /srv/mediawiki/1.40/extensions/MirahezeMagic/maintenance/generateExtensionDatabaseList.php --wiki=loginwiki --extension=CheckUser',
        'long': True,
        'nolog': False,
    }


def test_get_command_all_runner():
    args = mwscript.get_args()
    args.script = 'test.php'
    args.arguments = ['all']
    args.version = '1.40'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.json /srv/mediawiki/1.40/maintenance/run.php /srv/mediawiki/1.40/maintenance/test.php', 'generate': None, 'long': True, 'nolog': False}


def test_get_command_beta_runner():
    args = mwscript.get_args()
    args.script = 'test.php'
    args.arguments = ['beta']
    args.version = '1.40'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/beta.json /srv/mediawiki/1.40/maintenance/run.php /srv/mediawiki/1.40/maintenance/test.php', 'generate': None, 'long': True, 'nolog': False}


def test_get_command_args_runner():
    args = mwscript.get_args()
    args.script = 'test.php'
    args.arguments = ['metawiki', '--test']
    args.version = '1.40'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/1.40/maintenance/run.php /srv/mediawiki/1.40/maintenance/test.php --wiki=metawiki --test', 'generate': None, 'long': False, 'nolog': False}


def test_get_command_subdir_runner():
    args = mwscript.get_args()
    args.script = 'subdir/test.php'
    args.arguments = ['metawiki']
    args.version = '1.40'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/1.40/maintenance/run.php /srv/mediawiki/1.40/maintenance/subdir/test.php --wiki=metawiki', 'generate': None, 'long': False, 'nolog': False}


def test_get_command_class():
    args = mwscript.get_args()
    args.script = 'test'
    args.arguments = ['metawiki', '--test']
    args.version = '1.40'
    args.confirm = True
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': True, 'command': 'sudo -u www-data php /srv/mediawiki/1.40/maintenance/run.php test --wiki=metawiki --test', 'generate': None, 'long': False, 'nolog': False}


def test_get_command_long_runner():
    args = mwscript.get_args()
    args.script = 'rebuildall.php'
    args.arguments = ['metawiki']
    args.version = '1.40'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/1.40/maintenance/run.php /srv/mediawiki/1.40/maintenance/rebuildall.php --wiki=metawiki', 'generate': None, 'long': True, 'nolog': False}


def test_get_command_long_runner_class_lower():
    args = mwscript.get_args()
    args.script = 'rebuildall'
    args.arguments = ['metawiki']
    args.version = '1.40'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/1.40/maintenance/run.php rebuildall --wiki=metawiki', 'generate': None, 'long': True, 'nolog': False}


def test_get_command_long_runner_class_mixed():
    args = mwscript.get_args()
    args.script = 'rEbUiLdAll'
    args.arguments = ['metawiki']
    args.version = '1.40'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/1.40/maintenance/run.php rEbUiLdAll --wiki=metawiki', 'generate': None, 'long': True, 'nolog': False}


def test_get_command_class_norunner():
    args = mwscript.get_args()
    args.script = 'test'
    args.arguments = ['metawiki']
    args.version = '1.39'
    assert mwscript.get_commands(args) == 2


def test_get_command_wiki_typo():
    args = mwscript.get_args()
    args.script = 'test'
    args.arguments = ['metawik']
    args.version = '1.39'
    assert mwscript.get_commands(args) == 2


def test_get_command_nowiki():
    args = mwscript.get_args()
    args.script = 'test'
    args.arguments = []
    args.version = '1.39'
    assert mwscript.get_commands(args) == 2


def test_get_command_longextension():
    args = mwscript.get_args()
    args.script = 'extensions/Cargo/cargoRecreateData.php'
    args.arguments = ['metawiki']
    args.version = '1.40'
    assert mwscript.syscheck(mwscript.get_commands(args)) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/1.40/maintenance/run.php /srv/mediawiki/1.40/extensions/Cargo/maintenance/cargoRecreateData.php --wiki=metawiki', 'generate': None, 'long': True, 'nolog': False}
