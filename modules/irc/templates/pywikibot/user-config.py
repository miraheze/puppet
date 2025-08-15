# MANAGED BY PUPPET
family = 'wikitide'
mylang = 'metawiki'
usernames['wikitide']['*'] = 'BeeBot'
authenticate['*'] = ('<%= @consumer_token %>', '<%= @consumer_secret %>', '<%= @access_token %>', '<%= @access_secret %>')
user_agent_description = 'https://meta.miraheze.org/wiki/Tech:Pywikibot; tech@wikitide.org'
user_scripts_path = ['wikitide-userscripts']
