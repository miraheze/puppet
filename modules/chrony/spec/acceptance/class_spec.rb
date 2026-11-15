# frozen_string_literal: true

require 'spec_helper_acceptance'
# rubocop:disable RSpec/RepeatedExampleGroupBody
describe 'chrony class:' do
  it 'works idempotently with no errors' do
    pp = <<-EOS
    class { 'chrony':
      options => '-F 0 -x',
    }
    EOS

    # Run it twice and test for idempotency
    apply_manifest(pp, catch_failures: true)
    apply_manifest(pp, catch_changes: true)
  end

  describe package('chrony') do
    it { is_expected.to be_installed }
  end

  if %w[RedHat Archlinux].include?(fact('os.family'))
    describe service('chronyd') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe service('chrony-wait.service') do
      it { is_expected.not_to be_enabled }
      it { is_expected.not_to be_running }
    end
  else
    describe service('chrony') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe service('chrony-wait.service') do
      it { is_expected.not_to be_running }
    end

  end

  describe 'with chrony-wait service enabled' do
    it 'works idempotently with no errors' do
      pp = <<-EOS
      class { 'chrony':
        wait_ensure => 'running',
        wait_enable => true,
        options     => '-F 0 -x',
      }
      EOS

      # Run it twice and test for idempotency
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    if %w[RedHat Archlinux].include?(fact('os.family'))
      describe service('chronyd') do
        it { is_expected.to be_enabled }
        it { is_expected.to be_running }
      end

      describe service('chrony-wait.service') do
        it { is_expected.to be_enabled }
        it { is_expected.to be_running }
      end
    else
      describe service('chrony') do
        it { is_expected.to be_enabled }
        it { is_expected.to be_running }
      end

      describe service('chrony-wait.service') do
        it { is_expected.not_to be_running }
      end
    end
  end
end
# rubocop:enable RSpec/RepeatedExampleGroupBody
