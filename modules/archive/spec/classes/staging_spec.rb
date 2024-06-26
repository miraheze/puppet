# frozen_string_literal: true

require 'spec_helper'

describe 'archive::staging' do
  context 'RHEL Puppet opensource' do
    let(:facts) { { os: { family: 'RedHat' }, puppetversion: '4.4.0' } }

    it { is_expected.to contain_class 'archive' }

    it do
      expect(subject).to contain_file('/opt/staging').with(
        owner: '0',
        group: '0',
        mode: '0640'
      )
    end
  end

  context 'RHEL Puppet opensource with params' do
    let(:facts) { { os: { family: 'RedHat' }, puppetversion: '4.4.0' } }

    let(:params) do
      {
        path: '/tmp/staging',
        owner: 'puppet',
        group: 'puppet',
        mode: '0755'
      }
    end

    it { is_expected.to contain_class 'archive' }

    it do
      expect(subject).to contain_file('/tmp/staging').with(
        owner: 'puppet',
        group: 'puppet',
        mode: '0755'
      )
    end
  end

  context 'Windows Puppet Enterprise' do
    let(:facts) do
      {
        os: { family: 'Windows' },
        puppetversion: '3.4.3 (Puppet Enterprise 3.2.3)',
        archive_windir: 'C:/Windows/Temp/staging'
      }
    end

    it { is_expected.to contain_class 'archive' }

    it do
      expect(subject).to contain_file('C:/Windows/Temp/staging').with(
        owner: 'S-1-5-32-544',
        group: 'S-1-5-18',
        mode: '0640'
      )
    end
  end
end
