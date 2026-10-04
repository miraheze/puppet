import argparse
import contextlib
import os
import re
import shlex
import socket
import unittest
from types import SimpleNamespace
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
        'debug': False, 'task': None, 'nolog': True, 'servers': ['mw151'], 'versions': None,
        'config': False, 'landing': False, 'errorpages': False, 'reset_world': False,
        'upgrade_world': False, 'upgrade_vendor': False, 'upgrade_extensions': None,
        'upgrade_skins': None, 'upgrade_pack': None, 'apply_patches': None, 'pull': None,
        'branch': None, 'files': None, 'folders': None, 'extension_list': False, 'l10n': False,
        'lang': None, 'port': None, 'new_install': False,
    }
    defaults.update(overrides)
    return argparse.Namespace(**defaults)


def _make_runner(**overrides):
    runner = mwdeploy.DeploymentRunner(_make_args(**overrides))
    runner._reset_state()
    return runner


@contextlib.contextmanager
def _deploy_environment(hostname='mw151'):
    with contextlib.ExitStack() as stack:
        stack.enter_context(patch.object(mwdeploy, 'HOSTNAME', hostname))
        stack.enter_context(patch('os.chdir'))
        environment = SimpleNamespace(
            shell=stack.enter_context(patch('mwdeploy.ShellExecutor.run', return_value=0)),
            applier=stack.enter_context(patch.object(mwdeploy, '_patch_applier')),
            canary=stack.enter_context(patch.object(mwdeploy._default_canary_checker, 'check', return_value=True)),
            sync=stack.enter_context(patch.object(mwdeploy._remote_deployer, 'sync', return_value=0)),
        )
        environment.applier.apply_all.return_value = ([0], False)
        environment.applier.has_patches.return_value = True
        yield environment


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

    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_changed_files(self, mock_run):
        mock_run.return_value = MagicMock(stdout='\n'.join(self.changed_files))
        changed_files = mwdeploy.ChangeTagger.changed_files(self.path, self.version)
        self.assertIsInstance(changed_files, list)
        self.assertCountEqual(changed_files, self.changed_files)
        mock_run.assert_called_with(f'git -C {self.repo_dir} --no-pager --git-dir={self.repo_dir}/.git diff --name-only HEAD@{{1}} HEAD')

    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_changed_files_strips_each_line(self, mock_run):
        mock_run.return_value = MagicMock(stdout='  padded.php  \nother.php\n')
        changed_files = mwdeploy.ChangeTagger.changed_files(self.path, self.version)
        self.assertEqual(changed_files, ['padded.php', 'other.php'])

    @patch('mwdeploy.ShellExecutor.run_quiet')
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

    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_tags(self, mock_run):
        mock_run.return_value = MagicMock(stdout='\n'.join(self.changed_files))
        tags = mwdeploy.ChangeTagger.tags(self.path, self.version)
        self.assertIsInstance(tags, set)
        self.assertCountEqual(tags, {'code change', 'schema change', 'build', 'i18n'})


class TestComponentPacksAndDiscovery(unittest.TestCase):
    def test_discovery_extensions(self):
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

            extensions = mwdeploy.Discovery.extensions(versions_arg)
            self.assertEqual(extensions, extensions1 + extensions2)

    def test_discovery_skins(self):
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

            skins = mwdeploy.Discovery.skins(versions_arg)
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

    def test_discovery_versions_filters_by_existing_staging_dirs(self):
        with patch.dict(mwdeploy.versions, {'v1': 'v1', 'v2': 'v2'}, clear=True), \
             patch('os.path.exists', side_effect=lambda p: p.endswith('v1')):
            self.assertEqual(mwdeploy.Discovery.versions(), ['v1'])

    def test_discovery_patch_paths_dedupes_and_sorts(self):
        with patch.object(mwdeploy, 'patches', [{'path': 'b'}, {'path': 'a'}, {'path': 'a'}]):
            self.assertEqual(mwdeploy.Discovery.patch_paths(), ['a', 'b'])


class TestMarkAll(unittest.TestCase):
    def test_marks_all_when_actual_equals_full(self):
        loginfo = {'servers': ['a', 'b']}
        mwdeploy._mark_all(loginfo, 'servers', ['a', 'b'], ['a', 'b'])
        self.assertEqual(loginfo['servers'], 'all')

    def test_leaves_value_alone_when_not_matching_full(self):
        loginfo = {'servers': ['a']}
        mwdeploy._mark_all(loginfo, 'servers', ['a'], ['a', 'b'])
        self.assertEqual(loginfo['servers'], ['a'])

    def test_no_op_when_key_is_missing(self):
        loginfo = {}
        mwdeploy._mark_all(loginfo, 'servers', ['a'], ['a'])
        self.assertNotIn('servers', loginfo)


class TestSal(unittest.TestCase):
    def test_suffix_is_empty_without_a_task(self):
        with patch.object(mwdeploy.Sal, 'task', None):
            self.assertEqual(mwdeploy.Sal.suffix(), '')

    def test_suffix_names_the_task(self):
        with patch.object(mwdeploy.Sal, 'task', 'T12345'):
            self.assertEqual(mwdeploy.Sal.suffix(), ' (T12345)')

    def test_plain_removes_color_codes(self):
        colored = f'{mwdeploy.Console.BOLD}{mwdeploy.Console.RED}failed{mwdeploy.Console.RESET}'
        self.assertEqual(mwdeploy.Sal.plain(colored), 'failed')

    def test_plain_removes_the_leading_header_arrow(self):
        self.assertEqual(mwdeploy.Sal.plain('==> Starting deploy'), 'Starting deploy')

    def test_plain_keeps_an_arrow_that_is_not_at_the_start(self):
        self.assertEqual(mwdeploy.Sal.plain('moved a ==> b'), 'moved a ==> b')

    def test_plain_removes_double_quotes(self):
        self.assertEqual(mwdeploy.Sal.plain('deploy of "{\'a\': 1}" to test151'), "deploy of {'a': 1} to test151")

    def test_plain_leaves_an_undecorated_message_alone(self):
        self.assertEqual(mwdeploy.Sal.plain('DEPLOY ABORTED: Canary check failed for x'), 'DEPLOY ABORTED: Canary check failed for x')

    def test_command_sends_only_the_plain_text_as_one_argument(self):
        message = mwdeploy.Console.header('==> Starting deploy of "{1}" to test151')
        with patch.object(mwdeploy.Sal, 'task', None):
            command = mwdeploy.Sal.command(message)
        self.assertEqual(shlex.split(command), ['/usr/local/bin/logsalmsg', 'Starting deploy of {1} to test151'])

    def test_command_includes_the_task(self):
        with patch.object(mwdeploy.Sal, 'task', 'T12345'):
            command = mwdeploy.Sal.command('finished deploy')
        self.assertEqual(shlex.split(command), ['/usr/local/bin/logsalmsg', 'finished deploy (T12345)'])

    def test_command_survives_a_real_shell(self):
        import subprocess
        import tempfile

        message = 'finished deploy of {\'a\': 1} > Starting; echo $HOME (odd) | cat'
        with patch.object(mwdeploy.Sal, 'task', 'T12345'):
            command = mwdeploy.Sal.command(message).replace('/usr/local/bin/logsalmsg', 'printf %s', 1)
        with tempfile.TemporaryDirectory() as tmp:
            result = subprocess.run(command, shell=True, capture_output=True, text=True, cwd=tmp)
            self.assertEqual(os.listdir(tmp), [])
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, f'{message} (T12345)')

    def test_log_includes_the_task_when_printing(self):
        with patch.object(mwdeploy.Sal, 'task', 'T12345'), \
             patch('builtins.print') as mock_print:
            mwdeploy.DeploymentRunner._log('hello', nolog=True)
        mock_print.assert_called_once_with('hello (T12345)')

    def test_log_sends_the_message_without_its_display_decoration(self):
        decorated = mwdeploy.Console.header('==> Starting deploy of "{1}" to test151')
        with patch.object(mwdeploy.Sal, 'task', None), \
             patch('mwdeploy.subprocess.run') as mock_subprocess_run:
            mwdeploy.DeploymentRunner._log(decorated, nolog=False)
        self.assertEqual(shlex.split(mock_subprocess_run.call_args.args[0])[1], 'Starting deploy of {1} to test151')

    def test_log_keeps_the_decoration_when_printing(self):
        with patch.object(mwdeploy.Sal, 'task', None), \
             patch('builtins.print') as mock_print:
            mwdeploy.DeploymentRunner._log('==> Starting deploy of "{1}" to test151', nolog=True)
        mock_print.assert_called_once_with('==> Starting deploy of "{1}" to test151')

    def test_log_includes_the_task_when_sending(self):
        with patch.object(mwdeploy.Sal, 'task', 'T12345'), \
             patch('mwdeploy.subprocess.run') as mock_subprocess_run:
            mwdeploy.DeploymentRunner._log('hello', nolog=False)
        self.assertEqual(shlex.split(mock_subprocess_run.call_args.args[0])[1], 'hello (T12345)')

    @patch('mwdeploy.subprocess.run')
    def test_prep_abort_entry_includes_the_task(self, mock_subprocess_run):
        with patch.object(mwdeploy.Sal, 'task', 'T12345'), \
             pytest.raises(SystemExit):
            mwdeploy.ShellExecutor.ensure_all_zero([1], nolog=False, leave=True)
        self.assertEqual(shlex.split(mock_subprocess_run.call_args.args[0])[1], 'DEPLOY ABORTED: Non-Zero Exit Code in prep, see output. (T12345)')

    @patch('mwdeploy.subprocess.run')
    def test_canary_abort_entry_includes_the_task(self, mock_subprocess_run):
        checker = mwdeploy.CanaryChecker()
        fake_response = MagicMock(status_code=500, text='nope', headers={})
        with patch.object(checker._session, 'get', return_value=fake_response), \
             patch.object(mwdeploy.Sal, 'task', 'T12345'):
            checker.check(nolog=False, Debug='mw151', domain='example.org', verify=False, use_cert=False, exit_on_failure=False)
        self.assertEqual(shlex.split(mock_subprocess_run.call_args.args[0])[1], 'DEPLOY ABORTED: Canary check failed for example.org@mw151 (T12345)')


class TestTaskArgument(unittest.TestCase):
    def test_task_id_accepts_a_phorge_task(self):
        self.assertEqual(mwdeploy.task_id('T12345'), 'T12345')

    def test_task_id_rejects_anything_else(self):
        for value in ['', 'T', 't12345', '12345', 'T12a45', 'T12345 ', ' T12345', 'T12345;ls', 'T12345\n', 'T-1']:
            with self.subTest(value=value), \
                 pytest.raises(argparse.ArgumentTypeError, match='invalid task ID'):
                mwdeploy.task_id(value)

    def test_task_flag_parses_through_argparse(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--task', dest='task', type=mwdeploy.task_id)
        self.assertIsNone(parser.parse_args([]).task)
        self.assertEqual(parser.parse_args(['--task', 'T12345']).task, 'T12345')
        with pytest.raises(SystemExit):
            parser.parse_args(['--task', 'nope'])


class TestEnsureAllZero(unittest.TestCase):
    def test_only_one_zero(self):
        self.assertFalse(mwdeploy.ShellExecutor.ensure_all_zero([0], leave=False))

    def test_multi_zero(self):
        self.assertFalse(mwdeploy.ShellExecutor.ensure_all_zero([0, 0], leave=False))

    def test_zero_then_one(self):
        self.assertTrue(mwdeploy.ShellExecutor.ensure_all_zero([1, 0], leave=False))

    def test_one_then_one(self):
        self.assertTrue(mwdeploy.ShellExecutor.ensure_all_zero([1, 1], leave=False))

    def test_only_one_one(self):
        self.assertTrue(mwdeploy.ShellExecutor.ensure_all_zero([1], leave=False))

    def test_leave_exits_on_failure(self):
        with pytest.raises(SystemExit) as excinfo:
            mwdeploy.ShellExecutor.ensure_all_zero([1], leave=True)
        assert excinfo.value.code == 1

    @patch('mwdeploy.subprocess.run')
    def test_logs_to_logsalmsg_when_not_nolog(self, mock_subprocess_run):
        with pytest.raises(SystemExit):
            mwdeploy.ShellExecutor.ensure_all_zero([1], nolog=False, leave=True)
        mock_subprocess_run.assert_called_once()
        cmd = mock_subprocess_run.call_args.args[0]
        assert 'DEPLOY ABORTED' in cmd

    @patch('mwdeploy.subprocess.run')
    def test_does_not_log_when_nolog(self, mock_subprocess_run):
        with pytest.raises(SystemExit):
            mwdeploy.ShellExecutor.ensure_all_zero([1], nolog=True, leave=True)
        mock_subprocess_run.assert_not_called()


class TestSubprocessMigration(unittest.TestCase):
    @patch('mwdeploy.subprocess.run')
    def test_run_quiet_uses_shell_and_captures_text(self, mock_subprocess_run):
        mock_subprocess_run.return_value = 'sentinel'
        result = mwdeploy.ShellExecutor.run_quiet('echo hi')
        mock_subprocess_run.assert_called_once_with('echo hi', shell=True, capture_output=True, text=True)
        self.assertEqual(result, 'sentinel')

    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_load_mw_versions_parses_json_output(self, mock_run):
        mock_run.return_value = MagicMock(stdout='{"REL1_41": "REL1_41", "REL1_42": "REL1_42"}')
        self.assertEqual(mwdeploy._load_mw_versions(), {'REL1_41': 'REL1_41', 'REL1_42': 'REL1_42'})

    @patch('mwdeploy.ShellExecutor.run_quiet')
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

    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_fetch_component_returns_name_repo_output_and_returncode(self, mock_run):
        mock_run.return_value = MagicMock(stdout='Already up to date.\n', returncode=0, stderr='')
        name, repo, output, status, error = mwdeploy.DeploymentRunner._fetch_component('extensions', 'Foo', 'REL1_41')
        self.assertEqual(name, 'Foo')
        self.assertEqual(repo, 'extensions/Foo')
        self.assertEqual(output, 'Already up to date.')
        self.assertEqual(status, 0)
        self.assertEqual(error, '')

    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_fetch_component_nonzero_exit_is_a_plain_int(self, mock_run):
        mock_run.return_value = MagicMock(stdout='', returncode=1, stderr='')
        _name, _repo, _output, status, _error = mwdeploy.DeploymentRunner._fetch_component('extensions', 'Foo', 'REL1_41')
        self.assertEqual(status, 1)

    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_fetch_component_carries_stderr_through(self, mock_run):
        mock_run.return_value = MagicMock(stdout='', returncode=128, stderr='fatal: could not read from remote repository.\n')
        _name, _repo, _output, status, error = mwdeploy.DeploymentRunner._fetch_component('extensions', 'Foo', 'REL1_41')
        self.assertEqual(status, 128)
        self.assertIn('could not read from remote repository', error)


class TestCanaryChecker(unittest.TestCase):
    def test_no_debug_host_raises(self):
        failed = False
        try:
            mwdeploy.CanaryChecker().check(nolog=True)
        except Exception as e:
            self.assertEqual(str(e), 'Host or Debug must be specified')
            failed = True
        self.assertTrue(failed)

    def test_debug(self):
        if os.getenv('DEBUG_ACCESS_KEY'):
            self.assertTrue(mwdeploy.CanaryChecker().check(nolog=True, Debug='mwtask181', use_cert=False))

    def test_debug_fail(self):
        with pytest.raises(SystemExit) as excinfo:
            mwdeploy.CanaryChecker().check(nolog=True, Debug='mwtask181', domain='httpstatuses.maor.io/500', use_cert=False)
        assert excinfo.value.code == 3

    def test_debug_fail_force(self):
        self.assertTrue(mwdeploy.CanaryChecker().check(nolog=True, Debug='mwtask181', domain='httpstatuses.maor.io/500', force=True, use_cert=False))

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

    def test_rsync_requires_at_least_one_path(self):
        with pytest.raises(Exception, match='At least one path must be given.'):
            mwdeploy._rsync_builder.build(False, '/srv/mediawiki-staging', '/srv/mediawiki', [])

    def test_rsync_local_requires_no_server(self):
        with patch('os.path.exists', return_value=False), patch('glob.glob', return_value=[]):
            assert mwdeploy._rsync_builder.build(False, '/srv/mediawiki-staging', '/srv/mediawiki', ['config']) == \
                'sudo -u www-data rsync -R --update -r --delete --exclude=".*" /srv/mediawiki-staging/./config /srv/mediawiki/'

    def test_rsync_remote_without_server_raises(self):
        with pytest.raises(Exception, match='Server must be specified for a remote rsync.'):
            mwdeploy._rsync_builder.build(False, '/srv/mediawiki', '/srv/mediawiki', ['config'], local=False)

    def test_rsync_local_single_path_update(self):
        with patch('os.path.exists', return_value=False), patch('glob.glob', return_value=[]):
            assert mwdeploy._rsync_builder.build(False, '/srv/mediawiki-staging', '/srv/mediawiki', ['version']) == \
                'sudo -u www-data rsync -R --update -r --delete --exclude=".*" /srv/mediawiki-staging/./version /srv/mediawiki/'

    def test_rsync_excludes_a_protected_file_only_when_it_actually_exists(self):
        def exists(path):
            return path == '/srv/mediawiki/config/PrivateSettings.php'

        with patch('os.path.exists', side_effect=exists), patch('glob.glob', return_value=[]):
            with_it = mwdeploy._rsync_builder.build(False, '/srv/mediawiki-staging', '/srv/mediawiki', ['config'])
        self.assertIn('--exclude=PrivateSettings.php', with_it)
        self.assertNotIn('--exclude=OAuth2.key', with_it)

        with patch('os.path.exists', return_value=False), patch('glob.glob', return_value=[]):
            without_it = mwdeploy._rsync_builder.build(False, '/srv/mediawiki-staging', '/srv/mediawiki', ['config'])
        self.assertNotIn('PrivateSettings.php', without_it)
        self.assertNotIn('OAuth2.key', without_it)

    def test_rsync_checks_for_protected_files_under_dest_root_config(self):
        with patch('os.path.exists') as mock_exists, patch('glob.glob', return_value=[]) as mock_glob:
            mock_exists.return_value = False
            mwdeploy._rsync_builder.build(False, '/srv/mediawiki-staging', '/srv/mediawiki', ['config'])
        checked = {call.args[0] for call in mock_exists.call_args_list}
        self.assertEqual(checked, {'/srv/mediawiki/config/PrivateSettings.php', '/srv/mediawiki/config/OAuth2.key'})
        mock_glob.assert_called_once_with('/srv/mediawiki/config/ExtensionMessageFiles-*.php')

    def test_rsync_excludes_extension_message_files_only_when_any_exist(self):
        with patch('os.path.exists', return_value=False), patch('glob.glob', return_value=['/srv/mediawiki/config/ExtensionMessageFiles-1.46.php']):
            with_it = mwdeploy._rsync_builder.build(False, '/srv/mediawiki-staging', '/srv/mediawiki', ['config'])
        self.assertIn('--exclude="ExtensionMessageFiles-*.php"', with_it)

        with patch('os.path.exists', return_value=False), patch('glob.glob', return_value=[]):
            without_it = mwdeploy._rsync_builder.build(False, '/srv/mediawiki-staging', '/srv/mediawiki', ['config'])
        self.assertNotIn('ExtensionMessageFiles', without_it)

    def test_rsync_never_deletes_generated_but_still_deletes_real_stale_files(self):
        import shutil
        import subprocess
        import tempfile

        if shutil.which('rsync') is None:
            self.skipTest('rsync is not installed in this environment')

        with tempfile.TemporaryDirectory() as tmp:
            staging = os.path.join(tmp, 'staging')
            deployed = os.path.join(tmp, 'deployed')
            os.makedirs(os.path.join(staging, 'config'))
            os.makedirs(os.path.join(deployed, 'config'))
            with open(os.path.join(staging, 'config', 'LocalSettings.php'), 'w') as f:
                f.write('public')
            with open(os.path.join(deployed, 'config', 'PrivateSettings.php'), 'w') as f:
                f.write('secret')
            with open(os.path.join(deployed, 'config', 'OAuth2.key'), 'w') as f:
                f.write('secret-key')
            with open(os.path.join(deployed, 'config', 'ExtensionMessageFiles-1.46.php'), 'w') as f:
                f.write('generated by l10n')
            with open(os.path.join(deployed, 'config', 'stale_leftover.php'), 'w') as f:
                f.write('should be removed')

            command = mwdeploy._rsync_builder.build(False, staging, deployed, ['config']).replace('sudo -u www-data ', '', 1)
            result = subprocess.run(command, shell=True, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)

            remaining = set(os.listdir(os.path.join(deployed, 'config')))

        self.assertIn('PrivateSettings.php', remaining)
        self.assertIn('OAuth2.key', remaining)
        self.assertIn('ExtensionMessageFiles-1.46.php', remaining)
        self.assertNotIn('stale_leftover.php', remaining)

    def test_rsync_local_multiple_paths_in_one_call(self):
        with patch('os.path.exists', return_value=False), patch('glob.glob', return_value=[]):
            assert mwdeploy._rsync_builder.build(False, '/srv/mediawiki-staging', '/srv/mediawiki', ['version/extensions/Foo', 'version/extensions/Bar', 'config']) == \
                'sudo -u www-data rsync -R --update -r --delete --exclude=".*" ' \
                '/srv/mediawiki-staging/./version/extensions/Foo /srv/mediawiki-staging/./version/extensions/Bar /srv/mediawiki-staging/./config /srv/mediawiki/'

    def test_rsync_remote_multiple_paths_in_one_call(self):
        fqdn = socket.getfqdn()
        domain = '.'.join(fqdn.split('.')[1:])
        with patch('os.path.exists', return_value=False), patch('glob.glob', return_value=[]):
            assert mwdeploy._rsync_builder.build(False, '/srv/mediawiki', '/srv/mediawiki', ['version/extensions/Foo', 'config'], local=False, server='meta') == \
                f'sudo -u www-data rsync -R --update -r --delete -e "ssh -i /srv/mediawiki-staging/deploykey" ' \
                f'/srv/mediawiki/./version/extensions/Foo /srv/mediawiki/./config www-data@meta.{domain}:/srv/mediawiki/'

    def test_rsync_local_uses_inplace_when_time_is_true(self):
        with patch('os.path.exists', return_value=False), patch('glob.glob', return_value=[]):
            assert mwdeploy._rsync_builder.build(True, '/srv/mediawiki-staging', '/srv/mediawiki', ['config']) == \
                'sudo -u www-data rsync -R --inplace -r --delete --exclude=".*" /srv/mediawiki-staging/./config /srv/mediawiki/'

    def test_rsync_remote_uses_inplace_when_time_is_true(self):
        fqdn = socket.getfqdn()
        domain = '.'.join(fqdn.split('.')[1:])
        with patch('os.path.exists', return_value=False), patch('glob.glob', return_value=[]):
            assert mwdeploy._rsync_builder.build(True, '/srv/mediawiki', '/srv/mediawiki', ['config'], local=False, server='meta') == \
                f'sudo -u www-data rsync -R --inplace -r --delete -e "ssh -i /srv/mediawiki-staging/deploykey" /srv/mediawiki/./config www-data@meta.{domain}:/srv/mediawiki/'

    def test_git_pull(self):
        assert mwdeploy._git.pull('config') == 'sudo -H -u www-data git -C /srv/mediawiki-staging/config/ pull --quiet'

    def test_git_pull_branch(self):
        assert mwdeploy._git.pull('config', branch='myfunbranch') == 'sudo -H -u www-data git -C /srv/mediawiki-staging/config/ pull origin myfunbranch --quiet'

    def test_git_pull_skin(self):
        assert mwdeploy._git.pull('skins/Vector', version='version') == 'sudo -H -u www-data git -C /srv/mediawiki-staging/version/skins/Vector pull --quiet'

    def test_git_pull_skin_no_quiet(self):
        assert mwdeploy._git.pull('skins/Vector', quiet=False, version='version') == 'sudo -H -u www-data git -C /srv/mediawiki-staging/version/skins/Vector pull'

    def test_git_pull_extension_submodules(self):
        assert mwdeploy._git.pull('extensions/VisualEditor', submodules=True, version='version') == 'sudo -H -u www-data git -C /srv/mediawiki-staging/version/extensions/VisualEditor pull --recurse-submodules --quiet'

    def test_git_pull_extension_submodules_no_quiet(self):
        assert mwdeploy._git.pull('extensions/VisualEditor', submodules=True, quiet=False, version='version') == 'sudo -H -u www-data git -C /srv/mediawiki-staging/version/extensions/VisualEditor pull --recurse-submodules'

    def test_git_pull_branch_submodules(self):
        assert mwdeploy._git.pull('config', submodules=True, branch='test') == 'sudo -H -u www-data git -C /srv/mediawiki-staging/config/ pull --recurse-submodules origin test --quiet'

    def test_git_pull_branch_submodules_no_quiet(self):
        assert mwdeploy._git.pull('config', submodules=True, branch='test', quiet=False) == 'sudo -H -u www-data git -C /srv/mediawiki-staging/config/ pull --recurse-submodules origin test'

    def test_git_reset_revert(self):
        assert mwdeploy._git.reset_revert('extensions/VisualEditor', version='version') == 'sudo -H -u www-data git -C /srv/mediawiki-staging/version/extensions/VisualEditor reset --hard HEAD@{1}'

    def test_git_reset_hard(self):
        assert mwdeploy._git.reset_hard('vendor', version='version') == 'sudo -H -u www-data git -C /srv/mediawiki-staging/version/vendor reset --hard'

    def test_git_fetch_pr(self):
        assert mwdeploy._git.fetch_pr('config', 42, 'pr-42') == 'sudo -H -u www-data git -C /srv/mediawiki-staging/config/ fetch origin +pull/42/head:pr-42'

    def test_git_checkout(self):
        assert mwdeploy._git.checkout('config', 'pr-42') == 'sudo -H -u www-data git -C /srv/mediawiki-staging/config/ checkout pr-42'

    def test_git_apply_forward(self):
        assert mwdeploy._git.apply('config', '/patch.diff') == 'sudo -H -u www-data git -C /srv/mediawiki-staging/config/ apply --index /patch.diff'

    def test_git_apply_check(self):
        assert mwdeploy._git.apply('config', '/patch.diff', check=True) == 'sudo -H -u www-data git -C /srv/mediawiki-staging/config/ apply --check /patch.diff'

    def test_git_apply_check_reverse(self):
        assert mwdeploy._git.apply('config', '/patch.diff', check=True, reverse=True) == 'sudo -H -u www-data git -C /srv/mediawiki-staging/config/ apply --check --reverse /patch.diff'

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

    def test_git_strip_noise_keeps_a_real_fatal_error_sharing_the_same_phrase(self):
        text = (
            "warning: unable to access '/home/x/.config/git/attributes': Permission denied\n"
            "fatal: unable to access 'https://github.com/wikimedia/Foo.git/': Could not resolve host: github.com"
        )
        cleaned = mwdeploy.GitCommandBuilder.strip_noise(text)
        self.assertNotIn('.config/git/attributes', cleaned)
        self.assertIn('Could not resolve host', cleaned)

    def test_world_reset_remove_staging(self):
        assert mwdeploy._world_reset.remove_staging('version') == 'sudo -u www-data rm -rf /srv/mediawiki-staging/version/'

    def test_world_reset_run_puppet(self):
        assert mwdeploy._world_reset.run_puppet() == 'sudo puppet agent -tv'


class TestPatchApplierMatching(unittest.TestCase):
    def test_core_patch_matches_its_own_version(self):
        sample_patch = {'path': 'REL1_41', 'versions': ['all']}
        with patch.dict(mwdeploy.versions, {'REL1_41': 'REL1_41'}, clear=True):
            self.assertTrue(mwdeploy._patch_applier._matches(sample_patch, 'REL1_41', 'REL1_41'))

    def test_core_patch_does_not_match_a_different_version(self):
        sample_patch = {'path': 'REL1_45', 'versions': ['all']}
        with patch.dict(mwdeploy.versions, {'REL1_45': 'REL1_45', 'REL1_46': 'REL1_46'}, clear=True):
            self.assertFalse(mwdeploy._patch_applier._matches(sample_patch, 'REL1_45', 'REL1_46'))

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

    @patch('mwdeploy.ShellExecutor.run', return_value=0)
    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_apply_git_applies_cleanly_when_check_passes(self, mock_run_helper, mock_shell_run):
        mock_run_helper.return_value = MagicMock(returncode=0)
        code, changed = self.applier._apply_git('extensions/Foo', '/patches/public/foo.patch', 'REL1_41')
        self.assertEqual(code, 0)
        self.assertTrue(changed)
        mock_shell_run.assert_called_once()
        mock_run_helper.assert_called_once()

    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_apply_git_skips_when_already_applied(self, mock_run_helper):
        mock_run_helper.side_effect = [MagicMock(returncode=1, stderr=''), MagicMock(returncode=0)]
        code, changed = self.applier._apply_git('extensions/Foo', '/patches/public/foo.patch', 'REL1_41')
        self.assertEqual(code, 0)
        self.assertFalse(changed)
        self.assertEqual(mock_run_helper.call_count, 2)

    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_apply_git_reports_a_real_conflict(self, mock_run_helper):
        mock_run_helper.side_effect = [
            MagicMock(returncode=1, stderr='error: patch failed: file.php:1'),
            MagicMock(returncode=1, stderr=''),
        ]
        code, changed = self.applier._apply_git('extensions/Foo', '/patches/public/foo.patch', 'REL1_41')
        self.assertEqual(code, 1)
        self.assertFalse(changed)

    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_apply_git_conflict_output_has_noise_stripped(self, mock_run_helper):
        mock_run_helper.side_effect = [
            MagicMock(returncode=1, stderr="warning: unable to access foo\nerror: patch failed: file.php:1"),
            MagicMock(returncode=1, stderr=''),
        ]
        with patch('builtins.print') as mock_print:
            self.applier._apply_git('extensions/Foo', '/patches/public/foo.patch', 'REL1_41')
        printed = '\n'.join(str(call.args[0]) for call in mock_print.call_args_list)
        self.assertNotIn('unable to access', printed)
        self.assertIn('patch failed', printed)

    @patch('mwdeploy.ShellExecutor.run', return_value=0)
    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_apply_plain_skips_when_already_applied(self, mock_run_helper, mock_shell_run):
        mock_run_helper.return_value = MagicMock(returncode=0)
        code, changed = self.applier._apply_plain('vendor', '/patches/public/foo.patch', 'REL1_41')
        self.assertEqual(code, 0)
        self.assertFalse(changed)
        mock_shell_run.assert_not_called()

    @patch('mwdeploy.ShellExecutor.run', return_value=0)
    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_apply_plain_applies_when_not_already_applied(self, mock_run_helper, mock_shell_run):
        mock_run_helper.return_value = MagicMock(returncode=1)
        code, changed = self.applier._apply_plain('vendor', '/patches/public/foo.patch', 'REL1_41')
        self.assertEqual(code, 0)
        self.assertTrue(changed)
        mock_shell_run.assert_called_once()

    @patch('mwdeploy.ShellExecutor.run', return_value=0)
    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_apply_all_reports_changed_when_a_patch_is_actually_applied(self, mock_run_helper, mock_shell_run):
        mock_run_helper.return_value = MagicMock(returncode=0)
        with patch('os.path.isfile', return_value=True):
            codes, changed = self.applier.apply_all('extensions/Foo', 'REL1_41')
        self.assertEqual(codes, [0])
        self.assertTrue(changed)
        mock_shell_run.assert_called_once()

    @patch('mwdeploy.ShellExecutor.run_quiet')
    def test_apply_all_reports_unchanged_when_everything_already_applied(self, mock_run_helper):
        mock_run_helper.side_effect = [MagicMock(returncode=1, stderr=''), MagicMock(returncode=0)]
        with patch('os.path.isfile', return_value=True):
            codes, changed = self.applier.apply_all('extensions/Foo', 'REL1_41')
        self.assertEqual(codes, [0])
        self.assertFalse(changed)

    def test_apply_all_reports_unchanged_when_nothing_matches(self):
        codes, changed = self.applier.apply_all('extensions/Bar', 'REL1_41')
        self.assertEqual(codes, [])
        self.assertFalse(changed)

    def test_apply_all_warns_and_skips_on_missing_patch_file(self):
        with patch('os.path.isfile', return_value=False):
            codes, _ = self.applier.apply_all('extensions/Foo', 'REL1_41')
        self.assertEqual(codes, [])

    def test_apply_all_aborts_on_failure_strategy_abort(self):
        patches = [{'path': 'extensions/Foo', 'versions': ['all'], 'public': True, 'file': 'foo.patch', 'failureStrategy': 'abort'}]
        applier = mwdeploy.PatchApplier(patches, self.paths, self.mock_git)
        with patch('os.path.isfile', return_value=True), \
             patch.object(applier, '_apply_git', return_value=(1, False)), \
             pytest.raises(SystemExit) as excinfo:
            applier.apply_all('extensions/Foo', 'REL1_41')
        assert excinfo.value.code == 1

    def test_apply_all_continues_on_failure_strategy_skip(self):
        with patch('os.path.isfile', return_value=True), \
             patch.object(self.applier, '_apply_git', return_value=(1, False)):
            codes, _ = self.applier.apply_all('extensions/Foo', 'REL1_41')
        self.assertEqual(codes, [])

    def test_apply_all_uses_plain_patch_for_non_git_repos(self):
        self.mock_git.is_repo.return_value = False
        with patch('os.path.isfile', return_value=True), \
             patch.object(self.applier, '_apply_plain', return_value=(0, True)) as mock_apply_plain, \
             patch.object(self.applier, '_apply_git') as mock_apply_git:
            codes, _ = self.applier.apply_all('extensions/Foo', 'REL1_41')
        self.assertEqual(codes, [0])
        mock_apply_plain.assert_called_once()
        mock_apply_git.assert_not_called()

    def test_apply_all_no_matching_patches_is_a_no_op(self):
        codes, _ = self.applier.apply_all('extensions/Bar', 'REL1_41')
        self.assertEqual(codes, [])


class TestApplyExtraPatches(unittest.TestCase):
    def _runner_with(self, apply_patches):
        runner = _make_runner()
        runner.args = argparse.Namespace(apply_patches=apply_patches, ignore_time=False)
        return runner

    def test_skips_repo_with_no_matching_patches_for_this_version(self):
        runner = self._runner_with(['extensions/Foo'])
        with patch.object(mwdeploy, '_patch_applier') as mock_patch_applier:
            mock_patch_applier.has_patches.return_value = False
            runner._apply_extra_patches('REL1_41')
        mock_patch_applier.apply_all.assert_not_called()
        self.assertEqual(runner.rsync, [])
        self.assertEqual(runner.exitcodes, [])

    def test_applies_and_queues_rsync_for_a_matching_repo(self):
        runner = self._runner_with(['extensions/Foo'])
        with patch.object(mwdeploy, '_patch_applier') as mock_patch_applier:
            mock_patch_applier.has_patches.return_value = True
            mock_patch_applier.apply_all.return_value = ([0], False)
            runner._apply_extra_patches('REL1_41')
        mock_patch_applier.apply_all.assert_called_once_with('extensions/Foo', 'REL1_41')
        self.assertEqual(len(runner.rsync), 1)
        self.assertEqual(len(runner.rsyncpaths), 1)

    def test_records_the_exit_codes_from_applying_patches(self):
        runner = self._runner_with(['extensions/Foo'])
        with patch.object(mwdeploy, '_patch_applier') as mock_patch_applier:
            mock_patch_applier.has_patches.return_value = True
            mock_patch_applier.apply_all.return_value = ([7], False)
            runner._apply_extra_patches('REL1_41')
        self.assertEqual(runner.exitcodes, [7])

    def test_apply_patches_all_only_processes_the_repo_matching_the_current_version(self):
        runner = self._runner_with(['1.45', '1.46'])
        with patch.dict(mwdeploy.repos, {'1.45': '1.45', '1.46': '1.46'}), \
             patch.object(mwdeploy, '_patch_applier') as mock_patch_applier:
            mock_patch_applier.has_patches.side_effect = lambda repo, version: repo == version
            mock_patch_applier.apply_all.return_value = ([0], False)
            runner._apply_extra_patches('1.46')
        mock_patch_applier.apply_all.assert_called_once_with('1.46', '1.46')
        self.assertEqual(len(runner.rsync), 1)
        self.assertIn('1.46', runner.rsync[0])
        self.assertNotIn('1.45', runner.rsync[0])


class TestRemoteDeployer(unittest.TestCase):
    def setUp(self):
        self.canary = MagicMock()
        self.rsync_builder = mwdeploy.RsyncCommandBuilder()
        self.deployer = mwdeploy.RemoteDeployer(self.rsync_builder, self.canary, hostname='mw151', max_workers=4)
        self.envinfo = mwdeploy.Environment(wikidbname='testwiki', wikiurl='publictestwiki.com', servers=['mw151', 'mw152', 'mw153'])

    @patch.object(mwdeploy.ShellExecutor, 'run', return_value=0)
    def test_sync_skips_self_and_deploys_to_others(self, mock_run):
        result = self.deployer.sync(False, ['mw151', 'mw152', 'mw153'], ['config'], '/srv/mediawiki', self.envinfo, nolog=True)
        assert result == 0
        assert mock_run.call_count == 2
        commands = [call.args[0] for call in mock_run.call_args_list]
        assert any('@mw152.' in cmd for cmd in commands)
        assert any('@mw153.' in cmd for cmd in commands)

    @patch.object(mwdeploy.ShellExecutor, 'run', return_value=0)
    def test_sync_continues_past_self_mid_list(self, mock_run):
        self.deployer.sync(False, ['mw152', 'mw151', 'mw153'], ['config'], '/srv/mediawiki', self.envinfo, nolog=True)
        assert mock_run.call_count == 2
        commands = [call.args[0] for call in mock_run.call_args_list]
        assert not any('@mw151.' in cmd for cmd in commands)

    def test_sync_with_no_remote_targets_returns_zero(self):
        result = self.deployer.sync(False, ['mw151'], ['config'], '/srv/mediawiki', self.envinfo, nolog=True)
        assert result == 0

    @patch.object(mwdeploy.ShellExecutor, 'run', return_value=0)
    def test_sync_carries_every_path_in_one_rsync_call_per_server(self, mock_run):
        paths = [f'version/extensions/Ext{i}' for i in range(10)] + ['cache/version/gitinfo']
        self.deployer.sync(False, ['mw151', 'mw152'], paths, '/srv/mediawiki', self.envinfo, nolog=True)
        assert mock_run.call_count == 1  # one remote target (mw152), one rsync call
        cmd = mock_run.call_args.args[0]
        for path in paths:
            self.assertIn(f'/srv/mediawiki/./{path}', cmd)

    def test_sync_checks_canary_once_per_server_no_matter_how_many_paths(self):
        with patch.object(mwdeploy.ShellExecutor, 'run', return_value=0):
            self.deployer.sync(False, ['mw151', 'mw152'], ['config', 'version', 'cache/version/gitinfo'], '/srv/mediawiki', self.envinfo, nolog=True)
        self.canary.check.assert_called_once()

    @patch.object(mwdeploy.ShellExecutor, 'run', return_value=0)
    def test_sync_defaults_to_one_server_at_a_time_without_batch(self, mock_run):
        result = self.deployer.sync(False, ['mw151', 'mw152', 'mw153', 'mw161', 'mw162'], ['config'], '/srv/mediawiki', self.envinfo, nolog=True)
        assert result == 0
        assert mock_run.call_count == 4

    @patch.object(mwdeploy.ShellExecutor, 'run', side_effect=[0, 1])
    def test_sync_stops_after_a_failing_server(self, mock_run):
        with pytest.raises(SystemExit) as excinfo:
            self.deployer.sync(False, ['mw151', 'mw152', 'mw153'], ['config'], '/srv/mediawiki', self.envinfo, nolog=True)
        assert excinfo.value.code == 3
        assert mock_run.call_count == 2

    @patch.object(mwdeploy.ShellExecutor, 'run', return_value=0)
    def test_sync_with_batch_groups_targets_and_stops_on_canary_failure(self, mock_run):
        canary = MagicMock()
        canary.check.side_effect = [False, True, True]
        deployer = mwdeploy.RemoteDeployer(self.rsync_builder, canary, hostname='mw151', batch_size=2)

        with pytest.raises(SystemExit) as excinfo:
            deployer.sync(False, ['mw151', 'mw152', 'mw153', 'mw154'], ['config'], '/srv/mediawiki', self.envinfo, nolog=True, batch=True)

        assert excinfo.value.code == 3
        assert mock_run.call_count == 1

    @patch.object(mwdeploy.ShellExecutor, 'run', return_value=0)
    def test_sync_with_batch_runs_all_targets_when_healthy(self, mock_run):
        result = self.deployer.sync(False, ['mw151', 'mw152', 'mw153', 'mw161', 'mw162'], ['config'], '/srv/mediawiki', self.envinfo, nolog=True, batch=True)
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
    def test_new_install_builds_the_full_path_list_from_discovery(self):
        runner = _make_runner(new_install=True, servers=['mw152'], ignore_time=False, batch=False)
        with patch.object(mwdeploy.Discovery, 'versions', return_value=['REL1_41', 'REL1_42']), \
             patch.object(mwdeploy._remote_deployer, 'sync', return_value=0) as mock_sync:
            codes = runner._new_install()
        self.assertEqual(codes, [0])
        self.assertEqual(
            mock_sync.call_args.args[2],
            ['REL1_41', 'REL1_42', 'config', 'landing', 'ErrorPages', 'cache/databases.php'],
        )

    def test_new_install_works_with_no_versions_discovered(self):
        runner = _make_runner(new_install=True, servers=['mw152'])
        with patch.object(mwdeploy.Discovery, 'versions', return_value=[]), \
             patch.object(mwdeploy._remote_deployer, 'sync', return_value=0) as mock_sync:
            runner._new_install()
        self.assertEqual(mock_sync.call_args.args[2], ['config', 'landing', 'ErrorPages', 'cache/databases.php'])

    def test_new_install_returns_the_sync_exit_code(self):
        runner = _make_runner(new_install=True, servers=['mw152'])
        with patch.object(mwdeploy.Discovery, 'versions', return_value=[]), \
             patch.object(mwdeploy._remote_deployer, 'sync', return_value=3):
            self.assertEqual(runner._new_install(), [3])

    def test_new_install_hardcodes_inplace_even_when_ignore_time_is_false(self):
        runner = _make_runner(new_install=True, servers=['mw152'], ignore_time=False)
        with patch.object(mwdeploy.Discovery, 'versions', return_value=[]), \
             patch.object(mwdeploy._remote_deployer, 'sync', return_value=0) as mock_sync:
            runner._new_install()
        self.assertTrue(mock_sync.call_args.args[0])

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

    def test_run_sets_the_task_used_for_every_log_entry(self):
        args = _make_args(
            task='T12345', upgrade_world=False, reset_world=False, servers=['mw151'], l10n=False,
            extension_list=False, upgrade_extensions=None, upgrade_skins=None, upgrade_vendor=False,
            apply_patches=None, versions=None, upgrade_pack=None, nolog=True,
        )
        runner = mwdeploy.DeploymentRunner(args)
        with patch.object(mwdeploy.Sal, 'task', None), \
             patch.object(runner, 'process', return_value=[]), \
             patch.object(runner, '_log') as mock_log:
            runner.run(0.0)
            self.assertEqual(mwdeploy.Sal.task, 'T12345')
        self.assertEqual(mock_log.call_count, 2)

    def test_build_loginfo_leaves_the_task_out_since_it_is_added_to_the_entry_itself(self):
        args = argparse.Namespace(task='T12345', servers=['mw151'], pr=None, pr_repo='config')
        runner = mwdeploy.DeploymentRunner(args)
        self.assertEqual(runner._build_loginfo(), {'servers': 'mw151'})

    def test_checkout_pr_fetches_then_checks_out_once(self):
        args = argparse.Namespace(pr=42, pr_repo='config')
        runner = mwdeploy.DeploymentRunner(args)
        runner._reset_state()

        with patch('mwdeploy.ShellExecutor.run', return_value=0) as mock_shell_run:
            runner._checkout_pr()
            runner._checkout_pr()

        self.assertEqual(mock_shell_run.call_count, 2)
        fetch_cmd, checkout_cmd = (call.args[0] for call in mock_shell_run.call_args_list)
        self.assertIn('fetch origin +pull/42/head:pr-42', fetch_cmd)
        self.assertIn('checkout pr-42', checkout_cmd)
        self.assertTrue(runner._pr_checked_out)

    def test_checkout_pr_does_nothing_without_pr_flag(self):
        args = argparse.Namespace(pr=None, pr_repo='config')
        runner = mwdeploy.DeploymentRunner(args)
        runner._reset_state()

        with patch('mwdeploy.ShellExecutor.run') as mock_shell_run:
            runner._checkout_pr()

        mock_shell_run.assert_not_called()

    def test_upgrade_components_processes_more_than_one_batch(self):
        names = [f'Ext{i}' for i in range(25)]
        runner = _make_runner()

        fake_fetch = staticmethod(lambda kind, name, _version: (name, f'{kind}/{name}', 'Already up to date.', 0, ''))  # noqa: U101
        with patch('mwdeploy._git') as mock_git, \
             patch('os.path.exists', return_value=True), \
             patch.object(mwdeploy.DeploymentRunner, '_fetch_component', fake_fetch), \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_git.is_repo.return_value = True
            mock_patch_applier.apply_all.return_value = ([], False)
            runner._upgrade_components('extensions', names, 'REL1_41')

        self.assertEqual(runner.exitcodes, [])
        self.assertEqual(runner.rsync, [])

    def test_upgrade_components_does_not_use_a_thread_pool_without_batch(self):
        names = ['Ext1', 'Ext2', 'Ext3']
        runner = _make_runner(batch=False)

        fake_fetch = staticmethod(lambda kind, name, _version: (name, f'{kind}/{name}', 'Already up to date.', 0, ''))  # noqa: U101
        with patch('mwdeploy._git') as mock_git, \
             patch('os.path.exists', return_value=True), \
             patch.object(mwdeploy.DeploymentRunner, '_fetch_component', fake_fetch), \
             patch('mwdeploy._patch_applier') as mock_patch_applier, \
             patch('mwdeploy.ThreadPoolExecutor') as mock_pool:
            mock_git.is_repo.return_value = True
            mock_patch_applier.apply_all.return_value = ([], False)
            runner._upgrade_components('extensions', names, 'REL1_41')

        mock_pool.assert_not_called()

    def test_upgrade_components_fetches_everything_with_batch_on(self):
        names = ['Ext1', 'Ext2', 'Ext3']
        runner = _make_runner(batch=True)
        seen = []

        def fake_fetch(kind, name, _version):  # noqa: U101
            seen.append(name)
            return name, f'{kind}/{name}', 'Already up to date.', 0, ''

        with patch('mwdeploy._git') as mock_git, \
             patch('os.path.exists', return_value=True), \
             patch.object(mwdeploy.DeploymentRunner, '_fetch_component', staticmethod(fake_fetch)), \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_git.is_repo.return_value = True
            mock_patch_applier.apply_all.return_value = ([], False)
            runner._upgrade_components('extensions', names, 'REL1_41')

        self.assertCountEqual(seen, names)
        self.assertEqual(runner.exitcodes, [])

    def test_upgrade_components_non_git_repo_applies_patches_immediately(self):
        runner = _make_runner()
        with patch('mwdeploy._git') as mock_git, \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_git.is_repo.return_value = False
            mock_patch_applier.apply_all.return_value = ([0], False)
            runner._upgrade_components('extensions', ['Bundled'], 'REL1_41')

        mock_patch_applier.apply_all.assert_called_once_with('extensions/Bundled', 'REL1_41')
        self.assertEqual(len(runner.rsync), 1)

    def test_upgrade_components_skips_missing_staging_dir(self):
        runner = _make_runner()
        with patch('mwdeploy._git') as mock_git, \
             patch('os.path.exists', return_value=False):
            mock_git.is_repo.return_value = True
            runner._upgrade_components('extensions', ['Ghost'], 'REL1_41')

        self.assertEqual(runner.rsync, [])
        self.assertEqual(runner.exitcodes, [])

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_reports_applying_patches_when_a_patch_actually_applies(self, mock_patch_applier):
        mock_patch_applier.apply_all.return_value = ([0], True)
        runner = _make_runner()
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()), \
             patch('builtins.print') as mock_print:
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, '', 'REL1_41')
        printed = '\n'.join(str(call.args[0]) for call in mock_print.call_args_list)
        self.assertIn('already up to date. Applying patches...', printed)
        self.assertEqual(len(runner.rsync), 1)

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_reports_plain_up_to_date_when_nothing_changed(self, mock_patch_applier):
        mock_patch_applier.apply_all.return_value = ([], False)
        runner = _make_runner()
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()), \
             patch('builtins.print') as mock_print:
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, '', 'REL1_41')
        printed = '\n'.join(str(call.args[0]) for call in mock_print.call_args_list)
        self.assertIn('already up to date.', printed)
        self.assertNotIn('Applying patches', printed)
        self.assertEqual(runner.rsync, [])

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_reports_plain_up_to_date_when_a_patch_was_already_applied(self, mock_patch_applier):
        mock_patch_applier.apply_all.return_value = ([0], False)
        runner = _make_runner()
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()), \
             patch('builtins.print') as mock_print:
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, '', 'REL1_41')
        printed = '\n'.join(str(call.args[0]) for call in mock_print.call_args_list)
        self.assertIn('already up to date.', printed)
        self.assertNotIn('Applying patches', printed)
        self.assertEqual(runner.rsync, [])

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_reports_upgrading_when_output_changed(self, mock_patch_applier):
        mock_patch_applier.apply_all.return_value = ([], False)
        runner = _make_runner()
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()), \
             patch('builtins.print') as mock_print:
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Updating abc123..def456', 0, '', 'REL1_41')
        printed = '\n'.join(str(call.args[0]) for call in mock_print.call_args_list)
        self.assertIn('Upgrading Foo', printed)
        self.assertEqual(len(runner.rsync), 1)

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_force_upgrade_queues_rsync_even_with_no_changes(self, mock_patch_applier):
        mock_patch_applier.apply_all.return_value = ([], False)
        runner = _make_runner(force_upgrade=True)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()):
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, '', 'REL1_41')
        self.assertEqual(len(runner.rsync), 1)

    def test_process_component_fetch_records_failure_exit_code(self):
        runner = _make_runner()
        runner._process_component_fetch('Foo', 'extensions/Foo', '', 1, '', 'REL1_41')
        self.assertEqual(runner.exitcodes, [1])

    def test_process_component_fetch_force_prevents_a_fetch_failure_from_counting_but_still_skips_it(self):
        runner = _make_runner(force=True)
        with patch.object(mwdeploy, '_patch_applier') as mock_patch_applier:
            runner._process_component_fetch('Foo', 'extensions/Foo', '', 128, '', 'REL1_41')
        self.assertEqual(runner.exitcodes, [])
        self.assertEqual(runner.rsync, [])
        mock_patch_applier.apply_all.assert_not_called()

    def test_process_component_fetch_records_fetch_failure_without_force(self):
        runner = _make_runner(force=False)
        with patch.object(mwdeploy, '_patch_applier') as mock_patch_applier:
            runner._process_component_fetch('Foo', 'extensions/Foo', '', 128, '', 'REL1_41')
        self.assertEqual(runner.exitcodes, [128])
        self.assertEqual(runner.rsync, [])
        mock_patch_applier.apply_all.assert_not_called()

    def test_process_component_fetch_hides_failure_detail_without_debug(self):
        runner = _make_runner(force=True, debug=False)
        error = "fatal: unable to access 'https://github.com/wikimedia/Foo.git/': Could not resolve host: github.com"
        with patch('builtins.print') as mock_print:
            runner._process_component_fetch('Foo', 'extensions/Foo', '', 128, error, 'REL1_41')
        printed = '\n'.join(str(call.args[0]) for call in mock_print.call_args_list)
        self.assertIn('Failed to upgrade Foo', printed)
        self.assertNotIn('Could not resolve host', printed)

    def test_process_component_fetch_shows_failure_detail_with_debug(self):
        runner = _make_runner(force=True, debug=True)
        error = (
            "warning: unable to access '/home/x/.config/git/attributes': Permission denied\n"
            "fatal: unable to access 'https://github.com/wikimedia/Foo.git/': Could not resolve host: github.com"
        )
        with patch('builtins.print') as mock_print:
            runner._process_component_fetch('Foo', 'extensions/Foo', '', 128, error, 'REL1_41')
        printed = '\n'.join(str(call.args[0]) for call in mock_print.call_args_list)
        self.assertIn('Could not resolve host', printed)
        self.assertNotIn('.config/git/attributes', printed)

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_world_never_queues_rsync_even_with_a_real_change(self, mock_patch_applier):
        mock_patch_applier.apply_all.return_value = ([], False)
        runner = _make_runner(world=True)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()):
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Updating abc..def', 0, '', 'REL1_41')
        self.assertEqual(runner.rsync, [])

        runner2 = _make_runner(world=False)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()):
            runner2._process_component_fetch('Foo', 'extensions/Foo', 'Updating abc..def', 0, '', 'REL1_41')
        self.assertEqual(len(runner2.rsync), 1)

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_records_a_tag_when_show_tags(self, mock_patch_applier):
        mock_patch_applier.apply_all.return_value = ([], False)
        runner = _make_runner(show_tags=True)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()), \
             patch('mwdeploy.ChangeTagger.tags', return_value={'code change'}):
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, '', 'REL1_41')
        self.assertEqual(runner.tagsinfo, ['Tags for Foo: code change'])

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_schema_change_accept_keeps_it(self, mock_patch_applier):
        mock_patch_applier.apply_all.return_value = ([], False)
        runner = _make_runner(skip_schema_confirm=False)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value={'sql/patch.sql'}), \
             patch('mwdeploy.ShellExecutor.run') as mock_shell_run, \
             patch('builtins.input', return_value='Y'):
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, '', 'REL1_41')
        self.assertEqual(runner.newschema, ['/srv/mediawiki-staging/REL1_41/extensions/Foo/sql/patch.sql'])
        mock_shell_run.assert_not_called()

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_schema_change_decline_reverts(self, mock_patch_applier):
        mock_patch_applier.apply_all.return_value = ([], False)
        runner = _make_runner(skip_schema_confirm=False)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value={'sql/patch.sql'}), \
             patch('mwdeploy.ShellExecutor.run', return_value=0) as mock_shell_run, \
             patch('builtins.input', return_value='n'):
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, '', 'REL1_41')
        self.assertEqual(runner.newschema, [])
        mock_shell_run.assert_called_once()
        self.assertIn('reset --hard HEAD@{1}', mock_shell_run.call_args.args[0])

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_schema_change_only_confirms_once_per_name(self, mock_patch_applier):
        mock_patch_applier.apply_all.return_value = ([], False)
        runner = _make_runner(skip_schema_confirm=False)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value={'sql/a.sql', 'sql/b.sql'}), \
             patch('mwdeploy.ShellExecutor.run'), \
             patch('builtins.input', return_value='Y') as mock_input:
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, '', 'REL1_41')
        mock_input.assert_called_once()

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_skips_confirmation_when_skip_schema_confirm(self, mock_patch_applier):
        mock_patch_applier.apply_all.return_value = ([], False)
        runner = _make_runner(skip_schema_confirm=True)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value={'sql/patch.sql'}), \
             patch('builtins.input') as mock_input:
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, '', 'REL1_41')
        mock_input.assert_not_called()
        self.assertEqual(runner.newschema, [])

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_schema_change_keyboard_interrupt_reverts_and_exits(self, mock_patch_applier):
        mock_patch_applier.apply_all.return_value = ([], False)
        runner = _make_runner(skip_schema_confirm=False)
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value={'sql/patch.sql'}), \
             patch('mwdeploy.ShellExecutor.run', return_value=0) as mock_shell_run, \
             patch('builtins.input', side_effect=KeyboardInterrupt), \
             patch('builtins.print'), \
             pytest.raises(SystemExit) as excinfo:
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, '', 'REL1_41')
        assert excinfo.value.code == 1
        mock_shell_run.assert_called_once()
        self.assertIn('reset --hard HEAD@{1}', mock_shell_run.call_args.args[0])

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
        with patch('mwdeploy.ShellExecutor.run', return_value=0) as mock_shell_run, \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_patch_applier.apply_all.return_value = ([], False)
            args = argparse.Namespace(pull='config,landing', branch=None)
            runner.args = args
            runner._pull_named_repos('')
        self.assertEqual(mock_shell_run.call_count, 2)
        self.assertEqual(mock_patch_applier.apply_all.call_count, 2)

    def test_pull_named_repos_does_nothing_when_not_set(self):
        runner = _make_runner()
        runner.args = argparse.Namespace(pull=None, branch=None)
        with patch('mwdeploy.ShellExecutor.run') as mock_shell_run:
            runner._pull_named_repos('')
        mock_shell_run.assert_not_called()

    def test_pull_named_repos_world_is_skipped_without_a_version(self):
        runner = _make_runner()
        runner.args = argparse.Namespace(pull='world', branch=None)
        with patch('mwdeploy.ShellExecutor.run') as mock_shell_run:
            runner._pull_named_repos('')
        mock_shell_run.assert_not_called()

    def test_pull_named_repos_world_pulls_the_version_repo_when_given_one(self):
        runner = _make_runner()
        runner.args = argparse.Namespace(pull='world', branch=None)
        with patch('mwdeploy.ShellExecutor.run', return_value=0) as mock_shell_run, \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_patch_applier.apply_all.return_value = ([], False)
            runner._pull_named_repos('version')
        mock_shell_run.assert_called_once()
        self.assertIn('/srv/mediawiki-staging/version/', mock_shell_run.call_args.args[0])

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
        with patch('mwdeploy.ShellExecutor.run') as mock_shell_run:
            runner._upgrade_vendor('REL1_41')
        mock_shell_run.assert_not_called()

    def test_upgrade_vendor_resets_pulls_and_queues_rsync_outside_world(self):
        runner = _make_runner(upgrade_vendor=True, world=False, ignore_time=False)
        with patch('mwdeploy.ShellExecutor.run', return_value=0) as mock_shell_run, \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_patch_applier.apply_all.return_value = ([], False)
            runner._upgrade_vendor('REL1_41')
        self.assertEqual(mock_shell_run.call_count, 2)
        self.assertEqual(len(runner.stage), 1)
        self.assertEqual(len(runner.rsync), 1)
        self.assertEqual(len(runner.rsyncpaths), 1)

    def test_upgrade_vendor_records_the_exit_codes_from_applying_patches(self):
        runner = _make_runner(upgrade_vendor=True, world=False)
        with patch('mwdeploy.ShellExecutor.run', return_value=0), \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_patch_applier.apply_all.return_value = ([7], False)
            runner._upgrade_vendor('REL1_41')
        self.assertIn(7, runner.exitcodes)

    def test_pull_named_repos_records_the_exit_codes_from_applying_patches(self):
        runner = _make_runner()
        runner.args = argparse.Namespace(pull='config', branch=None)
        with patch('mwdeploy.ShellExecutor.run', return_value=0), \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_patch_applier.apply_all.return_value = ([7], False)
            runner._pull_named_repos('')
        self.assertIn(7, runner.exitcodes)

    def test_upgrade_components_non_git_repo_records_the_exit_codes_from_applying_patches(self):
        runner = _make_runner()
        with patch('mwdeploy._git') as mock_git, \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_git.is_repo.return_value = False
            mock_patch_applier.apply_all.return_value = ([7], False)
            runner._upgrade_components('extensions', ['Bundled'], 'REL1_41')
        self.assertEqual(runner.exitcodes, [7])

    @patch('mwdeploy._patch_applier')
    def test_process_component_fetch_records_the_exit_codes_from_applying_patches(self, mock_patch_applier):
        mock_patch_applier.apply_all.return_value = ([7], False)
        runner = _make_runner()
        with patch('mwdeploy.ChangeTagger.files_of_type', return_value=set()):
            runner._process_component_fetch('Foo', 'extensions/Foo', 'Already up to date.', 0, '', 'REL1_41')
        self.assertEqual(runner.exitcodes, [7])

    def test_upgrade_vendor_skips_local_rsync_during_a_world_upgrade(self):
        runner = _make_runner(upgrade_vendor=True, world=True)
        with patch('mwdeploy.ShellExecutor.run', return_value=0), \
             patch('mwdeploy._patch_applier') as mock_patch_applier:
            mock_patch_applier.apply_all.return_value = ([], False)
            runner._upgrade_vendor('REL1_41')
        self.assertEqual(runner.stage, [])
        self.assertEqual(runner.rsync, [])


class TestProcess(unittest.TestCase):
    def assertCommandsInOrder(self, commands, *fragments):
        position = 0
        for fragment in fragments:
            matches = [index for index, command in enumerate(commands) if fragment in command and index >= position]
            self.assertTrue(matches, f'{fragment!r} not found after position {position} in {commands}')
            position = matches[0] + 1

    def test_gitinfo_is_pushed_directly_from_deployed_root_with_no_local_copy(self):
        runner = _make_runner(upgrade_extensions=['Foo'])
        with _deploy_environment() as env, \
             patch.object(mwdeploy.DeploymentRunner, '_upgrade_components') as mock_components:
            def fake_upgrade_components(kind, items, version):  # noqa: U100
                runner._needs_version_cache_rebuild = True
            mock_components.side_effect = fake_upgrade_components
            runner.process('version')

        commands = [call.args[0] for call in env.shell.call_args_list]
        self.assertTrue(any('RebuildVersionCache' in cmd for cmd in commands))
        self.assertFalse(any(cmd.startswith('sudo -u www-data rsync -R') for cmd in commands))  # nothing local to copy
        env.sync.assert_called_once()
        self.assertEqual(env.sync.call_args.args[2], ['cache/version/gitinfo'])
        self.assertEqual(env.sync.call_args.args[3], '/srv/mediawiki')

    def test_versioned_pass_runs_every_step_in_order_on_the_local_server(self):
        runner = _make_runner(
            reset_world=True, upgrade_vendor=True, upgrade_extensions=['Foo'], apply_patches=['config'],
            extension_list=True, l10n=True, lang='en,fr',
        )
        patches = [{'path': 'config'}, {'path': 'vendor'}, {'path': 'config'}]
        with _deploy_environment() as env, \
             patch.object(mwdeploy, 'patches', patches), \
             patch.object(mwdeploy.DeploymentRunner, '_upgrade_components') as mock_components:
            codes = runner.process('version')

        commands = [call.args[0] for call in env.shell.call_args_list]
        self.assertCommandsInOrder(
            commands,
            'rm -rf /srv/mediawiki-staging/version/',
            'puppet agent',
            'composer update',
            'composer update',
            'rsync -R --update -r --delete',
            'MergeMessageFileList',
            'RebuildVersionCache',
            'RebuildExtensionListCache',
            'rebuildLocalisationCache.php --lang=en,fr',
        )
        self.assertIn(
            'sudo -u www-data rsync -R --update -r --delete --exclude=".*" '
            '/srv/mediawiki-staging/./version/vendor /srv/mediawiki-staging/./version /srv/mediawiki-staging/./config /srv/mediawiki/',
            commands,
        )
        self.assertIn(
            'sudo -u www-data php /srv/mediawiki/version/maintenance/run.php MirahezeMagic:MergeMessageFileList '
            '--quiet --wiki=testwiki --extensions-dir=/srv/mediawiki/version/extensions:/srv/mediawiki/version/skins '
            '--output /srv/mediawiki/config/ExtensionMessageFiles-version.php',
            commands,
        )
        mock_components.assert_called_once_with('extensions', ['Foo'], 'version')
        self.assertEqual(
            [call.args for call in env.applier.apply_all.call_args_list],
            [('vendor', 'version'), ('config', 'version'), ('vendor', 'version'), ('config', 'version')],
        )
        env.sync.assert_called_once()
        self.assertEqual(
            env.sync.call_args.args[2],
            ['version/vendor', 'cache/version/gitinfo', 'config', 'version', 'cache/version/extension-list.php', 'cache/version/l10n'],
        )
        self.assertEqual(env.sync.call_args.args[3], '/srv/mediawiki')
        env.canary.assert_called_once_with(Debug=None, Host=runner.envinfo.wikiurl, verify=False, force=False, nolog=True)
        self.assertEqual(set(codes), {0})

    def test_unversioned_pass_deploys_config_landing_errorpages_files_and_folders(self):
        runner = _make_runner(config=True, landing=True, errorpages=True, files='a.txt,b.txt', folders='dir1,dir2')
        with _deploy_environment() as env:
            codes = runner.process()

        commands = [call.args[0] for call in env.shell.call_args_list]
        self.assertEqual(commands, [
            'sudo -u www-data rsync -R --update -r --delete --exclude=".*" '
            '/srv/mediawiki-staging/./config /srv/mediawiki-staging/./landing /srv/mediawiki-staging/./ErrorPages '
            '/srv/mediawiki-staging/./a.txt /srv/mediawiki-staging/./b.txt /srv/mediawiki-staging/./dir1 /srv/mediawiki-staging/./dir2 /srv/mediawiki/',
        ])
        env.sync.assert_called_once()
        self.assertEqual(
            env.sync.call_args.args[2],
            ['config', 'landing', 'ErrorPages', 'a.txt', 'b.txt', 'dir1', 'dir2'],
        )
        self.assertEqual(env.sync.call_args.args[3], '/srv/mediawiki')
        self.assertEqual(set(codes), {0})

    def test_unversioned_pass_does_not_rebuild_the_version_cache(self):
        runner = _make_runner(config=True)
        with _deploy_environment() as env:
            runner.process()
        commands = [call.args[0] for call in env.shell.call_args_list]
        self.assertFalse(any('RebuildVersionCache' in command for command in commands))

    def test_a_server_that_is_not_the_deploy_target_only_syncs_to_the_fleet(self):
        runner = _make_runner(config=True, servers=['mw152'])
        with _deploy_environment(hostname='mw151') as env:
            runner.process()
        env.shell.assert_not_called()
        env.canary.assert_not_called()
        self.assertEqual([call.args[2] for call in env.sync.call_args_list], [['config']])

    def test_canary_check_uses_the_port_when_one_is_given(self):
        runner = _make_runner(config=True, port=8080)
        with _deploy_environment() as env:
            runner.process()
        env.canary.assert_called_once_with(Debug=None, Host=runner.envinfo.wikiurl, verify=False, force=False, nolog=True, port=8080)

    def test_a_failing_command_aborts_the_pass(self):
        runner = _make_runner(config=True)
        with _deploy_environment() as env:
            env.shell.return_value = 1
            with pytest.raises(SystemExit) as excinfo:
                runner.process()
        assert excinfo.value.code == 1
        env.sync.assert_not_called()


class TestRun(unittest.TestCase):
    def setUp(self):
        for patcher in (
            patch.object(mwdeploy.Console, 'enabled', False),
            patch.object(mwdeploy.Sal, 'task', None),
            patch.object(mwdeploy, 'HOSTNAME', 'mw151'),
            patch.object(mwdeploy.Discovery, 'extensions', return_value=['A', 'B']),
            patch.object(mwdeploy.Discovery, 'skins', return_value=['S', 'T']),
            patch.object(mwdeploy.Discovery, 'patch_paths', return_value=['config', 'vendor']),
            patch.object(mwdeploy.Discovery, 'versions', return_value=['v1', 'v2']),
        ):
            patcher.start()
            self.addCleanup(patcher.stop)

    def _run(self, results, **overrides):
        self.runner = mwdeploy.DeploymentRunner(_make_args(**overrides))
        with patch.object(self.runner, 'process', side_effect=results) as self.process, \
             patch.object(self.runner, '_log') as self.log, \
             patch('mwdeploy.time.time', return_value=1005.0):
            self.runner.run(1000.0)

    def _logged(self, index):
        return self.log.call_args_list[index].args[0]

    def test_new_install_pushes_every_version_plus_shared_repos_and_databases_cache(self):
        runner = mwdeploy.DeploymentRunner(_make_args(new_install=True, servers=['mw152']))
        with patch.object(mwdeploy._remote_deployer, 'sync', return_value=0) as mock_sync, \
             patch.object(runner, '_log'):
            runner.run(1000.0)
        mock_sync.assert_called_once()
        call = mock_sync.call_args
        self.assertEqual(call.args[2], ['v1', 'v2', 'config', 'landing', 'ErrorPages', 'cache/databases.php'])
        self.assertEqual(call.args[3], '/srv/mediawiki')
        self.assertTrue(call.kwargs['force'])

    def test_new_install_ignores_deploy_selection_flags(self):
        runner = mwdeploy.DeploymentRunner(_make_args(
            new_install=True, upgrade_extensions=['A'], apply_patches=['config'], reset_world=True,
        ))
        with patch.object(mwdeploy._remote_deployer, 'sync', return_value=0), \
             patch.object(runner, 'process') as mock_process, \
             patch.object(runner, '_log'):
            runner.run(1000.0)
        mock_process.assert_not_called()

    def test_new_install_logs_start_and_success(self):
        runner = mwdeploy.DeploymentRunner(_make_args(new_install=True, servers=['mw152']))
        with patch.object(mwdeploy._remote_deployer, 'sync', return_value=0), \
             patch.object(runner, '_log') as mock_log, \
             patch('mwdeploy.time.time', return_value=1005.0):
            runner.run(1000.0)
        logged = [call.args[0] for call in mock_log.call_args_list]
        self.assertIn('Starting new install of', logged[0])
        self.assertIn('finished new install of', logged[1])
        self.assertIn('SUCCESS in 5s', logged[1])

    def test_new_install_logs_failure_and_exits(self):
        runner = mwdeploy.DeploymentRunner(_make_args(new_install=True, servers=['mw152']))
        with patch.object(mwdeploy._remote_deployer, 'sync', return_value=1), \
             patch.object(runner, '_log') as mock_log, \
             pytest.raises(SystemExit) as excinfo:
            runner.run(1000.0)
        assert excinfo.value.code == 1
        self.assertIn('FAIL: [1]', mock_log.call_args_list[-1].args[0])

    def test_new_install_passes_through_nolog_and_batch(self):
        runner = mwdeploy.DeploymentRunner(_make_args(new_install=True, servers=['mw152'], nolog=False, batch=True))
        with patch.object(mwdeploy._remote_deployer, 'sync', return_value=0) as mock_sync, \
             patch.object(runner, '_log'):
            runner.run(1000.0)
        call = mock_sync.call_args
        self.assertFalse(call.args[5])  # nolog
        self.assertTrue(call.kwargs['batch'])

    def test_plain_deploy_logs_the_start_and_the_success(self):
        self._run([[]])
        self.process.assert_called_once_with()
        self.assertEqual(self.log.call_count, 2)
        self.assertIn('Starting deploy of', self._logged(0))
        self.assertIn('to mw151', self._logged(0))
        self.assertIn('finished deploy of', self._logged(1))
        self.assertIn('SUCCESS in 5s', self._logged(1))

    def test_a_failed_first_pass_logs_the_failure_and_exits(self):
        with pytest.raises(SystemExit) as excinfo:
            self._run([[1]])
        assert excinfo.value.code == 1
        self.process.assert_called_once_with()
        self.assertIn('FAIL: [1]', self._logged(1))
        self.assertNotIn('SUCCESS', self._logged(1))

    def test_each_version_gets_its_own_pass_when_something_needs_one(self):
        self._run([[], [], []], l10n=True, versions=['v1', 'v2'])
        self.assertEqual([call.args for call in self.process.call_args_list], [(), ('v1',), ('v2',)])
        self.assertIn('SUCCESS', self._logged(1))

    def test_a_failing_version_stops_the_remaining_ones(self):
        with pytest.raises(SystemExit) as excinfo:
            self._run([[], [1]], l10n=True, versions=['v1', 'v2'])
        assert excinfo.value.code == 1
        self.assertEqual([call.args for call in self.process.call_args_list], [(), ('v1',)])
        self.assertIn('FAIL: [1]', self._logged(1))

    def test_versions_are_not_processed_when_nothing_needs_one(self):
        self._run([[]], versions=['v1'])
        self.process.assert_called_once_with()
        self.assertNotIn('versions', self._logged(0))

    def test_upgrade_world_selects_everything(self):
        self._run([[], []], upgrade_world=True, versions=['v1'])
        args = self.runner.args
        self.assertTrue(args.world)
        self.assertEqual(args.pull, 'world')
        self.assertTrue(args.l10n)
        self.assertTrue(args.ignore_time)
        self.assertTrue(args.extension_list)
        self.assertTrue(args.upgrade_vendor)
        self.assertEqual(args.upgrade_extensions, ['A', 'B'])
        self.assertEqual(args.upgrade_skins, ['S', 'T'])
        self.assertEqual([call.args for call in self.process.call_args_list], [(), ('v1',)])

    def test_reset_world_takes_precedence_over_upgrade_world(self):
        self._run([[], []], upgrade_world=True, reset_world=True, versions=['v1'])
        args = self.runner.args
        self.assertFalse(args.world)
        self.assertIsNone(args.pull)
        self.assertIsNone(args.upgrade_extensions)

    def test_every_server_is_logged_as_all(self):
        every_server = list(mwdeploy.get_environment_info().servers)
        self._run([[]], servers=every_server)
        self.assertIn('to all', self._logged(0))

    def test_a_subset_of_servers_is_logged_by_name(self):
        self._run([[]], servers=['mw151', 'mw152'])
        self.assertIn("to ['mw151', 'mw152']", self._logged(0))

    def test_choosing_everything_is_logged_as_all(self):
        self._run(
            [[], [], []], l10n=True, versions=['v1', 'v2'], upgrade_extensions=['A', 'B'],
            upgrade_skins=['S', 'T'], apply_patches=['config', 'vendor'],
        )
        started = self._logged(0)
        for option in ('upgrade_extensions', 'upgrade_skins', 'apply_patches', 'versions'):
            self.assertIn(f"'{option}': 'all'", started)

    def test_choosing_a_subset_is_logged_as_is(self):
        self._run([[], []], versions=['v1'], upgrade_extensions=['A'], upgrade_skins=['S'], apply_patches=['config'])
        started = self._logged(0)
        self.assertIn("'upgrade_extensions': 'A'", started)
        self.assertIn("'upgrade_skins': 'S'", started)
        self.assertIn("'apply_patches': 'config'", started)
        self.assertIn("'versions': 'v1'", started)

    def test_a_pack_hides_the_extension_and_skin_lists_from_the_log(self):
        self._run([[], []], versions=['v1'], upgrade_pack='wikitide', upgrade_extensions=['A'], upgrade_skins=['S'])
        started = self._logged(0)
        self.assertNotIn('upgrade_extensions', started)
        self.assertNotIn('upgrade_skins', started)
        self.assertIn("'upgrade_pack': 'wikitide'", started)


class TestBuildParserAndMain(unittest.TestCase):
    def test_build_parser_requires_servers(self):
        with patch('mwdeploy.ShellExecutor.run_quiet', return_value=MagicMock(stdout='version')):
            parser = mwdeploy.build_parser()
        with pytest.raises(SystemExit):
            parser.parse_args([])

    def test_build_parser_defaults_versions_from_getmwversion(self):
        with patch('mwdeploy.ShellExecutor.run_quiet', return_value=MagicMock(stdout='REL1_41\n')) as mock_run:
            parser = mwdeploy.build_parser()
            namespace = parser.parse_args(['--servers', 'mw151'])
        self.assertEqual(namespace.versions, ['REL1_41'])
        mock_run.assert_called_once()
        self.assertIn('getMWVersion', mock_run.call_args.args[0])

    def test_build_parser_accepts_every_documented_flag(self):
        with patch('mwdeploy.ShellExecutor.run_quiet', return_value=MagicMock(stdout='REL1_41')), \
             patch.object(mwdeploy.Discovery, 'extensions', return_value=['Foo']), \
             patch.object(mwdeploy.Discovery, 'skins', return_value=['Vector']), \
             patch.object(mwdeploy.Discovery, 'versions', return_value=['REL1_41']), \
             patch.object(mwdeploy, 'patches', [{'path': 'config'}]):
            parser = mwdeploy.build_parser()
            namespace = parser.parse_args([
                '--servers', 'mw151', '--versions', 'REL1_41', '--upgrade-extensions', 'Foo',
                '--upgrade-skins', 'Vector', '--apply-patches', 'config', '--l10n', '--lang', 'en',
                '--task', 'T12345', '--batch', '--debug', '--force',
            ])
        self.assertEqual(namespace.upgrade_extensions, ['Foo'])
        self.assertEqual(namespace.upgrade_skins, ['Vector'])
        self.assertEqual(namespace.apply_patches, ['config'])
        self.assertEqual(namespace.lang, 'en')
        self.assertEqual(namespace.task, 'T12345')
        self.assertTrue(namespace.batch)
        self.assertTrue(namespace.debug)
        self.assertTrue(namespace.force)

    def test_main_parses_args_and_runs_the_deployment(self):
        namespace = argparse.Namespace(servers=['mw151'])
        with patch('mwdeploy.build_parser') as mock_build_parser, \
             patch.object(mwdeploy, 'DeploymentRunner') as mock_runner_cls, \
             patch('mwdeploy.time.time', return_value=42.0):
            mock_build_parser.return_value.parse_args.return_value = namespace
            mwdeploy.main()
        mock_build_parser.return_value.parse_args.assert_called_once_with()
        mock_runner_cls.assert_called_once_with(namespace)
        mock_runner_cls.return_value.run.assert_called_once_with(42.0)


class TestArgparseActions(unittest.TestCase):
    def test_upgrade_extensions_action_requires_versions_first(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--versions', action='store', default=None)
        parser.add_argument('--upgrade-extensions', dest='upgrade_extensions', action=mwdeploy.UpgradeExtensionsAction)
        with pytest.raises(SystemExit):
            parser.parse_args(['--upgrade-extensions', 'Foo'])

    def test_upgrade_extensions_action_rejects_an_unknown_extension(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--versions', action='store', default=None)
        parser.add_argument('--upgrade-extensions', dest='upgrade_extensions', action=mwdeploy.UpgradeExtensionsAction)
        with patch.object(mwdeploy.Discovery, 'extensions', return_value=['Foo', 'Bar']), \
             pytest.raises(SystemExit):
            parser.parse_args(['--versions', 'REL1_41', '--upgrade-extensions', 'Ghost'])

    def test_upgrade_extensions_action_sorts_the_chosen_extensions(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--versions', action='store', default=None)
        parser.add_argument('--upgrade-extensions', dest='upgrade_extensions', action=mwdeploy.UpgradeExtensionsAction)
        with patch.object(mwdeploy.Discovery, 'extensions', return_value=['Foo', 'Bar']):
            namespace = parser.parse_args(['--versions', 'REL1_41', '--upgrade-extensions', 'Foo,Bar'])
        self.assertEqual(namespace.upgrade_extensions, ['Bar', 'Foo'])

    def test_upgrade_extensions_action_all_expands_to_every_valid_extension(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--versions', action='store', default=None)
        parser.add_argument('--upgrade-extensions', dest='upgrade_extensions', action=mwdeploy.UpgradeExtensionsAction)
        with patch.object(mwdeploy.Discovery, 'extensions', return_value=['Foo', 'Bar']):
            namespace = parser.parse_args(['--versions', 'REL1_41', '--upgrade-extensions', 'all'])
        self.assertEqual(namespace.upgrade_extensions, ['Bar', 'Foo'])

    def test_upgrade_skins_action_requires_versions_first(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--versions', action='store', default=None)
        parser.add_argument('--upgrade-skins', dest='upgrade_skins', action=mwdeploy.UpgradeSkinsAction)
        with pytest.raises(SystemExit):
            parser.parse_args(['--upgrade-skins', 'Vector'])

    def test_upgrade_skins_action_rejects_an_unknown_skin(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--versions', action='store', default=None)
        parser.add_argument('--upgrade-skins', dest='upgrade_skins', action=mwdeploy.UpgradeSkinsAction)
        with patch.object(mwdeploy.Discovery, 'skins', return_value=['Vector']), \
             pytest.raises(SystemExit):
            parser.parse_args(['--versions', 'REL1_41', '--upgrade-skins', 'Ghost'])

    def test_upgrade_skins_action_sorts_the_chosen_skins(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--versions', action='store', default=None)
        parser.add_argument('--upgrade-skins', dest='upgrade_skins', action=mwdeploy.UpgradeSkinsAction)
        with patch.object(mwdeploy.Discovery, 'skins', return_value=['Vector', 'MonoBook']):
            namespace = parser.parse_args(['--versions', 'REL1_41', '--upgrade-skins', 'Vector,MonoBook'])
        self.assertEqual(namespace.upgrade_skins, ['MonoBook', 'Vector'])

    def test_upgrade_skins_action_all_expands_to_every_valid_skin(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--versions', action='store', default=None)
        parser.add_argument('--upgrade-skins', dest='upgrade_skins', action=mwdeploy.UpgradeSkinsAction)
        with patch.object(mwdeploy.Discovery, 'skins', return_value=['Vector', 'MonoBook']):
            namespace = parser.parse_args(['--versions', 'REL1_41', '--upgrade-skins', 'all'])
        self.assertEqual(namespace.upgrade_skins, ['MonoBook', 'Vector'])

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

    def test_debug_flag_defaults_to_false(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--debug', dest='debug', action='store_true')
        self.assertFalse(parser.parse_args([]).debug)
        self.assertTrue(parser.parse_args(['--debug']).debug)

    def test_new_install_flag_defaults_to_false(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--new-install', dest='new_install', action='store_true')
        self.assertFalse(parser.parse_args([]).new_install)
        self.assertTrue(parser.parse_args(['--new-install']).new_install)


if __name__ == '__main__':
    unittest.main()
