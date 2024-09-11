# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'ntp class:', unless: UNSUPPORTED_PLATFORMS.include?(os[:family]) do
  context 'with ntp' do
    let(:pp) { "class { 'ntp': }" }

    it 'runs successfully - not_to match' do
      apply_manifest(pp, catch_failures: true) do |r|
        expect(r.stderr).not_to match(%r{error}i)
      end
    end

    it 'runs successfully - not_to eq' do
      apply_manifest(pp, catch_failures: true) do |r|
        expect(r.stderr).not_to eq(%r{error}i)
      end
    end

    it 'runs successfully - to be_zero' do
      apply_manifest(pp, catch_failures: true) do |r|
        expect(r.exit_code).to be_zero
      end
    end
  end

  context 'when service_ensure => stopped:' do
    let(:pp) { "class { 'ntp': service_ensure => stopped }" }

    it 'runs successfully - not_to match' do
      apply_manifest(pp, catch_failures: true) do |r|
        expect(r.stderr).not_to match(%r{error}i)
      end
    end
  end

  context 'when service_ensure => running:' do
    it 'runs successfully - not_to match' do
      pp = "class { 'ntp': service_ensure => running }"

      apply_manifest(pp, catch_failures: true) do |r|
        expect(r.stderr).not_to match(%r{error}i)
      end
    end
  end
end
