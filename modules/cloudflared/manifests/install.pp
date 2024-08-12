# @summary
#   This class handles adding the Cloudflare repo to APT and installing cloudflared
#
# @api private
#
class cloudflared::install {
  if $cloudflared::package_manage {
    apt::source { 'cloudflare_cloudflared':
      location => 'https://pkg.cloudflare.com/cloudflared',
      repos    => 'main',
      key      => {
        'name'   => 'cloudlare-main.gpg',
        'source' => 'puppet:///modules/cloudflared/cloudflare-main.gpg',
      },
    }

    package { $cloudflared::package_name:
      ensure => $cloudflared::package_ensure,
    }
  }
}
