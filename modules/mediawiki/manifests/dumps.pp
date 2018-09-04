# class: mediawiki::dumps
#
# Cron jobs of select wiki dumps
class mediawiki::dumps {
    require_package(['heirloom-mailx', 'zip'])
    
    $module_path = get_module_path($module_name)
    $xml_dump = loadyaml("${module_path}/data/xml_dump.yaml")

    $xml_dump.each |$key, $value| {
        if $value == 'monthly' {
            $time = '1'
        } elsif  $value == 'fortnight' {
            $time = ['15', '30']
        } else {
            $time = ['1', '8', '15', '22', '29']
        }

        cron { "Export ${key} xml dump ${value}":
            ensure   => present,
            command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki ${key} --logs --full --uploads > /mnt/mediawiki-static/dumps/${key}.xml",
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
            $time = ['15', '30']
        } else {
            $time = ['1', '8', '15', '22', '29']
        }

        cron { "Export ${key} images ${value}":
            ensure   => present,
            command  => '/usr/bin/zip -r /mnt/mediawiki-static/dumps/${key}.zip /mnt/mediawiki-static/${key}/',
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
            $time = ['15', '30']
        } else {
            $time = ['1', '8', '15', '22', '29']
        }

        cron { "Export ${key} private xml dump ${value}":
            ensure   => present,
            command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki ${key} --logs --full --uploads > /mnt/mediawiki-static/private/dumps/${key}.xml && /usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/importImages.php --comment='Import xml dump for ${key}' --overwrite --wiki=${key} /mnt/mediawiki-static/private/dumps/${key}.xml",
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
            $time = ['15', '30']
        } else {
            $time = ['1', '8', '15', '22', '29']
        }

        cron { "Export ${key} private images ${value}":
            ensure   => present,
            command  => '/usr/bin/zip -r /mnt/mediawiki-static/private/dumps/${key}.zip /mnt/mediawiki-static/${key}/ && /usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/importImages.php --comment='Import image zip dump for ${key}' --overwrite --wiki=${key} /mnt/mediawiki-static/private/dumps/${key}.zip',
            user     => 'www-data',
            minute   => '0',
            hour     => '0',
            month    => '*',
            monthday => $time,
        }
    }
}
