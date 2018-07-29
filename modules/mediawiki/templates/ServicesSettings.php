<?php

$wgMathoidUrls = [
<%- @wikis.each_pair do |wiki, value| -%>
<%- if value == true -%>
    '<%= wiki %>wiki' => 'https://<%= wiki %>.miraheze.org/v1/rest_v1',
<%- else -%>
    '<%= wiki %>wiki' => '<%= value %>/v1/rest_v1',
<%- end -%>
<%- end -%>
];
