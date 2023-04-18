#!/bin/bash

/srv/matomo/console database:optimize-archive-tables last2 > /srv/matomo-optimize.log 2>&1
/srv/matomo/console database:optimize-archive-tables january > /srv/matomo-optimize.log 2>&1
