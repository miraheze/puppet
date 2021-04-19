# frozen_string_literal: true

require 'spec_helper'

describe 'apt_updates fact' do
  subject { Facter.fact(:apt_dist_updates).value }

  before(:each) { Facter.clear }

  describe 'when apt has no updates' do
    before(:each) do
      allow(Facter.fact(:apt_has_dist_updates)).to receive(:value).and_return(false)
    end
    it { is_expected.to be nil }
  end

  describe 'when apt has updates' do
    before(:each) do
      allow(Facter.fact(:osfamily)).to receive(:value).and_return('Debian')
      allow(File).to receive(:executable?) # Stub all other calls
      allow(Facter::Util::Resolution).to receive(:exec) # Catch all other calls
      allow(File).to receive(:executable?).with('/usr/bin/apt-get').and_return(true)
      allow(Facter::Util::Resolution).to receive(:exec).with('/usr/bin/apt-get -s -o Debug::NoLocking=true upgrade 2>&1').and_return('test')
      allow(File).to receive(:executable?).with('/usr/bin/apt-get').and_return(true)
      apt_output = "Inst extremetuxracer [2015f-0+deb8u1] (2015g-0+deb8u1 Debian:stable-updates [all])\n" \
                   "Conf extremetuxracer (2015g-0+deb8u1 Debian:stable-updates [all])\n" \
                   "Inst planet.rb [13-1.1] (22-2~bpo8+1 Debian Backports:jessie-backports [all])\n" \
                   "Conf planet.rb (22-2~bpo8+1 Debian Backports:jessie-backports [all])\n"
      allow(Facter::Util::Resolution).to receive(:exec).with('/usr/bin/apt-get -s -o Debug::NoLocking=true dist-upgrade 2>&1').and_return(apt_output)
    end
    it { is_expected.to eq(2) }
  end
end
