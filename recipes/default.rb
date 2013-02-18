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
libpq-dev
imagemagick
libmagick++-dev
libsqlite3-dev
}.each do |pgk|
  package pgk
end

#  rake rausgenommen TEST
%w{
  bundler
}.each do |gm|
  gem_package gm
end

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


deploy_revision "redmine" do
  repository node['redmine']['source']['repository']
  revision node['redmine']['source']['reference']
  deploy_to node['redmine']['deploy_to']
  enable_submodules true
  user "redmine"
  group "redmine"
  environment "RAILS_ENV" => "production"
  
  before_migrate do
    %w{config log system pids}.each do |dir|
      directory "#{node['redmine']['deploy_to']}/shared/#{dir}" do
        owner "redmine"
        group "redmine"
        mode '0755'
        recursive true
      end
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

    template "#{node['redmine']['deploy_to']}/shared/config/database.yml" do
      source "redmine/database.yml"
      owner "redmine"
      group "redmine"
      variables :database_server => node['redmine']['database']['hostname']
      mode "0664"
    end

    template "#{node['redmine']['deploy_to']}/shared/config/email.yml" do
      source "redmine/email.yml"
      owner "redmine"
      group "redmine"
      mode "0664"
    end

    template "#{release_path}/Gemfile.lock" do
      source "redmine/Gemfile.lock"
      owner "redmine"
      group "redmine"
      mode "0664"
    end

    execute "bundle install" do
      command "bundle install --binstubs --deployment --without development test"
      cwd release_path
      user "redmine"
    end

    execute "rake generate_session_store" do
      command "/var/lib/gems/1.8/bin/bundle exec rake generate_session_store"
      user "redmine"
      cwd release_path
      creates "#{node['redmine']['deploy_to']}/shared/config/initializers/session_store.rb"
      only_if { node['redmine']['branch'] =~ /^1.4/ }
      not_if { ::File.exists?("#{release_path}/db/schema.rb") }
    end

    execute "rake generate_secret_token" do
      command "/var/lib/gems/1.8/bin/bundle exec rake generate_secret_token"
      user "redmine"
      cwd release_path
      creates "#{node['redmine']['deploy_to']}/shared/config/initializers/secret_token.rb"
      only_if { node['redmine']['branch'] =~ /^2./ }
      not_if { ::File.exists?("#{release_path}/db/schema.rb") }
    end
  end

  migrate true
  migration_command 'bundle exec rake db:migrate:all'

  action :deploy
  notifies :restart, "service[thin-redmine]"
end

include_recipe "redmine::thin"
include_recipe "redmine::nginx"
