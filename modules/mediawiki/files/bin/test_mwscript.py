import argparse
import shlex
import subprocess
from typing import Optional
from unittest.mock import MagicMock, patch

import pytest

import mwscript
from mwscript import (
    CommandBuilder,
    CommandInfo,
    Console,
    Sal,
    ScriptRunner,
    ShellExecutor,
    UsageError,
)

RUNNER = '/srv/mediawiki/1.43/maintenance/run.php'
PHP = 'sudo -u www-data php'
FOREACH = 'sudo -u www-data /usr/local/bin/foreachwikiindblist'


def completed(stdout: str = '', returncode: int = 0) -> subprocess.CompletedProcess:
    return subprocess.CompletedProcess(args='', returncode=returncode, stdout=stdout, stderr='')


@pytest.fixture(autouse=True)
def _reset_state():
    Sal.task = None
    original = Console.enabled
    Console.enabled = False
    yield
    Sal.task = None
    Console.enabled = original


@pytest.fixture()
def shell():
    calls = []

    def fake(cmd):
        calls.append(cmd)
        if 'getMWVersions' in cmd:
            return completed('{"stable": "1.43"}')
        if 'getMWVersion' in cmd:
            return completed('1.43\n')
        return completed()

    with patch.object(ShellExecutor, 'run_quiet', side_effect=fake):
        yield calls


def build(*argv: str) -> CommandInfo:
    return CommandBuilder(mwscript.get_args(list(argv))).build()


@pytest.mark.usefixtures('shell')
def test_simple():
    info = build('test.php', 'metawiki', '--version', '1.43')
    assert info == CommandInfo(
        command=f'{PHP} {RUNNER} /srv/mediawiki/1.43/maintenance/test.php --wiki=metawiki',
        generate=None,
        long=False,
        nolog=False,
        confirm=False,
    )


@pytest.mark.usefixtures('shell')
def test_extension_path():
    info = build('extensions/CheckUser/test.php', 'metawiki', '--version', '1.43')
    assert info.command == f'{PHP} {RUNNER} /srv/mediawiki/1.43/extensions/CheckUser/maintenance/test.php --wiki=metawiki'
    assert info.long is False


@pytest.mark.usefixtures('shell')
def test_extension_nested_path():
    info = build('extensions/Foo/sub/test.php', 'metawiki', '--version', '1.43')
    assert info.command.endswith('/srv/mediawiki/1.43/extensions/Foo/maintenance/sub/test.php --wiki=metawiki')


@pytest.mark.usefixtures('shell')
def test_subdir():
    info = build('subdir/test.php', 'metawiki', '--version', '1.43')
    assert info.command == f'{PHP} {RUNNER} /srv/mediawiki/1.43/maintenance/subdir/test.php --wiki=metawiki'


@pytest.mark.usefixtures('shell')
def test_class():
    info = build('test', 'metawiki', '--test', '--version', '1.43', '--yes')
    assert info == CommandInfo(
        command=f'{PHP} {RUNNER} test --wiki=metawiki --test',
        generate=None,
        long=False,
        nolog=False,
        confirm=True,
    )


@pytest.mark.usefixtures('shell')
def test_extension_list():
    info = build('test.php', '--extension', 'CheckUser', '--version', '1.43')
    assert info.long is True
    assert info.generate == f'{PHP} {RUNNER} MirahezeMagic:GenerateExtensionDatabaseList --wiki=metawiki --extension=CheckUser --directory=/tmp'
    assert info.command == f'{FOREACH} /tmp/CheckUser.php {RUNNER} /srv/mediawiki/1.43/maintenance/test.php'


@pytest.mark.usefixtures('shell')
def test_extension_list_beta_suffix():
    with patch.object(mwscript, 'WIKISUFFIX', 'wikibeta'):
        info = build('test.php', '--skin', 'Vector', '--version', '1.43')
    assert info.generate is not None
    assert '--wiki=metawikibeta' in info.generate


def test_extension_list_detects_default_version(shell):
    info = build('test.php', '--extension', 'CheckUser')
    assert RUNNER in info.command
    assert shell[-1] == 'sudo -u www-data /usr/local/bin/getMWVersion default'


@pytest.mark.usefixtures('shell')
def test_all():
    info = build('test.php', 'all', '--version', '1.43')
    assert info.long is True
    assert info.command == f'{FOREACH} /srv/mediawiki/cache/databases.php {RUNNER} /srv/mediawiki/1.43/maintenance/test.php'


@pytest.mark.usefixtures('shell')
def test_dblist():
    info = build('test.php', 'active', '--version', '1.43')
    assert info.long is True
    assert info.command == f'{FOREACH} /srv/mediawiki/cache/active.php {RUNNER} /srv/mediawiki/1.43/maintenance/test.php'


def test_version_list_resolves_version(shell):
    info = build('test.php', 'stable-wikis')
    assert info.long is True
    assert info.command.startswith(f'{FOREACH} /srv/mediawiki/cache/stable-wikis.php {RUNNER} ')
    assert not any('getMWVersion ' in call for call in shell)


def test_version_detected_from_wiki(shell):
    info = build('test.php', 'metawiki')
    assert info.command == f'{PHP} {RUNNER} /srv/mediawiki/1.43/maintenance/test.php --wiki=metawiki'
    assert shell[-1] == 'sudo -u www-data /usr/local/bin/getMWVersion metawiki'


def test_no_versions_output():
    with patch.object(ShellExecutor, 'run_quiet', return_value=completed('')), \
            pytest.raises(UsageError, match='Could not determine'):
        build('test.php', 'metawiki')


def test_version_list_unknown_version():
    with patch.object(ShellExecutor, 'run_quiet', return_value=completed('{"stable": ""}')), \
            pytest.raises(UsageError, match='Could not determine'):
        build('test.php', 'stable-wikis')


@pytest.mark.usefixtures('shell')
def test_wiki_typo():
    with pytest.raises(UsageError, match='metawik'):
        build('test', 'metawik', '--version', '1.43')


@pytest.mark.usefixtures('shell')
def test_no_wiki():
    with pytest.raises(UsageError, match='Not enough'):
        build('test', '--version', '1.43')


@pytest.mark.usefixtures('shell')
def test_wikibeta():
    info = build('test', 'metawikibeta', '--version', '1.43')
    assert info.command.endswith('--wiki=metawikibeta')


@pytest.mark.usefixtures('shell')
def test_script_args_passed_through():
    info = build('test.php', 'metawiki', '--test', 'value', '--version', '1.43')
    assert info.command.endswith('--wiki=metawiki --test value')


@pytest.mark.parametrize('script', [
    'rebuildall.php',
    'rebuildall',
    'rEbUiLdAll',
    'ManageWiki:ResetWikiCaches',
    'ManageWiki:ResetWikiCaches.php',
    'managewiki:resetwikicaches',
    'Ns\\ResetWikiCaches',
    'extensions/Cargo/cargoRecreateData.php',
    'CargoRecreateData',
])
@pytest.mark.usefixtures('shell')
def test_long_scripts(script):
    assert build(script, 'metawiki', '--version', '1.43').long is True


@pytest.mark.parametrize('script', ['test.php', 'test', 'MirahezeMagic:GetSiteInfo'])
@pytest.mark.usefixtures('shell')
def test_not_long_scripts(script):
    assert build(script, 'metawiki', '--version', '1.43').long is False


@pytest.mark.usefixtures('shell')
def test_arguments_are_quoted():
    info = build('test.php', 'metawiki', '--reason=two words', "it's", '$(id)', ';', '--version', '1.43')
    assert info.command.endswith(shlex.join(['--reason=two words', "it's", '$(id)', ';']))
    assert shlex.split(info.command)[-4:] == ['--reason=two words', "it's", '$(id)', ';']


@pytest.mark.usefixtures('shell')
def test_wiki_is_quoted():
    info = build('test.php', 'evil; reboot wiki', '--version', '1.43')
    assert shlex.split(info.command)[-1] == '--wiki=evil; reboot wiki'


@pytest.mark.usefixtures('shell')
def test_extension_is_quoted():
    info = build('test.php', '--extension', 'A B', '--version', '1.43')
    assert info.generate is not None
    assert '--extension=A B' in shlex.split(info.generate)
    assert '/tmp/A B.php' in shlex.split(info.command)


@pytest.mark.usefixtures('shell')
def test_conf_is_not_read_as_confirm():
    args = mwscript.get_args(['test.php', 'metawiki', '--conf=/tmp/LocalSettings.php', '--ext=foo'])
    assert args.confirm is False
    assert args.extension is None
    assert args.arguments == ['metawiki', '--conf=/tmp/LocalSettings.php', '--ext=foo']


def test_get_args_does_not_share_state():
    mwscript.get_args(['test.php', '--foo'])
    assert mwscript.get_args(['test.php', 'metawiki']).arguments == ['metawiki']


def test_get_args_flags():
    args = mwscript.get_args(['test.php', 'metawiki', '-y', '--no-log', '--task', 'T123'])
    assert (args.confirm, args.nolog, args.task) == (True, True, 'T123')


def test_get_args_reads_sys_argv():
    with patch('sys.argv', ['mwscript', 'test.php', 'metawiki']):
        assert mwscript.get_args().script == 'test.php'


def test_task_id():
    assert mwscript.task_id('T12345') == 'T12345'
    for bad in ('12345', 'T', 'Tabc', 't1', 'T1 '):
        with pytest.raises(argparse.ArgumentTypeError):
            mwscript.task_id(bad)


def test_invalid_task_exits():
    with pytest.raises(SystemExit):
        mwscript.get_args(['test.php', 'metawiki', '--task', 'nope'])


def test_help_has_descriptions(capsys):
    with pytest.raises(SystemExit):
        mwscript.get_args(['--help'])
    out = capsys.readouterr().out
    for text in ('maintenance script', '--task', '--no-log', '--confirm', '--extension', '--version', 'examples:'):
        assert text in out


def test_console_disabled():
    Console.enabled = False
    assert Console.header('a') == 'a'
    assert Console.bold('a') == 'a'
    assert Console.dim('a') == 'a'
    assert Console.ok('a') == 'a'
    assert Console.warn('a') == 'a'
    assert Console.fail('a') == 'a'


def test_console_enabled():
    Console.enabled = True
    assert Console.header('a') == f'{Console.BOLD}{Console.CYAN}a{Console.RESET}'
    assert Console.bold('a') == f'{Console.BOLD}a{Console.RESET}'
    assert Console.dim('a') == f'{Console.DIM}a{Console.RESET}'
    assert Console.ok('a') == f'{Console.GREEN}a{Console.RESET}'
    assert Console.warn('a') == f'{Console.YELLOW}a{Console.RESET}'
    assert Console.fail('a') == f'{Console.BOLD}{Console.RED}a{Console.RESET}'


def test_console_strip():
    Console.enabled = True
    assert Console.strip(Console.fail('bad')) == 'bad'


def test_sal_suffix():
    assert Sal.suffix() == ''
    Sal.task = 'T12345'
    assert Sal.suffix() == ' (T12345)'


def test_sal_plain():
    assert Sal.plain(Console.header('==> a "b"')) == 'a b'
    assert Sal.plain('moved a ==> b') == 'moved a ==> b'


def test_sal_command_quotes_message():
    Sal.task = 'T12345'
    command = Sal.command("run it's $(id) \"x\"")
    assert shlex.split(command) == ['/usr/local/bin/logsalmsg', "run it's $(id) x (T12345)"]


def test_shell_run(capsys):
    assert ShellExecutor.run('exit 0') == 0
    out = capsys.readouterr().out
    assert 'Execute: exit 0' in out
    assert 'Completed (0) in' in out


def test_shell_run_failure_and_no_echo(capsys):
    assert ShellExecutor.run('exit 3', echo=False) == 3
    out = capsys.readouterr().out
    assert 'Execute:' not in out
    assert 'Completed (3) in' in out


def test_shell_run_quiet():
    result = ShellExecutor.run_quiet('echo hi')
    assert (result.returncode, result.stdout) == (0, 'hi\n')


def make_runner(generate: Optional[str] = None, long: bool = False, nolog: bool = False, confirm: bool = True) -> ScriptRunner:
    return ScriptRunner(CommandInfo(command='do it', generate=generate, long=long, nolog=nolog, confirm=confirm))


@pytest.fixture()
def executor():
    with patch.object(ShellExecutor, 'run', return_value=0) as run, patch.object(ShellExecutor, 'run_quiet', return_value=completed()) as quiet:
        yield run, quiet


def logged(quiet: MagicMock) -> list[str]:
    return [shlex.split(call.args[0])[1] for call in quiet.call_args_list]


def test_run_confirmed_flag(executor, capsys):
    run, quiet = executor
    assert make_runner().run() == 0
    run.assert_called_once_with('do it', echo=False)
    assert logged(quiet) == ['do it (END - exit=0)']
    out = capsys.readouterr().out
    assert 'Will execute:' in out
    assert 'Done!' in out
    assert 'Logging via' in out


def test_run_long_logs_start_and_end(executor):
    _, quiet = executor
    make_runner(long=True).run()
    assert logged(quiet) == ['do it (START)', 'do it (END - exit=0)']


def test_run_nolog(executor):
    _, quiet = executor
    make_runner(long=True, nolog=True).run()
    quiet.assert_not_called()


def test_run_logs_task(executor):
    _, quiet = executor
    Sal.task = 'T99'
    make_runner(long=True).run()
    assert logged(quiet) == ['do it (START) (T99)', 'do it (END - exit=0) (T99)']


def test_run_generate_first(executor, capsys):
    run, _ = executor
    make_runner(generate='gen it').run()
    assert [call.args[0] for call in run.call_args_list] == ['gen it', 'do it']
    assert 'gen it' in capsys.readouterr().out


def test_run_generate_failure_skips_command(executor, capsys):
    run, quiet = executor
    run.return_value = 4
    assert make_runner(generate='gen it').run() == 4
    run.assert_called_once_with('gen it', echo=False)
    assert logged(quiet) == ['do it (END - exit=4)']
    assert 'Failed with exit code 4.' in capsys.readouterr().out


def test_run_returns_command_exit_code(executor, capsys):
    run, _ = executor
    run.return_value = 2
    assert make_runner().run() == 2
    assert 'Failed with exit code 2.' in capsys.readouterr().out


@pytest.mark.parametrize('answer', ['y', 'Y', ' y '])
def test_run_prompt_accepts(executor, answer):
    run, _ = executor
    with patch('builtins.input', return_value=answer):
        assert make_runner(confirm=False).run() == 0
    run.assert_called_once()


@pytest.mark.parametrize('answer', ['n', '', 'yes'])
def test_run_prompt_declines(executor, capsys, answer):
    run, quiet = executor
    with patch('builtins.input', return_value=answer):
        assert make_runner(confirm=False, long=True).run() == 1
    run.assert_not_called()
    quiet.assert_not_called()
    assert 'Aborted!' in capsys.readouterr().out


@pytest.mark.parametrize('error', [EOFError, KeyboardInterrupt])
def test_run_prompt_interrupted(executor, capsys, error):
    run, _ = executor
    with patch('builtins.input', side_effect=error):
        assert make_runner(confirm=False).run() == 1
    run.assert_not_called()
    assert 'Aborted!' in capsys.readouterr().out


@pytest.mark.usefixtures('shell')
def test_main_runs_command():
    with patch.object(ScriptRunner, 'run', return_value=0) as run, pytest.raises(SystemExit) as exit_info:
        mwscript.main(['test.php', 'metawiki', '--version', '1.43', '--task', 'T5'])
    assert exit_info.value.code == 0
    run.assert_called_once_with()
    assert Sal.task == 'T5'


@pytest.mark.usefixtures('shell')
def test_main_passes_exit_code():
    with patch.object(ScriptRunner, 'run', return_value=7), pytest.raises(SystemExit) as exit_info:
        mwscript.main(['test.php', 'metawiki', '--version', '1.43'])
    assert exit_info.value.code == 7


@pytest.mark.usefixtures('shell')
def test_main_usage_error(capsys):
    with pytest.raises(SystemExit) as exit_info:
        mwscript.main(['test', 'metawik', '--version', '1.43'])
    assert exit_info.value.code == 2
    assert 'metawik' in capsys.readouterr().out
