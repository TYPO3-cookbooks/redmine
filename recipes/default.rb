#
# Cookbook Name:: redmine
# Recipe:: default
#
# Copyright 2012, Steffen Gebert / TYPO3 Association
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#######################
# User
#######################

group "redmine"

user "redmine" do
  shell "/bin/bash"
  group "redmine"
end

directory "/home/redmine" do
  owner "redmine"
  group "redmine"
end

#######################
# Packages
#######################

include_recipe "build-essential"
include_recipe "git"

# @todo: support other ruby implementations (jruby, rbenv, ...)
%w{
  ruby
  subversion
}.each do |pkg|
  package pkg
end

%w{
  ruby-dev
  libpq-dev
  imagemagick
  libmagick++-dev
  libsqlite3-dev
}.each do |pgk|
  package pgk
end

# only require bundler as everything else is managed by bundler
gem_package "bundler"





#######################
# Redmine
#######################

case node['redmine']['database']['type']
  when "sqlite"
    include_recipe "sqlite"
  when "mysql"
    include_recipe "mysql::client"
    include_recipe "redmine::mysql"
end


directories = %w{
  /
  shared/
  shared/config/
  shared/files/
  shared/log/
}.concat(node['redmine']['deploy']['additional_directories'])

# ensure that all directories start with a /
# we need .chr() for ruby 1.8 compatibility
directories.map!{|dir| (dir[0].chr() == "/" ? dir : "/#{dir}") }

directories.each do |dir|
  directory "#{node['redmine']['deploy_to']}#{dir}" do
    owner "redmine"
    group "redmine"
    mode '0755'
    recursive true
  end
end

deploy_revision "redmine" do
  repository node['redmine']['source']['repository']
  revision node['redmine']['source']['reference']
  deploy_to node['redmine']['deploy_to']
  enable_submodules true
  user "redmine"
  group "redmine"
  environment "RAILS_ENV" => node['redmine']['rails_env']

  symlink_before_migrate "config/database.yml" => "config/database.yml"

  purge_before_symlink %w{log files}
  symlinks({
      "files" => "files",
      "log" => "log",
      "config/configuration.yml" => "config/configuration.yml"
  }.merge(node['redmine']['deploy']['additional_symlinks']))

  before_migrate do

    # danger on Gemfile.local, it must be in place rather early as otherwise bundler will not detect the dependency
    # it seems the symlink_before_migrate does only happen after this piece of code is processed
    template "#{release_path}/Gemfile.local" do
      source "redmine/Gemfile.local.erb"
      owner "redmine"
      group "redmine"
      mode "0664"
    end

    template "#{node['redmine']['deploy_to']}/shared/config/configuration.yml" do
      source "redmine/configuration.yml"
      owner "redmine"
      group "redmine"
      mode "0664"
    end

    template "#{node['redmine']['deploy_to']}/shared/config/database.yml" do
      source "redmine/database.yml"
      owner "redmine"
      group "redmine"
      variables :database_server => node['redmine']['database']['hostname']
      mode "0664"
    end

    case node['redmine']['database']['type']
      when "sqlite"
        gem_package "sqlite3-ruby"
        file "#{node['redmine']['deploy_to']}/db/production.db" do
          owner "redmine"
          group "redmine"
          mode "0644"
        end
    end

    # we just bundle as root without --deployment
    execute "bundle install --binstubs --without development test" do
      command "bundle install --binstubs --without development test"
      cwd release_path
    end

    # handle generate_session_store / secret_token
    # @todo improve way to get redmine version
    if Gem::Version.new(node['redmine']['source']['reference'].gsub!('/[\D\.]/', '')) < Gem::Version.new('2.0.0')
    #if Gem::Version.new('1.4') < Gem::Version.new('2.0.0')
      execute 'bundle exec rake generate_session_store' do
        cwd release_path
        not_if { ::File.exists?("#{release_path}/db/schema.rb") }
      end
    else
      execute 'bundle exec rake generate_secret_token' do
        cwd release_path
        not_if { ::File.exists?("#{release_path}/config/initializers/secret_token.rb") }
      end
    end

  end

  migrate true
  migration_command 'bundle exec rake db:migrate db:migrate_plugins tmp:cache:clear tmp:sessions:clear'

  # remove the cached-copy folder caching the git repo, as it more harms than it helps us
  # reasons:
  # - does not remove files that were removed from repo
  # - does not sync submodules
  after_restart do
    directory "#{node['redmine']['deploy_to']}/shared/cached-copy" do
      action :delete
      recursive true
    end
  end

  action :deploy
  notifies :restart, "service[thin-redmine]"
end

##########################
# Includes
##########################

include_recipe "redmine::thin"
include_recipe "redmine::nginx"
include_recipe "redmine::cron"