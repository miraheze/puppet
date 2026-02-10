# SPDX-License-Identifier: Apache-2.0
# Generate the html for a wmf-style error page
function mediawiki::errorpage_content(Optional[Mediawiki::Errorpage::Options] $options) >> String {
    $defaults = {
        'title'              => 'Miraheze Error',
        'pagetitle'          => 'Error',
        'logo_link'          => 'https://meta.miraheze.org',
        'logo_src'           => 'https://static.wikitide.net/metawiki/3/35/Miraheze_Logo.svg',
        'logo_srcset'        => 'https://static.wikitide.net/metawiki/3/35/Miraheze_Logo.svg 2x',
        'logo_width'         => 135,
        'logo_height'        => 101,
        'logo_alt'           => 'Miraheze',
        'browsersec_comment' => false,
    }
    $errorpage = $defaults.merge($options)
    template('mediawiki/errorpage.html.erb')
}

