Description
===========

A [Chef](http://opscode.com/chef) cookbook for [Redmine](http://redmine.org) developed by the TYPO3 infrastructure team. The cookbook is intended to provide a generic approach for installing redmine via chef. The cookbook is in production use on our [forge.typo3.org](http://forge.typo3.org) instance (Internal Note: it's wrapped by additional typo3.org specific cookbooks for sso, messaging-services and more).

Tested to be working on debian/jessie and redmine > 3.x, while it should work for redmine 2.x as well. We are generally willing to accept patches for additional platform support if someone does provide these.

Deployment Architecture
------------------------

* Nginx as reverse proxy
* Thin as ruby application server running redmine rails application
* mysql or sqlite as database (sqlite currently untested) 
* Redmine sources/release can be adapted via custom git ressource or release tage

Testing/Development
------------------------

Make sure you have [Chefdk](https://downloads.chef.io/chef-dk/),[Vagrant](https://www.vagrantup.com/) and [Virtualbox](https://www.virtualbox.org/) installed and running on your box. (vmware support?)

Copy the file `.kitchen.local.example.yml` to `.kitchen.local.yml` and adjust the IP to match your local environment.

Use `kitchen converge` to provision a debian based vagrant box.

Redmine should be available on the IP that you set in `.kitchen.local.yml` 

Cookbook Dependencies
-----------------------

The following dependencies are pulled in via metadata.rb:

* [Nginx](http://community.opscode.com/cookbooks/nginx) as proxy
* [Thin](http://github.com/typo3-cookbooks/thin) as Ruby application server. 
* [Database](https://github.com/chef-cookbooks/database)
* [mysql](https://github.com/chef-cookbooks/mysql) ~> 6.0
* [mysql2_chef_gem](https://github.com/sinfomicien/mysql2_chef_gem)

Ruby shit
------------

- ruby is installed via native package and (default systm ruby) is expected to be >= 1.9.1 (1.8 should work but requires mysql gem instead of mysql2)
- Support for rbenv, jruby and alike is unknown
- Bundler is installed as native system package
- Gemfile.local will be injected via a Template and used to add the dependency on thin into bundler as well as to add the database dependencies
- bundler install will run as user and use --binstub and --path options (quite simialr behaviour to --deployment)
- binstubs are used by the thin recipe / init script.dd


Known Issues
------------

common approach for using the chef deploy resource is to use symlink\_before\_migrate for application specific config. The redmine Gemfile does pull in these configs to resolve dependencies. 
As the bundle install command is run in the before\_migrate callback the corresponding dependencies are *not* in place at the time of the bundler install run. The default recipe solves this by adding
the proper dependencies for database.yml into the Gemfile.local.erb template


Database
--------

MySQL is the only tested database. Sqlite could work.

Attributes
==========
* `node[:redmine][:rails_env]` -  The RAILS ENVIRONMENT used. Defaults to production`.
* `node[:redmine][:thin_servers]` -  The number of thin sockets/processes to start, defaults to 1 and most likely needs to be raised
* `node[:redmine][:deploy_to]` -  Base directory for Redmine deployement. Defaults to `/srv/redmine`
* `node[:redmine][:force_deploy]` -  boolean to trigger a deployment if the sha1/reference was not updated. only usefull in development. Should not be set in production env. Defaults to false
* `node[:redmine][:hostname]` - Host name of the Redmine server (used as the vhost's server_name). Defaults to `node[:fqdn]`.
* `node[:redmine][:database][:name]` - Database name. Defaults to `redmine`.
* `node[:redmine][:database][:username]` - Database user name. Defaults to `redmine`.
* `node[:redmine][:database][:password]` - Database user's password. Defaults to `nil`.
* `node[:redmine][:database][:hostname]` - Database host. Defaults to `localhost`.
* `node[:redmine][:database][:socket]` - Database socket. Defaults to `/var/run/mysql-redmine/mysqld.sock`.
* `node[:redmine][:database][:encoding]` - Database encoding. Defaults to `utf8`.
* `node[:redmine][:database][:collation]` - Database collation. Defaults to `utf8_general_ci`.

* `node[:redmine][:source][:repository]` - Git repository. At the moment, you have to use your own fork, as a `Gemfile.lock` is required. Defaults to `git://github.com/redmine/redmine.git`.
* `node[:redmine][:source][:reference]` - Git reference (branch, tag, commit SHA1) to checkout. Defaults to `2.3-stable`.

