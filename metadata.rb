name             "redmine"
maintainer       "TYPO3 Association"
maintainer_email "steffen.gebert@typo3.org"
license          "Apache 2.0"
description      "Installs/Configures redmine"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.3.4"

depends "build-essential"
depends "nginx",            "~> 2.8.0"
depends "ohai",             ">= 4.0.0"
depends "php",              "= 1.1.2"

depends "git"
depends "logrotate"
depends "chef-sugar"

# Depend on private t3-mysql cookbook as long as "database" and "mysql"
# are not working for us.
depends "t3-mysql",         "~> 5.1.0"
#depends "database"
#depends "mysql"
