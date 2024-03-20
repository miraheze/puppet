# Change log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org).

## [v1.5.0](https://github.com/deric/puppet-zookeeper/tree/v1.5.0) (2023-08-08)

### Features

- Allow audit logs  ([#190](https://github.com/deric/puppet-zookeeper/pull/190))
- Support Puppet 8
- Support puppetlabs/stdlib 9
- Improve CI tests

### Fixes

- Fix ssl ciphersuites is optional, and removed when not set ([#188](https://github.com/deric/puppet-zookeeper/pull/188))
- Remove anchors, use `contain`


[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v1.4.0...v1.5.0)

## [v1.4.0](https://github.com/deric/puppet-zookeeper/tree/v1.4.0) (2023-01-10)

### Features

- Allow passing repo credentials ([#184](https://github.com/deric/puppet-zookeeper/pull/184))
- Secure client port only ([#182](https://github.com/deric/puppet-zookeeper/pull/182))

### Fixes

- Fix ciphersuite variable on zoo.cfg.erb ([#186](https://github.com/deric/puppet-zookeeper/pull/186))


[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v1.3.0...v1.4.0)

## [v1.3.0](https://github.com/deric/puppet-zookeeper/tree/v1.3.0) (2022-09-13)


### Features

- Add SSL/TLS support for client and node configuration ([#176](https://github.com/deric/puppet-zookeeper/pull/176))
- Add support for Rocky Linux 8 ([#176](https://github.com/deric/puppet-zookeeper/pull/176))

### Fixes

- Fix truststore type parameter used in zoo.cfg ruby template ([#180](https://github.com/deric/puppet-zookeeper/pull/180))

## [v1.2.1](https://github.com/deric/puppet-zookeeper/tree/v1.2.1) (2021-10-08)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v1.2.0...v1.2.1)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Get rid of validate\_string due to deprecation [\#173](https://github.com/deric/puppet-zookeeper/pull/173) ([weastur](https://github.com/weastur))
- Change default archive url [\#172](https://github.com/deric/puppet-zookeeper/pull/172) ([weastur](https://github.com/weastur))

## [v1.2.0](https://github.com/deric/puppet-zookeeper/tree/v1.2.0) (2021-08-04)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v1.1.0...v1.2.0)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- allow latest archive and stdlib dependencies [\#171](https://github.com/deric/puppet-zookeeper/pull/171) ([kenyon](https://github.com/kenyon))

## [v1.1.0](https://github.com/deric/puppet-zookeeper/tree/v1.1.0) (2021-03-17)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v1.0.0...v1.1.0)

### Added

- Add quorum\_listen\_on\_all\_ips option [\#168](https://github.com/deric/puppet-zookeeper/pull/168) ([Wiston999](https://github.com/Wiston999))
- Add var for preAllocSize [\#166](https://github.com/deric/puppet-zookeeper/pull/166) ([deemon87](https://github.com/deemon87))
- Metrics provider [\#165](https://github.com/deric/puppet-zookeeper/pull/165) ([deemon87](https://github.com/deemon87))
- Allow changing initialize datastore binary path [\#163](https://github.com/deric/puppet-zookeeper/pull/163) ([olevole](https://github.com/olevole))
- add port\_unification parameter [\#159](https://github.com/deric/puppet-zookeeper/pull/159) ([jduepmeier](https://github.com/jduepmeier))
- Add support for parameter secureClientPort [\#156](https://github.com/deric/puppet-zookeeper/pull/156) ([dhoppe](https://github.com/dhoppe))
- Add support for SLES 12 [\#155](https://github.com/deric/puppet-zookeeper/pull/155) ([dhoppe](https://github.com/dhoppe))
- Support CentOS 8 [\#152](https://github.com/deric/puppet-zookeeper/pull/152) ([bjoernhaeuser](https://github.com/bjoernhaeuser))

### Fixed

- install\_method set to archive should not try and install the repository [\#164](https://github.com/deric/puppet-zookeeper/pull/164) ([achevalet](https://github.com/achevalet))
- Move daemon-reload to restart\_on\_change [\#162](https://github.com/deric/puppet-zookeeper/pull/162) ([yakirgb](https://github.com/yakirgb))
- Ignore CLASSPATH if systemd is used [\#157](https://github.com/deric/puppet-zookeeper/pull/157) ([dhoppe](https://github.com/dhoppe))

## [v1.0.0](https://github.com/deric/puppet-zookeeper/tree/v1.0.0) (2020-04-14)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.8.7...v1.0.0)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Modulesync 2.12.0 [\#148](https://github.com/deric/puppet-zookeeper/pull/148) ([dhoppe](https://github.com/dhoppe))
- Add support for Modulesync [\#146](https://github.com/deric/puppet-zookeeper/pull/146) ([dhoppe](https://github.com/dhoppe))
- Drop support for Puppet 4 [\#145](https://github.com/deric/puppet-zookeeper/pull/145) ([dhoppe](https://github.com/dhoppe))
- Drop support for Puppet 3 [\#144](https://github.com/deric/puppet-zookeeper/pull/144) ([dhoppe](https://github.com/dhoppe))
- Drop support for Debian \(6, 7\) and Ubuntu \(10.04, 12.04, 14.04\) [\#143](https://github.com/deric/puppet-zookeeper/pull/143) ([dhoppe](https://github.com/dhoppe))
- Support for new distro releases [\#141](https://github.com/deric/puppet-zookeeper/pull/141) ([Hexta](https://github.com/Hexta))
- allow configuring additional log appenders [\#139](https://github.com/deric/puppet-zookeeper/pull/139) ([automaticserver](https://github.com/automaticserver))
- Symlink not needed if using Exhibitor [\#114](https://github.com/deric/puppet-zookeeper/pull/114) ([maximedevalland](https://github.com/maximedevalland))

## [v0.8.7](https://github.com/deric/puppet-zookeeper/tree/v0.8.7) (2019-08-13)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.8.6...v0.8.7)

## [v0.8.6](https://github.com/deric/puppet-zookeeper/tree/v0.8.6) (2019-08-12)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.8.5...v0.8.6)

## [v0.8.5](https://github.com/deric/puppet-zookeeper/tree/v0.8.5) (2019-06-21)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.8.4...v0.8.5)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Allow puppetlabs/stdlib 6.x, puppet/archive 4.x [\#131](https://github.com/deric/puppet-zookeeper/pull/131) ([dhoppe](https://github.com/dhoppe))
- Update archive filename for version 3.5.5+ install [\#130](https://github.com/deric/puppet-zookeeper/pull/130) ([alexconrey](https://github.com/alexconrey))
- Remove require functions [\#125](https://github.com/deric/puppet-zookeeper/pull/125) ([PierreR](https://github.com/PierreR))

## [v0.8.4](https://github.com/deric/puppet-zookeeper/tree/v0.8.4) (2019-02-05)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.8.2...v0.8.4)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Fix bug: prevent service from failing to log any upcoming events [\#122](https://github.com/deric/puppet-zookeeper/pull/122) ([theosotr](https://github.com/theosotr))

## [v0.8.2](https://github.com/deric/puppet-zookeeper/tree/v0.8.2) (2019-01-31)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.8.3...v0.8.2)

## [v0.8.3](https://github.com/deric/puppet-zookeeper/tree/v0.8.3) (2019-01-31)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.8.1...v0.8.3)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- fixing typo in readme [\#121](https://github.com/deric/puppet-zookeeper/pull/121) ([sergigp](https://github.com/sergigp))
- Fix JAVA\_OPTS broken with enabled sasl auth [\#120](https://github.com/deric/puppet-zookeeper/pull/120) ([Thor77](https://github.com/Thor77))

## [v0.8.1](https://github.com/deric/puppet-zookeeper/tree/v0.8.1) (2018-10-24)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.8.0...v0.8.1)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- allow puppet 5.x,  puppetlabs/stdlib 5.x and puppet/archive 3.x [\#116](https://github.com/deric/puppet-zookeeper/pull/116) ([bastelfreak](https://github.com/bastelfreak))
- Allow to set sasl users in init.pp [\#115](https://github.com/deric/puppet-zookeeper/pull/115) ([simioa](https://github.com/simioa))

## [v0.8.0](https://github.com/deric/puppet-zookeeper/tree/v0.8.0) (2018-07-22)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.7.7...v0.8.0)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- use puppet types [\#107](https://github.com/deric/puppet-zookeeper/pull/107) ([TheMeier](https://github.com/TheMeier))

## [v0.7.7](https://github.com/deric/puppet-zookeeper/tree/v0.7.7) (2018-03-07)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.7.6...v0.7.7)

### Fixed

- Replace sh with bash in systemd unit [\#113](https://github.com/deric/puppet-zookeeper/pull/113) ([marfx000](https://github.com/marfx000))

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Fix Minor Version typo in changelog [\#110](https://github.com/deric/puppet-zookeeper/pull/110) ([christek91](https://github.com/christek91))

## [v0.7.6](https://github.com/deric/puppet-zookeeper/tree/v0.7.6) (2017-11-29)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.7.5...v0.7.6)

## [v0.7.5](https://github.com/deric/puppet-zookeeper/tree/v0.7.5) (2017-10-17)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.7.4...v0.7.5)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- WIP: replace all resource-style class with plain `include` [\#106](https://github.com/deric/puppet-zookeeper/pull/106) ([Andor](https://github.com/Andor))
- A pair of log4j properties like vars [\#105](https://github.com/deric/puppet-zookeeper/pull/105) ([alvarolmedo](https://github.com/alvarolmedo))

## [v0.7.4](https://github.com/deric/puppet-zookeeper/tree/v0.7.4) (2017-08-30)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.7.3...v0.7.4)

### Fixed

- 101: do not overwrite the CLASSPATH [\#102](https://github.com/deric/puppet-zookeeper/pull/102) ([denys-mazhar-rp](https://github.com/denys-mazhar-rp))

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Allow service restarts to be skipped on change [\#100](https://github.com/deric/puppet-zookeeper/pull/100) ([quixoten](https://github.com/quixoten))
- Provide option to remove host and realm from Kerberos principal [\#99](https://github.com/deric/puppet-zookeeper/pull/99) ([dlanza1](https://github.com/dlanza1))

## [v0.7.3](https://github.com/deric/puppet-zookeeper/tree/v0.7.3) (2017-06-02)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.7.2...v0.7.3)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- enable possibility of system users for zookeeper [\#98](https://github.com/deric/puppet-zookeeper/pull/98) ([Wayneoween](https://github.com/Wayneoween))
- Make service run even if bin/zkEnv.sh does not exist [\#94](https://github.com/deric/puppet-zookeeper/pull/94) ([dlanza1](https://github.com/dlanza1))

## [v0.7.2](https://github.com/deric/puppet-zookeeper/tree/v0.7.2) (2017-03-20)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.7.1...v0.7.2)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Fix service settings when installing from archive [\#92](https://github.com/deric/puppet-zookeeper/pull/92) ([antyale](https://github.com/antyale))
- Service filename should be equal to the service name [\#91](https://github.com/deric/puppet-zookeeper/pull/91) ([antyale](https://github.com/antyale))

## [v0.7.1](https://github.com/deric/puppet-zookeeper/tree/v0.7.1) (2017-01-23)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.7.0...v0.7.1)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- \[Issue \#87\] Refactor zookeeper user & group creation [\#88](https://github.com/deric/puppet-zookeeper/pull/88) ([travees](https://github.com/travees))
- fix a typo in template [\#86](https://github.com/deric/puppet-zookeeper/pull/86) ([eyal-lupu](https://github.com/eyal-lupu))
- Add exhibitor support [\#85](https://github.com/deric/puppet-zookeeper/pull/85) ([travees](https://github.com/travees))

## [v0.7.0](https://github.com/deric/puppet-zookeeper/tree/v0.7.0) (2016-12-05)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.6.1...v0.7.0)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- parameterize environment file [\#82](https://github.com/deric/puppet-zookeeper/pull/82) ([cristifalcas](https://github.com/cristifalcas))
- fix template for el6 server [\#79](https://github.com/deric/puppet-zookeeper/pull/79) ([cristifalcas](https://github.com/cristifalcas))
- Proposal: extensive refactoring [\#74](https://github.com/deric/puppet-zookeeper/pull/74) ([fraenki](https://github.com/fraenki))

## [v0.6.1](https://github.com/deric/puppet-zookeeper/tree/v0.6.1) (2016-08-04)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.6.0...v0.6.1)

## [v0.6.0](https://github.com/deric/puppet-zookeeper/tree/v0.6.0) (2016-08-03)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.5.5...v0.6.0)

### Added

- SASL authentication [\#70](https://github.com/deric/puppet-zookeeper/pull/70) ([deric](https://github.com/deric))

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Custom zookeeper ids configurable [\#69](https://github.com/deric/puppet-zookeeper/pull/69) ([rohte](https://github.com/rohte))
- Replaces "Redhat" by "RedHat" as it won't match [\#68](https://github.com/deric/puppet-zookeeper/pull/68) ([alejandroandreu](https://github.com/alejandroandreu))

## [v0.5.5](https://github.com/deric/puppet-zookeeper/tree/v0.5.5) (2016-05-27)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.5.4...v0.5.5)

## [v0.5.4](https://github.com/deric/puppet-zookeeper/tree/v0.5.4) (2016-04-25)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.5.3...v0.5.4)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Drop init script on Redhat-derived systems [\#63](https://github.com/deric/puppet-zookeeper/pull/63) ([ghost](https://github.com/ghost))
- Fix RedHat 6 service provider [\#61](https://github.com/deric/puppet-zookeeper/pull/61) ([ortz](https://github.com/ortz))

## [v0.5.3](https://github.com/deric/puppet-zookeeper/tree/v0.5.3) (2016-03-30)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.5.2...v0.5.3)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Tell systemd that this service needs a running process. [\#60](https://github.com/deric/puppet-zookeeper/pull/60) ([deric](https://github.com/deric))
- Update zookeeper.init.erb [\#59](https://github.com/deric/puppet-zookeeper/pull/59) ([bobra200](https://github.com/bobra200))
- Have $manage\_service\_file honored for init [\#58](https://github.com/deric/puppet-zookeeper/pull/58) ([RainofTerra](https://github.com/RainofTerra))

## [v0.5.2](https://github.com/deric/puppet-zookeeper/tree/v0.5.2) (2016-03-12)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.5.1...v0.5.2)

## [v0.5.1](https://github.com/deric/puppet-zookeeper/tree/v0.5.1) (2016-02-19)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.5.0...v0.5.1)

### Added

- Init file [\#51](https://github.com/deric/puppet-zookeeper/pull/51) ([Vlaszaty](https://github.com/Vlaszaty))

## [v0.5.0](https://github.com/deric/puppet-zookeeper/tree/v0.5.0) (2016-02-17)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.4.2...v0.5.0)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Align Java options between files [\#54](https://github.com/deric/puppet-zookeeper/pull/54) ([eyal-lupu](https://github.com/eyal-lupu))
- don't zookeeper service if already exists [\#52](https://github.com/deric/puppet-zookeeper/pull/52) ([deric](https://github.com/deric))
- Create user and group to run zookeeper under.  [\#49](https://github.com/deric/puppet-zookeeper/pull/49) ([Vlaszaty](https://github.com/Vlaszaty))
- Fix for https://github.com/deric/puppet-zookeeper/issues/47 [\#48](https://github.com/deric/puppet-zookeeper/pull/48) ([eyal-lupu](https://github.com/eyal-lupu))
- Fix logging level setup and styling to config file [\#45](https://github.com/deric/puppet-zookeeper/pull/45) ([eyal-lupu](https://github.com/eyal-lupu))

## [v0.4.2](https://github.com/deric/puppet-zookeeper/tree/v0.4.2) (2016-01-12)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.4.1...v0.4.2)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Added ability to configure custom \(local\) repository for installation [\#40](https://github.com/deric/puppet-zookeeper/pull/40) ([danielvdende](https://github.com/danielvdende))

## [v0.4.1](https://github.com/deric/puppet-zookeeper/tree/v0.4.1) (2015-12-16)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.4.0...v0.4.1)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Add missing trailing quote [\#39](https://github.com/deric/puppet-zookeeper/pull/39) ([james-masson](https://github.com/james-masson))
- Added user and group as parameters for zookeeper conf template. [\#37](https://github.com/deric/puppet-zookeeper/pull/37) ([danielvdende](https://github.com/danielvdende))
- add support for cloudera cdh repo version 5 [\#35](https://github.com/deric/puppet-zookeeper/pull/35) ([EslamElHusseiny](https://github.com/EslamElHusseiny))

## [v0.4.0](https://github.com/deric/puppet-zookeeper/tree/v0.4.0) (2015-09-16)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.3.9...v0.4.0)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Update project non-development dependencies. [\#32](https://github.com/deric/puppet-zookeeper/pull/32) ([MrAlias](https://github.com/MrAlias))
- CentOS7 with mesosphere repo installation fix [\#31](https://github.com/deric/puppet-zookeeper/pull/31) ([cornelf](https://github.com/cornelf))
- replacing debian with redhat in the redhat.pp manifest [\#30](https://github.com/deric/puppet-zookeeper/pull/30) ([jmktam](https://github.com/jmktam))
- manage systemd unit files optionally [\#26](https://github.com/deric/puppet-zookeeper/pull/26) ([cristifalcas](https://github.com/cristifalcas))
- zoo.cfg: Add maxSessionTimeout in the template [\#25](https://github.com/deric/puppet-zookeeper/pull/25) ([Spredzy](https://github.com/Spredzy))

## [v0.3.9](https://github.com/deric/puppet-zookeeper/tree/v0.3.9) (2015-06-04)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.3.8...v0.3.9)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Support CentOS 7 [\#24](https://github.com/deric/puppet-zookeeper/pull/24) ([domq](https://github.com/domq))
- Fixed dependency in "initialize\_datastore" step [\#23](https://github.com/deric/puppet-zookeeper/pull/23) ([stephanmitchev](https://github.com/stephanmitchev))

## [v0.3.8](https://github.com/deric/puppet-zookeeper/tree/v0.3.8) (2015-05-13)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.3.7...v0.3.8)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Adding datalogstore param for dataLogDir to split transaction logs onto different directory [\#21](https://github.com/deric/puppet-zookeeper/pull/21) ([redstonemercury](https://github.com/redstonemercury))

## [v0.3.7](https://github.com/deric/puppet-zookeeper/tree/v0.3.7) (2015-04-23)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.3.6...v0.3.7)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Add support for declaring observers in the zookeeper cluster [\#19](https://github.com/deric/puppet-zookeeper/pull/19) ([kscherer](https://github.com/kscherer))

## [v0.3.6](https://github.com/deric/puppet-zookeeper/tree/v0.3.6) (2015-04-08)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.3.5...v0.3.6)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Fixed missing ports in server line of zoo.cfg.erb [\#17](https://github.com/deric/puppet-zookeeper/pull/17) ([brutus333](https://github.com/brutus333))
- added = to allow for variable to be set [\#15](https://github.com/deric/puppet-zookeeper/pull/15) ([fin09pcap](https://github.com/fin09pcap))
- Support attribute clientPortAddress in zoo.cfg [\#14](https://github.com/deric/puppet-zookeeper/pull/14) ([pbyrne413](https://github.com/pbyrne413))

## [v0.3.5](https://github.com/deric/puppet-zookeeper/tree/v0.3.5) (2015-02-09)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.3.4...v0.3.5)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- fail is a function, not a type [\#13](https://github.com/deric/puppet-zookeeper/pull/13) ([cristifalcas](https://github.com/cristifalcas))

## [v0.3.4](https://github.com/deric/puppet-zookeeper/tree/v0.3.4) (2015-01-29)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.3.3...v0.3.4)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Java requirement [\#9](https://github.com/deric/puppet-zookeeper/pull/9) ([coreone](https://github.com/coreone))

## [v0.3.3](https://github.com/deric/puppet-zookeeper/tree/v0.3.3) (2015-01-16)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.3.2...v0.3.3)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Add Cloudera repo installation [\#8](https://github.com/deric/puppet-zookeeper/pull/8) ([coreone](https://github.com/coreone))
- Fix issues with future parser in puppet 3.7+ [\#7](https://github.com/deric/puppet-zookeeper/pull/7) ([tayzlor](https://github.com/tayzlor))

## [v0.3.2](https://github.com/deric/puppet-zookeeper/tree/v0.3.2) (2014-12-11)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.3.1...v0.3.2)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Make servers default value an empty array [\#5](https://github.com/deric/puppet-zookeeper/pull/5) ([tayzlor](https://github.com/tayzlor))

## [v0.3.1](https://github.com/deric/puppet-zookeeper/tree/v0.3.1) (2014-12-04)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.3.0...v0.3.1)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Provide options to override service name and initialize the datastore. [\#4](https://github.com/deric/puppet-zookeeper/pull/4) ([tomstockton](https://github.com/tomstockton))

## [v0.3.0](https://github.com/deric/puppet-zookeeper/tree/v0.3.0) (2014-11-29)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.2.4...v0.3.0)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Fix cron package collision if its declared somewhere outside [\#3](https://github.com/deric/puppet-zookeeper/pull/3) ([claudio-walser](https://github.com/claudio-walser))
- Add peerType parameter to support zookeeper observers [\#2](https://github.com/deric/puppet-zookeeper/pull/2) ([kscherer](https://github.com/kscherer))

## [v0.2.4](https://github.com/deric/puppet-zookeeper/tree/v0.2.4) (2014-03-15)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.2.3...v0.2.4)

### UNCATEGORIZED PRS; LABEL THEM ON GITHUB

- Max connections setting introduced [\#1](https://github.com/deric/puppet-zookeeper/pull/1) ([fiksn](https://github.com/fiksn))

## [v0.2.3](https://github.com/deric/puppet-zookeeper/tree/v0.2.3) (2014-01-29)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/v0.2.2...v0.2.3)

## [v0.2.2](https://github.com/deric/puppet-zookeeper/tree/v0.2.2) (2014-01-29)

[Full Changelog](https://github.com/deric/puppet-zookeeper/compare/d0a476e612b9ce80bcd333e13c31850c1afe1091...v0.2.2)



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
