# Miraheze's Puppet configuration

[Miraheze](https://meta.miraheze.org/) is a not-for-profit wiki farm that provides free MediaWiki hosting. Miraheze is powered by volunteers only, and we believe our code should be open source.

This repository contains our production Puppet configuration. Contributions (see below) are always welcome.

# Contributing

Pull requests are welcome!

# Issues

Our issue tracker is in [Phabricator](https://phabricator.miraheze.org/maniphest/). You may directly open a new issue by clicking [here](https://phabricator.miraheze.org/maniphest/task/edit/form/1/). Please read below for security-related concerns.

# Security Vulnerabilities

If you believe you have found a security vulnerability in any part of our code, please do not post it publicly by using our wikis or bug trackers for that; rather, please read our [security page](https://meta.miraheze.org/wiki/Security) carefully, and follow the instructions.

As a quick overview, you can email security concerns to security@miraheze.org which will open a phabricator task that is hidden from public view. If you'd like, you can instead directly create a security-related task [here](https://phabricator.miraheze.org/maniphest/task/edit/form/2/), but please leave the "Security" project on the issue.

This repository is licensed per the GNU General Public License, Version 3.
The full license is available in LICENSE.md.

The repository is made of an assortment of code developed by hand, reusing PuppetLabs Forge and code by the Wikimedia Foundation.
Attritubtions should exist in module directories if code if fully unmodified or slightly.
If attribution is missing, please open a code request adding the attribution and it will be merged.

This works out of the box as long as Puppet is installed on the local machine.
All code is tested and developed on Debian Bullseye and is ran in production on Debian Bullseye.
