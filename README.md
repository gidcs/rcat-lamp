# Description
RCAT LAMP Stack for CentOS is a yum based solution to install LAMP Stack development environment come with some other software and advanced setup.

Why I need it
-------

- RCAT can be installed by one-key installation script, all configuration will be setup automatically.
- RCAT has a simple script to create a virtualhost, account(system/ftp/mysql), mysql database, and etc.
- RCAT cares about cross site problem and use mod_ruid2 to changes the permissions of all of the HTTP requests for a domain to the permissions of the owner of that domain.
- RCAT use PageSpeed Module to automatically apply web performance best practices to pages and associated assets (CSS, JavaScript, images) without requiring that you modify your existing content or workflow.

Supported System
-------

- CentOS 6

Software will be installed
-------

- Apache 2.2 with mod_ruid2, mod-pagespeed
- MariaDB 10.1
- phpMyAdmin
- PHP 5.6 with OPcache, ZendGuardLoader, ionCube_Loader
- Postfix
- ProFTPD
- DenyHosts
- screen, vim(along with Vundle.vim), unzip, git, etc.
- repo: epel-release, MariaDB, webtatic
- some personal rc files


Installation
-------

```
yum install wget -y
wget -O rcat.sh https://raw.githubusercontent.com/gidcs/rcat-lamp/master/rcat.sh
chmod 755 rcat.sh
./rcat.sh
```

License
-------

Copyright 2016 [guyusoftware]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

```
http://www.apache.org/licenses/LICENSE-2.0
```

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

[guyusoftware]: https://www.guyusoftware.com/

