# Changelog

All notable changes to this project will be documented in this file.
Each new release typically also includes the latest modulesync defaults.
These should not affect the functionality of the module.

## [v7.0.0](https://github.com/voxpupuli/puppet-icinga/tree/v7.0.0) (2025-06-09)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v6.0.0...v7.0.0)

**Breaking changes:**

- Drop Ubuntu 20.04 support [\#162](https://github.com/voxpupuli/puppet-icinga/pull/162) ([lbetz](https://github.com/lbetz))
- 🔥 remove EOL SLES versions and ✨ add currrent SLES minor versions [\#159](https://github.com/voxpupuli/puppet-icinga/pull/159) ([thomas-merz](https://github.com/thomas-merz))

**Implemented enhancements:**

- Allow puppetlabs/apt 10.x [\#158](https://github.com/voxpupuli/puppet-icinga/pull/158) ([smortex](https://github.com/smortex))
- Replace service command usage to restart icinga service [\#156](https://github.com/voxpupuli/puppet-icinga/pull/156) ([lbetz](https://github.com/lbetz))
- metadata.json: Add OpenVox [\#155](https://github.com/voxpupuli/puppet-icinga/pull/155) ([jstraw](https://github.com/jstraw))
- Run unit tests on CERN runners [\#150](https://github.com/voxpupuli/puppet-icinga/pull/150) ([bastelfreak](https://github.com/bastelfreak))

**Fixed bugs:**

- Fix the lack of idempotency in database management for MySQL [\#157](https://github.com/voxpupuli/puppet-icinga/pull/157) ([lbetz](https://github.com/lbetz))

**Closed issues:**

- etc/apt/keyrings owned by nagios [\#153](https://github.com/voxpupuli/puppet-icinga/issues/153)

## [v6.0.0](https://github.com/voxpupuli/puppet-icinga/tree/v6.0.0) (2024-08-19)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v5.0.0...v6.0.0)

**Breaking changes:**

- Drop EOL CentOS 8 support [\#144](https://github.com/voxpupuli/puppet-icinga/pull/144) ([lbetz](https://github.com/lbetz))
- Remove EL7 support [\#139](https://github.com/voxpupuli/puppet-icinga/pull/139) ([lbetz](https://github.com/lbetz))
- Drop Debian Buster support [\#131](https://github.com/voxpupuli/puppet-icinga/pull/131) ([lbetz](https://github.com/lbetz))

**Implemented enhancements:**

- Restrict parameters to non-empty strings [\#145](https://github.com/voxpupuli/puppet-icinga/pull/145) ([lbetz](https://github.com/lbetz))
- Add new param to load additonal Apache modules [\#143](https://github.com/voxpupuli/puppet-icinga/pull/143) ([lbetz](https://github.com/lbetz))
- Add new parameter to disable the default apache config for Icinga [\#142](https://github.com/voxpupuli/puppet-icinga/pull/142) ([lbetz](https://github.com/lbetz))
- Add SELinux support for the Icinga 2 core [\#141](https://github.com/voxpupuli/puppet-icinga/pull/141) ([lbetz](https://github.com/lbetz))
- Add Fedora 40 support [\#140](https://github.com/voxpupuli/puppet-icinga/pull/140) ([lbetz](https://github.com/lbetz))
- Add Ubuntu \(24.04\) Noble support [\#138](https://github.com/voxpupuli/puppet-icinga/pull/138) ([lbetz](https://github.com/lbetz))
- Switch to keyring for all supported Ubuntu and Debian repos [\#132](https://github.com/voxpupuli/puppet-icinga/pull/132) ([lbetz](https://github.com/lbetz))
- Add Debian bookworm support [\#130](https://github.com/voxpupuli/puppet-icinga/pull/130) ([lbetz](https://github.com/lbetz))
- Move cert\_name parameter default to module data [\#126](https://github.com/voxpupuli/puppet-icinga/pull/126) ([lbetz](https://github.com/lbetz))

**Fixed bugs:**

- Fix private key permissions [\#135](https://github.com/voxpupuli/puppet-icinga/pull/135) ([lbetz](https://github.com/lbetz))
- Limit package dependency to icinga modules [\#128](https://github.com/voxpupuli/puppet-icinga/pull/128) ([lbetz](https://github.com/lbetz))
- Fix eventlog as logging\_type on Windows [\#124](https://github.com/voxpupuli/puppet-icinga/pull/124) ([lbetz](https://github.com/lbetz))

**Merged pull requests:**

- .fixtures.yml: Fix augeas module name [\#134](https://github.com/voxpupuli/puppet-icinga/pull/134) ([bastelfreak](https://github.com/bastelfreak))
- Update soft dependencies in README.md [\#146](https://github.com/voxpupuli/puppet-icinga/pull/146) ([lbetz](https://github.com/lbetz))
- Fix typo in requires [\#133](https://github.com/voxpupuli/puppet-icinga/pull/133) ([viscountstyx](https://github.com/viscountstyx))
- Add use of puppet-php \>= 10.2.0 to docs [\#129](https://github.com/voxpupuli/puppet-icinga/pull/129) ([lbetz](https://github.com/lbetz))

## [v5.0.0](https://github.com/voxpupuli/puppet-icinga/tree/v5.0.0) (2024-05-17)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v4.2.1...v5.0.0)

**Breaking changes:**

- Remove paremeters for ssh login from class icinga [\#108](https://github.com/voxpupuli/puppet-icinga/pull/108) ([lbetz](https://github.com/lbetz))

**Implemented enhancements:**

- Remove combat repo file names [\#116](https://github.com/voxpupuli/puppet-icinga/pull/116) ([lbetz](https://github.com/lbetz))
- Add class agentless to monitor via SSH [\#114](https://github.com/voxpupuli/puppet-icinga/pull/114) ([lbetz](https://github.com/lbetz))
- Using keyring on current Debian platforms [\#113](https://github.com/voxpupuli/puppet-icinga/pull/113) ([lbetz](https://github.com/lbetz))
- Set logging type eventlog on Windows by default [\#107](https://github.com/voxpupuli/puppet-icinga/pull/107) ([lbetz](https://github.com/lbetz))
- Set logging\_type to syslog on Linux platforms by default [\#106](https://github.com/voxpupuli/puppet-icinga/pull/106) ([lbetz](https://github.com/lbetz))
- Set logging\_level to warning by default [\#105](https://github.com/voxpupuli/puppet-icinga/pull/105) ([lbetz](https://github.com/lbetz))
- Add eventlog support on Windows platforms [\#104](https://github.com/voxpupuli/puppet-icinga/pull/104) ([lbetz](https://github.com/lbetz))
- Replace duplicate function icinga::unwrap with built-in unwrap function [\#103](https://github.com/voxpupuli/puppet-icinga/pull/103) ([lbetz](https://github.com/lbetz))
- Remove puppet support less than 7.9.0 [\#102](https://github.com/voxpupuli/puppet-icinga/pull/102) ([lbetz](https://github.com/lbetz))

**Merged pull requests:**

- Update landing page [\#122](https://github.com/voxpupuli/puppet-icinga/pull/122) ([lbetz](https://github.com/lbetz))
- README.md: fix codeblock highlighting & metadata.json: Cleanup after repo migration [\#121](https://github.com/voxpupuli/puppet-icinga/pull/121) ([bastelfreak](https://github.com/bastelfreak))
- README.md: Add badges & transfer notice [\#120](https://github.com/voxpupuli/puppet-icinga/pull/120) ([bastelfreak](https://github.com/bastelfreak))

## [v4.2.1](https://github.com/voxpupuli/puppet-icinga/tree/v4.2.1) (2024-02-07)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v4.2.0...v4.2.1)

**Fixed bugs:**

- Fix call of wrong function icinga2::unwrap [\#112](https://github.com/voxpupuli/puppet-icinga/pull/112) ([lbetz](https://github.com/lbetz))

## [v4.2.0](https://github.com/voxpupuli/puppet-icinga/tree/v4.2.0) (2024-02-07)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v4.1.1...v4.2.0)

**Implemented enhancements:**

- Extend connection functionn to use ssl\_mode [\#110](https://github.com/voxpupuli/puppet-icinga/pull/110) ([SimonHoenscheid](https://github.com/SimonHoenscheid))

**Closed issues:**

- Support SUSE based distros [\#59](https://github.com/voxpupuli/puppet-icinga/issues/59)

## [v4.1.1](https://github.com/voxpupuli/puppet-icinga/tree/v4.1.1) (2023-12-21)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v4.1.0...v4.1.1)

**Fixed bugs:**

- Add PostgreSQL 15 support [\#100](https://github.com/voxpupuli/puppet-icinga/issues/100)

**Closed issues:**

- Add example for an Icinga HA and TLS based with dedicated MariaDB/MySQL and Icinga Web [\#101](https://github.com/voxpupuli/puppet-icinga/issues/101)

## [v4.1.0](https://github.com/voxpupuli/puppet-icinga/tree/v4.1.0) (2023-11-28)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v4.0.0...v4.1.0)

**Implemented enhancements:**

- Add feature to add additional zones to server and workers e.g. for cascading satellites [\#99](https://github.com/voxpupuli/puppet-icinga/issues/99)
- Add order to global zones to have them at the end of the file zones.conf [\#98](https://github.com/voxpupuli/puppet-icinga/issues/98)

## [v4.0.0](https://github.com/voxpupuli/puppet-icinga/tree/v4.0.0) (2023-11-23)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v3.2.1...v4.0.0)

**Implemented enhancements:**

- Fix the icingaweb2 modules to run with older puppet-icingaweb2 than 4… [\#95](https://github.com/voxpupuli/puppet-icinga/pull/95) ([lbetz](https://github.com/lbetz))
- Add new parameter to mange a additional config dir like conf.d [\#94](https://github.com/voxpupuli/puppet-icinga/pull/94) ([lbetz](https://github.com/lbetz))
- Add Puppet 8 Support [\#93](https://github.com/voxpupuli/puppet-icinga/pull/93) ([lbetz](https://github.com/lbetz))
- Add x509 module support [\#87](https://github.com/voxpupuli/puppet-icinga/pull/87) ([lbetz](https://github.com/lbetz))

**Fixed bugs:**

- Add missing grants on mysql Ido database for idoreports  [\#97](https://github.com/voxpupuli/puppet-icinga/issues/97)
- mysql:db above 13.1.0 requires an array for the tis\_options [\#91](https://github.com/voxpupuli/puppet-icinga/issues/91)
- Fix some issues if tls and noverify for mariadb/mysql [\#96](https://github.com/voxpupuli/puppet-icinga/pull/96) ([lbetz](https://github.com/lbetz))

**Closed issues:**

- Add classes to manage pdfexports [\#46](https://github.com/voxpupuli/puppet-icinga/issues/46)
- Drop Puppet 6 Support [\#90](https://github.com/voxpupuli/puppet-icinga/issues/90)

## [v3.2.1](https://github.com/voxpupuli/puppet-icinga/tree/v3.2.1) (2023-04-15)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v3.2.0...v3.2.1)

**Fixed bugs:**

- Fix db\_charset \(UTF8\) for the web-icingadb resource [\#86](https://github.com/voxpupuli/puppet-icinga/pull/86) ([lbetz](https://github.com/lbetz))

## [v3.2.0](https://github.com/voxpupuli/puppet-icinga/tree/v3.2.0) (2023-03-10)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v3.1.1...v3.2.0)

**Implemented enhancements:**

- Install icingaweb2 model pdfexport by default [\#85](https://github.com/voxpupuli/puppet-icinga/pull/85) ([lbetz](https://github.com/lbetz))
- Add additional Apache vhost support, add apache module proxy\_http [\#84](https://github.com/voxpupuli/puppet-icinga/pull/84) ([lbetz](https://github.com/lbetz))

**Fixed bugs:**

- Remove handling of PHP extensions [\#83](https://github.com/voxpupuli/puppet-icinga/pull/83) ([lbetz](https://github.com/lbetz))

## [v3.1.1](https://github.com/voxpupuli/puppet-icinga/tree/v3.1.1) (2023-03-05)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v3.1.0...v3.1.1)

**Fixed bugs:**

- Install citext extension via contrib class [\#82](https://github.com/voxpupuli/puppet-icinga/pull/82) ([lbetz](https://github.com/lbetz))

## [v3.1.0](https://github.com/voxpupuli/puppet-icinga/tree/v3.1.0) (2023-03-05)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v3.0.1...v3.1.0)

**Breaking changes:**

- Remove setting of default db ports in modules [\#76](https://github.com/voxpupuli/puppet-icinga/pull/76) ([lbetz](https://github.com/lbetz))

**Implemented enhancements:**

- Add classes to manage idoreports [\#47](https://github.com/voxpupuli/puppet-icinga/issues/47)
- Add support for reporting [\#81](https://github.com/voxpupuli/puppet-icinga/pull/81) ([lbetz](https://github.com/lbetz))
- Add warning for CRB on unsupported os [\#77](https://github.com/voxpupuli/puppet-icinga/pull/77) ([lbetz](https://github.com/lbetz))

**Fixed bugs:**

- Turn on backports for Debian Buster by default  [\#79](https://github.com/voxpupuli/puppet-icinga/issues/79)
- Install pgcrypto extension via contrib class [\#80](https://github.com/voxpupuli/puppet-icinga/pull/80) ([lbetz](https://github.com/lbetz))
- fix broken idempotency on Debian [\#78](https://github.com/voxpupuli/puppet-icinga/pull/78) ([lbetz](https://github.com/lbetz))

## [v3.0.1](https://github.com/voxpupuli/puppet-icinga/tree/v3.0.1) (2023-02-02)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v3.0.0...v3.0.1)

**Fixed bugs:**

- Fix php extentions mysql and process [\#75](https://github.com/voxpupuli/puppet-icinga/pull/75) ([lbetz](https://github.com/lbetz))

## [v3.0.0](https://github.com/voxpupuli/puppet-icinga/tree/v3.0.0) (2023-01-31)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.9.1...v3.0.0)

**Breaking changes:**

- Rename default branch to main [\#74](https://github.com/voxpupuli/puppet-icinga/issues/74)

**Implemented enhancements:**

- Add Ubuntu jammy support [\#62](https://github.com/voxpupuli/puppet-icinga/issues/62)
- Add datatype sensitive to all passwords in all classes [\#73](https://github.com/voxpupuli/puppet-icinga/pull/73) ([lbetz](https://github.com/lbetz))
- Add IcingaDB support [\#72](https://github.com/voxpupuli/puppet-icinga/pull/72) ([lbetz](https://github.com/lbetz))

**Closed issues:**

- Add example for using the Icinga Subscription Repo [\#69](https://github.com/voxpupuli/puppet-icinga/issues/69)

## [v2.9.1](https://github.com/voxpupuli/puppet-icinga/tree/v2.9.1) (2023-01-02)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.9.0...v2.9.1)

**Fixed bugs:**

- Database schema import always failed for PostgreSQL [\#71](https://github.com/voxpupuli/puppet-icinga/issues/71)
- error: Could not find template 'icinga/apache\_custom\_default.conf' [\#70](https://github.com/voxpupuli/puppet-icinga/issues/70)

## [v2.9.0](https://github.com/voxpupuli/puppet-icinga/tree/v2.9.0) (2022-12-27)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.8.0...v2.9.0)

**Breaking changes:**

- Fix Warnings and Errors from pdk validate [\#37](https://github.com/voxpupuli/puppet-icinga/issues/37)

**Implemented enhancements:**

- Add management of databases for icingadb [\#66](https://github.com/voxpupuli/puppet-icinga/issues/66)
- Add param manage\_crb to class icinga::repos [\#68](https://github.com/voxpupuli/puppet-icinga/pull/68) ([lbetz](https://github.com/lbetz))

## [v2.8.0](https://github.com/voxpupuli/puppet-icinga/tree/v2.8.0) (2022-07-26)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.7.1...v2.8.0)

**Breaking changes:**

- Remove management of redis [\#64](https://github.com/voxpupuli/puppet-icinga/issues/64)

**Implemented enhancements:**

- Add parameter for initial admin user and password to Icinga Web 2 [\#65](https://github.com/voxpupuli/puppet-icinga/issues/65)

**Fixed bugs:**

- The director database requires the postgresql extention pgcrypto [\#61](https://github.com/voxpupuli/puppet-icinga/issues/61)
- Support Alma and Rocky Linux [\#55](https://github.com/voxpupuli/puppet-icinga/issues/55)

## [v2.7.1](https://github.com/voxpupuli/puppet-icinga/tree/v2.7.1) (2022-05-30)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.7.0...v2.7.1)

**Fixed bugs:**

- Fix unsupported apache feature CGIPassAuth for older version like on RHEL7 [\#58](https://github.com/voxpupuli/puppet-icinga/issues/58)

## [v2.7.0](https://github.com/voxpupuli/puppet-icinga/tree/v2.7.0) (2022-03-08)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.6.1...v2.7.0)

**Implemented enhancements:**

- Add support to manage repo server\_monitoring on SLES [\#57](https://github.com/voxpupuli/puppet-icinga/issues/57)
- Change apache mpm from worker to event [\#53](https://github.com/voxpupuli/puppet-icinga/issues/53)
- Manage PowerTools on CentOS8 and other clones [\#42](https://github.com/voxpupuli/puppet-icinga/issues/42)

**Fixed bugs:**

- Remove management of Fedora's EPEL from OracleLinux  [\#56](https://github.com/voxpupuli/puppet-icinga/issues/56)

## [v2.6.1](https://github.com/voxpupuli/puppet-icinga/tree/v2.6.1) (2022-01-14)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.6.0...v2.6.1)

**Fixed bugs:**

- Do not set an api user for the director and icingaweb2 if the password is empty [\#54](https://github.com/voxpupuli/puppet-icinga/issues/54)
- Add missing mime apache module [\#52](https://github.com/voxpupuli/puppet-icinga/issues/52)

## [v2.6.0](https://github.com/voxpupuli/puppet-icinga/tree/v2.6.0) (2022-01-05)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.5.0...v2.6.0)

**Implemented enhancements:**

- Add management of module fileshipper to director class [\#51](https://github.com/voxpupuli/puppet-icinga/issues/51)
- Update to https repos for Debian [\#50](https://github.com/voxpupuli/puppet-icinga/issues/50)

## [v2.5.0](https://github.com/voxpupuli/puppet-icinga/tree/v2.5.0) (2021-12-03)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.4.2...v2.5.0)

**Implemented enhancements:**

- Add parameter to icinga to manage icingaweb2 group for the use of icingacli as plugins [\#49](https://github.com/voxpupuli/puppet-icinga/issues/49)
- Add vshperedb support [\#45](https://github.com/voxpupuli/puppet-icinga/issues/45)

**Fixed bugs:**

- Ubuntu focal does not know charset utf8 for mysql [\#48](https://github.com/voxpupuli/puppet-icinga/issues/48)
- Idempotency of icinga::web::director is broken [\#44](https://github.com/voxpupuli/puppet-icinga/issues/44)

## [v2.4.2](https://github.com/voxpupuli/puppet-icinga/tree/v2.4.2) (2021-12-01)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.4.1...v2.4.2)

**Fixed bugs:**

- set import\_schema in web class to hiera lookup [\#34](https://github.com/voxpupuli/puppet-icinga/issues/34)

## [v2.4.1](https://github.com/voxpupuli/puppet-icinga/tree/v2.4.1) (2021-11-05)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.4.0...v2.4.1)

**Fixed bugs:**

- Debian Bullseye support is broken [\#43](https://github.com/voxpupuli/puppet-icinga/issues/43)

## [v2.4.0](https://github.com/voxpupuli/puppet-icinga/tree/v2.4.0) (2021-11-05)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.3.3...v2.4.0)

**Implemented enhancements:**

- Remove listen from icinga::web [\#40](https://github.com/voxpupuli/puppet-icinga/issues/40)
- Extend icinga::database with a parameter to set database encoding [\#39](https://github.com/voxpupuli/puppet-icinga/issues/39)
- Add director support [\#38](https://github.com/voxpupuli/puppet-icinga/issues/38)

## [v2.3.3](https://github.com/voxpupuli/puppet-icinga/tree/v2.3.3) (2021-09-03)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.3.2...v2.3.3)

**Fixed bugs:**

- Namespace function postgresql::postgresql\_password does not work on Puppet 5 [\#36](https://github.com/voxpupuli/puppet-icinga/issues/36)

## [v2.3.2](https://github.com/voxpupuli/puppet-icinga/tree/v2.3.2) (2021-08-17)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.3.1...v2.3.2)

**Fixed bugs:**

- using data types of another module breaks puppet 5 compatibility [\#35](https://github.com/voxpupuli/puppet-icinga/issues/35)

## [v2.3.1](https://github.com/voxpupuli/puppet-icinga/tree/v2.3.1) (2021-06-21)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.3.0...v2.3.1)

**Fixed bugs:**

- NETWAYS repos named the suffix -release by there packages [\#33](https://github.com/voxpupuli/puppet-icinga/issues/33)

## [v2.3.0](https://github.com/voxpupuli/puppet-icinga/tree/v2.3.0) (2021-06-05)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.2.0...v2.3.0)

**Implemented enhancements:**

- Add parameter zone to agent and cert\_name to icinga class [\#28](https://github.com/voxpupuli/puppet-icinga/issues/28)
- Add support for Suse [\#25](https://github.com/voxpupuli/puppet-icinga/issues/25)

**Fixed bugs:**

- web\_api\_user has to manage only on config\_server's [\#30](https://github.com/voxpupuli/puppet-icinga/issues/30)
- Parameter api\_host of class web  should be also a list of Stdlib::Host [\#29](https://github.com/voxpupuli/puppet-icinga/issues/29)
- Option to switch off the package management on windows [\#27](https://github.com/voxpupuli/puppet-icinga/issues/27)

## [v2.2.0](https://github.com/voxpupuli/puppet-icinga/tree/v2.2.0) (2021-05-19)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.1.4...v2.2.0)

**Breaking changes:**

- Rework unit tests for class repos [\#19](https://github.com/voxpupuli/puppet-icinga/issues/19)

**Implemented enhancements:**

- Add direct management of logging to server, worker and agent [\#23](https://github.com/voxpupuli/puppet-icinga/issues/23)
- Add management of extra packages [\#17](https://github.com/voxpupuli/puppet-icinga/issues/17)

## [v2.1.4](https://github.com/voxpupuli/puppet-icinga/tree/v2.1.4) (2021-05-04)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.1.3...v2.1.4)

**Fixed bugs:**

- Broken dependency for yumrepos [\#22](https://github.com/voxpupuli/puppet-icinga/issues/22)

## [v2.1.3](https://github.com/voxpupuli/puppet-icinga/tree/v2.1.3) (2021-05-04)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.1.2...v2.1.3)

**Fixed bugs:**

- Using wrong file names for repos plugins and extras [\#21](https://github.com/voxpupuli/puppet-icinga/issues/21)
- manage\_epel do not work [\#20](https://github.com/voxpupuli/puppet-icinga/issues/20)

## [v2.1.2](https://github.com/voxpupuli/puppet-icinga/tree/v2.1.2) (2021-04-26)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.1.1...v2.1.2)

**Fixed bugs:**

- Setting config\_server manage a zones directory named zone [\#18](https://github.com/voxpupuli/puppet-icinga/issues/18)

## [v2.1.1](https://github.com/voxpupuli/puppet-icinga/tree/v2.1.1) (2021-04-26)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.1.0...v2.1.1)

**Fixed bugs:**

- Setting manage for any repo does not work [\#16](https://github.com/voxpupuli/puppet-icinga/issues/16)

## [v2.1.0](https://github.com/voxpupuli/puppet-icinga/tree/v2.1.0) (2021-04-24)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v2.0.0...v2.1.0)

**Breaking changes:**

- Duplicate declaration: Yumrepo\[epel\] is already declared [\#9](https://github.com/voxpupuli/puppet-icinga/issues/9)

**Implemented enhancements:**

- Add new class to manage Icinga Web 2 [\#15](https://github.com/voxpupuli/puppet-icinga/issues/15)
- Add new class to supports IDO [\#14](https://github.com/voxpupuli/puppet-icinga/issues/14)
- Add new classes for simple managing  [\#13](https://github.com/voxpupuli/puppet-icinga/issues/13)
- Add new repo packages.netways.de/plugins [\#12](https://github.com/voxpupuli/puppet-icinga/issues/12)
- Add new repo packages.netways.de/extras [\#11](https://github.com/voxpupuli/puppet-icinga/issues/11)

**Closed issues:**

- Fresh roll-out apt\_key dependency error [\#10](https://github.com/voxpupuli/puppet-icinga/issues/10)

## [v2.0.0](https://github.com/voxpupuli/puppet-icinga/tree/v2.0.0) (2021-01-11)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v1.0.3...v2.0.0)

**Fixed bugs:**

- Change Management Behavoir for Repositories [\#6](https://github.com/voxpupuli/puppet-icinga/issues/6)

**Closed issues:**

- Add Dependency to puppet-redis [\#8](https://github.com/voxpupuli/puppet-icinga/issues/8)

## [v1.0.3](https://github.com/voxpupuli/puppet-icinga/tree/v1.0.3) (2020-10-22)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v1.0.2...v1.0.3)

**Fixed bugs:**

- fix gpgkey for epel EL8 [\#5](https://github.com/voxpupuli/puppet-icinga/pull/5) ([lbetz](https://github.com/lbetz))

## [v1.0.2](https://github.com/voxpupuli/puppet-icinga/tree/v1.0.2) (2020-10-13)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v0.1.2...v1.0.2)

**Implemented enhancements:**

- Remove repo management of SCL [\#2](https://github.com/voxpupuli/puppet-icinga/issues/2)
- Add a relase guide [\#1](https://github.com/voxpupuli/puppet-icinga/issues/1)

**Closed issues:**

- correct fixtures and metadata [\#4](https://github.com/voxpupuli/puppet-icinga/issues/4)

## [v0.1.2](https://github.com/voxpupuli/puppet-icinga/tree/v0.1.2) (2020-04-21)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v0.1.1...v0.1.2)

## [v0.1.1](https://github.com/voxpupuli/puppet-icinga/tree/v0.1.1) (2020-04-20)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/v0.1.0...v0.1.1)

## [v0.1.0](https://github.com/voxpupuli/puppet-icinga/tree/v0.1.0) (2020-04-20)

[Full Changelog](https://github.com/voxpupuli/puppet-icinga/compare/fad739989bd9c9133abffd39e0d7deb75797de06...v0.1.0)



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
