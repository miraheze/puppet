#!/bin/bash

# Wrapper script that runs pwb.py with the correct env vars set
# All parameters to this script are sent as-is to pwb.py

PYWIKIBOT_DIR=<%= @base_path %> /usr/bin/python3 <%= @install_path %>/pwb.py $*
