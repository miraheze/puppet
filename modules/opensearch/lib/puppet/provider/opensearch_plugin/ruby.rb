# frozen_string_literal: true

require 'puppet/provider/opensearch_plugin'

Puppet::Type.type(:opensearch_plugin).provide(
  :opensearch_plugin,
  parent: Puppet::Provider::OpensearchPlugin
) do
  desc <<-END
    Provider for Opensearch bin/opensearch-plugin
    command operations.'
  END

  case Facter.value('osfamily')
  when 'OpenBSD'
    commands plugin: '/usr/local/opensearch/bin/opensearch-plugin'
    commands os: '/usr/local/opensearch/bin/opensearch'
    commands javapathhelper: '/usr/local/bin/javaPathHelper'
  else
    if File.exist? '/usr/share/opensearch/bin/opensearch-plugin'
      commands plugin: '/usr/share/opensearch/bin/opensearch-plugin'
    else
      commands plugin: '/usr/share/opensearch/bin/plugin'
    end
    commands os: '/usr/share/opensearch/bin/opensearch'
  end
end
