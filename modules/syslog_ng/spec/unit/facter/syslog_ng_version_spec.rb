require "spec_helper"

describe Facter::Util::Fact do
  before {
    Facter.clear
  }

  describe "syslog_ng" do
    context 'fact' do
      output = <<-EOS
syslog-ng 3.7.1
Installer-Version: 3.7.1
Revision:
Compile-Date: Aug 17 2015 14:25:00
Available-Modules: afamqp,basicfuncs,linux-kmsg-format,csvparser,system-source,sdjournal,afsmtp,afmongodb,mod-java,riemann,afsocket,cryptofuncs,trigger-source,afstomp,lua,confgen,rust,rss,afuser,affile,afsql,dbparser,tfgetent,geoip-plugin,graphite,pseudofile,mod-perl,kvformat,grok-parser,json-plugin,afprog,basicfuncs-plus,monitor-source,syslogformat,mod-python,date-parser
Enable-Debug: off
Enable-GProf: off
Enable-Memtrace: off
Enable-IPv6: on
Enable-Spoof-Source: off
Enable-TCP-Wrapper: off
Enable-Linux-Caps: off
      EOS
      expected_syslog_ng = {
        'Installer-Version' => '3.7.1',
        'Revision' => '',
        'Compile-Date' => 'Aug 17 2015 14:25:00',
        'Available-Modules' => %w[afamqp basicfuncs linux-kmsg-format csvparser system-source sdjournal afsmtp afmongodb mod-java riemann afsocket cryptofuncs trigger-source afstomp lua confgen rust rss afuser affile afsql dbparser tfgetent geoip-plugin graphite pseudofile mod-perl kvformat grok-parser json-plugin afprog basicfuncs-plus monitor-source syslogformat mod-python date-parser],
        'Enable-Debug' => 'off',
        'Enable-GProf' => 'off',
        'Enable-Memtrace' => 'off',
        'Enable-IPv6' => 'on',
        'Enable-Spoof-Source' => 'off',
        'Enable-TCP-Wrapper' => 'off',
        'Enable-Linux-Caps' => 'off',
      }
      expected_syslog_ng_version = '3.7.1'
      it "string" do
        Facter::Util::Resolution.expects(:which).with("syslog-ng").returns("/usr/sbin/syslog-ng")
        Facter::Util::Resolution.expects(:exec).with("syslog-ng --version").returns(output)
        expect(Facter.value(:syslog_ng_version)).to eq(expected_syslog_ng_version)
      end
      it "structured" do
        Facter::Util::Resolution.expects(:which).with("syslog-ng").returns("/usr/sbin/syslog-ng")
        Facter::Util::Resolution.expects(:exec).with("syslog-ng --version").returns(output)
        syslog_ng = Facter.value(:syslog_ng)
        expect(syslog_ng.keys).to eq(expected_syslog_ng.keys)
        syslog_ng.keys.each do |k|
          expect(syslog_ng[k]).to eq(expected_syslog_ng[k]) 
        end
      end
    end
  end
end
