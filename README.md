Description
===========

A [Chef](http://opscode.com/chef) cookbook for [Redmine](http://redmine.org) used on [forge.typo3.org](http://forge.typo3.org).
Tested to be working on debian/wheezy and redmine > 2.0.0

Used Cookbooks
--------------

This cookook uses [Nginx](http://community.opscode.com/cookbooks/nginx) as proxy and [Thin](http://github.com/typo3-cookbooks/thin) as Ruby application server. 

Ruby shit
---------

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

* `node[:redmine][:source][:repository]` - Git repository. At the moment, you have to use your own fork, as a `Gemfile.lock` is required. Defaults to `git://github.com/redmine/redmine.git`.
* `node[:redmine][:source][:reference]` - Git reference (branch, tag, commit SHA1) to checkout. Defaults to `2.3-stable`.

