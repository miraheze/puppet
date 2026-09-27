import argparse
import re
import socket
import unittest
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import MagicMock, patch

import pytest

import mwdeploy
from mwdeploy import (
    ApplyPatchesAction,
    LangAction,
    ServersAction,
    UpgradePackAction,
    VersionsAction,
)


class TestConsole(unittest.TestCase):
    def setUp(self):
        self._original_enabled = mwdeploy.Console.enabled

    def tearDown(self):
        mwdeploy.Console.enabled = self._original_enabled

    def test_wraps_text_when_enabled(self):
        mwdeploy.Console.enabled = True
        assert mwdeploy.Console.ok('hi') == '\033[32mhi\033[0m'
        assert mwdeploy.Console.fail('no') == '\033[1m\033[31mno\033[0m'
        assert mwdeploy.Console.header('h') == '\033[1m\033[36mh\033[0m'
        assert mwdeploy.Console.warn('w') == '\033[33mw\033[0m'
        assert mwdeploy.Console.dim('d') == '\033[2md\033[0m'
        assert mwdeploy.Console.bold('b') == '\033[1mb\033[0m'

    def test_passthrough_when_disabled(self):
        mwdeploy.Console.enabled = False
        assert mwdeploy.Console.ok('hi') == 'hi'
        assert mwdeploy.Console.header('x') == 'x'
        assert mwdeploy.Console.fail('y') == 'y'

    def test_strip_removes_color_codes(self):
        mwdeploy.Console.enabled = True
        colored = mwdeploy.Console.fail('boom')
        assert mwdeploy.Console.strip(colored) == 'boom'

    def test_strip_is_noop_on_plain_text(self):
        assert mwdeploy.Console.strip('plain text') == 'plain text'


class TestProgressBar(unittest.TestCase):
    def test_update_prints_percentage_and_counts(self):
        bar = mwdeploy.ProgressBar(10, label='ext')
        with patch('builtins.print') as mock_print:
            bar.update(5)
        printed = mock_print.call_args[0][0]
        assert '50%' in printed
        assert '(5/10)' in printed

    def test_total_of_zero_does_not_divide_by_zero(self):
        bar = mwdeploy.ProgressBar(0)
        bar.update(0)  # must not raise ZeroDivisionError

    def test_current_is_capped_at_total(self):
        bar = mwdeploy.ProgressBar(10)
        with patch('builtins.print') as mock_print:
            bar.update(999)
        printed = mock_print.call_args[0][0]
        assert '100%' in printed
        assert '(10/10)' in printed


class TestShellExecutor(unittest.TestCase):
    @patch('subprocess.run')
    def test_run_returns_exit_code(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0)
        assert mwdeploy.ShellExecutor.run('echo hi') == 0
        args, kwargs = mock_run.call_args
        assert args[0] == 'echo hi'
        assert kwargs.get('shell') is True

    @patch('subprocess.run')
    def test_run_returns_nonzero_exit_code(self, mock_run):
        mock_run.return_value = MagicMock(returncode=5)
        assert mwdeploy.ShellExecutor.run('exit 5') == 5

    @patch('subprocess.run')
    def test_run_quiet_captures_output_as_text(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout='hi', stderr='')
        result = mwdeploy.ShellExecutor.run_quiet('echo hi')
        assert result.stdout == 'hi'
        _, kwargs = mock_run.call_args
        assert kwargs['shell'] is True
        assert kwargs['capture_output'] is True
        assert kwargs['text'] is True

    @patch('subprocess.run')
    def test_ensure_all_zero_fires_logsalmsg_when_logging(self, mock_run):
        assert mwdeploy.ShellExecutor.ensure_all_zero([1], nolog=False, leave=False) is True
        mock_run.assert_called_once()
        assert 'logsalmsg' in mock_run.call_args[0][0]

    @patch('subprocess.run')
    def test_ensure_all_zero_skips_logsalmsg_when_nolog(self, mock_run):
        assert mwdeploy.ShellExecutor.ensure_all_zero([1], nolog=True, leave=False) is True
        mock_run.assert_not_called()


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


def test_check_up_no_debug_host() -> None:
    with pytest.raises(Exception) as excinfo:
        mwdeploy.check_up(nolog=True)
    assert str(excinfo.value) == 'Host or Debug must be specified'


def test_canary_checker_reuses_a_single_session() -> None:
    checker = mwdeploy.CanaryChecker()
    assert isinstance(checker._session, mwdeploy.requests.Session)
    assert checker._session is checker._session


def test_canary_check_reports_failure_without_exiting_when_asked():
    # inside a batch, a canary failure has to come back as a value the
    # RemoteDeployer can act on, not kill whichever worker thread hit it
    checker = mwdeploy.CanaryChecker()
    fake_response = MagicMock(status_code=500, text='nope', headers={})
    with patch.object(checker._session, 'get', return_value=fake_response):
        result = checker.check(nolog=True, Debug='mw151', domain='example.org', verify=False, use_cert=False, exit_on_failure=False)
    assert result is False


def test_canary_check_passes_and_prints_ok(capsys):
    checker = mwdeploy.CanaryChecker()
    fake_response = MagicMock(status_code=200, text='mainpageisdomainroot', headers={'X-Served-By': 'mw151'})
    with patch.object(checker._session, 'get', return_value=fake_response):
        result = checker.check(nolog=True, Debug='mw151', domain='example.org', verify=False, use_cert=False)
    assert result is True
    assert 'Canary check passed' in capsys.readouterr().out


def test_canary_check_force_skips_the_request():
    checker = mwdeploy.CanaryChecker()
    with patch.object(checker, '_request') as mock_request:
        result = checker.check(nolog=True, Debug='mw151', force=True)
    assert result is True
    mock_request.assert_not_called()


class TestPathResolver(unittest.TestCase):
    def test_staging_default(self):
        assert mwdeploy._paths.staging('version') == '/srv/mediawiki-staging/version/'

    def test_deployed_default(self):
        assert mwdeploy._paths.deployed('version') == '/srv/mediawiki/version/'

    def test_staging_extension_with_version(self):
        assert mwdeploy._paths.staging('extensions/Vector', 'REL1_46') == '/srv/mediawiki-staging/REL1_46/extensions/Vector'

    def test_deployed_extension_with_version(self):
        assert mwdeploy._paths.deployed('extensions/Vector', 'REL1_46') == '/srv/mediawiki/REL1_46/extensions/Vector'


class TestRsyncCommandBuilder(unittest.TestCase):
    def setUp(self):
        self.builder = mwdeploy.RsyncCommandBuilder()

    def test_no_location_local_raises(self):
        with pytest.raises(Exception) as excinfo:
            self.builder.build(time=False, dest='/srv/mediawiki/version/')
        assert str(excinfo.value) == 'Location must be specified for local rsync.'

    def test_no_server_remote_raises(self):
        with pytest.raises(Exception) as excinfo:
            self.builder.build(time=False, dest='/srv/mediawiki/version/', local=False)
        assert str(excinfo.value) == 'Error constructing command. Either server was missing or /srv/mediawiki/version/ != /srv/mediawiki/version/'

    def test_conflicting_location_and_server_remote_raises(self):
        with pytest.raises(Exception) as excinfo:
            self.builder.build(time=False, dest='/srv/mediawiki/version/', location='garbage', local=False, server='meta')
        assert str(excinfo.value) == 'Error constructing command. Either server was missing or garbage != /srv/mediawiki/version/'

    def test_conflicting_location_no_server_remote_raises(self):
        with pytest.raises(Exception) as excinfo:
            self.builder.build(time=False, dest='/srv/mediawiki/version/', location='garbage', local=False)
        assert str(excinfo.value) == 'Error constructing command. Either server was missing or garbage != /srv/mediawiki/version/'

    def test_local_dir_update(self):
        assert self.builder.build(time=False, dest='/srv/mediawiki/version/', location='/home/') == 'sudo -u www-data rsync --update -r --delete --exclude=".*" /home/ /srv/mediawiki/version/'

    def test_local_file_update(self):
        assert self.builder.build(time=False, dest='/srv/mediawiki/version/test.txt', location='/home/test.txt', recursive=False) == 'sudo -u www-data rsync --update --exclude=".*" /home/test.txt /srv/mediawiki/version/test.txt'

    def test_remote_dir_update(self):
        fqdn = socket.getfqdn()
        domain = '.'.join(fqdn.split('.')[1:])
        assert self.builder.build(time=False, dest='/srv/mediawiki/version/', local=False, server='meta') == f'sudo -u www-data rsync --update -r --delete -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/version/ www-data@meta.{domain}:/srv/mediawiki/version/'

    def test_remote_file_update(self):
        fqdn = socket.getfqdn()
        domain = '.'.join(fqdn.split('.')[1:])
        assert self.builder.build(time=False, dest='/srv/mediawiki/version/test.txt', recursive=False, local=False, server='meta') == f'sudo -u www-data rsync --update -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/version/test.txt www-data@meta.{domain}:/srv/mediawiki/version/test.txt'

    def test_local_dir_time(self):
        assert self.builder.build(time=True, dest='/srv/mediawiki/version/', location='/home/') == 'sudo -u www-data rsync --inplace -r --delete --exclude=".*" /home/ /srv/mediawiki/version/'

    def test_local_file_time(self):
        assert self.builder.build(time=True, dest='/srv/mediawiki/version/test.txt', location='/home/test.txt', recursive=False) == 'sudo -u www-data rsync --inplace --exclude=".*" /home/test.txt /srv/mediawiki/version/test.txt'

    def test_remote_dir_time(self):
        fqdn = socket.getfqdn()
        domain = '.'.join(fqdn.split('.')[1:])
        assert self.builder.build(time=True, dest='/srv/mediawiki/version/', local=False, server='meta') == f'sudo -u www-data rsync --inplace -r --delete -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/version/ www-data@meta.{domain}:/srv/mediawiki/version/'

    def test_remote_file_time(self):
        fqdn = socket.getfqdn()
        domain = '.'.join(fqdn.split('.')[1:])
        assert self.builder.build(time=True, dest='/srv/mediawiki/version/test.txt', recursive=False, local=False, server='meta') == f'sudo -u www-data rsync --inplace -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/version/test.txt www-data@meta.{domain}:/srv/mediawiki/version/test.txt'


class TestGitCommandBuilder(unittest.TestCase):
    def test_pull_default(self):
        assert mwdeploy._git.pull('config') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --quiet'

    def test_pull_with_branch(self):
        assert mwdeploy._git.pull('config', branch='myfunbranch') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull origin myfunbranch --quiet'

    def test_pull_skin(self):
        assert mwdeploy._git.pull('skins/Vector', version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/skins/Vector pull --quiet'

    def test_pull_skin_no_quiet(self):
        assert mwdeploy._git.pull('skins/Vector', quiet=False, version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/skins/Vector pull 2> /dev/null'

    def test_pull_extension_with_submodules(self):
        assert mwdeploy._git.pull('extensions/VisualEditor', submodules=True, version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/extensions/VisualEditor pull --recurse-submodules --quiet'

    def test_pull_extension_with_submodules_no_quiet(self):
        assert mwdeploy._git.pull('extensions/VisualEditor', submodules=True, quiet=False, version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/extensions/VisualEditor pull --recurse-submodules 2> /dev/null'

    def test_pull_branch_with_submodules(self):
        assert mwdeploy._git.pull('config', submodules=True, branch='test') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --recurse-submodules origin test --quiet'

    def test_pull_branch_with_submodules_no_quiet(self):
        assert mwdeploy._git.pull('config', submodules=True, branch='test', quiet=False) == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --recurse-submodules origin test 2> /dev/null'

    def test_reset_revert(self):
        assert mwdeploy._git.reset_revert('extensions/VisualEditor', version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/extensions/VisualEditor reset --hard HEAD@{1}'

    def test_reset_hard(self):
        assert mwdeploy._git.reset_hard('vendor', version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/vendor reset --hard'

    def test_apply_default_is_index(self):
        assert mwdeploy._git.apply('config', '/patches/x.patch') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ apply --index /patches/x.patch'

    def test_apply_check(self):
        assert mwdeploy._git.apply('config', '/patches/x.patch', check=True) == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ apply --check /patches/x.patch'

    def test_apply_check_reverse(self):
        assert mwdeploy._git.apply('config', '/patches/x.patch', check=True, reverse=True) == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ apply --check --reverse /patches/x.patch'

    def test_fetch_pr(self):
        assert mwdeploy._git.fetch_pr('config', 42, 'pr-42') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ fetch origin +pull/42/head:pr-42'

    def test_checkout(self):
        assert mwdeploy._git.checkout('config', 'pr-42') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ checkout pr-42'

    def test_is_repo_true(self):
        with patch('os.path.isdir', return_value=True):
            assert mwdeploy._git.is_repo('config', '') is True

    def test_is_repo_false(self):
        with patch('os.path.isdir', return_value=False):
            assert mwdeploy._git.is_repo('config', '') is False

    def test_strip_noise_drops_permission_warnings_keeps_real_errors(self):
        text = (
            "warning: unable to access '/home/x/.config/git/attributes': Permission denied\n"
            "error: patch failed: file.php:10\n"
            "error: file.php: patch does not apply"
        )
        result = mwdeploy._git.strip_noise(text)
        assert 'unable to access' not in result
        assert 'patch failed: file.php:10' in result
        assert 'patch does not apply' in result

    def test_strip_noise_is_case_insensitive(self):
        text = 'Warning: Unable to Access something\nreal error line'
        assert mwdeploy._git.strip_noise(text) == 'real error line'

    def test_strip_noise_empty_when_only_noise(self):
        text = "warning: unable to access '/x': Permission denied"
        assert mwdeploy._git.strip_noise(text) == ''


class TestWorldReset(unittest.TestCase):
    def test_remove_staging(self):
        assert mwdeploy._world_reset.remove_staging('version') == 'sudo -u www-data rm -rf /srv/mediawiki-staging/version/'

    def test_run_puppet(self):
        assert mwdeploy._world_reset.run_puppet() == 'sudo puppet agent -tv'


class TestChangeTagger(unittest.TestCase):
    def setUp(self):
        self.path = 'test/path'
        self.version = 'version'
        self.repo_dir = '/srv/mediawiki-staging/version/test/path'
        self.changed_files = ['tests/test1.js', 'tests/test.sql', 'resources/test1.js', 'src/main.php', 'extension.json', 'extension-client.json', 'extension-repo.json', 'skin.json', 'test.sql', 'sql/test.sql', 'composer.lock', 'i18n/en.json', 'i18n/fr.json', 'test/i18n/test/en.json', 'test/i18n/test/fr.json']
        self.expected_codechange_files = {'resources/test1.js', 'src/main.php', 'extension.json', 'extension-client.json', 'extension-repo.json', 'skin.json'}
        self.expected_schema_files = {'test.sql', 'sql/test.sql'}
        self.expected_build_files = {'tests/test1.js', 'tests/test.sql', 'composer.lock'}
        self.expected_i18n_files = {'i18n/en.json', 'i18n/fr.json', 'test/i18n/test/en.json', 'test/i18n/test/fr.json'}

    def _fake_result(self):
        return MagicMock(stdout='\n'.join(self.changed_files) + '\n')

    def test_tag_map_is_the_shared_dict(self):
        assert mwdeploy.ChangeTagger.TAG_MAP is mwdeploy.CHANGE_TAG_MAP
        self.assertTrue(all(isinstance(pattern, type(re.compile(''))) for pattern in mwdeploy.ChangeTagger.TAG_MAP.keys()))
        self.assertTrue(all(isinstance(tag, str) for tag in mwdeploy.ChangeTagger.TAG_MAP.values()))

    @patch('mwdeploy._run')
    def test_changed_files(self, mock_run):
        mock_run.return_value = self._fake_result()
        changed = mwdeploy.ChangeTagger.changed_files(self.path, self.version)
        self.assertIsInstance(changed, list)
        self.assertCountEqual(changed, self.changed_files)
        mock_run.assert_called_with(f'git -C {self.repo_dir} --no-pager --git-dir={self.repo_dir}/.git diff --name-only HEAD@{{1}} HEAD')

    @patch('mwdeploy._run')
    def test_files_of_type(self, mock_run):
        mock_run.return_value = self._fake_result()
        self.assertCountEqual(mwdeploy.ChangeTagger.files_of_type(self.path, self.version, 'code change'), self.expected_codechange_files)
        self.assertCountEqual(mwdeploy.ChangeTagger.files_of_type(self.path, self.version, 'schema change'), self.expected_schema_files)
        self.assertCountEqual(mwdeploy.ChangeTagger.files_of_type(self.path, self.version, 'build'), self.expected_build_files)
        self.assertCountEqual(mwdeploy.ChangeTagger.files_of_type(self.path, self.version, 'i18n'), self.expected_i18n_files)

    @patch('mwdeploy._run')
    def test_tags(self, mock_run):
        mock_run.return_value = self._fake_result()
        tags = mwdeploy.ChangeTagger.tags(self.path, self.version)
        self.assertIsInstance(tags, set)
        self.assertCountEqual(tags, {'code change', 'schema change', 'build', 'i18n'})


def test_get_valid_extensions():
    versions_arg = ['version1', 'version2']
    extensions1 = ['Extension1', 'Extension2']
    extensions2 = ['Extension3', 'Extension4']

    with patch('os.scandir') as mock_scandir:
        mock_cm1 = MagicMock()
        mock_cm1.__enter__.return_value = [MagicMock(is_dir=lambda: True) for _ in extensions1]
        for i, ext in enumerate(extensions1):
            setattr(mock_cm1.__enter__.return_value[i], 'name', ext)

        mock_cm2 = MagicMock()
        mock_cm2.__enter__.return_value = [MagicMock(is_dir=lambda: True) for _ in extensions2]
        for i, ext in enumerate(extensions2):
            setattr(mock_cm2.__enter__.return_value[i], 'name', ext)

        mock_scandir.side_effect = [mock_cm1, mock_cm2]

        extensions = mwdeploy.get_valid_extensions(versions_arg)
        assert extensions == extensions1 + extensions2


def test_get_valid_skins():
    versions_arg = ['version1', 'version2']
    skins1 = ['Skins1', 'Skins2']
    skins2 = ['Skins3', 'Skins4']

    with patch('os.scandir') as mock_scandir:
        mock_cm1 = MagicMock()
        mock_cm1.__enter__.return_value = [MagicMock(is_dir=lambda: True) for _ in skins1]
        for i, skin in enumerate(skins1):
            setattr(mock_cm1.__enter__.return_value[i], 'name', skin)

        mock_cm2 = MagicMock()
        mock_cm2.__enter__.return_value = [MagicMock(is_dir=lambda: True) for _ in skins2]
        for i, skin in enumerate(skins2):
            setattr(mock_cm2.__enter__.return_value[i], 'name', skin)

        mock_scandir.side_effect = [mock_cm1, mock_cm2]

        skins = mwdeploy.get_valid_skins(versions_arg)
        assert skins == skins1 + skins2


def test_component_packs_known_pack():
    assert mwdeploy.ComponentPacks.extensions('mleb') == ['Babel', 'cldr', 'CleanChanges', 'Translate', 'UniversalLanguageSelector']
    assert mwdeploy.ComponentPacks.skins('bundled') == ['MinervaNeue', 'MonoBook', 'Timeless', 'Vector']


def test_component_packs_unknown_pack_returns_empty():
    assert mwdeploy.ComponentPacks.extensions('does-not-exist') == []
    assert mwdeploy.ComponentPacks.skins('does-not-exist') == []


class TestPatchApplierMatching(unittest.TestCase):
    def test_matches_core_patch(self):
        sample_patch = {'path': 'REL1_41', 'versions': ['all']}
        with patch.dict(mwdeploy.versions, {'REL1_41': 'REL1_41'}, clear=True):
            assert mwdeploy._patch_applier._matches(sample_patch, 'REL1_41', 'REL1_41') is True

    def test_matches_extension_patch_scoped_to_version(self):
        sample_patch = {'path': 'extensions/Vector', 'versions': ['REL1_41']}
        assert mwdeploy._patch_applier._matches(sample_patch, 'extensions/Vector', 'REL1_41') is True
        assert mwdeploy._patch_applier._matches(sample_patch, 'extensions/Vector', 'REL1_42') is False

    def test_matches_all_versions(self):
        sample_patch = {'path': 'extensions/Vector', 'versions': ['all']}
        assert mwdeploy._patch_applier._matches(sample_patch, 'extensions/Vector', 'REL1_99') is True

    def test_matching_patches_and_has_patches(self):
        fake_patches = [
            {'path': 'extensions/Vector', 'versions': ['REL1_41'], 'public': True, 'file': 'a.patch', 'failureStrategy': 'skip'},
            {'path': 'extensions/Other', 'versions': ['REL1_41'], 'public': True, 'file': 'b.patch', 'failureStrategy': 'skip'},
        ]
        applier = mwdeploy.PatchApplier(fake_patches, mwdeploy._paths, mwdeploy._git)
        assert applier.has_patches('extensions/Vector', 'REL1_41') is True
        assert applier.has_patches('extensions/Missing', 'REL1_41') is False
        matches = applier._matching_patches('extensions/Vector', 'REL1_41')
        assert len(matches) == 1
        assert matches[0]['file'] == 'a.patch'


class TestPatchApplierApply(unittest.TestCase):
    def setUp(self):
        self.applier = mwdeploy.PatchApplier([], mwdeploy._paths, mwdeploy._git)

    def test_apply_git_forward_check_succeeds_applies_for_real(self):
        forward = MagicMock(returncode=0)
        with patch.object(mwdeploy.ShellExecutor, 'run_quiet', return_value=forward), \
             patch('mwdeploy.run_command', return_value=0) as mock_run_command:
            code = self.applier._apply_git('extensions/Bucket', '/patches/public/x.patch', 'REL1_46')
        assert code == 0
        mock_run_command.assert_called_once()

    def test_apply_git_already_applied_detected_via_reverse_check(self):
        forward = MagicMock(returncode=1, stderr='error: patch failed')
        reverse = MagicMock(returncode=0, stderr='')
        with patch.object(mwdeploy.ShellExecutor, 'run_quiet', side_effect=[forward, reverse]), \
             patch('mwdeploy.run_command') as mock_run_command, \
             patch('builtins.print') as mock_print:
            code = self.applier._apply_git('extensions/Bucket', '/patches/public/x.patch', 'REL1_46')
        assert code == 0
        mock_run_command.assert_not_called()
        printed = ' '.join(str(call.args[0]) for call in mock_print.call_args_list)
        assert 'already applied' in printed

    def test_apply_git_real_conflict_strips_noise_and_reports(self):
        forward = MagicMock(returncode=1, stderr="warning: unable to access '/home/x/.config/git/attributes': Permission denied\nerror: patch failed: file.php:1")
        reverse = MagicMock(returncode=1, stderr='')
        with patch.object(mwdeploy.ShellExecutor, 'run_quiet', side_effect=[forward, reverse]), \
             patch('mwdeploy.run_command') as mock_run_command, \
             patch('builtins.print') as mock_print:
            code = self.applier._apply_git('extensions/Bucket', '/patches/public/x.patch', 'REL1_46')
        assert code == 1
        mock_run_command.assert_not_called()
        printed = ' '.join(str(call.args[0]) for call in mock_print.call_args_list)
        assert 'unable to access' not in printed
        assert 'error: patch failed' in printed

    def test_apply_plain_already_applied(self):
        already = MagicMock(returncode=0)
        with patch.object(mwdeploy.ShellExecutor, 'run_quiet', return_value=already), \
             patch('mwdeploy.run_command') as mock_run_command:
            code = self.applier._apply_plain('extensions/SomePackage', '/patches/public/x.patch', 'REL1_46')
        assert code == 0
        mock_run_command.assert_not_called()

    def test_apply_plain_not_already_applied_runs_real_patch(self):
        already = MagicMock(returncode=1)
        with patch.object(mwdeploy.ShellExecutor, 'run_quiet', return_value=already), \
             patch('mwdeploy.run_command', return_value=0) as mock_run_command:
            code = self.applier._apply_plain('extensions/SomePackage', '/patches/public/x.patch', 'REL1_46')
        assert code == 0
        mock_run_command.assert_called_once()

    def test_apply_all_warns_on_missing_patch_file(self):
        fake_patches = [{'path': 'extensions/Vector', 'versions': ['all'], 'public': True, 'file': 'missing.patch', 'failureStrategy': 'skip'}]
        applier = mwdeploy.PatchApplier(fake_patches, mwdeploy._paths, mwdeploy._git)
        with patch('os.path.isfile', return_value=False), patch('builtins.print') as mock_print:
            codes = applier.apply_all('extensions/Vector', 'REL1_41')
        assert codes == []
        printed = ' '.join(str(call.args[0]) for call in mock_print.call_args_list)
        assert 'could not be found' in printed

    def test_apply_all_aborts_on_failure_strategy_abort(self):
        fake_patches = [{'path': 'extensions/Vector', 'versions': ['all'], 'public': True, 'file': 'x.patch', 'failureStrategy': 'abort'}]
        applier = mwdeploy.PatchApplier(fake_patches, mwdeploy._paths, mwdeploy._git)
        with patch('os.path.isfile', return_value=True), \
             patch.object(mwdeploy._git, 'is_repo', return_value=False), \
             patch.object(applier, '_apply_plain', return_value=1):
            with pytest.raises(SystemExit) as excinfo:
                applier.apply_all('extensions/Vector', 'REL1_41')
        assert excinfo.value.code == 1

    def test_apply_all_skips_on_non_abort_failure_strategy(self):
        fake_patches = [{'path': 'extensions/Vector', 'versions': ['all'], 'public': True, 'file': 'x.patch', 'failureStrategy': 'skip'}]
        applier = mwdeploy.PatchApplier(fake_patches, mwdeploy._paths, mwdeploy._git)
        with patch('os.path.isfile', return_value=True), \
             patch.object(mwdeploy._git, 'is_repo', return_value=False), \
             patch.object(applier, '_apply_plain', return_value=1), \
             patch('builtins.print') as mock_print:
            codes = applier.apply_all('extensions/Vector', 'REL1_41')
        assert codes == []
        printed = ' '.join(str(call.args[0]) for call in mock_print.call_args_list)
        assert 'Skipping patch' in printed

    def test_apply_all_records_successful_patches(self):
        fake_patches = [{'path': 'extensions/Vector', 'versions': ['all'], 'public': True, 'file': 'x.patch', 'failureStrategy': 'skip'}]
        applier = mwdeploy.PatchApplier(fake_patches, mwdeploy._paths, mwdeploy._git)
        with patch('os.path.isfile', return_value=True), \
             patch.object(mwdeploy._git, 'is_repo', return_value=False), \
             patch.object(applier, '_apply_plain', return_value=0):
            codes = applier.apply_all('extensions/Vector', 'REL1_41')
        assert codes == [0]


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
    def test_sync_stops_after_a_failing_server(self, mock_run):
        with pytest.raises(SystemExit) as excinfo:
            self.deployer.sync(False, ['mw151', 'mw152', 'mw153'], '/srv/mediawiki/config/', self.envinfo, nolog=True)
        assert excinfo.value.code == 3
        assert mock_run.call_count == 2

    @patch.object(mwdeploy.ShellExecutor, 'run', return_value=0)
    def test_sync_stops_on_canary_failure_even_if_rsync_succeeds(self, mock_run):
        canary = MagicMock()
        canary.check.side_effect = [False, True, True]  # the first server's check fails
        deployer = mwdeploy.RemoteDeployer(self.rsync_builder, canary, hostname='mw151', batch_size=2)

        with pytest.raises(SystemExit) as excinfo:
            deployer.sync(False, ['mw151', 'mw152', 'mw153', 'mw154'], '/srv/mediawiki/config/', self.envinfo, nolog=True)

        assert excinfo.value.code == 3
        assert mock_run.call_count == 1  # only the first server was ever touched

    @patch.object(mwdeploy.ShellExecutor, 'run', return_value=0)
    def test_sync_with_batch_flag_deploys_remaining_servers_together(self, mock_run):
        deployer = mwdeploy.RemoteDeployer(self.rsync_builder, self.canary, hostname='mw151', batch_size=3)
        result = deployer.sync(False, ['mw151', 'mw152', 'mw153', 'mw154'], '/srv/mediawiki/config/', self.envinfo, nolog=True, batch=True)
        assert result == 0
        assert mock_run.call_count == 3

    def test_batches_without_batch_flag_runs_every_server_alone(self):
        deployer = mwdeploy.RemoteDeployer(self.rsync_builder, self.canary, hostname='build', batch_size=2)
        batches = list(deployer._batches(['a', 'b', 'c', 'd', 'e'], batch=False))
        assert batches == [['a'], ['b'], ['c'], ['d'], ['e']]

    def test_batches_with_batch_flag_puts_first_server_alone_then_fixed_size_groups(self):
        deployer = mwdeploy.RemoteDeployer(self.rsync_builder, self.canary, hostname='build', batch_size=2)
        batches = list(deployer._batches(['a', 'b', 'c', 'd', 'e'], batch=True))
        assert batches == [['a'], ['b', 'c'], ['d', 'e']]

    def test_batches_single_target_is_the_same_either_way(self):
        assert list(self.deployer._batches(['only'], batch=True)) == [['only']]
        assert list(self.deployer._batches(['only'], batch=False)) == [['only']]

    def test_batches_no_targets_yields_nothing(self):
        assert list(self.deployer._batches([], batch=True)) == []
        assert list(self.deployer._batches([], batch=False)) == []


def test_build_loginfo_filters_falsy_and_unwraps_single_item_lists() -> None:
    args = argparse.Namespace(pull=None, force=False, servers=['mw151'], versions=['REL1_41'], branch=None)
    runner = mwdeploy.DeploymentRunner(args)
    loginfo = runner._build_loginfo()
    assert loginfo == {'servers': 'mw151', 'versions': 'REL1_41'}


def test_build_loginfo_excludes_pr_repo_when_pr_not_used() -> None:
    args = argparse.Namespace(pr=None, pr_repo='config', servers=['mw151'], versions=['REL1_46'])
    runner = mwdeploy.DeploymentRunner(args)
    loginfo = runner._build_loginfo()
    assert 'pr_repo' not in loginfo


def test_build_loginfo_includes_pr_repo_when_pr_used() -> None:
    args = argparse.Namespace(pr=42, pr_repo='config', servers=['mw151'], versions=['REL1_46'])
    runner = mwdeploy.DeploymentRunner(args)
    loginfo = runner._build_loginfo()
    assert loginfo['pr_repo'] == 'config'
    assert loginfo['pr'] == 42


def test_checkout_pr_fetches_then_checks_out_once() -> None:
    args = argparse.Namespace(pr=42, pr_repo='config')
    runner = mwdeploy.DeploymentRunner(args)
    runner._reset_state()

    with patch('mwdeploy.run_command', return_value=0) as mock_run_command:
        runner._checkout_pr()
        runner._checkout_pr()  # a repeat call (e.g. from a second --versions pass) should be a no-op

    assert mock_run_command.call_count == 2
    fetch_cmd, checkout_cmd = (call.args[0] for call in mock_run_command.call_args_list)
    assert 'fetch origin +pull/42/head:pr-42' in fetch_cmd
    assert 'checkout pr-42' in checkout_cmd
    assert runner._pr_checked_out is True


def test_checkout_pr_does_nothing_without_pr_flag() -> None:
    args = argparse.Namespace(pr=None, pr_repo='config')
    runner = mwdeploy.DeploymentRunner(args)
    runner._reset_state()

    with patch('mwdeploy.run_command') as mock_run_command:
        runner._checkout_pr()

    mock_run_command.assert_not_called()


def test_upgrade_components_processes_more_than_one_batch() -> None:
    # COMPONENT_FETCH_BATCH_SIZE is 20, so 25 items forces two batches through
    # the loop instead of one, as long as --batch is on
    names = [f'Ext{i}' for i in range(25)]
    args = argparse.Namespace(world=False, force=False, force_upgrade=False,
                              skip_schema_confirm=True, show_tags=False, ignore_time=False, batch=True)
    runner = mwdeploy.DeploymentRunner(args)
    runner._reset_state()

    fake_fetch = staticmethod(lambda kind, name, _version: (name, f'{kind}/{name}', 'Already up to date.', 0))  # noqa: U101
    with patch('mwdeploy._git') as mock_git, \
         patch('os.path.exists', return_value=True), \
         patch.object(mwdeploy.DeploymentRunner, '_fetch_component', fake_fetch):
        mock_git.is_repo.return_value = True
        runner._upgrade_components('extensions', names, 'REL1_41')

    # everything reported "already up to date", so nothing should have queued
    # rsync work or recorded a failing exit code, across either batch
    assert runner.exitcodes == []
    assert runner.rsync == []


def test_upgrade_components_uses_thread_pool_when_batch_true() -> None:
    names = ['Ext1', 'Ext2']
    args = argparse.Namespace(world=False, force=False, force_upgrade=False,
                              skip_schema_confirm=True, show_tags=False, ignore_time=False, batch=True)
    runner = mwdeploy.DeploymentRunner(args)
    runner._reset_state()

    fake_fetch = staticmethod(lambda kind, name, _version: (name, f'{kind}/{name}', 'Already up to date.', 0))  # noqa: U101
    with patch('mwdeploy._git') as mock_git, \
         patch('os.path.exists', return_value=True), \
         patch.object(mwdeploy.DeploymentRunner, '_fetch_component', fake_fetch), \
         patch('mwdeploy.ThreadPoolExecutor', wraps=ThreadPoolExecutor) as mock_pool:
        mock_git.is_repo.return_value = True
        runner._upgrade_components('extensions', names, 'REL1_41')

    mock_pool.assert_called_once()


def test_upgrade_components_runs_sequentially_when_batch_false() -> None:
    names = ['Ext1', 'Ext2']
    args = argparse.Namespace(world=False, force=False, force_upgrade=False,
                              skip_schema_confirm=True, show_tags=False, ignore_time=False, batch=False)
    runner = mwdeploy.DeploymentRunner(args)
    runner._reset_state()

    fetch_calls = []

    def fake_fetch(kind, name, _version):
        fetch_calls.append(name)
        return name, f'{kind}/{name}', 'Already up to date.', 0

    with patch('mwdeploy._git') as mock_git, \
         patch('os.path.exists', return_value=True), \
         patch.object(mwdeploy.DeploymentRunner, '_fetch_component', staticmethod(fake_fetch)), \
         patch('mwdeploy.ThreadPoolExecutor') as mock_pool:
        mock_git.is_repo.return_value = True
        runner._upgrade_components('extensions', names, 'REL1_41')

    mock_pool.assert_not_called()
    assert fetch_calls == names


def test_process_component_fetch_already_up_to_date_no_patches(capsys) -> None:
    args = argparse.Namespace(force=False, force_upgrade=False, skip_schema_confirm=True,
                              show_tags=False, ignore_time=False, world=False)
    runner = mwdeploy.DeploymentRunner(args)
    runner._reset_state()
    with patch.object(mwdeploy._patch_applier, 'has_patches', return_value=False), \
         patch.object(mwdeploy._patch_applier, 'apply_all', return_value=[]), \
         patch.object(mwdeploy.ChangeTagger, 'files_of_type', return_value=set()):
        runner._process_component_fetch('Bucket', 'extensions/Bucket', 'Already up to date.', 0, 'REL1_46')
    out = capsys.readouterr().out.lower()
    assert 'already up to date.' in out
    assert 'applying patches' not in out


def test_process_component_fetch_already_up_to_date_with_patches(capsys) -> None:
    args = argparse.Namespace(force=False, force_upgrade=False, skip_schema_confirm=True,
                              show_tags=False, ignore_time=False, world=False)
    runner = mwdeploy.DeploymentRunner(args)
    runner._reset_state()
    with patch.object(mwdeploy._patch_applier, 'has_patches', return_value=True), \
         patch.object(mwdeploy._patch_applier, 'apply_all', return_value=[]), \
         patch.object(mwdeploy.ChangeTagger, 'files_of_type', return_value=set()):
        runner._process_component_fetch('Bucket', 'extensions/Bucket', 'Already up to date.', 0, 'REL1_46')
    assert 'applying patches' in capsys.readouterr().out.lower()


def test_process_component_fetch_updated_prints_upgrading(capsys) -> None:
    args = argparse.Namespace(force=False, force_upgrade=False, skip_schema_confirm=True,
                              show_tags=False, ignore_time=False, world=True)
    runner = mwdeploy.DeploymentRunner(args)
    runner._reset_state()
    with patch.object(mwdeploy._patch_applier, 'apply_all', return_value=[]), \
         patch.object(mwdeploy.ChangeTagger, 'files_of_type', return_value=set()):
        runner._process_component_fetch('Bucket', 'extensions/Bucket', 'Updating...', 0, 'REL1_46')
    assert 'Upgrading Bucket' in capsys.readouterr().out


def test_process_component_fetch_failure_reports_and_stops(capsys) -> None:
    args = argparse.Namespace(force=False)
    runner = mwdeploy.DeploymentRunner(args)
    runner._reset_state()
    runner._process_component_fetch('Bucket', 'extensions/Bucket', '', 1, 'REL1_46')
    assert 'Failed to upgrade Bucket' in capsys.readouterr().out
    assert runner.exitcodes == [1]


def test_process_component_fetch_failure_ignored_when_force(capsys) -> None:
    args = argparse.Namespace(force=True, force_upgrade=True, skip_schema_confirm=True,
                              show_tags=False, ignore_time=False, world=True)
    runner = mwdeploy.DeploymentRunner(args)
    runner._reset_state()
    with patch.object(mwdeploy._patch_applier, 'apply_all', return_value=[]), \
         patch.object(mwdeploy.ChangeTagger, 'files_of_type', return_value=set()):
        runner._process_component_fetch('Bucket', 'extensions/Bucket', '', 1, 'REL1_46')
    # --force means a nonzero status from the fetch itself isn't treated as fatal
    assert runner.exitcodes == []
    assert 'Failed to upgrade' not in capsys.readouterr().out


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


def test_ApplyPatchesAction_requires_versions_first():
    parser = argparse.ArgumentParser()
    parser.add_argument('--versions', action='store', default=None)
    parser.add_argument('--apply-patches', action=ApplyPatchesAction)
    with pytest.raises(SystemExit):
        parser.parse_args(['--apply-patches', 'config'])


def test_ApplyPatchesAction_splits_comma_list():
    parser = argparse.ArgumentParser()
    parser.add_argument('--versions', action='store', default=None)
    parser.add_argument('--apply-patches', action=ApplyPatchesAction)
    namespace = parser.parse_args(['--versions', 'REL1_41', '--apply-patches', 'config,vendor'])
    assert namespace.apply_patches == ['config', 'vendor']


def test_ApplyPatchesAction_all_expands_to_unique_patch_paths():
    parser = argparse.ArgumentParser()
    parser.add_argument('--versions', action='store', default=None)
    parser.add_argument('--apply-patches', action=ApplyPatchesAction)
    fake_patches = [
        {'path': 'extensions/Vector'},
        {'path': 'config'},
        {'path': 'extensions/Vector'},
    ]
    with patch.object(mwdeploy, 'patches', fake_patches):
        namespace = parser.parse_args(['--versions', 'REL1_41', '--apply-patches', 'all'])
    assert namespace.apply_patches == ['config', 'extensions/Vector']


if __name__ == '__main__':
    unittest.main()
