## 2.0.0 (2023-08-14)

**ATTENTION:** This major release removes support for Graylog versions < 5.0
and switches the `graylog::allinone` module from Elasticsearch to OpenSearch.

- Add `java_opts` config option to configure addition Java options. ([#52](https://github.com/Graylog2/puppet-graylog/pull/52), @timdeluxe)
- Add stdlib 9.x compatibility. ([#59](https://github.com/Graylog2/puppet-graylog/pull/59), @cruelsmith)
- Replace deprecated `is_master` flag with `is_leader`. ([#57](https://github.com/Graylog2/puppet-graylog/issues/57))
- Update default Graylog version to 5.1.
- Disable `JAVA` setting in environment file by default. ([#60](https://github.com/Graylog2/puppet-graylog/issues/60))
- Update PDK to 3.0.
- Switch default MongoDB version to 5.0.19 in `graylog::allinone`.
- Add `package_name` setting for `graylog::server`.
- Remove java module requirement from documentation.
- Replace Elasticsearch with OpenSearch in `graylog::allinone`.
- Remove support for Graylog < 5.0.

## 1.0.0 (2021-10-25)

- Add ability to update Java Heapsize. ([#47](https://github.com/Graylog2/puppet-graylog/issues/47))
- Add ability to restart service on package upgrade. ([#48](https://github.com/Graylog2/puppet-graylog/issues/48), @clxnetom)
- Convert module to PDK. ([#33](https://github.com/Graylog2/puppet-graylog/issues/33))

## 0.9.1 (2021-10-21)

- Update the module to use the latest version of Graylog. ([#44](https://github.com/Graylog2/puppet-graylog/issues/44))
  - Update Vagrant VMs used in test script.
  - Updated metadata.json to specify supported Puppet and OS versions. ([#33](https://github.com/Graylog2/puppet-graylog/issues/33))
  - Updated Elasticsearch config to specify OSS version and disable `action.auto_create_index`. ([#38](https://github.com/Graylog2/puppet-graylog/issues/38))
  - Migrated CI from TravisCI to Github Actions

## 0.9.0 (2019-08-01)

- Fix problem with missing "/etc/apt/apt.conf.d" directory (#31)
  - **Attention:** This also changes the proxy configuration file from `/etc/apt/apt.conf.d/01proxy`
    to `/etc/apt/apt.conf.d/01_graylog_proxy`. Make sure to remove the old one when upgrading
    this module.
- Run apt-get update after adding repo and before installing server package (#32)

## 0.8.0 (2019-02-14)

- Update for Graylog 3.0.0
- Add capability for installation behind proxy (yum/apt) (#20)
- Don't force `show_diff` to `true` (#24)
- Bump required stdlib version to 4.16 for the length function (#23)

## 0.7.0 (2018-11-30)

- Update for Graylog 2.5.0
- Allow puppetlabs-apt < 7.0.0, puppetlabs-stdlib < 6.0.0 (#27)

## 0.6.0 (2018-02-02)

- Replace deprecated size() with length() (#22, #21)
- Replace deprecated elasticsearch module references (#17)
- Replace deprecated mongodb module references
- Allow puppetlabs/apt module version >3.0.0 (#16)

## 0.5.0 (2017-12-22)

- Update for Graylog 2.4.0

## 0.4.0 (2017-07-26)

- Update for Graylog 2.3.0

## 0.3.0 (2017-03-06)

- Adding a more complex example to README (#11)
- Fix variable scoping (#12, #10)
- Prepare for Graylog 2.2.0
- Fix dependency declaration in metadata.json (#8)
- Replace own custom function with `merge` from stdlib. (#4)
- Make the Vagrant setup work (#3)

## 0.2.0 (2016-09-01)

- Use Graylog 2.1.0 as default version
- Fixed a typo in the README

## 0.1.0 (2016-04-29)

Initial Release
