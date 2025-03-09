# Maintainer Guide

This file outlines the current maintainers of this open source project and
expectations. It also includes credits to past maintainers and the project
creator.

## Project Name

When reference externally, please use this for the short name:

- Puppet module for Mattermost

Please use this long name:

- Puppet module for Mattermost by Richard Grainger

## Maintainers

The following people help to maintain this open source project:

| Name              | GitLab ID                                   | GitHub ID                                   | Start Date   |
|:------------------|:--------------------------------------------|:--------------------------------------------|:-------------|
| Richard Grainger  | [@harbottle](https://gitlab.com/harbottle)  | [@liger1978](https://github.com/liger1978)  | Jan 09 2016  |
| Carlos Panato     | [@cpanato](https://gitlab.com/cpanato)      | [@cpanato](https://github.com/cpanato)      | Aug 30 2017  |

In case something happens where no maintainers are able to complete their
responsibilies, the following sponsoring organization can help find a new
maintainer:

| Sponsoring Organization                                         | Start Date    |
|:----------------------------------------------------------------|:--------------|
| [Mattermost Open Source Project](https://github.com/mattermost) | Mar 06 2017   |

## Activities

The following is a guide for current, new maintainers and prospective
maintainers of this open source project to get started and to understand
on-going responsibilities:

### Getting Started

The following steps should be completed by a new maintainer

1. **Add your name** - Create a pull request to add your name, GitHub username
and start date to this document.
2. **Subscribe to mailing lists** - To be notified of new releases and security
updates of Mattermost, subscribe to the
[Mattermost Security Update Mailing List](http://mattermost.us11.list-manage.com/subscribe?u=6cdba22349ae374e188e7ab8e&id=3a93eb6929) and the
[Mattermost Insiders Newsletter](http://mattermost.us11.list-manage.com/subscribe?u=6cdba22349ae374e188e7ab8e&id=2add1c8034)

### Updating

When receiving a mailing list email about a new security update or major version
of Mattermost being released, the maintainer should update the version number of
this project by doing the following:

1) In the **master branch**

- Change the version number to the latest release in:
  * `metadata.json`
  * `CHANGELOG`
  * `README.md`
  * `manifests/params.pp`

2) Release a new forge module.

### Issue and Pull Request Review

Maintainers should periodically review pull requests and issues submitted to provide feedback and to merge pull request changes when the maintainer feels the change would be appropriate.

## Credits

### Creator

| Name              | GitLab ID                                   | GitHub ID                                   | Created Date |
|:------------------|:--------------------------------------------|:--------------------------------------------|:-------------|
| Richard Grainger  | [@harbottle](https://gitlab.com/harbottle)  | [@liger1978](https://github.com/liger1978)  | Jan 09 2016  |

### Contributors

| Name                     | GitLab ID                                                  | GitHub ID                                             |
|:-------------------------|:-----------------------------------------------------------|:------------------------------------------------------|
| Carles Amigó             | [@fr3nd](https://gitlab.com/fr3nd)                         | [@fr3nd](https://github.com/fr3nd)                    |
| Jeoffrey Bauvin          | [@JeoffreyB](https://gitlab.com/JeoffreyB)                 | [@Jeoffreybauvin](https://github.com/Jeoffreybauvin)  |
| Francesco Canovai        | [@francesco.canovai](https://gitlab.com/francesco.canovai) | [@fcanovai](https://github.com/fcanovai)              |
| Richard Grainger         | [@harbottle](https://gitlab.com/harbottle)                 | [@liger1978](https://github.com/liger1978)            |
| Garrett Guillotte        | [@oznogon](https://gitlab.com/oznogon)                     | [@gguillotte](https://github.com/gguillotte)          |
| Christopher Jenkins      | [@christj](https://gitlab.com/christj)                     | [@sevendials](https://github.com/sevendials)          |
| Martin Krebs             | [@mtkr](https://gitlab.com/mtkr)                           | [@posteingang](https://github.com/posteingang)        |
| Marco Nenciarini         | [@mnencia](https://gitlab.com/mnencia)                     | [@mnencia](https://github.com/mnencia)                |
| Carlos Panato            | [@cpanato](https://gitlab.com/cpanato)                     | [@cpanato](https://github.com/cpanato)                |
| Louis-Philippe Véronneau | [@baldurmen](https://gitlab.com/baldurmen)                 | [@baldurmen](https://github.com/baldurmen)            |
