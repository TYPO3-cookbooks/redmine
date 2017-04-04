name             "redmine"
maintainer       "TYPO3 Association"
maintainer_email "steffen.gebert@typo3.org"
license          "Apache 2.0"
description      "Installs/Configures redmine"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          IO.read(File.join(File.dirname(__FILE__), 'VERSION')) rescue '0.0.1'

depends "build-essential"
depends "chef_nginx",       "< 6.0.0" # 6.0 requires Chef 12.7 at least
# php uses a modified version of the upstream cookbook, right?
depends "php",              "= 1.1.2"

depends "git"
depends "logrotate"
depends "chef-sugar"

# Depend on private t3-mysql cookbook as long as "database" and "mysql"
# are not working for us.
depends "t3-mysql",         "~> 5.1.0"
#depends "database"
#depends "mysql"

# For compatibility with Chef 12.5.1
depends "ohai",         "< 5.0.0"
