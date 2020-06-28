# Changelog

## 4.0.0

- Add array remove functionality (#36)
- Make uncomment work with array_append (fix #13)

## 3.1.0

- Add support for Puppet 6
- Deprecate support for Puppet < 5
- Update supported OSes in metadata.json

## 3.0.0

- Fix support for 'puppet generate types'

## 2.2.4

- Revert the 'puppet generate types' fix due to a discovery that it does not
  work properly prior to puppet 4.10.4 due to a bug in puppet.

## 2.2.3

- Fix support for 'puppet generate types'
- Added CentOS and OracleLinux to supported OS list

## 2.2.2

- Upped supported Puppet versions to include Puppet 5

## 2.2.1

- Only remove seq entries in array entries (GH #10)
- Resync value when exporting/unsetting (GH #10)

## 2.2.0

- Detect value in existing comment when uncommenting (GH #18)
- Improve README.md
- Use containerized Travis CI infrastructure
- Test on Puppet 4
- Update copyright

## 2.1.1

- Fix metadata.json

## 2.1.0

- Add multiline value support
- Depend on augeasproviders_core >= 2.1.0

## 2.0.4

- Fix Travis build

## 2.0.3

- Make sure :name is always fed by the composite namevar (GH #3)
- Always use resource[:variable] instead of resource[:name] in the provider

## 2.0.2

- Add target as namevar, activate composite namevars (GH #2)

## 2.0.1

- Fix exporting array values (GH #1)

## 2.0.0

- First release of split module.
