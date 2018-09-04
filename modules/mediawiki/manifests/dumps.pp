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

        cron { "Export ${key}wiki xml dump ${value}":
            ensure   => present,
            command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki ${key}wiki --logs --full --uploads > /mnt/mediawiki-static/dumps/${key}wiki.xml",
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

        cron { "Export ${key}wiki images ${value}":
            ensure   => present,
            command  => '/usr/bin/zip -r /mnt/mediawiki-static/dumps/${key}wiki.zip /mnt/mediawiki-static/${key}wiki/',
            user     => 'www-data',
            minute   => '0',
            hour     => '0',
            month    => '*',
            monthday => $time,
        }
    }

    # used for private dumps
    $email_dump = hiera('mediawiki::dumps::email_dump', [])
    
    $noreply_password     = hiera('passwords::mail::noreply')

    $email_dump.each |$key, $val| {
        $date = $val['time']
        $email = $val['email']
        if $date == 'monthly' {
            $time = '1'
        } elsif  $date == 'fortnight' {
            $time = ['15', '30']
        } else {
            $time = ['1', '8', '15', '22', '29']
        }

        cron { "Export ${key} email xml dump ${date}":
            ensure   => present,
            command  => "mkdir -p /mnt/mediawiki-static/private/dumps && /usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki ${key} --logs --full --uploads > /mnt/mediawiki-static/private/dumps/${key}.xml && heirloom-mailx -v -a /mnt/mediawiki-static/private/dumps/${key}.xml -s 'Email dump for ${key} wiki' -S smtp-use-starttls -S ssl-verify=ignore -S smtp-auth=login -S smtp='mail.miraheze.org:25' -S from='noreply@miraheze.org' -S smtp-auth-user='noreply' -S smtp-auth-password='${noreply_password}' ${email} < /dev/null",
            user     => 'www-data',
            minute   => '0',
            hour     => '0',
            month    => '*',
            monthday => $time,
        }
    }
}
