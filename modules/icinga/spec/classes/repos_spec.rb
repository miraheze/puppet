# frozen_string_literal: true

require 'spec_helper'

describe 'icinga::repos' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      context 'with defaults' do
        case os_facts[:osfamily]
        when 'Debian'
          it { is_expected.to contain_apt__source('icinga-stable-release').with('ensure' => 'present') }
          it { is_expected.not_to contain_apt__source('icinga-testing-builds') }
          it { is_expected.not_to contain_apt__source('icinga-snapshot-builds') }

          case os_facts[:operatingsystem] == 'Debian'
          when 'Debian'
            if Integer(os_facts[:operatingsystemmajrelease]) < 10
              it { is_expected.to contain_class('apt::backports').with('ensure' => 'present') }
            else
              it { is_expected.not_to contain_class('apt::backports') }
            end
          when 'Ubuntu'
            if Integer(os_facts[:operatingsystemmajrelease]) < 18
              it { is_expected.to contain_class('apt::backports').with('ensure' => 'present') }
            else
              it { is_expected.not_to contain_class('apt::backports') }
            end
          end

        when 'RedHat'
          it { is_expected.to contain_yumrepo('icinga-stable-release').with('enabled' => 1) }
          it { is_expected.not_to contain_yumrepo('icinga-testing-builds') }
          it { is_expected.not_to contain_yumrepo('icinga-snapshot-builds') }
          it { is_expected.not_to contain_yumrepo('powertools') }
          case os_facts[:operatingsystem]
          when 'Fedora', 'OracleLinux'
            it { is_expected.not_to contain_yumrepo('epel') }
          else
            if Integer(os_facts[:operatingsystemmajrelease]) < 8
              it { is_expected.to contain_yumrepo('epel').with('enabled' => 1) }
            else
              it { is_expected.not_to contain_yumrepo('epel') }
            end
          end

        when 'Suse'
          it { is_expected.to contain_zypprepo('icinga-stable-release').with('enabled' => 1) }
          it { is_expected.not_to contain_zypprepo('icinga-testing-builds') }
          it { is_expected.not_to contain_zypprepo('icinga-snapshot-builds') }
          it { is_expected.not_to contain_zypprepo('server_monitoring') }
        end
      end

      context 'with manage_stable => false, manage_testing => true, manage_plugins => true' do
        let(:params) { { manage_stable: false, manage_testing: true, manage_plugins: true } }

        case os_facts[:osfamily]
        when 'Debian'
          it { is_expected.not_to contain_apt__source('icinga-stable-release') }
          it { is_expected.to contain_apt__source('icinga-testing-builds').with('ensure' => 'present') }
          it { is_expected.to contain_apt__source('netways-plugins-release').with('ensure' => 'present') }
        when 'RedHat'
          it { is_expected.not_to contain_yumrepo('icinga-stable-release') }
          it { is_expected.to contain_yumrepo('icinga-testing-builds').with('enabled' => 1) }
          it { is_expected.to contain_yumrepo('netways-plugins-release').with('enabled' => 1) }
        when 'Suse'
          it { is_expected.not_to contain_zypprepo('icinga-stable-release') }
          it { is_expected.to contain_zypprepo('icinga-testing-builds').with('enabled' => 1) }
        end
      end

      context 'with manage_stable => false, manage_nightly => true, manage_extras => true' do
        let(:params) { { manage_stable: false, manage_nightly: true, manage_extras: true } }

        case os_facts[:osfamily]
        when 'Debian'
          it { is_expected.not_to contain_apt__source('icinga-stable-release') }
          it { is_expected.to contain_apt__source('icinga-snapshot-builds').with('ensure' => 'present') }
          it { is_expected.to contain_apt__source('netways-extras-release').with('ensure' => 'present') }
        when 'RedHat'
          it { is_expected.not_to contain_yumrepo('icinga-stable-release') }
          it { is_expected.to contain_yumrepo('icinga-snapshot-builds').with('enabled' => 1) }
          it { is_expected.to contain_yumrepo('netways-extras-release').with('enabled' => 1) }
        when 'Suse'
          it { is_expected.not_to contain_zypprepo('icinga-stable-release') }
          it { is_expected.to contain_zypprepo('icinga-snapshot-builds').with('enabled' => 1) }
        end
      end

      case os_facts[:osfamily]
      when 'RedHat'
        context 'with manage_epel => false, manage_powertools => false' do
          let(:params) { { manage_epel: false } }

          it { is_expected.not_to contain_yumrepo('epel') }
          it { is_expected.not_to contain_yumrepo('powertools') }
        end
        context 'with manage_epel => true, manage_powertools => true' do
          let(:params) { { manage_epel: true, manage_powertools: true } }

          case os_facts[:operatingsystem]
          when 'Fedora', 'OracleLinux'
            it { is_expected.not_to contain_yumrepo('epel') }
            it { is_expected.not_to contain_yumrepo('powertools') }
          when 'CentOS'
            it { is_expected.to contain_yumrepo('epel').with('enabled' => 1) }
            if Integer(os_facts[:operatingsystemmajrelease]) >= 8
              it { is_expected.to contain_yumrepo('powertools').with('enabled' => 1) }
            end
          else
            it { is_expected.to contain_yumrepo('epel').with('enabled' => 1) }
          end
        end

      when 'Debian'
        context 'with configure_backports => false' do
          let(:params) { { configure_backports: false } }

          it { is_expected.not_to contain_class('apt::backports') }
        end
        context 'with configure_backports => true' do
          let(:params) { { configure_backports: true } }

          it { is_expected.to contain_class('apt::backports') }
        end

      when 'Suse'
        context 'with manage_server_monitoring => false' do
          let(:params) { { manage_server_monitoring: false } }

          it { is_expected.not_to contain_zypprepo('server_monitoring') }
        end

        context 'with manage_server_monitoring => true' do
          let(:params) { { manage_server_monitoring: true } }

          if os_facts[:operatingsystem] == 'SLES'
            it { is_expected.to contain_zypprepo('server_monitoring').with('enabled' => 1) }
          end
        end 
      end
    end
  end
end
