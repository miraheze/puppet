import argparse
import os
import re
import socket
import unittest
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


def _make_args(**overrides):
    defaults = {
        'world': False, 'force': False, 'force_upgrade': False, 'skip_schema_confirm': True,
        'show_tags': False, 'ignore_time': False, 'batch': False, 'pr': None, 'pr_repo': 'config',
    }
    defaults.update(overrides)
    return argparse.Namespace(**defaults)


def _make_runner(**overrides):
    runner = mwdeploy.DeploymentRunner(_make_args(**overrides))
    runner._reset_state()
    return runner


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

    def test_tag_map_keys_are_regexes_and_values_are_strings(self):
        tag_map = mwdeploy.ChangeTagger.TAG_MAP
        self.assertIsInstance(tag_map, dict)
        self.assertTrue(all(isinstance(pattern, type(re.compile(''))) for pattern in tag_map.keys()))
        self.assertTrue(all(isinstance(tag, str) for tag in tag_map.values()))

    def test_tag_map_is_the_shared_module_level_map(self):
        self.assertIs(mwdeploy.ChangeTagger.TAG_MAP, mwdeploy.CHANGE_TAG_MAP)

    @patch('mwdeploy._run')
    def test_changed_files(self, mock_run):
        mock_run.return_value = MagicMock(stdout='\n'.join(self.changed_files))
        changed_files = mwdeploy.ChangeTagger.changed_files(self.path, self.version)
        self.assertIsInstance(changed_files, list)
        self.assertCountEqual(changed_files, self.changed_files)
        mock_run.assert_called_with(f'git -C {self.repo_dir} --no-pager --git-dir={self.repo_dir}/.git diff --name-only HEAD@{{1}} HEAD')

    @patch('mwdeploy._run')
    def test_changed_files_strips_each_line(self, mock_run):
        mock_run.return_value = MagicMock(stdout='  padded.php  \nother.php\n')
        changed_files = mwdeploy.ChangeTagger.changed_files(self.path, self.version)
        self.assertEqual(changed_files, ['padded.php', 'other.php'])

    @patch('mwdeploy._run')
    def test_files_of_type(self, mock_run):
        mock_run.return_value = MagicMock(stdout='\n'.join(self.changed_files))
        codechange_files = mwdeploy.ChangeTagger.files_of_type(self.path, self.version, 'code change')
        schema_files = mwdeploy.ChangeTagger.files_of_type(self.path, self.version, 'schema change')
        build_files = mwdeploy.ChangeTagger.files_of_type(self.path, self.version, 'build')
        i18n_files = mwdeploy.ChangeTagger.files_of_type(self.path, self.version, 'i18n')
        self.assertIsInstance(codechange_files, set)
        self.assertCountEqual(codechange_files, self.expected_codechange_files)
        self.assertCountEqual(schema_files, self.expected_schema_files)
        self.assertCountEqual(build_files, self.expected_build_files)
        self.assertCountEqual(i18n_files, self.expected_i18n_files)

    @patch('mwdeploy._run')
    def test_tags(self, mock_run):
        mock_run.return_value = MagicMock(stdout='\n'.join(self.changed_files))
        tags = mwdeploy.ChangeTagger.tags(self.path, self.version)
        self.assertIsInstance(tags, set)
        self.assertCountEqual(tags, {'code change', 'schema change', 'build', 'i18n'})


class TestComponentPacksAndDiscovery(unittest.TestCase):
    def test_get_valid_extensions(self):
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
            self.assertEqual(extensions, extensions1 + extensions2)

    def test_get_valid_skins(self):
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
            self.assertEqual(skins, skins1 + skins2)

    def test_component_packs_known_pack(self):
        self.assertEqual(
            mwdeploy.ComponentPacks.extensions('mleb'),
            ['Babel', 'cldr', 'CleanChanges', 'Translate', 'UniversalLanguageSelector'],
        )
        self.assertEqual(
            mwdeploy.ComponentPacks.skins('bundled'),
            ['MinervaNeue', 'MonoBook', 'Timeless', 'Vector'],
        )

    def test_component_packs_unknown_pack_returns_empty(self):
        self.assertEqual(mwdeploy.ComponentPacks.extensions('does-not-exist'), [])
        self.assertEqual(mwdeploy.ComponentPacks.skins('does-not-exist'), [])

    def test_environment_info_returns_prod_for_normal_hostnames(self):
        with patch.object(mwdeploy, 'HOSTNAME', 'mw151'):
            self.assertIs(mwdeploy.get_environment_info(), mwdeploy.ENVIRONMENTS['prod'])

    def test_environment_info_returns_beta_for_test_hostnames(self):
        with patch.object(mwdeploy, 'HOSTNAME', 'test151'):
            self.assertIs(mwdeploy.get_environment_info(), mwdeploy.ENVIRONMENTS['beta'])


class TestNonZeroCode(unittest.TestCase):
    def test_only_one_zero(self):
        self.assertFalse(mwdeploy.non_zero_code([0], leave=False))

    def test_multi_zero(self):
        self.assertFalse(mwdeploy.non_zero_code([0, 0], leave=False))

    def test_zero_then_one(self):
        self.assertTrue(mwdeploy.non_zero_code([1, 0], leave=False))

    def test_one_then_one(self):
        self.assertTrue(mwdeploy.non_zero_code([1, 1], leave=False))

    def test_only_one_one(self):
        self.assertTrue(mwdeploy.non_zero_code([1], leave=False))

    def test_leave_exits_on_failure(self):
        with pytest.raises(SystemExit) as excinfo:
            mwdeploy.non_zero_code([1], leave=True)
        assert excinfo.value.code == 1

    @patch('mwdeploy.subprocess.run')
    def test_logs_to_logsalmsg_when_not_nolog(self, mock_subprocess_run):
        with pytest.raises(SystemExit):
            mwdeploy.non_zero_code([1], nolog=False, leave=True)
        mock_subprocess_run.assert_called_once()
        cmd = mock_subprocess_run.call_args.args[0]
        assert 'DEPLOY ABORTED' in cmd

    @patch.object(mwdeploy.ShellExecutor, 'run', return_value=0)
    def test_run_command_delegates_to_shell_executor(self, mock_run):
        result = mwdeploy.run_command('echo hi')
        self.assertEqual(result, 0)
        mock_run.assert_called_once_with('echo hi')

    @patch('mwdeploy.subprocess.run')
    def test_does_not_log_when_nolog(self, mock_subprocess_run):
        with pytest.raises(SystemExit):
            mwdeploy.non_zero_code([1], nolog=True, leave=True)
        mock_subprocess_run.assert_not_called()


class TestSubprocessMigration(unittest.TestCase):
    @patch('mwdeploy.subprocess.run')
    def test_run_helper_uses_shell_and_captures_text(self, mock_subprocess_run):
        mock_subprocess_run.return_value = 'sentinel'
        result = mwdeploy._run('echo hi')
        mock_subprocess_run.assert_called_once_with('echo hi', shell=True, capture_output=True, text=True)
        self.assertEqual(result, 'sentinel')

    @patch('mwdeploy._run')
    def test_load_mw_versions_parses_json_output(self, mock_run):
        mock_run.return_value = MagicMock(stdout='{"REL1_41": "REL1_41", "REL1_42": "REL1_42"}')
        self.assertEqual(mwdeploy._load_mw_versions(), {'REL1_41': 'REL1_41', 'REL1_42': 'REL1_42'})

    @patch('mwdeploy._run')
    def test_load_mw_versions_falls_back_when_command_produces_nothing(self, mock_run):
        mock_run.return_value = MagicMock(stdout='')
        self.assertEqual(mwdeploy._load_mw_versions(), {'version': 'version'})

    def test_load_patches_merges_public_and_private_files(self):
        import json
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            os.makedirs(os.path.join(tmp, 'patches'))
            with open(os.path.join(tmp, 'patches', 'public.json'), 'w') as handle:
                json.dump([{'path': 'config', 'file': 'a.patch'}], handle)
            with open(os.path.join(tmp, 'patches', 'private.json'), 'w') as handle:
                json.dump([{'path': 'vendor', 'file': 'b.patch'}], handle)

            with patch.object(mwdeploy, 'STAGING_ROOT', tmp):
                loaded = mwdeploy._load_patches()

        self.assertEqual(len(loaded), 2)
        self.assertCountEqual([p['file'] for p in loaded], ['a.patch', 'b.patch'])

    def test_load_patches_ignores_missing_files(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            os.makedirs(os.path.join(tmp, 'patches'))
            # neither public.json nor private.json exists here
            with patch.object(mwdeploy, 'STAGING_ROOT', tmp):
                loaded = mwdeploy._load_patches()

        self.assertEqual(loaded, [])

    @patch('mwdeploy.subprocess.run')
    def test_shell_executor_run_success(self, mock_subprocess_run):
        mock_subprocess_run.return_value = MagicMock(returncode=0)
        mwdeploy.Console.enabled = False
        ec = mwdeploy.ShellExecutor.run('echo hi')
        self.assertEqual(ec, 0)
        mock_subprocess_run.assert_called_once_with('echo hi', shell=True)

    @patch('mwdeploy.subprocess.run')
    def test_shell_executor_run_failure(self, mock_subprocess_run):
        mock_subprocess_run.return_value = MagicMock(returncode=1)
        mwdeploy.Console.enabled = False
        ec = mwdeploy.ShellExecutor.run('false')
        self.assertEqual(ec, 1)

    @patch('mwdeploy.subprocess.run')
    def test_shell_executor_run_prints_execute_and_completed(self, mock_subprocess_run):
        mock_subprocess_run.return_value = MagicMock(returncode=0)
        mwdeploy.Console.enabled = False
        with patch('builtins.print') as mock_print:
            mwdeploy.ShellExecutor.run('echo hi')
        printed = '\n'.join(str(call.args[0]) for call in mock_print.call_args_list)
        self.assertIn('Execute: echo hi', printed)
        self.assertIn('Completed (0)', printed)

    @patch('mwdeploy._run')
    def test_shell_executor_run_quiet_delegates_to_run_helper(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout='ok', stderr='')
        result = mwdeploy.ShellExecutor.run_quiet('git status')
        mock_run.assert_called_once_with('git status')
        self.assertEqual(result.returncode, 0)

    @patch('mwdeploy._run')
    def test_fetch_component_returns_name_repo_output_and_returncode(self, mock_run):
        mock_run.return_value = MagicMock(stdout='Already up to date.\n', returncode=0)
        name, repo, output, status = mwdeploy.DeploymentRunner._fetch_component('extensions', 'Foo', 'REL1_41')
        self.assertEqual(name, 'Foo')
        self.assertEqual(repo, 'extensions/Foo')
        self.assertEqual(output, 'Already up to date.')
        self.assertEqual(status, 0)

    @patch('mwdeploy._run')
    def test_fetch_component_nonzero_exit_is_a_plain_int(self, mock_run):
        mock_run.return_value = MagicMock(stdout='', returncode=1)
        _name, _repo, _output, status = mwdeploy.DeploymentRunner._fetch_component('extensions', 'Foo', 'REL1_41')
        self.assertEqual(status, 1)


class TestCanaryChecker(unittest.TestCase):
    def test_no_debug_host_raises(self):
        failed = False
        try:
            mwdeploy.check_up(nolog=True)
        except Exception as e:
            self.assertEqual(str(e), 'Host or Debug must be specified')
            failed = True
        self.assertTrue(failed)

    def test_debug(self):
        if os.getenv('DEBUG_ACCESS_KEY'):
            self.assertTrue(mwdeploy.check_up(nolog=True, Debug='mwtask181', use_cert=False))

    def test_debug_fail(self):
        with pytest.raises(SystemExit) as excinfo:
            mwdeploy.check_up(nolog=True, Debug='mwtask181', domain='httpstatuses.maor.io/500', use_cert=False)
        assert excinfo.value.code == 3

    def test_debug_fail_force(self):
        self.assertTrue(mwdeploy.check_up(nolog=True, Debug='mwtask181', domain='httpstatuses.maor.io/500', force=True, use_cert=False))

    def test_reuses_a_single_session(self):
        checker = mwdeploy.CanaryChecker()
        self.assertIsInstance(checker._session, mwdeploy.requests.Session)
        self.assertIs(checker._session, checker._session)

    def test_check_reports_failure_without_exiting_when_asked(self):
        checker = mwdeploy.CanaryChecker()
        fake_response = MagicMock(status_code=500, text='nope', headers={})
        with patch.object(checker._session, 'get', return_value=fake_response):
            result = checker.check(nolog=True, Debug='mw151', domain='example.org', verify=False, use_cert=False, exit_on_failure=False)
        self.assertFalse(result)

    def test_check_passes_and_returns_true(self):
        checker = mwdeploy.CanaryChecker()
        fake_response = MagicMock(status_code=200, text='mainpageisdomainroot', headers={'X-Served-By': 'mw151'})
        with patch.object(checker._session, 'get', return_value=fake_response):
            result = checker.check(nolog=True, Debug='mw151', domain='example.org', verify=False, use_cert=False)
        self.assertTrue(result)

    @patch('mwdeploy.subprocess.run')
    def test_check_failure_logs_when_not_nolog(self, mock_subprocess_run):
        checker = mwdeploy.CanaryChecker()
        fake_response = MagicMock(status_code=500, text='nope', headers={})
        with patch.object(checker._session, 'get', return_value=fake_response):
            checker.check(nolog=False, Debug='mw151', domain='example.org', verify=False, use_cert=False, exit_on_failure=False)
        mock_subprocess_run.assert_called_once()
        assert 'DEPLOY ABORTED' in mock_subprocess_run.call_args.args[0]

    def test_check_adds_debug_access_key_header_when_env_var_set(self):
        checker = mwdeploy.CanaryChecker()
        fake_response = MagicMock(status_code=200, text='mainpageisdomainroot', headers={'X-Served-By': 'mw151'})
        with patch.object(checker._session, 'get', return_value=fake_response) as mock_get, \
             patch.dict(os.environ, {'DEBUG_ACCESS_KEY': 'secret-key'}):
            checker.check(nolog=True, Debug='mw151', domain='example.org', verify=False, use_cert=False)
        self.assertEqual(mock_get.call_args.kwargs['headers']['X-WikiTide-Debug-Access-Key'], 'secret-key')

    def test_check_skips_entirely_when_forced(self):
        checker = mwdeploy.CanaryChecker()
        with patch.object(checker, '_request') as mock_request:
            result = checker.check(nolog=True, Debug='mw151', force=True, domain='example.org')
        self.assertTrue(result)
        mock_request.assert_not_called()

    def test_request_adds_client_cert_when_use_cert(self):
        checker = mwdeploy.CanaryChecker()
        fake_response = MagicMock(status_code=200)
        with patch.object(checker._session, 'get', return_value=fake_response) as mock_get:
            checker._request('https://', 'example.org', 443, {}, True, True)
        self.assertIn('cert', mock_get.call_args.kwargs)
        self.assertEqual(mock_get.call_args.kwargs['cert'][0], '/etc/ssl/localcerts/mwdeploy.crt')

    def test_request_omits_cert_when_use_cert_false(self):
        checker = mwdeploy.CanaryChecker()
        fake_response = MagicMock(status_code=200)
        with patch.object(checker._session, 'get', return_value=fake_response) as mock_get:
            checker._request('https://', 'example.org', 443, {}, True, False)
        self.assertNotIn('cert', mock_get.call_args.kwargs)

    def test_check_with_host_instead_of_debug_uses_the_local_proxy_path(self):
        checker = mwdeploy.CanaryChecker()
        fake_response = MagicMock(status_code=200, text='mainpageisdomainroot', headers={})
        with patch.object(checker._session, 'get', return_value=fake_response) as mock_get:
            result = checker.check(nolog=True, Host='meta.miraheze.org', verify=False, use_cert=False)
        self.assertTrue(result)
        self.assertIn('localhost', mock_get.call_args.args[0])


class TestPathAndCommandBuilders(unittest.TestCase):
    def test_staging_path(self):
        self.assertEqual(mwdeploy._paths.staging('version'), '/srv/mediawiki-staging/version/')

    def test_deployed_path(self):
        self.assertEqual(mwdeploy._paths.deployed('version'), '/srv/mediawiki/version/')

    def test_deployed_path_version_scoped_component(self):
        self.assertEqual(mwdeploy._paths.deployed('extensions/Foo', 'REL1_41'), '/srv/mediawiki/REL1_41/extensions/Foo')

    def test_rsync_no_location_local_raises(self):
        with pytest.raises(Exception, match='Location must be specified for local rsync.'):
            mwdeploy._rsync_builder.build(time=False, dest='/srv/mediawiki/version/')

    def test_rsync_no_server_remote_raises(self):
        with pytest.raises(Exception, match=re.escape('Error constructing command. Either server was missing or /srv/mediawiki/version/ != /srv/mediawiki/version/')):
            mwdeploy._rsync_builder.build(time=False, dest='/srv/mediawiki/version/', local=False)

    def test_rsync_conflicting_location_and_server_raises(self):
        with pytest.raises(Exception, match=re.escape('Error constructing command. Either server was missing or garbage != /srv/mediawiki/version/')):
            mwdeploy._rsync_builder.build(time=False, dest='/srv/mediawiki/version/', location='garbage', local=False, server='meta')

    def test_rsync_conflicting_location_no_server_raises(self):
        with pytest.raises(Exception, match=re.escape('Error constructing command. Either server was missing or garbage != /srv/mediawiki/version/')):
            mwdeploy._rsync_builder.build(time=False, dest='/srv/mediawiki/version/', location='garbage', local=False)

    def test_rsync_local_dir_update(self):
        assert mwdeploy._rsync_builder.build(time=False, dest='/srv/mediawiki/version/', location='/home/') == 'sudo -u www-data rsync --update -r --delete --exclude=".*" /home/ /srv/mediawiki/version/'

    def test_rsync_local_file_update(self):
        assert mwdeploy._rsync_builder.build(time=False, dest='/srv/mediawiki/version/test.txt', location='/home/test.txt', recursive=False) == 'sudo -u www-data rsync --update --exclude=".*" /home/test.txt /srv/mediawiki/version/test.txt'

    def test_rsync_remote_dir_update(self):
        fqdn = socket.getfqdn()
        domain = '.'.join(fqdn.split('.')[1:])
        assert mwdeploy._rsync_builder.build(time=False, dest='/srv/mediawiki/version/', local=False, server='meta') == f'sudo -u www-data rsync --update -r --delete -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/version/ www-data@meta.{domain}:/srv/mediawiki/version/'

    def test_rsync_remote_file_update(self):
        fqdn = socket.getfqdn()
        domain = '.'.join(fqdn.split('.')[1:])
        assert mwdeploy._rsync_builder.build(time=False, dest='/srv/mediawiki/version/test.txt', recursive=False, local=False, server='meta') == f'sudo -u www-data rsync --update -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/version/test.txt www-data@meta.{domain}:/srv/mediawiki/version/test.txt'

    def test_rsync_local_dir_time(self):
        assert mwdeploy._rsync_builder.build(time=True, dest='/srv/mediawiki/version/', location='/home/') == 'sudo -u www-data rsync --inplace -r --delete --exclude=".*" /home/ /srv/mediawiki/version/'

    def test_rsync_local_file_time(self):
        assert mwdeploy._rsync_builder.build(time=True, dest='/srv/mediawiki/version/test.txt', location='/home/test.txt', recursive=False) == 'sudo -u www-data rsync --inplace --exclude=".*" /home/test.txt /srv/mediawiki/version/test.txt'

    def test_rsync_remote_dir_time(self):
        fqdn = socket.getfqdn()
        domain = '.'.join(fqdn.split('.')[1:])
        assert mwdeploy._rsync_builder.build(time=True, dest='/srv/mediawiki/version/', local=False, server='meta') == f'sudo -u www-data rsync --inplace -r --delete -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/version/ www-data@meta.{domain}:/srv/mediawiki/version/'

    def test_rsync_remote_file_time(self):
        fqdn = socket.getfqdn()
        domain = '.'.join(fqdn.split('.')[1:])
        assert mwdeploy._rsync_builder.build(time=True, dest='/srv/mediawiki/version/test.txt', recursive=False, local=False, server='meta') == f'sudo -u www-data rsync --inplace -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/version/test.txt www-data@meta.{domain}:/srv/mediawiki/version/test.txt'

    def test_git_pull(self):
        assert mwdeploy._git.pull('config') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --quiet'

    def test_git_pull_branch(self):
        assert mwdeploy._git.pull('config', branch='myfunbranch') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull origin myfunbranch --quiet'

    def test_git_pull_skin(self):
        assert mwdeploy._git.pull('skins/Vector', version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/skins/Vector pull --quiet'

    def test_git_pull_skin_no_quiet(self):
        assert mwdeploy._git.pull('skins/Vector', quiet=False, version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/skins/Vector pull 2> /dev/null'

    def test_git_pull_extension_submodules(self):
        assert mwdeploy._git.pull('extensions/VisualEditor', submodules=True, version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/extensions/VisualEditor pull --recurse-submodules --quiet'

    def test_git_pull_extension_submodules_no_quiet(self):
        assert mwdeploy._git.pull('extensions/VisualEditor', submodules=True, quiet=False, version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/extensions/VisualEditor pull --recurse-submodules 2> /dev/null'

    def test_git_pull_branch_submodules(self):
        assert mwdeploy._git.pull('config', submodules=True, branch='test') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --recurse-submodules origin test --quiet'

    def test_git_pull_branch_submodules_no_quiet(self):
        assert mwdeploy._git.pull('config', submodules=True, branch='test', quiet=False) == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ pull --recurse-submodules origin test 2> /dev/null'

    def test_git_reset_revert(self):
        assert mwdeploy._git.reset_revert('extensions/VisualEditor', version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/extensions/VisualEditor reset --hard HEAD@{1}'

    def test_git_reset_hard(self):
        assert mwdeploy._git.reset_hard('vendor', version='version') == 'sudo -u www-data git -C /srv/mediawiki-staging/version/vendor reset --hard'

    def test_git_fetch_pr(self):
        assert mwdeploy._git.fetch_pr('config', 42, 'pr-42') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ fetch origin +pull/42/head:pr-42'

    def test_git_checkout(self):
        assert mwdeploy._git.checkout('config', 'pr-42') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ checkout pr-42'

    def test_git_apply_forward(self):
        assert mwdeploy._git.apply('config', '/patch.diff') == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ apply --index /patch.diff'

    def test_git_apply_check(self):
        assert mwdeploy._git.apply('config', '/patch.diff', check=True) == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ apply --check /patch.diff'

    def test_git_apply_check_reverse(self):
        assert mwdeploy._git.apply('config', '/patch.diff', check=True, reverse=True) == 'sudo -u www-data git -C /srv/mediawiki-staging/config/ apply --check --reverse /patch.diff'

    def test_git_is_repo(self):
        with patch('os.path.isdir', return_value=True) as mock_isdir:
            assert mwdeploy._git.is_repo('config', '') is True
        mock_isdir.assert_called_once_with('/srv/mediawiki-staging/config/.git')

    def test_git_is_repo_false(self):
        with patch('os.path.isdir', return_value=False):
            assert mwdeploy._git.is_repo('config', '') is False

    def test_git_strip_noise_removes_permission_warnings(self):
        text = (
            "warning: unable to access '/home/x/.config/git/attributes': Permission denied\n"
            "error: patch failed: file.php:10\n"
            "error: file.php: patch does not apply"
        )
        cleaned = mwdeploy.GitCommandBuilder.strip_noise(text)
        self.assertNotIn('unable to access', cleaned)
        self.assertIn('patch failed', cleaned)

    def test_git_strip_noise_empty_when_only_noise(self):
        text = "warning: unable to access '/home/x/.config/git/attributes': Permission denied"
        self.assertEqual(mwdeploy.GitCommandBuilder.strip_noise(text), '')

    def test_git_strip_noise_case_insensitive(self):
        text = "Warning: Unable to access something\nreal line"
        self.assertEqual(mwdeploy.GitCommandBuilder.strip_noise(text), 'real line')

    def test_world_reset_remove_staging(self):
        assert mwdeploy._world_reset.remove_staging('version') == 'sudo -u www-data rm -rf /srv/mediawiki-staging/version/'

    def test_world_reset_run_puppet(self):
        assert mwdeploy._world_reset.run_puppet() == 'sudo puppet agent -tv'


class TestPatchApplierMatching(unittest.TestCase):
    def test_core_patch_matches(self):
        sample_patch = {'path': 'REL1_41', 'versions': ['all']}
        with patch.dict(mwdeploy.versions, {'REL1_41': 'REL1_41'}, clear=True):
            self.assertTrue(mwdeploy._patch_applier._matches(sample_patch, 'REL1_41', 'REL1_41'))

    def test_extension_patch_scoped_to_version(self):
        sample_patch = {'path': 'extensions/Vector', 'versions': ['REL1_41']}
        self.assertTrue(mwdeploy._patch_applier._matches(sample_patch, 'extensions/Vector', 'REL1_41'))
        self.assertFalse(mwdeploy._patch_applier._matches(sample_patch, 'extensions/Vector', 'REL1_42'))

    def test_patch_matches_all_versions(self):
        sample_patch = {'path': 'extensions/Vector', 'versions': ['all']}
        self.assertTrue(mwdeploy._patch_applier._matches(sample_patch, 'extensions/Vector', 'REL1_99'))


class TestPatchApplier(unittest.TestCase):
    def setUp(self):
        self.mock_git = MagicMock(spec=mwdeploy.GitCommandBuilder)
        self.mock_git.strip_noise.side_effect = mwdeploy.GitCommandBuilder.strip_noise
        self.mock_git.is_repo.return_value = True
        self.paths = mwdeploy.PathResolver(mwdeploy.repos)
        self.sample_patches = [
            {'path': 'extensions/Foo', 'versions': ['all'], 'public': True, 'file': 'foo.patch', 'failureStrategy': 'skip'},
        ]
        self.applier = mwdeploy.PatchApplier(self.sample_patches, self.paths, self.mock_git)

    def test_has_patches_true_for_matching_repo(self):
        self.assertTrue(self.applier.has_patches('extensions/Foo', 'REL1_41'))

    def test_has_patches_false_for_unrelated_repo(self):
        self.assertFalse(self.applier.has_patches('extensions/Bar', 'REL1_41'))

    def test_matching_patches_returns_only_matches(self):
        matches = self.applier._matching_patches('extensions/Foo', 'REL1_41')
        self.assertEqual(matches, self.sample_patches)
        self.assertEqual(self.applier._matching_patches('extensions/Bar', 'REL1_41'), [])

    @patch('mwdeploy.run_command', return_value=0)
    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_apply_git_applies_cleanly_when_check_passes(self, mock_run_quiet, mock_run_command):
        mock_run_quiet.return_value = MagicMock(returncode=0)
        code = self.applier._apply_git('extensions/Foo', '/patches/public/foo.patch', 'REL1_41')
        self.assertEqual(code, 0)
        mock_run_command.assert_called_once()
        mock_run_quiet.assert_called_once()  # only the forward check ran, no reverse probe needed

    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_apply_git_skips_when_already_applied(self, mock_run_quiet):
        # forward check fails, reverse check succeeds: it's already applied
        mock_run_quiet.side_effect = [MagicMock(returncode=1, stderr=''), MagicMock(returncode=0)]
        code = self.applier._apply_git('extensions/Foo', '/patches/public/foo.patch', 'REL1_41')
        self.assertEqual(code, 0)
        self.assertEqual(mock_run_quiet.call_count, 2)

    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_apply_git_reports_a_real_conflict(self, mock_run_quiet):
        # both forward and reverse fail: this is a genuine conflict, not an
        # already applied patch
        mock_run_quiet.side_effect = [
            MagicMock(returncode=1, stderr='error: patch failed: file.php:1'),
            MagicMock(returncode=1, stderr=''),
        ]
        code = self.applier._apply_git('extensions/Foo', '/patches/public/foo.patch', 'REL1_41')
        self.assertEqual(code, 1)

    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_apply_git_conflict_output_has_noise_stripped(self, mock_run_quiet):
        mock_run_quiet.side_effect = [
            MagicMock(returncode=1, stderr="warning: unable to access foo\nerror: patch failed: file.php:1"),
            MagicMock(returncode=1, stderr=''),
        ]
        with patch('builtins.print') as mock_print:
            self.applier._apply_git('extensions/Foo', '/patches/public/foo.patch', 'REL1_41')
        printed = '\n'.join(str(call.args[0]) for call in mock_print.call_args_list)
        self.assertNotIn('unable to access', printed)
        self.assertIn('patch failed', printed)

    @patch('mwdeploy.run_command', return_value=0)
    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_apply_plain_skips_when_already_applied(self, mock_run_quiet, mock_run_command):
        mock_run_quiet.return_value = MagicMock(returncode=0)
        code = self.applier._apply_plain('vendor', '/patches/public/foo.patch', 'REL1_41')
        self.assertEqual(code, 0)
        mock_run_command.assert_not_called()

    @patch('mwdeploy.run_command', return_value=0)
    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_apply_plain_applies_when_not_already_applied(self, mock_run_quiet, mock_run_command):
        mock_run_quiet.return_value = MagicMock(returncode=1)
        code = self.applier._apply_plain('vendor', '/patches/public/foo.patch', 'REL1_41')
        self.assertEqual(code, 0)
        mock_run_command.assert_called_once()

    def test_apply_all_warns_and_skips_on_missing_patch_file(self):
        with patch('os.path.isfile', return_value=False):
            codes = self.applier.apply_all('extensions/Foo', 'REL1_41')
        self.assertEqual(codes, [])

    def test_apply_all_aborts_on_failure_strategy_abort(self):
        patches = [{'path': 'extensions/Foo', 'versions': ['all'], 'public': True, 'file': 'foo.patch', 'failureStrategy': 'abort'}]
        applier = mwdeploy.PatchApplier(patches, self.paths, self.mock_git)
        with patch('os.path.isfile', return_value=True), \
             patch.object(applier, '_apply_git', return_value=1), \
             pytest.raises(SystemExit) as excinfo:
            applier.apply_all('extensions/Foo', 'REL1_41')
        assert excinfo.value.code == 1

    def test_apply_all_continues_on_failure_strategy_skip(self):
        with patch('os.path.isfile', return_value=True), \
             patch.object(self.applier, '_apply_git', return_value=1):
            codes = self.applier.apply_all('extensions/Foo', 'REL1_41')
        self.assertEqual(codes, [])  # the failing code is never appended, only successes are

    def test_apply_all_uses_plain_patch_for_non_git_repos(self):
        self.mock_git.is_repo.return_value = False
        with patch('os.path.isfile', return_value=True), \
             patch.object(self.applier, '_apply_plain', return_value=0) as mock_apply_plain, \
             patch.object(self.applier, '_apply_git') as mock_apply_git:
            codes = self.applier.apply_all('extensions/Foo', 'REL1_41')
        self.assertEqual(codes, [0])
        mock_apply_plain.assert_called_once()
        mock_apply_git.assert_not_called()

    def test_apply_all_no_matching_patches_is_a_no_op(self):
        codes = self.applier.apply_all('extensions/Bar', 'REL1_41')
        self.assertEqual(codes, [])


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

    @patch.object(mwdeploy.ShellExecutor, 'run', return_value=0)
    def test_sync_defaults_to_one_server_at_a_time_without_batch(self, mock_run):
        # without --batch, every server is its own single item group, so a
        # deploy to several remote servers still means one run() call per
        # server, made one after another rather than grouped
        result = self.deployer.sync(False, ['mw151', 'mw152', 'mw153', 'mw161', 'mw162'], '/srv/mediawiki/config/', self.envinfo, nolog=True)
        assert result == 0
        assert mock_run.call_count == 4

    @patch.object(mwdeploy.ShellExecutor, 'run', side_effect=[0, 1])
    def test_sync_stops_after_a_failing_server(self, mock_run):
        with pytest.raises(SystemExit) as excinfo:
            self.deployer.sync(False, ['mw151', 'mw152', 'mw153'], '/srv/mediawiki/config/', self.envinfo, nolog=True)
        assert excinfo.value.code == 3
        assert mock_run.call_count == 2

    @patch.object(mwdeploy.ShellExecutor, 'run', return_value=0)
    def test_sync_with_batch_groups_targets_and_stops_on_canary_failure(self, mock_run):
        canary = MagicMock()
        canary.check.side_effect = [False, True, True]  # the lone canary server fails its check
        deployer = mwdeploy.RemoteDeployer(self.rsync_builder, canary, hostname='mw151', batch_size=2)

        with pytest.raises(SystemExit) as excinfo:
            deployer.sync(False, ['mw151', 'mw152', 'mw153', 'mw154'], '/srv/mediawiki/config/', self.envinfo, nolog=True, batch=True)

        assert excinfo.value.code == 3
        assert mock_run.call_count == 1  # only the canary server was ever touched

    @patch.object(mwdeploy.ShellExecutor, 'run', return_value=0)
    def test_sync_with_batch_runs_all_targets_when_healthy(self, mock_run):
        result = self.deployer.sync(False, ['mw151', 'mw152', 'mw153', 'mw161', 'mw162'], '/srv/mediawiki/config/', self.envinfo, nolog=True, batch=True)
        assert result == 0
        assert mock_run.call_count == 4

    def test_batches_one_at_a_time_when_batch_off(self):
        batches = list(self.deployer._batches(['a', 'b', 'c'], batch=False))
        assert batches == [['a'], ['b'], ['c']]

    def test_batches_puts_first_server_alone_then_fixed_size_groups_when_batch_on(self):
        deployer = mwdeploy.RemoteDeployer(self.rsync_builder, self.canary, hostname='build', batch_size=2)
        batches = list(deployer._batches(['a', 'b', 'c', 'd', 'e'], batch=True))
        assert batches == [['a'], ['b', 'c'], ['d', 'e']]

    def test_batches_single_target_batch_on(self):
        batches = list(self.deployer._batches(['only'], batch=True))
        assert batches == [['only']]

    def test_batches_single_target_batch_off(self):
        batches = list(self.deployer._batches(['only'], batch=False))
        assert batches == [['only']]

    def test_batches_no_targets_yields_nothing(self):
        assert list(self.deployer._batches([], batch=True)) == []
        assert list(self.deployer._batches([], batch=False)) == []


class TestConsole(unittest.TestCase):
    def setUp(self):
        self._original_enabled = mwdeploy.Console.enabled

    def tearDown(self):
        mwdeploy.Console.enabled = self._original_enabled

    def test_wrap_disabled_returns_plain_text(self):
        mwdeploy.Console.enabled = False
        self.assertEqual(mwdeploy.Console.ok('hello'), 'hello')
        self.assertEqual(mwdeploy.Console.fail('bye'), 'bye')
        self.assertEqual(mwdeploy.Console.header('title'), 'title')

    def test_wrap_enabled_adds_codes_and_resets(self):
        mwdeploy.Console.enabled = True
        result = mwdeploy.Console.ok('hi')
        self.assertTrue(result.startswith(mwdeploy.Console.GREEN))
        self.assertTrue(result.endswith(mwdeploy.Console.RESET))
        self.assertIn('hi', result)

    def test_header_combines_bold_and_cyan(self):
        mwdeploy.Console.enabled = True
        result = mwdeploy.Console.header('title')
        self.assertIn(mwdeploy.Console.BOLD, result)
        self.assertIn(mwdeploy.Console.CYAN, result)

    def test_fail_combines_bold_and_red(self):
        mwdeploy.Console.enabled = True
        result = mwdeploy.Console.fail('bad')
        self.assertIn(mwdeploy.Console.BOLD, result)
        self.assertIn(mwdeploy.Console.RED, result)

    def test_strip_removes_ansi_codes(self):
        colored = f'{mwdeploy.Console.BOLD}{mwdeploy.Console.RED}fail{mwdeploy.Console.RESET}'
        self.assertEqual(mwdeploy.Console.strip(colored), 'fail')

    def test_strip_is_a_no_op_on_plain_text(self):
        self.assertEqual(mwdeploy.Console.strip('plain text'), 'plain text')


class TestProgressBar(unittest.TestCase):
    def setUp(self):
        self._original_enabled = mwdeploy.Console.enabled
        mwdeploy.Console.enabled = False

    def tearDown(self):
        mwdeploy.Console.enabled = self._original_enabled

    def test_update_reports_percentage_and_counts(self):
        bar = mwdeploy.ProgressBar(10, label='ext')
        with patch('builtins.print') as mock_print:
            bar.update(3)
        line = mock_print.call_args.args[0]
        self.assertIn('ext', line)
        self.assertIn('30%', line)
        self.assertIn('(3/10)', line)

    def test_update_clamps_to_total(self):
        bar = mwdeploy.ProgressBar(5)
        with patch('builtins.print') as mock_print:
            bar.update(999)
        line = mock_print.call_args.args[0]
        self.assertIn('100%', line)
        self.assertIn('(5/5)', line)

    def test_zero_total_is_treated_as_one_to_avoid_division_by_zero(self):
        bar = mwdeploy.ProgressBar(0)
        self.assertEqual(bar.total, 1)

    def test_suffix_is_appended(self):
        bar = mwdeploy.ProgressBar(2)
        with patch('builtins.print') as mock_print:
            bar.update(1, suffix='extra info')
        self.assertIn('extra info', mock_print.call_args.args[0])


class TestDeploymentRunnerHelpers(unittest.TestCase):
    def test_build_loginfo_filters_falsy_and_unwraps_single_item_lists(self):
        args = argparse.Namespace(pull=None, force=False, servers=['mw151'], versions=['REL1_41'], branch=None, pr=None, pr_repo='config')
        runner = mwdeploy.DeploymentRunner(args)
        loginfo = runner._build_loginfo()
        self.assertEqual(loginfo, {'servers': 'mw151', 'versions': 'REL1_41'})

    def test_build_loginfo_excludes_pr_repo_when_pr_not_used(self):
        args = argparse.Namespace(pr_repo='config', upgrade_world=True, nolog=True, force=True,
                                  versions=['1.46'], batch=True, upgrade_extensions='all',
                                  upgrade_skins='all', pr=None)
        runner = mwdeploy.DeploymentRunner(args)
        loginfo = runner._build_loginfo()
        self.assertNotIn('pr_repo', loginfo)

    def test_build_loginfo_includes_pr_repo_when_pr_is_used(self):
        args = argparse.Namespace(pr=42, pr_repo='config', nolog=True, versions=['1.46'])
        runner = mwdeploy.DeploymentRunner(args)
        loginfo = runner._build_loginfo()
        self.assertEqual(loginfo['pr_repo'], 'config')
        self.assertEqual(loginfo['pr'], 42)

    def test_checkout_pr_fetches_then_checks_out_once(self):
        args = argparse.Namespace(pr=42, pr_repo='config')
        runner = mwdeploy.DeploymentRunner(args)
        runner._reset_state()

        with patch('mwdeploy.run_command', return_value=0) as mock_run_command:
            runner._checkout_pr()
            runner._checkout_pr()  # a repeat call (e.g. from a second --versions pass) should be a no-op

        self.assertEqual(mock_run_command.call_count, 2)
        fetch_cmd, checkout_cmd = (call.args[0] for call in mock_run_command.call_args_list)
        self.assertIn('fetch origin +pull/42/head:pr-42', fetch_cmd)
        self.assertIn('checkout pr-42', checkout_cmd)
        self.assertTrue(runner._pr_checked_out)

    def test_checkout_pr_does_nothing_without_pr_flag(self):
        args = argparse.Namespace(pr=None, pr_repo='config')
        runner = mwdeploy.DeploymentRunner(args)
        runner._reset_state()

        with patch('mwdeploy.run_command') as mock_run_command:
            runner._checkout_pr()

        mock_run_command.assert_not_called()

    def test_upgrade_components_processes_more_than_one_batch(self):
        # COMPONENT_FETCH_BATCH_SIZE is 20, so 25 items forces two batches
        # through the loop instead of one, even with --batch off (batch size 1)
        names = [f'Ext{i}' for i in range(25)]
        runner = _make_runner()

        fake_fetch = staticmethod(lambda kind, name, _version: (name, f'{kind}/{name}', 'Already up to date.', 0))  # noqa: U101
        with patch('mwdeploy._git') as mock_git, \
             patch('os.path.exists', return_value=True), \
             patch.object(mwdeploy.DeploymentRunner, '_fetch_component', fake_fetch), \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_git.is_repo.return_value = True
            mock_patch_applier.has_patches.return_value = False
            mock_patch_applier.apply_all.return_value = []
            runner._upgrade_components('extensions', names, 'REL1_41')

        # every item is processed across both batches (20 then 5) without a
        # failing exit code, and each queues its rsync regardless of whether
        # git actually pulled anything, since a patch can still change files
        self.assertEqual(runner.exitcodes, [])
        self.assertEqual(len(runner.rsync), 25)

    def test_upgrade_components_does_not_use_a_thread_pool_without_batch(self):
        names = ['Ext1', 'Ext2', 'Ext3']
        runner = _make_runner(batch=False)

        fake_fetch = staticmethod(lambda kind, name, _version: (name, f'{kind}/{name}', 'Already up to date.', 0))  # noqa: U101
        with patch('mwdeploy._git') as mock_git, \
             patch('os.path.exists', return_value=True), \
             patch.object(mwdeploy.DeploymentRunner, '_fetch_component', fake_fetch), \
             patch('mwdeploy._patch_applier') as mock_patch_applier, \
             patch('mwdeploy.ThreadPoolExecutor') as mock_pool:
            mock_git.is_repo.return_value = True
            mock_patch_applier.has_patches.return_value = False
            mock_patch_applier.apply_all.return_value = []
            runner._upgrade_components('extensions', names, 'REL1_41')

        mock_pool.assert_not_called()

    def test_upgrade_components_fetches_everything_with_batch_on(self):
        names = ['Ext1', 'Ext2', 'Ext3']
        runner = _make_runner(batch=True)
        seen = []

        def fake_fetch(kind, name, _version):  # noqa: U101
            seen.append(name)
            return name, f'{kind}/{name}', 'Already up to date.', 0

        with patch('mwdeploy._git') as mock_git, \
             patch('os.path.exists', return_value=True), \
             patch.object(mwdeploy.DeploymentRunner, '_fetch_component', staticmethod(fake_fetch)), \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_git.is_repo.return_value = True
            mock_patch_applier.has_patches.return_value = False
            mock_patch_applier.apply_all.return_value = []
            runner._upgrade_components('extensions', names, 'REL1_41')

        self.assertCountEqual(seen, names)
        self.assertEqual(runner.exitcodes, [])

    def test_upgrade_components_non_git_repo_applies_patches_immediately(self):
        runner = _make_runner()
        with patch('mwdeploy._git') as mock_git, \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_git.is_repo.return_value = False
            mock_patch_applier.apply_all.return_value = [0]
            runner._upgrade_components('extensions', ['Bundled'], 'REL1_41')

        mock_patch_applier.apply_all.assert_called_once_with('extensions/Bundled', 'REL1_41')
        self.assertEqual(len(runner.rsync), 1)  # rsync was queued for the non-git component

    def test_upgrade_components_skips_missing_staging_dir(self):
        runner = _make_runner()
        with patch('mwdeploy._git') as mock_git, \
             patch('os.path.exists', return_value=False):
            mock_git.is_repo.return_value = True
            runner._upgrade_components('extensions', ['Ghost'], 'REL1_41')

        self.assertEqual(runner.rsync, [])
        self.assertEqual(runner.exitcodes, [])

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_reports_applying_patches_when_up_to_date_with_patches(self, mock_patch_applier):
        mock_patch_applier.has_patches.return_value = True
        mock_patch_applier.apply_all.return_value = []
        runner = _make_runner()
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()), \
             patch('builtins.print') as mock_print:
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, 'REL1_41')
        printed = '\n'.join(str(call.args[0]) for call in mock_print.call_args_list)
        self.assertIn('already up to date. Applying patches...', printed)

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_reports_plain_up_to_date_without_patches(self, mock_patch_applier):
        mock_patch_applier.has_patches.return_value = False
        mock_patch_applier.apply_all.return_value = []
        runner = _make_runner()
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()), \
             patch('builtins.print') as mock_print:
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, 'REL1_41')
        printed = '\n'.join(str(call.args[0]) for call in mock_print.call_args_list)
        self.assertIn('already up to date.', printed)
        self.assertNotIn('Applying patches', printed)

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_reports_upgrading_when_output_changed(self, mock_patch_applier):
        mock_patch_applier.has_patches.return_value = False
        mock_patch_applier.apply_all.return_value = []
        runner = _make_runner()
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()), \
             patch('builtins.print') as mock_print:
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Updating abc123..def456', 0, 'REL1_41')
        printed = '\n'.join(str(call.args[0]) for call in mock_print.call_args_list)
        self.assertIn('Upgrading Foo', printed)

    def test_process_component_fetch_records_failure_exit_code(self):
        runner = _make_runner()
        runner._process_component_fetch('Foo', 'extensions/Foo', '', 1, 'REL1_41')
        self.assertEqual(runner.exitcodes, [1])

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_ignores_status_when_force(self, mock_patch_applier):
        mock_patch_applier.has_patches.return_value = False
        mock_patch_applier.apply_all.return_value = []
        runner = _make_runner(force=True)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()):
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 1, 'REL1_41')
        self.assertEqual(runner.exitcodes, [])

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_queues_rsync_unless_world(self, mock_patch_applier):
        mock_patch_applier.has_patches.return_value = False
        mock_patch_applier.apply_all.return_value = []
        runner = _make_runner(world=True)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()):
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, 'REL1_41')
        self.assertEqual(runner.rsync, [])

        runner2 = _make_runner(world=False)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()):
            runner2._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, 'REL1_41')
        self.assertEqual(len(runner2.rsync), 1)

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_records_a_tag_when_show_tags(self, mock_patch_applier):
        mock_patch_applier.has_patches.return_value = False
        mock_patch_applier.apply_all.return_value = []
        runner = _make_runner(show_tags=True)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()), \
             patch('mwdeploy.ChangeTagger.tags', return_value={'code change'}):
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, 'REL1_41')
        self.assertEqual(runner.tagsinfo, ['Tags for Foo: code change'])

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_schema_change_accept_keeps_it(self, mock_patch_applier):
        mock_patch_applier.has_patches.return_value = False
        mock_patch_applier.apply_all.return_value = []
        runner = _make_runner(skip_schema_confirm=False)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value={'sql/patch.sql'}), \
             patch('mwdeploy.run_command') as mock_run_command, \
             patch('builtins.input', return_value='Y'):
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, 'REL1_41')
        self.assertEqual(runner.newschema, ['/srv/mediawiki-staging/REL1_41/extensions/Foo/sql/patch.sql'])
        mock_run_command.assert_not_called()  # accepting the schema change reverts nothing

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_schema_change_decline_reverts(self, mock_patch_applier):
        mock_patch_applier.has_patches.return_value = False
        mock_patch_applier.apply_all.return_value = []
        runner = _make_runner(skip_schema_confirm=False)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value={'sql/patch.sql'}), \
             patch('mwdeploy.run_command', return_value=0) as mock_run_command, \
             patch('builtins.input', return_value='n'):
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, 'REL1_41')
        self.assertEqual(runner.newschema, [])
        mock_run_command.assert_called_once()
        self.assertIn('reset --hard HEAD@{1}', mock_run_command.call_args.args[0])

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_schema_change_only_confirms_once_per_name(self, mock_patch_applier):
        mock_patch_applier.has_patches.return_value = False
        mock_patch_applier.apply_all.return_value = []
        runner = _make_runner(skip_schema_confirm=False)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value={'sql/a.sql', 'sql/b.sql'}), \
             patch('mwdeploy.run_command'), \
             patch('builtins.input', return_value='Y') as mock_input:
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, 'REL1_41')
        mock_input.assert_called_once()

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_skips_confirmation_when_skip_schema_confirm(self, mock_patch_applier):
        mock_patch_applier.has_patches.return_value = False
        mock_patch_applier.apply_all.return_value = []
        runner = _make_runner(skip_schema_confirm=True)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value={'sql/patch.sql'}), \
             patch('builtins.input') as mock_input:
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, 'REL1_41')
        mock_input.assert_not_called()
        self.assertEqual(runner.newschema, [])

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_schema_change_keyboard_interrupt_reverts_and_exits(self, mock_patch_applier):
        mock_patch_applier.has_patches.return_value = False
        mock_patch_applier.apply_all.return_value = []
        runner = _make_runner(skip_schema_confirm=False)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value={'sql/patch.sql'}), \
             patch('mwdeploy.run_command', return_value=0) as mock_run_command, \
             patch('builtins.input', side_effect=KeyboardInterrupt), \
             patch('builtins.print'), \
             pytest.raises(SystemExit) as excinfo:
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, 'REL1_41')
        assert excinfo.value.code == 1
        mock_run_command.assert_called_once()
        self.assertIn('reset --hard HEAD@{1}', mock_run_command.call_args.args[0])

    def test_log_prints_when_nolog(self):
        with patch('builtins.print') as mock_print, \
             patch('mwdeploy.subprocess.run') as mock_subprocess_run:
            mwdeploy.DeploymentRunner._log('hello', nolog=True)
        mock_print.assert_called_once_with('hello')
        mock_subprocess_run.assert_not_called()

    def test_log_sends_to_logsalmsg_with_color_stripped_when_not_nolog(self):
        colored = f'{mwdeploy.Console.BOLD}{mwdeploy.Console.CYAN}deploy started{mwdeploy.Console.RESET}'
        with patch('mwdeploy.subprocess.run') as mock_subprocess_run:
            mwdeploy.DeploymentRunner._log(colored, nolog=False)
        mock_subprocess_run.assert_called_once()
        cmd = mock_subprocess_run.call_args.args[0]
        self.assertIn('deploy started', cmd)
        self.assertNotIn(mwdeploy.Console.BOLD, cmd)
        self.assertNotIn(mwdeploy.Console.RESET, cmd)

    def test_print_summary_shows_tags_and_schema_warnings(self):
        runner = _make_runner()
        runner.tagsinfo = ['Tags for Foo: code change']
        runner.newschema = ['/srv/mediawiki-staging/REL1_41/extensions/Foo/sql/patch.sql']
        with patch('builtins.print') as mock_print:
            runner._print_summary()
        printed = '\n'.join(str(call.args[0]) for call in mock_print.call_args_list)
        self.assertIn('TAGS:', printed)
        self.assertIn('Tags for Foo: code change', printed)
        self.assertIn('NEW SCHEMA CHANGES DETECTED', printed)
        self.assertIn('sql/patch.sql', printed)

    def test_print_summary_prints_nothing_when_empty(self):
        runner = _make_runner()
        with patch('builtins.print') as mock_print:
            runner._print_summary()
        mock_print.assert_not_called()

    def test_pull_named_repos_pulls_and_applies_patches_for_each_repo(self):
        runner = _make_runner()
        with patch('mwdeploy.run_command', return_value=0) as mock_run_command, \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_patch_applier.apply_all.return_value = []
            args = argparse.Namespace(pull='config,landing', branch=None)
            runner.args = args
            runner._pull_named_repos('')
        self.assertEqual(mock_run_command.call_count, 2)
        self.assertEqual(mock_patch_applier.apply_all.call_count, 2)

    def test_pull_named_repos_does_nothing_when_not_set(self):
        runner = _make_runner()
        runner.args = argparse.Namespace(pull=None, branch=None)
        with patch('mwdeploy.run_command') as mock_run_command:
            runner._pull_named_repos('')
        mock_run_command.assert_not_called()

    def test_pull_named_repos_world_is_skipped_without_a_version(self):
        runner = _make_runner()
        runner.args = argparse.Namespace(pull='world', branch=None)
        with patch('mwdeploy.run_command') as mock_run_command:
            runner._pull_named_repos('')  # no version means the world pull has nothing to target yet
        mock_run_command.assert_not_called()

    def test_pull_named_repos_world_pulls_the_version_repo_when_given_one(self):
        runner = _make_runner()
        runner.args = argparse.Namespace(pull='world', branch=None)
        # 'version' is the fallback key mwdeploy.versions resolves to when
        # getMWVersions isn't available, so it's the one guaranteed to exist
        # in mwdeploy.repos here
        with patch('mwdeploy.run_command', return_value=0) as mock_run_command, \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_patch_applier.apply_all.return_value = []
            runner._pull_named_repos('version')
        mock_run_command.assert_called_once()
        self.assertIn('/srv/mediawiki-staging/version/', mock_run_command.call_args.args[0])

    def test_pull_named_repos_reports_invalid_repo_name(self):
        runner = _make_runner()
        runner.args = argparse.Namespace(pull='not-a-real-repo', branch=None)
        with patch('mwdeploy._git') as mock_git, \
             patch('builtins.print') as mock_print:
            mock_git.pull.side_effect = KeyError('not-a-real-repo')
            runner._pull_named_repos('')
        printed = '\n'.join(str(call.args[0]) for call in mock_print.call_args_list)
        self.assertIn('Failed to pull not-a-real-repo due to invalid name', printed)

    def test_upgrade_vendor_does_nothing_when_not_requested(self):
        runner = _make_runner(upgrade_vendor=False)
        with patch('mwdeploy.run_command') as mock_run_command:
            runner._upgrade_vendor('REL1_41')
        mock_run_command.assert_not_called()

    def test_upgrade_vendor_resets_pulls_and_queues_rsync_outside_world(self):
        runner = _make_runner(upgrade_vendor=True, world=False, ignore_time=False)
        with patch('mwdeploy.run_command', return_value=0) as mock_run_command, \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_patch_applier.apply_all.return_value = []
            runner._upgrade_vendor('REL1_41')
        self.assertEqual(mock_run_command.call_count, 2)  # reset --hard, then pull
        self.assertEqual(len(runner.stage), 1)  # the composer update command was queued
        self.assertEqual(len(runner.rsync), 1)
        self.assertEqual(len(runner.rsyncpaths), 1)

    def test_upgrade_vendor_skips_local_rsync_during_a_world_upgrade(self):
        # --world already syncs the whole version tree at once, so vendor
        # doesn't need its own separate composer update or rsync entry
        runner = _make_runner(upgrade_vendor=True, world=True)
        with patch('mwdeploy.run_command', return_value=0), \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_patch_applier.apply_all.return_value = []
            runner._upgrade_vendor('REL1_41')
        self.assertEqual(runner.stage, [])
        self.assertEqual(runner.rsync, [])


class TestArgparseActions(unittest.TestCase):
    def test_upgrade_pack_action(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--upgrade-extensions', action='store_const', const=True, default=False)
        parser.add_argument('--upgrade-skins', action='store_const', const=True, default=False)
        parser.add_argument('--versions', action='store', default=None)
        parser.add_argument('--upgrade-pack', action=UpgradePackAction)
        namespace = parser.parse_args(['--upgrade-pack', 'wikitide'])
        self.assertEqual(
            namespace.upgrade_extensions,
            ['CreateWiki', 'DataDump', 'DiscordNotifications', 'GlobalNewFiles', 'ImportDump', 'IncidentReporting', 'ManageWiki', 'MatomoAnalytics', 'MirahezeMagic', 'PDFEmbed', 'RemovePII', 'RequestCustomDomain', 'RottenLinks', 'WikiDiscover'],
        )

    def test_lang_action(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--l10n', action='store_const', const=True, default=False)
        parser.add_argument('--lang', action=LangAction)

        with pytest.raises(SystemExit):
            parser.parse_args(['--lang', 'invalid_tag'])

        with pytest.raises(SystemExit):
            parser.parse_args(['--lang', 'en,fr'])

        with pytest.raises(SystemExit):
            # l10n is set here, so this exercises the invalid tag check
            # itself rather than the "needs --l10n first" check above
            parser.parse_args(['--l10n', '--lang', 'invalid_tag'])

        namespace = parser.parse_args(['--l10n', '--lang', 'en,fr'])
        self.assertEqual(namespace.lang, 'en,fr')

    def test_servers_action(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--servers', action=ServersAction)
        with pytest.raises(SystemExit):
            parser.parse_args(['--servers', 'invalid_server'])
        namespace = parser.parse_args(['--servers', 'mw151,mw152'])
        self.assertEqual(namespace.servers, ['mw151', 'mw152'])

    def test_servers_action_all_expands_to_every_environment_server(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--servers', action=ServersAction)
        namespace = parser.parse_args(['--servers', 'all'])
        self.assertEqual(namespace.servers, mwdeploy.get_environment_info().servers)

    def test_versions_action(self):
        mwdeploy.versions.clear()
        with patch('os.path.exists', return_value=True), \
             patch.dict(mwdeploy.versions, {'version1': 'version1', 'version2': 'version2'}):
            parser = argparse.ArgumentParser()
            parser.add_argument('--versions', action=VersionsAction)

            with pytest.raises(SystemExit):
                parser.parse_args(['--versions', 'invalid_version'])

            namespace = parser.parse_args(['--versions', 'version1'])
            self.assertEqual(namespace.versions, ['version1'])

            namespace = parser.parse_args(['--versions', 'all'])
            self.assertEqual(namespace.versions, ['version1', 'version2'])

    def test_apply_patches_action_requires_versions_first(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--versions', action='store', default=None)
        parser.add_argument('--apply-patches', dest='apply_patches', action=ApplyPatchesAction)
        with pytest.raises(SystemExit):
            parser.parse_args(['--apply-patches', 'extensions/Foo'])

    def test_apply_patches_action_splits_repo_list(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--versions', action='store', default=None)
        parser.add_argument('--apply-patches', dest='apply_patches', action=ApplyPatchesAction)
        namespace = parser.parse_args(['--versions', 'REL1_41', '--apply-patches', 'extensions/Foo,vendor'])
        self.assertEqual(namespace.apply_patches, ['extensions/Foo', 'vendor'])

    def test_apply_patches_action_all_expands_to_every_unique_patch_path(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--versions', action='store', default=None)
        parser.add_argument('--apply-patches', dest='apply_patches', action=ApplyPatchesAction)
        sample_patches = [{'path': 'extensions/Foo'}, {'path': 'vendor'}, {'path': 'extensions/Foo'}]
        with patch.object(mwdeploy, 'patches', sample_patches):
            namespace = parser.parse_args(['--versions', 'REL1_41', '--apply-patches', 'all'])
        self.assertEqual(namespace.apply_patches, sorted({'extensions/Foo', 'vendor'}))

    def test_batch_flag_defaults_to_false(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--batch', dest='batch', action='store_true')
        self.assertFalse(parser.parse_args([]).batch)
        self.assertTrue(parser.parse_args(['--batch']).batch)


if __name__ == '__main__':
    unittest.main()
