#!/bin/bash
#
# Dump Backup and also backups images
#
# Miraheze Staff 2018

set -e
set -u

WIKI=""
IMAGE=0
XML=0
PRIVATE=0

function log {
    echo "$@"
}

function usage {
    echo "Usage: $0 [-h] [-i or -x cannot be both] [-p] [-w <wiki>] [-p]"
    echo "  -h      display help"
    echo "  -i      weather to backup xml"
    echo "  -p      weather the wiki is private"
    echo "  -x      weather to backup xml"
    echo "  -w      wiki to be used for the dump, eg -w testwiki"
    exit 1
}

while getopts "hipxw:" option; do
    case $option in
        h)
            usage
            ;;
        i)
            # IMAGE dump
            IMAGE=1
            ;;
        p)
            # special casing for private wiki's
            PRIVATE=1
            ;;
        x)
            # XML dump
            XML=1
            ;;
        w)
            # WIKI used for the dump
            WIKI="$OPTARG"
            ;;
        *)
            usage
            ;;
    esac
done

if [ "$WIKI" = "" ];
then
    usage
fi

# cannot be both 0
if [ $XML = 1 ] && [ $IMAGE = 1 ];
then
    usage
fi

# cannot be both 1
if [ $XML = 0 ] && [ $IMAGE = 0 ];
then
    usage
fi

# private xml/image dumps function
function run_backups_private_xml {
    log "Regenerating/Generating private XML dumps for wiki: ${WIKI}"

    /usr/bin/nice -n19 /bin/mkdir -p /mnt/mediawiki-static/private/dumps/${WIKI} /mnt/mediawiki-static/private/dumps/${WIKI}/xml/

    /bin/rm -rf /mnt/mediawiki-static/private/dumps/${WIKI}/xml/${WIKI}.xml.gz

    /bin/echo "File:${WIKI}.xml.gz" | /usr/bin/nice -n19 php /srv/mediawiki/w/maintenance/deleteBatch.php --wiki=${WIKI} && /usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/eraseArchivedFile.php --wiki=${WIKI} --filekey="*" --filename="File:${WIKI}.xml.gz" --delete &&
    /usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki=${WIKI} --logs --full --uploads --output=gzip:/mnt/mediawiki-static/private/dumps/${WIKI}/xml/${WIKI}.xml.gz &&  /usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/importImages.php /mnt/mediawiki-static/private/dumps/${WIKI}/xml/ --comment="Import XML dump for ${WIKI}" --overwrite --wiki=${WIKI} --extensions=gz,xml
}

function run_backups_private_image {
    log "Regenerating/Generating private image dumps for wiki: ${WIKI}"

    /usr/bin/nice -n19 /bin/mkdir -p /mnt/mediawiki-static/private/dumps/${WIKI} /mnt/mediawiki-static/private/dumps/${WIKI}/images/

    /bin/rm -rf /mnt/mediawiki-static/private/dumps/${WIKI}/images/${WIKI}.zip

    /bin/echo "File:${WIKI}.zip" | /usr/bin/nice -n19 php /srv/mediawiki/w/maintenance/deleteBatch.php --wiki=${WIKI} && /usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/eraseArchivedFile.php --wiki=${WIKI} --filekey="*" --filename="File:${WIKI}.zip" --delete &&
    /usr/bin/nice -n19 /usr/bin/zip -r /mnt/mediawiki-static/private/dumps/${WIKI}/images/${WIKI}.zip /mnt/mediawiki-static/${WIKI}/ && /usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/importImages.php /mnt/mediawiki-static/private/dumps/${WIKI}/images/ --comment="Import image zip dump for ${WIKI}" --overwrite --wiki=${WIKI} --extensions=zip
}

# public xml/image dumps function
function run_backups_public_xml {
    log "Regenerating/Generating public XML dumps for wiki: ${WIKI}"

    /bin/rm -rf /mnt/mediawiki-static/dumps/${WIKI}.xml.gz

    /usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki ${WIKI} --logs --full --uploads --output=gzip:/mnt/mediawiki-static/dumps/${WIKI}.xml.gz
}

function run_backups_public_image {
    log "Regenerating/Generating public image folder for wiki: ${WIKI}"

    /bin/rm -rf /mnt/mediawiki-static/dumps/${WIKI}.zip
    
    /usr/bin/nice -n19 /usr/bin/zip -r /mnt/mediawiki-static/dumps/${WIKI}.zip /mnt/mediawiki-static/${WIKI}/
}

if [ $XML -eq 1 ];
then
    if [ $PRIVATE -eq 1 ];
    then
        run_backups_private_xml
    else
        run_backups_public_xml
    fi
fi

if [ $IMAGE -eq 1 ]
then
    if [ $PRIVATE -eq 1 ];
    then
        run_backups_private_image
    else
        run_backups_public_image
    fi
fi
