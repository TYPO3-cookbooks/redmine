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

%w{
  subversion
}.each do |pkg|
  package pkg
end

%w{
  libpq-dev
  imagemagick
  libmagick++-dev
  libsqlite3-dev
}.each do |pgk|
  package pgk
end

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

secret_token_file = node['redmine']['branch'] =~ /^1.4/ ? "session_store.rb" : "secret_token.rb"

if node['redmine']['secret_token_secret'].nil?
  secret_token_secret = ''

  while secret_token_secret.length < 30
    secret_token_secret << ::OpenSSL::Random.random_bytes(10).gsub(/\W/, '')
  end

  node.set['redmine']['secret_token_secret'] = secret_token_secret

  Chef::Log.info "Generated new secret token"
else
  secret_token_secret = node['redmine']['secret_token_secret']
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

template "#{node['redmine']['deploy_to']}/shared/config/#{secret_token_file}" do
  source "redmine/#{secret_token_file}.erb"
  user "redmine"
  group "redmine"
  variables :secret => secret_token_secret
end

%w{config files log system pids}.each do |dir|
  directory "#{node['redmine']['deploy_to']}/shared/#{dir}" do
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

  symlink_before_migrate "config/database.yml" => "config/database.yml",
                         "config/#{secret_token_file}" => "config/initializers/#{secret_token_file}"

  purge_before_symlink %w{log files}
  symlinks "system" => "public/system",
    "pids" => "tmp/pids",
    "log" => "log",
    "config/configuration.yml" => "config/configuration.yml",
    "config/amqp.yml" => "config/amqp.yml",
    "files" => "files"


  before_migrate do

    case node['redmine']['database']['type']
      when "sqlite"
        gem_package "sqlite3-ruby"
        file "#{node['redmine']['deploy_to']}/db/production.db" do
          owner "redmine"
          group "redmine"
          mode "0644"
        end
    end

    execute "bundle install" do
      command "bundle install --binstubs --deployment --without development test"
      cwd release_path
      user "redmine"
    end

  end

  migrate true
  migration_command 'bundle exec rake db:migrate:all'

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

link node[:redmine][:dir] do
  to "#{node.redmine.deploy_to}/current"
end

##########################
# Includes
##########################

include_recipe "redmine::thin"
include_recipe "redmine::nginx"
include_recipe "redmine::cron"