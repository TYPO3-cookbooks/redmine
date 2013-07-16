Description
===========

A [Chef](http://opscode.com/chef) cookbook for [Redmine](http://redmine.org) used on [forge.typo3.org](http://forge.typo3.org).

Used Cookbooks
--------------

This cookook uses [Nginx](http://community.opscode.com/cookbooks/nginx) as proxy and [Thin](http://github.com/typo3-cookbooks/thin) as Ruby application server. 

Ruby shit
---------

Currently ruby is installed via native package and (default systm ruby) is expected to be >= 1.9.
An adaption for 1.8 would probably only need to replace adapter mysql2 by mysql in templates/default/redmine/database.yml.
Support for rbenv, jruby and alike is unknown

Bundler is installed as native system package

Gemfile.local will be injected via a Template and used to add the dependency on thin into bundler (@todo: respect/merge any existing file)

@todo next section needs to be rechecked. Gemfile.lock is problmatic as redmine dynamically adds dependencies from plugins and Gemfile.local

All other Gems are installed through as defined in `Gemfile.lock` (caveat: this file is not contained in the [official Redmine repository](http://github.com/redmine/redmine)). Add this using your own cookbook, see ours as example: [site-forgetypo3org](http://github.com/typo3-cookbooks/site-forgetypo3org). Bundler runs as the Redmine user and installs these Gems into `vendor/gems/` in your Redmine installation.

Binstubs are also created, which care be used by the thin recipe / init script.

Database
--------

MySQL is the only tested database. Sqlite could work.

Attributes
==========
* `node[:redmine][:rails_env]` -  The RAILS ENVIRONMENT used. Defaults to production`.
* `node[:redmine][:deploy_to]` -  Base directory for Redmine deployement. Defaults to `/srv/redmine`
* `node[:redmine][:force_deploy]` -  boolean to trigger a deployment if the sha1/reference was not updated. only usefull in development. Should not be set in production env. Defaults to false
* `node[:redmine][:hostname]` - Host name of the Redmine server (used as the vhost's server_name). Defaults to `node[:fqdn]`.
* `node[:redmine][:database][:name]` - Database name. Defaults to `redmine`.
* `node[:redmine][:database][:username]` - Database user name. Defaults to `redmine`.
* `node[:redmine][:database][:password]` - Database user's password. Defaults to `nil`.
* `node[:redmine][:database][:hostname]` - Database host. Defaults to `localhost`.

* `node[:redmine][:branch]` - Branch of Redmine that is used. Needed e.g. for some `rake` tasks, which changed from 1.x to 2.x. Defaults to `2.2`.
* `node[:redmine][:source][:repository]` - Git repository. At the moment, you have to use your own fork, as a `Gemfile.lock` is required. Defaults to `git://github.com/redmine/redmine.git`.
* `node[:redmine][:source][:reference]` - Git reference (branch, tag, commit SHA1) to checkout. Defaults to `2.2-stable`.

