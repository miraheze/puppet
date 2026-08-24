import argparse
import os
import re
import socket
import pytest
import unittest
from unittest.mock import MagicMock, patch
import mwdeploy
from mwdeploy import (
    UpgradePackAction,
    LangAction,
    VersionsAction,
    ServersAction,
)


class TestTagFunctions(unittest.TestCase):
    def setUp(self):
        self.path = 'test/path'
        self.version = 'version'
        self.repo_dir = '/srv/mediawiki-staging/version/test/path'
        self.changed_files = ['tests/test1.js', 'tests/test.sql', 'resources/test1.js', 'src/main.php', 'extension.json', 'extension-client.json', 'extension-repo.json', 'skin.json', 'test.sql', 'sql/test.sql', 'composer.lock', 'i18n/en.json', 'i18n/fr.json', 'test/i18n/test/en.json', 'test/i18n/test/fr.json']
        self.expected_codechange_files = {'resources/test1.js', 'src/main.php', 'extension.json', 'extension-client.json', 'extension-repo.json', 'skin.json'}
        self.expected_schema_files = {'test.sql', 'sql/test.sql'}
        self.expected_build_files = {'tests/test1.js', 'tests/test.sql', 'composer.lock'}
        self.expected_i18n_files = {'i18n/en.json', 'i18n/fr.json', 'test/i18n/test/en.json', 'test/i18n/test/fr.json'}

    def test_get_change_tag_map(self):
        tag_map = mwdeploy.get_change_tag_map()
        self.assertIsInstance(tag_map, dict)
        self.assertTrue(all(isinstance(pattern, type(re.compile(''))) for pattern in tag_map.keys()))
        self.assertTrue(all(isinstance(tag, str) for tag in tag_map.values()))

    def test_get_change_tag_map_is_cached(self):
        self.assertIs(mwdeploy.get_change_tag_map(), mwdeploy.get_change_tag_map())

    @patch('os.popen')
    def test_get_changed_files(self, mock_popen):
        mock_popen.return_value.readlines.return_value = self.changed_files
        changed_files = mwdeploy.get_changed_files(self.path, self.version)
        self.assertIsInstance(changed_files, list)
        self.assertCountEqual(changed_files, self.changed_files)
        mock_popen.assert_called_with(f'git -C {self.repo_dir} --no-pager --git-dir={self.repo_dir}/.git diff --name-only HEAD@{{1}} HEAD 2> /dev/null')

    @patch('os.popen')
    def test_get_changed_files_type(self, mock_popen):
        mock_popen.return_value.readlines.return_value = self.changed_files
        codechange_files = mwdeploy.get_changed_files_type(self.path, self.version, 'code change')
        schema_files = mwdeploy.get_changed_files_type(self.path, self.version, 'schema change')
        build_files = mwdeploy.get_changed_files_type(self.path, self.version, 'build')
        i18n_files = mwdeploy.get_changed_files_type(self.path, self.version, 'i18n')
        self.assertIsInstance(codechange_files, set)
        self.assertIsInstance(schema_files, set)
        self.assertIsInstance(build_files, set)
        self.assertIsInstance(i18n_files, set)
        self.assertCountEqual(codechange_files, self.expected_codechange_files)
        self.assertCountEqual(schema_files, self.expected_schema_files)
        self.assertCountEqual(build_files, self.expected_build_files)
        self.assertCountEqual(i18n_files, self.expected_i18n_files)

    @patch('os.popen')
    def test_get_change_tags(self, mock_popen):
        mock_popen.return_value.readlines.return_value = self.changed_files
        tags = mwdeploy.get_change_tags(self.path, self.version)
        self.assertIsInstance(tags, set)
        self.assertTrue(all(isinstance(tag, str) for tag in tags))
        self.assertCountEqual(tags, {'code change', 'schema change', 'build', 'i18n'})


if __name__ == '__main__':
    unittest.main()


def test_get_valid_extensions():
    versions = ['version1', 'version2']
    extensions1 = ['Extension1', 'Extension2']
    extensions2 = ['Extension3', 'Extension4']

    with patch('os.scandir') as mock_scandir:
        mock_cm1 = MagicMock()
        mock_cm1.__enter__.return_value = [MagicMock(is_dir=lambda: True) for name in extensions1]
        for i, ext in enumerate(extensions1):
            setattr(mock_cm1.__enter__.return_value[i], 'name', ext)

        mock_cm2 = MagicMock()
        mock_cm2.__enter__.return_value = [MagicMock(is_dir=lambda: True) for name in extensions2]
        for i, ext in enumerate(extensions2):
            setattr(mock_cm2.__enter__.return_value[i], 'name', ext)

        mock_scandir.side_effect = [mock_cm1, mock_cm2]

        extensions = mwdeploy.get_valid_extensions(versions)
        assert extensions == extensions1 + extensions2


def test_get_valid_skins():
    versions = ['version1', 'version2']
    skins1 = ['Skins1', 'Skins2']
    skins2 = ['Skins3', 'Skins4']

    with patch('os.scandir') as mock_scandir:
        mock_cm1 = MagicMock()
        mock_cm1.__enter__.return_value = [MagicMock(is_dir=lambda: True) for name in skins1]
        for i, skin in enumerate(skins1):
            setattr(mock_cm1.__enter__.return_value[i], 'name', skin)

        mock_cm2 = MagicMock()
        mock_cm2.__enter__.return_value = [MagicMock(is_dir=lambda: True) for name in skins2]
        for i, skin in enumerate(skins2):
            setattr(mock_cm2.__enter__.return_value[i], 'name', skin)

        mock_scandir.side_effect = [mock_cm1, mock_cm2]

        skins = mwdeploy.get_valid_skins(versions)
        assert skins == skins1 + skins2


def test_get_extensions_in_pack():
    extensions = mwdeploy.get_extensions_in_pack('mleb')
    assert extensions == ['Babel', 'cldr', 'CleanChanges', 'Translate', 'UniversalLanguageSelector']


def test_get_skins_in_pack():
    skins = mwdeploy.get_skins_in_pack('bundled')
    assert skins == ['MinervaNeue', 'MonoBook', 'Timeless', 'Vector']


def test_component_packs_unknown_pack_returns_empty():
    assert mwdeploy.ComponentPacks.extensions('does-not-exist') == []
    assert mwdeploy.ComponentPacks.skins('does-not-exist') == []


def test_non_zero_ec_only_one_zero() -> None:
    assert not mwdeploy.non_zero_code([0], leave=False)


def test_non_zero_ec_multi_zero() -> None:
    assert not mwdeploy.non_zero_code([0, 0], leave=False)


def test_non_zero_ec_zero_one() -> None:
    assert mwdeploy.non_zero_code([1, 0], leave=False)


def test_non_zero_ec_one_one() -> None:
    assert mwdeploy.non_zero_code([1, 1], leave=False)


def test_non_zero_ec_only_one_one() -> None:
    assert mwdeploy.non_zero_code([1], leave=False)


@patch('os.system', return_value=0)
def test_shell_executor_run_parallel_preserves_order(mock_system) -> None:
    codes = mwdeploy.ShellExecutor.run_parallel(['echo one', 'echo two', 'echo three'])
    assert codes == [0, 0, 0]
    assert mock_system.call_count == 3


def test_shell_executor_run_parallel_empty_list() -> None:
    assert mwdeploy.ShellExecutor.run_parallel([]) == []


def test_check_up_no_debug_host() -> None:
    failed = False
    try:
        mwdeploy.check_up(nolog=True)
    except Exception as e:
        assert str(e) == 'Host or Debug must be specified'
        failed = True
    assert failed


def test_check_up_debug() -> None:
    if os.getenv('DEBUG_ACCESS_KEY'):
        assert mwdeploy.check_up(nolog=True, Debug='mwtask181', use_cert=False)


def test_check_up_debug_fail() -> None:
    with pytest.raises(SystemExit) as excinfo:
        mwdeploy.check_up(nolog=True, Debug='mwtask181', domain='httpstatuses.maor.io/500', use_cert=False)
    assert excinfo.value.code == 3


def test_check_up_debug_fail_force() -> None:
    assert mwdeploy.check_up(nolog=True, Debug='mwtask181', domain='httpstatuses.maor.io/500', force=True, use_cert=False)


def test_canary_checker_reuses_a_single_session() -> None:
    checker = mwdeploy.CanaryChecker()
    assert isinstance(checker._session, mwdeploy.requests.Session)
    assert checker._session is checker._session


def test_get_staging_path() -> None:
    assert mwdeploy._get_staging_path('version') == '/srv/mediawiki-staging/version/'


def test_get_deployed_path() -> None:
    assert mwdeploy._get_deployed_path('version') == '/srv/mediawiki/version/'


def test_construct_rsync_no_location_local() -> None:
    failed = False
    try:
        mwdeploy._construct_rsync_command(time=False, dest='/srv/mediawiki/version/')
    except Exception as e:
        assert str(e) == 'Location must be specified for local rsync.'
        failed = True
    assert failed


def test_construct_rsync_no_server_remote() -> None:
    failed = False
    try:
        mwdeploy._construct_rsync_command(time=False, dest='/srv/mediawiki/version/', local=False)
    except Exception as e:
        assert str(e) == 'Error constructing command. Either server was missing or /srv/mediawiki/version/ != /srv/mediawiki/version/'
        failed = True
    assert failed


def test_construct_rsync_conflict_options_remote() -> None:
    failed = False
    try:
        mwdeploy._construct_rsync_command(time=False, dest='/srv/mediawiki/version/', location='garbage', local=False, server='meta')
    except Exception as e:
        assert str(e) == 'Error constructing command. Either server was missing or garbage != /srv/mediawiki/version/'
        failed = True
    assert failed


def test_construct_rsync_conflict_options_no_server_remote() -> None:
    failed = False
    try:
        mwdeploy._construct_rsync_command(time=False, dest='/srv/mediawiki/version/', location='garbage', local=False)
    except Exception as e:
        assert str(e) == 'Error constructing command. Either server was missing or garbage != /srv/mediawiki/version/'
        failed = True
    assert failed


def test_construct_rsync_local_dir_update() -> None:
    assert mwdeploy._construct_rsync_command(time=False, dest='/srv/mediawiki/version/', location='/home/') == 'sudo -u www-data rsync --update -r --delete --exclude=".*" /home/ /srv/mediawiki/version/'


def test_construct_rsync_local_file_update() -> None:
    assert mwdeploy._construct_rsync_command(time=False, dest='/srv/mediawiki/version/test.txt', location='/home/test.txt', recursive=False) == 'sudo -u www-data rsync --update --exclude=".*" /home/test.txt /srv/mediawiki/version/test.txt'


def test_construct_rsync_remote_dir_update() -> None:
    fqdn = socket.getfqdn()
    domain = '.'.join(fqdn.split('.')[1:])
    assert mwdeploy._construct_rsync_command(time=False, dest='/srv/mediawiki/version/', local=False, server='meta') == f'sudo -u www-data rsync --update -r --delete -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/version/ www-data@meta.{domain}:/srv/mediawiki/version/'


def test_construct_rsync_remote_file_update() -> None:
    fqdn = socket.getfqdn()
    domain = '.'.join(fqdn.split('.')[1:])
    assert mwdeploy._construct_rsync_command(time=False, dest='/srv/mediawiki/version/test.txt', recursive=False, local=False, server='meta') == f'sudo -u www-data rsync --update -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/version/test.txt www-data@meta.{domain}:/srv/mediawiki/version/test.txt'


def test_construct_rsync_local_dir_time() -> None:
    assert mwdeploy._construct_rsync_command(time=True, dest='/srv/mediawiki/version/', location='/home/') == 'sudo -u www-data rsync --inplace -r --delete --exclude=".*" /home/ /srv/mediawiki/version/'


def test_construct_rsync_local_file_time() -> None:
    assert mwdeploy._construct_rsync_command(time=True, dest='/srv/mediawiki/version/test.txt', location='/home/test.txt', recursive=False) == 'sudo -u www-data rsync --inplace --exclude=".*" /home/test.txt /srv/mediawiki/version/test.txt'


def test_construct_rsync_remote_dir_time() -> None:
    fqdn = socket.getfqdn()
    domain = '.'.join(fqdn.split('.')[1:])
    assert mwdeploy._construct_rsync_command(time=True, dest='/srv/mediawiki/version/', local=False, server='meta') == f'sudo -u www-data rsync --inplace -r --delete -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/version/ www-data@meta.{domain}:/srv/mediawiki/version/'


def test_construct_rsync_remote_file_time() -> None:
    fqdn = socket.getfqdn()
    domain = '.'.join(fqdn.split('.')[1:])
    assert mwdeploy._construct_rsync_command(time=True, dest='/srv/mediawiki/version/test.txt', recursive=False, local=False, server='meta') == f'sudo -u www-data rsync --inplace -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/version/test.txt www-data@meta.{domain}:/srv/mediawiki/version/test.txt'


def test_construct_git_pull() -> None:
    assert mwdeploy._construct_git_pull('config') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --quiet'


def test_construct_git_pull_branch() -> None:
    assert mwdeploy._construct_git_pull('config', branch='myfunbranch') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull origin myfunbranch --quiet'


def test_construct_git_pull_skin() -> None:
    assert mwdeploy._construct_git_pull('skins/Vector', version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/skins/Vector pull --quiet'


def test_construct_git_pull_skin_no_quiet() -> None:
    assert mwdeploy._construct_git_pull('skins/Vector', quiet=False, version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/skins/Vector pull 2> /dev/null'


def test_construct_git_pull_extension_sm() -> None:
    assert mwdeploy._construct_git_pull('extensions/VisualEditor', submodules=True, version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/extensions/VisualEditor pull --recurse-submodules --quiet'


def test_construct_git_pull_extension_sm_no_quiet() -> None:
    assert mwdeploy._construct_git_pull('extensions/VisualEditor', submodules=True, quiet=False, version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/extensions/VisualEditor pull --recurse-submodules 2> /dev/null'


def test_construct_git_pull_branch_sm() -> None:
    assert mwdeploy._construct_git_pull('config', submodules=True, branch='test') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --recurse-submodules origin test --quiet'


def test_construct_git_pull_branch_sm_no_quiet() -> None:
    assert mwdeploy._construct_git_pull('config', submodules=True, branch='test', quiet=False) == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --recurse-submodules origin test 2> /dev/null'


def test_construct_git_reset_revert() -> None:
    assert mwdeploy._construct_git_reset_revert('extensions/VisualEditor', version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/extensions/VisualEditor reset --hard HEAD@{1}'


def test_construct_git_reset_hard() -> None:
    assert mwdeploy._construct_git_reset_hard('vendor', version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/vendor reset --hard'


def test_construct_reset_mediawiki_rm_staging() -> None:
    assert mwdeploy._construct_reset_mediawiki_rm_staging('version') == 'sudo -u www-data rm -rf /srv/mediawiki-staging/version/'


def test_construct_reset_mediawiki_run_puppet() -> None:
    assert mwdeploy._construct_reset_mediawiki_run_puppet() == 'sudo puppet agent -tv'


def test_patch_matches_core_patch() -> None:
    sample_patch = {'path': 'REL1_41', 'versions': ['all']}
    with patch.dict(mwdeploy.versions, {'REL1_41': 'REL1_41'}, clear=True):
        assert mwdeploy._patch_matches(sample_patch, 'REL1_41', 'REL1_41') is True


def test_patch_matches_extension_patch_scoped_to_version() -> None:
    sample_patch = {'path': 'extensions/Vector', 'versions': ['REL1_41']}
    assert mwdeploy._patch_matches(sample_patch, 'extensions/Vector', 'REL1_41') is True
    assert mwdeploy._patch_matches(sample_patch, 'extensions/Vector', 'REL1_42') is False


def test_patch_matches_all_versions() -> None:
    sample_patch = {'path': 'extensions/Vector', 'versions': ['all']}
    assert mwdeploy._patch_matches(sample_patch, 'extensions/Vector', 'REL1_99') is True


class TestRemoteDeployer(unittest.TestCase):
    def setUp(self):
        self.canary = MagicMock()
        self.rsync_builder = mwdeploy.RsyncCommandBuilder()
        self.deployer = mwdeploy.RemoteDeployer(self.rsync_builder, self.canary, hostname='mw151', max_workers=4)
        self.envinfo = mwdeploy.Environment(wikidbname='testwiki', wikiurl='publictestwiki.com', servers=['mw151', 'mw152', 'mw153'])

    @patch.object(mwdeploy.ShellExecutor, 'run', return_value=0)
    def test_sync_skips_self_and_deploys_to_others(self, mock_run):
        result = self.deployer.sync(False, ['mw151', 'mw152', 'mw153'], '/srv/mediawiki/config/', self.envinfo, nolog=True)
        assert result == 0
        assert mock_run.call_count == 2
        commands = [call.args[0] for call in mock_run.call_args_list]
        assert any('@mw152.' in cmd for cmd in commands)
        assert any('@mw153.' in cmd for cmd in commands)

    @patch.object(mwdeploy.ShellExecutor, 'run', return_value=0)
    def test_sync_continues_past_self_mid_list(self, mock_run):
        self.deployer.sync(False, ['mw152', 'mw151', 'mw153'], '/srv/mediawiki/config/', self.envinfo, nolog=True)
        assert mock_run.call_count == 2
        commands = [call.args[0] for call in mock_run.call_args_list]
        assert not any('@mw151.' in cmd for cmd in commands)

    def test_sync_with_no_remote_targets_returns_zero(self):
        result = self.deployer.sync(False, ['mw151'], '/srv/mediawiki/config/', self.envinfo, nolog=True)
        assert result == 0

    @patch.object(mwdeploy.ShellExecutor, 'run', side_effect=[0, 1])
    def test_sync_surfaces_a_failing_server(self, mock_run):
        result = self.deployer.sync(False, ['mw151', 'mw152', 'mw153'], '/srv/mediawiki/config/', self.envinfo, nolog=True)
        assert result != 0
        assert mock_run.call_count == 2


def test_build_loginfo_filters_falsy_and_unwraps_single_item_lists() -> None:
    args = argparse.Namespace(pull=None, force=False, servers=['mw151'], versions=['REL1_41'], branch=None)
    runner = mwdeploy.DeploymentRunner(args)
    loginfo = runner._build_loginfo()
    assert loginfo == {'servers': 'mw151', 'versions': 'REL1_41'}


def test_UpgradePackAction():
    parser = argparse.ArgumentParser()
    parser.add_argument('--upgrade-extensions', action='store_const', const=True, default=False)
    parser.add_argument('--upgrade-skins', action='store_const', const=True, default=False)
    parser.add_argument('--versions', action='store', default=None)
    parser.add_argument('--upgrade-pack', action=UpgradePackAction)
    namespace = parser.parse_args(['--upgrade-pack', 'wikitide'])
    assert namespace.upgrade_extensions == ['CreateWiki', 'DataDump', 'DiscordNotifications', 'GlobalNewFiles', 'ImportDump', 'IncidentReporting', 'ManageWiki', 'MatomoAnalytics', 'MirahezeMagic', 'PDFEmbed', 'RemovePII', 'RequestCustomDomain', 'RottenLinks', 'WikiDiscover']


def test_LangAction():
    parser = argparse.ArgumentParser()
    parser.add_argument('--l10n', action='store_const', const=True, default=False)
    parser.add_argument('--lang', action=LangAction)

    with pytest.raises(SystemExit):
        parser.parse_args(['--lang', 'invalid_tag'])

    with pytest.raises(SystemExit):
        parser.parse_args(['--lang', 'en,fr'])

    namespace = parser.parse_args(['--l10n', '--lang', 'en,fr'])
    assert namespace.lang == 'en,fr'


def test_VersionsAction():
    mwdeploy.versions.clear()
    with patch('os.path.exists', return_value=True), \
         patch.dict(mwdeploy.versions, {'version1': 'version1', 'version2': 'version2'}):
        parser = argparse.ArgumentParser()
        parser.add_argument('--versions', action=VersionsAction)

        with pytest.raises(SystemExit):
            parser.parse_args(['--versions', 'invalid_version'])

        namespace = parser.parse_args(['--versions', 'version1'])
        assert namespace.versions == ['version1']

        namespace = parser.parse_args(['--versions', 'all'])
        assert namespace.versions == ['version1', 'version2']


def test_ServersAction():
    parser = argparse.ArgumentParser()
    parser.add_argument('--servers', action=ServersAction)
    with pytest.raises(SystemExit):
        parser.parse_args(['--servers', 'invalid_server'])
    namespace = parser.parse_args(['--servers', 'mw151,mw152'])
    assert namespace.servers == ['mw151', 'mw152']
