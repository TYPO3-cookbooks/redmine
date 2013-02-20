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

#  rake rausgenommen TEST
%w{
  bundler
}.each do |gm|
  gem_package gm
end

bundle_install_dir = "vendor/bundle"

#######################
# Redmine
#######################

directory node['redmine']['dir'] do
  owner "redmine"
  recursive true
end

git "redmine" do
  repository node['redmine']['source']['repository']
  reference node['redmine']['source']['reference']
  destination node['redmine']['dir']
  enable_submodules true
  user "redmine"
  group "redmine"
  notifies :run, "execute[bundle install]", :immediately
  notifies :restart, "service[thin-redmine]"
end

case node['redmine']['database']['type']
when "sqlite"
  include_recipe "sqlite"
  gem_package "sqlite3-ruby"
  file "#{node.redmine.dir}/db/production.db" do
    owner "redmine"
    group "redmine"
    mode "0644"
  end
when "mysql"
  include_recipe "mysql::client"
  include_recipe "redmine::mysql"
end

template "#{node.redmine.dir}/config/email.yml" do
  source "redmine/email.yml"
  owner "redmine"
  group "redmine"
  mode "0664"
end

template "#{node.redmine.dir}/config/database.yml" do
  source "redmine/database.yml"
  owner "redmine"
  group "redmine"
  variables :database_server => node['redmine']['database']['hostname']
  mode "0664"
end

template "#{node.redmine.dir}/Gemfile.lock" do
  source "redmine/Gemfile.lock"
  owner "redmine"
  group "redmine"
  mode "0664"
  notifies :run, "execute[bundle install]", :immediately
end

execute "bundle install" do
  command "bundle install --binstubs --deployment"
  cwd node['redmine']['dir']
  user "redmine"
  only_if { ::File.exists?("#{node.redmine.dir}/Gemfile.lock") }
  action :nothing
end

execute "rake generate_session_store" do
  command "/var/lib/gems/1.8/bin/bundle exec rake generate_session_store"
  user "redmine"
  cwd node['redmine']['dir']
  creates "#{node.redmine.dir}/config/initializers/session_store.rb"
  only_if { node['redmine']['branch'] =~ /^1.4/ }
end

execute "rake generate_secret_token" do
  command "/var/lib/gems/1.8/bin/bundle exec rake generate_secret_token"
  user "redmine"
  cwd node['redmine']['dir']
  creates "#{node.redmine.dir}/config/initializers/secret_token.rb"
  only_if { node['redmine']['branch'] =~ /^2./ }
end

execute "rake db:migrate:all" do
  command "bundle exec rake db:migrate:all"
  environment ({"RAILS_ENV" => "production"})
  user "redmine"
  cwd node['redmine']['dir']
#  action :nothing
end

include_recipe "redmine::thin"
include_recipe "redmine::nginx"