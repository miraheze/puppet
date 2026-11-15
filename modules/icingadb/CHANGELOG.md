# Changelog

All notable changes to this project will be documented in this file.
Each new release typically also includes the latest modulesync defaults.
These should not affect the functionality of the module.

## [v4.0.0](https://github.com/voxpupuli/puppet-icingadb/tree/v4.0.0) (2025-07-11)

[Full Changelog](https://github.com/voxpupuli/puppet-icingadb/compare/v3.2.0...v4.0.0)

**Breaking changes:**

- Drop EOL Ubuntu 20.04 support [\#62](https://github.com/voxpupuli/puppet-icingadb/pull/62) ([lbetz](https://github.com/lbetz))
- Drop Fedora EOL 39 and 40 support [\#61](https://github.com/voxpupuli/puppet-icingadb/pull/61) ([lbetz](https://github.com/lbetz))

**Implemented enhancements:**

- Add Fedora 41 support [\#60](https://github.com/voxpupuli/puppet-icingadb/pull/60) ([lbetz](https://github.com/lbetz))
- Add Fedora 42 support [\#59](https://github.com/voxpupuli/puppet-icingadb/pull/59) ([lbetz](https://github.com/lbetz))
- Add EL 10 support [\#58](https://github.com/voxpupuli/puppet-icingadb/pull/58) ([lbetz](https://github.com/lbetz))
- metadata.json: allow puppet/icinga 7.x [\#57](https://github.com/voxpupuli/puppet-icingadb/pull/57) ([lbetz](https://github.com/lbetz))

## [v3.2.0](https://github.com/voxpupuli/puppet-icingadb/tree/v3.2.0) (2025-06-09)

[Full Changelog](https://github.com/voxpupuli/puppet-icingadb/compare/v3.1.1...v3.2.0)

**Implemented enhancements:**

- metadata.json: Add OpenVox [\#50](https://github.com/voxpupuli/puppet-icingadb/pull/50) ([jstraw](https://github.com/jstraw))

**Closed issues:**

- Redis won't start after upgrading to icingadb-redis 7.2.6-2+debian12 [\#47](https://github.com/voxpupuli/puppet-icingadb/issues/47)

## [v3.1.1](https://github.com/voxpupuli/puppet-icingadb/tree/v3.1.1) (2024-10-18)

[Full Changelog](https://github.com/voxpupuli/puppet-icingadb/compare/v3.1.0...v3.1.1)

**Fixed bugs:**

- Fix \#43 add missing redis module dependency [\#45](https://github.com/voxpupuli/puppet-icingadb/pull/45) ([lbetz](https://github.com/lbetz))
- fix \#35 allow null values in dboptions [\#44](https://github.com/voxpupuli/puppet-icingadb/pull/44) ([lbetz](https://github.com/lbetz))

## [v3.1.0](https://github.com/voxpupuli/puppet-icingadb/tree/v3.1.0) (2024-09-24)

[Full Changelog](https://github.com/voxpupuli/puppet-icingadb/compare/v3.0.0...v3.1.0)

**Implemented enhancements:**

- Add new data type for db options [\#40](https://github.com/voxpupuli/puppet-icingadb/pull/40) ([lbetz](https://github.com/lbetz))
- Add new data type for retention options [\#39](https://github.com/voxpupuli/puppet-icingadb/pull/39) ([lbetz](https://github.com/lbetz))
- Add new data type for logging options [\#38](https://github.com/voxpupuli/puppet-icingadb/pull/38) ([lbetz](https://github.com/lbetz))
- Replace config template by conversion to yaml [\#37](https://github.com/voxpupuli/puppet-icingadb/pull/37) ([lbetz](https://github.com/lbetz))
- Add missing database options in class icingadb [\#36](https://github.com/voxpupuli/puppet-icingadb/pull/36) ([lbetz](https://github.com/lbetz))

## [v3.0.0](https://github.com/voxpupuli/puppet-icingadb/tree/v3.0.0) (2024-08-15)

[Full Changelog](https://github.com/voxpupuli/puppet-icingadb/compare/v2.0.1...v3.0.0)

**Breaking changes:**

- Drop EOL CentOS 8 support [\#29](https://github.com/voxpupuli/puppet-icingadb/pull/29) ([lbetz](https://github.com/lbetz))
- remove Debian Buster support [\#26](https://github.com/voxpupuli/puppet-icingadb/pull/26) ([lbetz](https://github.com/lbetz))
- remove support of EL7 platforms [\#25](https://github.com/voxpupuli/puppet-icingadb/pull/25) ([lbetz](https://github.com/lbetz))

**Implemented enhancements:**

- Set requirement of puppet-icinga to \>= 3.0.0 [\#31](https://github.com/voxpupuli/puppet-icingadb/pull/31) ([lbetz](https://github.com/lbetz))
- Restrict params to non-empty strings, replace to Icinga::Secret datatype [\#30](https://github.com/voxpupuli/puppet-icingadb/pull/30) ([lbetz](https://github.com/lbetz))
- Add Ubuntu Noble \(24.04\) support [\#28](https://github.com/voxpupuli/puppet-icingadb/pull/28) ([lbetz](https://github.com/lbetz))
- Add Fedora 40 support [\#27](https://github.com/voxpupuli/puppet-icingadb/pull/27) ([lbetz](https://github.com/lbetz))

**Fixed bugs:**

- Fix missing dependency beween redis package and logdir [\#24](https://github.com/voxpupuli/puppet-icingadb/pull/24) ([lbetz](https://github.com/lbetz))

## [v2.0.1](https://github.com/voxpupuli/puppet-icingadb/tree/v2.0.1) (2024-07-02)

[Full Changelog](https://github.com/voxpupuli/puppet-icingadb/compare/v2.0.0...v2.0.1)

**Fixed bugs:**

- Mange missing log\_dir for icingadb-redis [\#19](https://github.com/voxpupuli/puppet-icingadb/pull/19) ([lbetz](https://github.com/lbetz))

**Merged pull requests:**

- fixtures.yml: Pull dependencies from git [\#18](https://github.com/voxpupuli/puppet-icingadb/pull/18) ([bastelfreak](https://github.com/bastelfreak))

## [v2.0.0](https://github.com/voxpupuli/puppet-icingadb/tree/v2.0.0) (2024-05-23)

[Full Changelog](https://github.com/voxpupuli/puppet-icingadb/compare/v1.0.1...v2.0.0)

**Breaking changes:**

- Drop Puppet 6 Support [\#7](https://github.com/voxpupuli/puppet-icingadb/issues/7)
- Add Puppet 8 Support [\#9](https://github.com/voxpupuli/puppet-icingadb/pull/9) ([lbetz](https://github.com/lbetz))

**Implemented enhancements:**

- Add Debian Bookworm Support [\#5](https://github.com/voxpupuli/puppet-icingadb/issues/5)
- Create FreeBSD.yaml [\#10](https://github.com/voxpupuli/puppet-icingadb/pull/10) ([Fogelholk](https://github.com/Fogelholk))

## [v1.0.1](https://github.com/voxpupuli/puppet-icingadb/tree/v1.0.1) (2023-07-20)

[Full Changelog](https://github.com/voxpupuli/puppet-icingadb/compare/v1.0.0...v1.0.1)

**Fixed bugs:**

- Duplicate declaration of Icinga::Cert\[icingadb tls files for the database client connect\] [\#8](https://github.com/voxpupuli/puppet-icingadb/issues/8)

## [v1.0.0](https://github.com/voxpupuli/puppet-icingadb/tree/v1.0.0) (2022-12-27)

[Full Changelog](https://github.com/voxpupuli/puppet-icingadb/compare/v0.1.0...v1.0.0)

**Implemented enhancements:**

- Rework management of icingadb to support the released version [\#3](https://github.com/voxpupuli/puppet-icingadb/issues/3)

**Fixed bugs:**

- Fix some typos in commands [\#1](https://github.com/voxpupuli/puppet-icingadb/pull/1) ([scoiatael](https://github.com/scoiatael))

**Closed issues:**

- Add support for Redis requirepass [\#4](https://github.com/voxpupuli/puppet-icingadb/issues/4)
- Add management of icingadb-redis [\#2](https://github.com/voxpupuli/puppet-icingadb/issues/2)

## [v0.1.0](https://github.com/voxpupuli/puppet-icingadb/tree/v0.1.0) (2020-04-21)

[Full Changelog](https://github.com/voxpupuli/puppet-icingadb/compare/2de3956e6d14f7a69e9d66333e18c49ba0bbbef2...v0.1.0)



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
