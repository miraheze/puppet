# class: mediawiki::dumps
#
# Cron jobs of select wiki dumps
class mediawiki::dumps {
    require_package('zip')
    
    file { '/usr/local/bin/dumpsBackup.sh':
        ensure  => 'present',
        mode    => '0755',
        source  => 'puppet:///modules/mediawiki/dumps/dumpsBackup.sh',
        require => File['/srv/mediawiki'],
    }

    $module_path = get_module_path($module_name)
    $xml_dump = loadyaml("${module_path}/data/xml_dump.yaml")

    $xml_dump.each |$key, $value| {
        if $value == 'monthly' {
            $time = '1'
        } elsif  $value == 'fortnight' {
            $time = ['14', '28']
        } elsif  $value == 'biweekly' {
            $time = ['1', '5', '8', '12', '15', '19', '22', '26', '29']
        } else {
            $time = ['1', '8', '15', '22', '29']
        }

        cron { "Export ${key} xml dump ${value}":
            ensure   => present,
            command  => "/usr/local/bin/dumpsBackup.sh -x -w ${key}",
            user     => 'www-data',
            minute   => '0',
            hour     => '0',
            month    => '*',
            monthday => $time,
        }
    }

    $image_dump = loadyaml("${module_path}/data/image_dump.yaml")

    $image_dump.each |$key, $value| {
        if $value == 'monthly' {
            $time = '1'
        } elsif  $value == 'fortnight' {
            $time = ['14', '28']
        } else {
            $time = ['1', '8', '15', '22', '29']
        }

        cron { "Export ${key} images ${value}":
            ensure   => present,
            command  => "/usr/local/bin/dumpsBackup.sh -i -w ${key}",
            user     => 'www-data',
            minute   => '0',
            hour     => '0',
            month    => '*',
            monthday => $time,
        }
    }

    # private dumps
    $private_xml_dump = loadyaml("${module_path}/data/private_xml_dump.yaml")

    $private_xml_dump.each |$key, $value| {
        if $value == 'monthly' {
            $time = '1'
        } elsif  $value == 'fortnight' {
            $time = ['14', '28']
        } else {
            $time = ['1', '8', '15', '22', '29']
        }

        cron { "Export ${key} private xml dump ${value}":
            ensure   => present,
            command  => "/usr/local/bin/dumpsBackup.sh -x -p -w ${key}",
            user     => 'www-data',
            minute   => '0',
            hour     => '0',
            month    => '*',
            monthday => $time,
        }
    }

    $private_image_dump = loadyaml("${module_path}/data/private_image_dump.yaml")

    $private_image_dump.each |$key, $value| {
        if $value == 'monthly' {
            $time = '1'
        } elsif  $value == 'fortnight' {
            $time = ['14', '28']
        } else {
            $time = ['1', '8', '15', '22', '29']
        }

        cron { "Export ${key} private images ${value}":
            ensure   => present,
            command  => "/usr/local/bin/dumpsBackup.sh -i -p -w ${key}",
            user     => 'www-data',
            minute   => '0',
            hour     => '0',
            month    => '*',
            monthday => $time,
        }
    }
}
