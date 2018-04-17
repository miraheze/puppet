require 'spec_helper'

describe('icinga2::object::user', :type => :define) do
  let(:title) { 'bar' }
  let(:pre_condition) { [
      "class { 'icinga2': }"
  ] }

  on_supported_os.each do |os, facts|
    let :facts do
      facts
    end

    context "#{os} with all defaults and target => /bar/baz" do
      let(:params) { {:target =>  '/bar/baz'} }

      it { is_expected.to contain_concat('/bar/baz') }

      it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                              .with({'target' => '/bar/baz'})
                              .with_content(/object User "bar"/)
                              .without_content(/assign where/)
                              .without_content(/ignore where/) }

      it { is_expected.to contain_icinga2__object('icinga2::object::User::bar')
                              .that_notifies('Class[icinga2::service]') }
    end


    context "#{os} with user_name => foo" do
      let(:params) { {:user_name => 'foo', :target => '/bar/baz'} }

      it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                              .with({'target' => '/bar/baz'})
                              .with_content(/object User "foo"/) }
    end


    context "#{os} with display_name => foo" do
      let(:params) { {:display_name => 'foo', :target => '/bar/baz'} }

      it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                              .with({'target' => '/bar/baz'})
                              .with_content(/display_name = "foo"/) }
    end


    context "#{os} with email => foo" do
      let(:params) { {:email => 'foo', :target => '/bar/baz'} }

      it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                              .with({'target' => '/bar/baz'})
                              .with_content(/email = "foo"/) }
    end


    context "#{os} with pager => foo" do
      let(:params) { {:pager => 'foo', :target => '/bar/baz'} }

      it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                              .with({'target' => '/bar/baz'})
                              .with_content(/pager = "foo"/) }
    end


    context "#{os} with vars => { foo => 'bar', bar => 'foo' }" do
      let(:params) { {:vars => { 'foo' => "bar", 'bar' => "foo"}, :target => '/bar/baz' } }

      it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                              .with({ 'target' => '/bar/baz' })
                              .with_content(/vars.foo = "bar"/)
                              .with_content(/vars.bar = "foo"/) }
    end


    context "#{os} with groups => [foo, bar]" do
      let(:params) { {:groups => ['foo','bar'], :target => '/bar/baz'} }

      it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                              .with({'target' => '/bar/baz'})
                              .with_content(/groups = \[ "foo", "bar", \]/) }
    end


    context "#{os} with groups => foo (not a valid array)" do
      let(:params) { {:groups => 'foo', :target => '/bar/baz'} }

      it { is_expected.to raise_error(Puppet::Error, /"foo" is not an Array/) }
    end


    context "#{os} with enable_notifications => false" do
      let(:params) { {:enable_notifications => false, :target => '/bar/baz'} }

      it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                              .with({'target' => '/bar/baz'})
                              .with_content(/enable_notifications = false/) }
    end


    context "#{os} with enable_notifications => foo (not a valid boolean)" do
      let(:params) { {:enable_notifications => 'foo', :target => '/bar/baz'} }

      it { is_expected.to raise_error(Puppet::Error, /"foo" is not a boolean/) }
    end


    context "#{os} with period => foo" do
      let(:params) { {:period => 'foo', :target => '/bar/baz'} }

      it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                              .with({'target' => '/bar/baz'})
                              .with_content(/period = "foo"/) }
    end


    context "#{os} with types => [foo, bar]" do
      let(:params) { {:types => ['foo','bar'], :target => '/bar/baz'} }

      it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                              .with({'target' => '/bar/baz'})
                              .with_content(/types = \[ "foo", "bar", \]/) }
    end


    context "#{os} with types => foo (not a valid array)" do
      let(:params) { {:types => 'foo', :target => '/bar/baz'} }

      it { is_expected.to raise_error(Puppet::Error, /"foo" is not an Array/) }
    end


    context "#{os} with states => [foo, bar]" do
      let(:params) { {:states => ['foo','bar'], :target => '/bar/baz'} }

      it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                              .with({'target' => '/bar/baz'})
                              .with_content(/states = \[ "foo", "bar", \]/) }
    end


    context "#{os} with states => foo (not a valid array)" do
      let(:params) { {:states => 'foo', :target => '/bar/baz'} }

      it { is_expected.to raise_error(Puppet::Error, /"foo" is not an Array/) }
    end
  end
end

describe('icinga2::object::user', :type => :define) do
  let(:facts) { {
      :kernel => 'Windows',
      :architecture => 'x86_64',
      :osfamily => 'Windows',
      :operatingsystem => 'Windows',
      :operatingsystemmajrelease => '2012 R2',
      :path => 'C:\Program Files\Puppet Labs\Puppet\puppet\bin;
               C:\Program Files\Puppet Labs\Puppet\facter\bin;
               C:\Program Files\Puppet Labs\Puppet\hiera\bin;
               C:\Program Files\Puppet Labs\Puppet\mcollective\bin;
               C:\Program Files\Puppet Labs\Puppet\bin;
               C:\Program Files\Puppet Labs\Puppet\sys\ruby\bin;
               C:\Program Files\Puppet Labs\Puppet\sys\tools\bin;
               C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;
               C:\Windows\System32\WindowsPowerShell\v1.0\;
               C:\ProgramData\chocolatey\bin;',
  } }
  let(:title) { 'bar' }
  let(:pre_condition) { [
      "class { 'icinga2': }"
  ] }

  context "Windows 2012 R2 with all defaults and target => /bar/baz" do
    let(:params) { {:target =>  'C:/bar/baz'} }

    it { is_expected.to contain_concat('C:/bar/baz') }

    it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                            .with({'target' => 'C:/bar/baz'})
                            .with_content(/object User "bar"/)
                            .without_content(/assign where/)
                            .without_content(/ignore where/) }

    it { is_expected.to contain_icinga2__object('icinga2::object::User::bar')
                            .that_notifies('Class[icinga2::service]') }
  end


  context "Windows 2012 R2 with user_name => foo" do
    let(:params) { {:user_name => 'foo', :target => 'C:/bar/baz'} }

    it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                           .with({'target' => 'C:/bar/baz'})
                           .with_content(/object User "foo"/) }
  end


  context "Windows 2012 R2 with display_name => foo" do
    let(:params) { {:display_name => 'foo', :target => 'C:/bar/baz'} }

    it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                            .with({'target' => 'C:/bar/baz'})
                            .with_content(/display_name = "foo"/) }
  end


  context "Windows 2012 R2 with email => foo" do
    let(:params) { {:email => 'foo', :target => 'C:/bar/baz'} }

    it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                            .with({'target' => 'C:/bar/baz'})
                            .with_content(/email = "foo"/) }
  end


  context "Windows 2012 R2 with pager => foo" do
    let(:params) { {:pager => 'foo', :target => 'C:/bar/baz'} }

    it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                            .with({'target' => 'C:/bar/baz'})
                            .with_content(/pager = "foo"/) }
  end


  context "Windows 2012 R2 with vars => { foo => 'bar', bar => 'foo' }" do
    let(:params) { {:vars => { 'foo' => "bar", 'bar' => "foo"}, :target => 'C:/bar/baz' } }

    it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                            .with({ 'target' => 'C:/bar/baz' })
                            .with_content(/vars.foo = "bar"/)
                            .with_content(/vars.bar = "foo"/) }
  end


  context "Windows 2012 R2 with groups => [foo, bar]" do
    let(:params) { {:groups => ['foo','bar'], :target => 'C:/bar/baz'} }

    it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                            .with({'target' => 'C:/bar/baz'})
                            .with_content(/groups = \[ "foo", "bar", \]/) }
  end


  context "Windows 2012 R2 with groups => foo (not a valid array)" do
    let(:params) { {:groups => 'foo', :target => 'C:/bar/baz'} }

    it { is_expected.to raise_error(Puppet::Error, /"foo" is not an Array/) }
  end


  context "Windows 2012 R2 with enable_notifications => false" do
    let(:params) { {:enable_notifications => false, :target => 'C:/bar/baz'} }

    it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                            .with({'target' => 'C:/bar/baz'})
                            .with_content(/enable_notifications = false/) }
  end


  context "Windows 2012 R2 with enable_notifications => foo (not a valid boolean)" do
    let(:params) { {:enable_notifications => 'foo', :target => 'C:/bar/baz'} }

    it { is_expected.to raise_error(Puppet::Error, /"foo" is not a boolean/) }
  end


  context "Windows 2012 R2 with period => foo" do
    let(:params) { {:period => 'foo', :target => 'C:/bar/baz'} }

    it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                            .with({'target' => 'C:/bar/baz'})
                            .with_content(/period = "foo"/) }
  end


  context "Windows 2012 R2 with types => [foo, bar]" do
    let(:params) { {:types => ['foo','bar'], :target => 'C:/bar/baz'} }

    it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                            .with({'target' => 'C:/bar/baz'})
                            .with_content(/types = \[ "foo", "bar", \]/) }
  end


  context "Windows 2012 R2 with types => foo (not a valid array)" do
    let(:params) { {:types => 'foo', :target => 'C:/bar/baz'} }

    it { is_expected.to raise_error(Puppet::Error, /"foo" is not an Array/) }
  end


  context "Windows 2012 R2 with states => [foo, bar]" do
    let(:params) { {:states => ['foo','bar'], :target => 'C:/bar/baz'} }

    it { is_expected.to contain_concat__fragment('icinga2::object::User::bar')
                            .with({'target' => 'C:/bar/baz'})
                            .with_content(/states = \[ "foo", "bar", \]/) }
  end


  context "Windows 2012 R2 with states => foo (not a valid array)" do
    let(:params) { {:states => 'foo', :target => 'C:/bar/baz'} }

    it { is_expected.to raise_error(Puppet::Error, /"foo" is not an Array/) }
  end

end
