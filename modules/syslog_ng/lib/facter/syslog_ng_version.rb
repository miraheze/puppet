Facter.add(:syslog_ng_version) do
  setcode do
    syslog_ng = Facter.value(:syslog_ng)
    if syslog_ng.nil? || syslog_ng.empty?
      nil
    elsif syslog_ng.key?('Installer-Version')
      syslog_ng['Installer-Version']
    elsif syslog_ng.key?('Config-Version')
      syslog_ng['Config-Version']
    end
  end
end

