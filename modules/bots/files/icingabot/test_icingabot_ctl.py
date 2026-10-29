import stat

import pytest
from icingabot_ctl import main


def run(capsys, tmp_path, *args):
    code = main(list(args), str(tmp_path))
    captured = capsys.readouterr()
    return code, captured.out.splitlines(), captured.err


class TestCtl:
    def test_everything_runs_by_default(self, capsys, tmp_path):
        assert run(capsys, tmp_path) == (0, ['irc: running', 'phorge: running'], '')

    def test_status_alone_shows_both(self, capsys, tmp_path):
        assert run(capsys, tmp_path, 'status')[1] == ['irc: running', 'phorge: running']

    def test_one_side_can_be_paused_and_resumed(self, capsys, tmp_path):
        assert run(capsys, tmp_path, 'irc', 'off') == (0, ['irc: paused'], '')
        assert (tmp_path / 'pause_irc').exists()
        assert not (tmp_path / 'pause_phorge').exists()
        assert run(capsys, tmp_path, 'status')[1] == ['irc: paused', 'phorge: running']
        assert run(capsys, tmp_path, 'irc', 'on') == (0, ['irc: running'], '')
        assert not (tmp_path / 'pause_irc').exists()

    def test_all_covers_both_sides(self, capsys, tmp_path):
        assert run(capsys, tmp_path, 'all', 'off')[1] == ['irc: paused', 'phorge: paused']
        assert run(capsys, tmp_path, 'all', 'on')[1] == ['irc: running', 'phorge: running']

    def test_a_side_can_be_asked_for_its_status(self, capsys, tmp_path):
        (tmp_path / 'pause_phorge').touch()
        assert run(capsys, tmp_path, 'phorge', 'status')[1] == ['phorge: paused']

    def test_resuming_what_is_not_paused_is_fine(self, capsys, tmp_path):
        assert run(capsys, tmp_path, 'phorge', 'on')[:2] == (0, ['phorge: running'])

    def test_pausing_twice_is_fine(self, capsys, tmp_path):
        run(capsys, tmp_path, 'irc', 'off')
        assert run(capsys, tmp_path, 'irc', 'off')[:2] == (0, ['irc: paused'])

    def test_the_service_can_read_the_file_whatever_the_umask(self, capsys, tmp_path):
        run(capsys, tmp_path, 'irc', 'off')
        assert stat.S_IMODE((tmp_path / 'pause_irc').stat().st_mode) == 0o644

    @pytest.mark.parametrize('args', [
        ['irc'], ['bogus', 'on'], ['irc', 'maybe'], ['irc', 'on', 'extra'], ['status', 'irc'], ['off'],
    ])
    def test_bad_arguments_print_the_usage(self, capsys, tmp_path, args):
        code, out, err = run(capsys, tmp_path, *args)
        assert (code, out) == (2, [])
        assert err.startswith('Usage: icingabot-ctl')
        assert not list(tmp_path.iterdir())

    def test_a_missing_state_directory_is_an_error(self, capsys, tmp_path):
        code, out, err = run(capsys, tmp_path / 'missing', 'irc', 'off')
        assert (code, out) == (1, [])
        assert 'has the icingabot service started' in err

    def test_a_write_failure_is_reported_not_a_traceback(self, capsys, tmp_path):
        (tmp_path / 'pause_irc').mkdir()
        code, out, err = run(capsys, tmp_path, 'irc', 'off')
        assert (code, out) == (1, [])
        assert err.startswith('Could not change the pause file')
