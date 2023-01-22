# frozen_string_literal: true

require 'spec_helper'

describe 'apt_sources fact' do
  subject { Facter.fact(:apt_sources).value }

  before(:each) { Facter.clear }

  describe 'returns a list of .list files' do
    let(:sources_raw) { ['/etc/apt/sources.list.d/puppet-tools.list', '/etc/apt/sources.list.d/some-cli.list'] }
    let(:sources_want) { ['sources.list', 'puppet-tools.list', 'some-cli.list'] }

    before(:each) do
      allow(Dir).to receive(:glob).and_return(sources_raw)
    end

    it { is_expected.to eq(sources_want) }
  end
end
