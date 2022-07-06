import os

import mwscript

import pytest


def test_get_command_simple():
    args = mwscript.get_args()
    args.script = 'test.php'
    args.arguments = ['metawiki']
    assert mwscript.get_commands(args) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/w/maintenance/test.php --wiki=metawiki', 'generate': None, 'long': False, 'nolog': False}


def test_get_command_extension():
    args = mwscript.get_args()
    args.script = 'extensions/CheckUser/test.php'
    args.arguments = ['metawiki']
    assert mwscript.get_commands(args) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/w/extensions/CheckUser/maintenance/test.php --wiki=metawiki', 'generate': None, 'long': False, 'nolog': False}


def test_get_command_extension_list():
    args = mwscript.get_args()
    args.script = 'test.php'
    args.extension = 'CheckUser'
    try:
        assert mwscript.get_commands(args) == {'confirm': False, 'command': f'sudo -u www-data /usr/local/bin/foreachwikiindblist /home/{os.environ["LOGNAME"]}/CheckUser.json /srv/mediawiki/w/maintenance/test.php', 'generate': 'php /srv/mediawiki/w/extensions/MirahezeMagic/maintenance/generateExtensionDatabaseList.php --wiki=loginwiki --extension=CheckUser', 'long': True, 'nolog': False}
    except KeyError:
        pytest.skip('You have a stupid environment')


def test_get_command_all():
    args = mwscript.get_args()
    args.script = 'test.php'
    args.arguments = ['all']
    assert mwscript.get_commands(args) == {'confirm': False, 'command': 'sudo -u www-data /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.json /srv/mediawiki/w/maintenance/test.php', 'generate': None, 'long': True, 'nolog': False}


def test_get_command_beta():
    args = mwscript.get_args()
    args.script = 'test.php'
    args.arguments = ['beta']
    assert mwscript.get_commands(args) == {'confirm': False, 'command': 'sudo -u www-data /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/beta.json /srv/mediawiki/w/maintenance/test.php', 'generate': None, 'long': True, 'nolog': False}


def test_get_command_args():
    args = mwscript.get_args()
    args.script = 'test.php'
    args.arguments = ['metawiki', '--test']
    assert mwscript.get_commands(args) == {'confirm': False, 'command': 'sudo -u www-data php /srv/mediawiki/w/maintenance/test.php --wiki=metawiki --test', 'generate': None, 'long': False, 'nolog': False}
