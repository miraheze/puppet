# frozen_string_literal: true

require 'spec_helper'

describe 'stdlib::os_version_gte' do
  context 'on Debian 9' do
    let(:facts) do
      {
        os: {
          name: 'Debian',
          release: { major: '9' }
        }
      }
    end

    it { is_expected.to run.with_params('Debian', '10').and_return(false) }
    it { is_expected.to run.with_params('Debian', '9').and_return(true) }
    it { is_expected.to run.with_params('Debian', '8').and_return(true) }
    it { is_expected.to run.with_params('Debian', '8.0').and_return(true) }
    it { is_expected.to run.with_params('Ubuntu', '16.04').and_return(false) }
    it { is_expected.to run.with_params('Fedora', '29').and_return(false) }
  end

  context 'on Ubuntu 16.04' do
    let(:facts) do
      {
        os: {
          name: 'Ubuntu',
          release: { major: '16.04' }
        }
      }
    end

    it { is_expected.to run.with_params('Debian', '9').and_return(false) }
    it { is_expected.to run.with_params('Ubuntu', '16').and_return(true) }
    it { is_expected.to run.with_params('Ubuntu', '14.04').and_return(true) }
    it { is_expected.to run.with_params('Ubuntu', '16.04').and_return(true) }
    it { is_expected.to run.with_params('Ubuntu', '18.04').and_return(false) }
    it { is_expected.to run.with_params('Ubuntu', '20.04').and_return(false) }
    it { is_expected.to run.with_params('Fedora', '29').and_return(false) }
  end

  context 'with invalid params' do
    let(:facts) do
      {
        os: {
          name: 'Ubuntu',
          release: { major: '16.04' }
        }
      }
    end

    it { is_expected.to run.with_params('123', 'abc').and_return(false) }
    it { is_expected.to run.with_params([], 123).and_raise_error(ArgumentError) }
  end
end
