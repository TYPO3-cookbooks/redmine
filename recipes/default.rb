#
# Cookbook Name:: redmine
# Recipe:: default
#
# Copyright 2012-2013, Steffen Gebert & Peter Niederlag / TYPO3 Association
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

if node['redmine']['clear_cached_copy']
  directory "#{node['redmine']['deploy_to']}/shared/cached-copy" do
    action :delete
    recursive true
    only_if { ::File.exists?("#{node['redmine']['deploy_to']}/shared/cached-copy") }
  end
end

deploy_revision "redmine" do
  repository node['redmine']['source']['repository']
  revision node['redmine']['source']['reference']
  deploy_to node['redmine']['deploy_to']
  enable_submodules true
  user "redmine"
  group "redmine"
  # use variable environment (which propably matches the one from chef) ?
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
    # symlink_before_migrate modifier will only run as part of the migration, files will not be available during before_migrate callback
    # that's why we have to also include dependency from database.yml in Gemfile.local. Database.yml will not be in place during before_migrat
    template "Gemfile.local" do
      source "redmine/Gemfile.local.erb"
      path "#{release_path}/Gemfile.local"
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

    # chef runs before_migrate, then symlink_before_migrate symlinks, then migrations,
    # yet our before_migrate needs database.yml to exist (and must complete before
    # migrations).
    #
    # maybe worth doing run_symlinks_before_migrate before before_migrate callbacks,
    # or an add'l callback.
    # we just bundle as user and "fake" --deployment to gain some more flexibility on existance and state of Gemfile.lock
    execute "bundle install --binstubs --path=vendor/bundle --without development test" do
      command "ln -s ../../../shared/config/database.yml config/database.yml; bundle install --binstubs --path=vendor/bundle --without development test; rm config/database.yml"
      cwd release_path
      environment new_resource.environment
      user "redmine"
    end

    # handle generate_session_store / secret_token
    # @todo improve way to get redmine version
    if Gem::Version.new(node['redmine']['source']['reference'].gsub!('/[\D\.]/', '')) < Gem::Version.new('2.0.0')
    #if Gem::Version.new('1.4') < Gem::Version.new('2.0.0')
      execute 'bundle exec rake generate_session_store' do
        environment new_resource.environment
        cwd release_path
        user "redmine"
        not_if { ::File.exists?("#{release_path}/db/schema.rb") }
      end
    else
      execute 'bundle exec rake generate_secret_token' do
        environment new_resource.environment
        cwd release_path
        user "redmine"
        not_if { ::File.exists?("#{release_path}/config/initializers/secret_token.rb") }
      end
    end

  end

  migrate true
  # @todo redmine version specific migrate command (?)
  #migration_command 'bundle exec rake db:migrate redmine:plugins:migrate tmp:cache:clear tmp:sessions:clear'
  migration_command 'bundle exec rake db:migrate db:migrate:plugins tmp:cache:clear tmp:sessions:clear'

  end

  action node['redmine']['force_deploy'] ? :force_deploy : :deploy
  notifies :restart, "service[thin-redmine]"
end

##########################
# Includes
##########################

include_recipe "redmine::thin"
include_recipe "redmine::nginx"
include_recipe "redmine::cron"
