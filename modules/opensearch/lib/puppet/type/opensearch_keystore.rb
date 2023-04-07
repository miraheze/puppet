# frozen_string_literal: true

require 'puppet/parameter/boolean'

Puppet::Type.newtype(:opensearch_keystore) do
  desc 'Manages an Opensearch keystore settings file.'

  ensurable

  newparam(:instance, namevar: true) do
    desc 'Opensearch instance this keystore belongs to.'
  end

  newparam(:configdir) do
    desc 'Path to the opensearch configuration directory (OPENSEARCH_PATH_CONF).'
    defaultto '/etc/opensearch'
  end

  newparam(:purge, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc <<-EOS
      Whether to proactively remove settings that exist in the keystore but
      are not present in this resource's settings.
    EOS

    defaultto false
  end

  newproperty(:settings, array_matching: :all) do
    desc 'A key/value hash of settings names and values.'

    # The keystore utility can only retrieve a list of stored settings,
    # so here we only compare the existing settings (sorted) with the
    # desired settings' keys
    def insync?(value)
      if resource[:purge]
        value.sort == @should.first.keys.sort
      else
        (@should.first.keys - value).empty?
      end
    end

    def change_to_s(currentvalue, newvalue_raw)
      ret = ''

      newvalue = newvalue_raw.first.keys

      added_settings = newvalue - currentvalue
      ret << "added: #{added_settings.join(', ')} " unless added_settings.empty?

      removed_settings = currentvalue - newvalue
      unless removed_settings.empty?
        ret << if resource[:purge]
                 "removed: #{removed_settings.join(', ')}"
               else
                 "would have removed: #{removed_settings.join(', ')}, but purging is disabled"
               end
      end

      ret
    end
  end

  autorequire(:augeas) do
    "defaults_#{self[:name]}"
  end
end
