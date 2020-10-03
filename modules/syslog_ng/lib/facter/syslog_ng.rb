Facter.add(:syslog_ng) do
  setcode do
    if Facter::Util::Resolution.which('syslog-ng')
      output = Facter::Util::Resolution.exec("syslog-ng --version").lines
      facts = {}
      output.each do |e|
        if e =~ /^([^:]*):\s*(.*)/
          k = $1
          v = $2
          facts[k] = v
          if v =~ /,/
            facts[k] = v.split(',')
          end
        end
      end
      facts
    end
  end
end

