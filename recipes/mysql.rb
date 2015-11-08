#
# Cookbook Name:: redmine
# Recipe:: mysql
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

include_recipe "build-essential"
#include_recipe "mysql::server"
#include_recipe "database::mysql"

# include the #secure_password method
Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

mysql2_chef_gem 'default' do
  action :install
end

# Disable the default MySQL service
# Needed due to the bug https://github.com/chef-cookbooks/mysql/issues/378
case node["platform_family"]
when "debian"
  service "mysql" do
    action [ :disable, :stop ]
  end
end

mysql_service 'redmine' do
  #server_debian_password  node['mysql']['server_root_password']
  bind_address '::ffff:127.0.0.1'
  socket "/run/mysql-redmine/mysqld-sock"
  initial_root_password  node['mysql']['server_root_password']
  action [:create, :start]
end

mysql_connection_info = {
  :host =>  "localhost",
  :username => "root",
  :password => node['mysql']['server_root_password'],
  :socket => "/run/mysql-redmine/mysqld-sock"
}

mysql_database node['redmine']['database']['name'] do
  connection mysql_connection_info
  encoding node['redmine']['database']['encoding']
  collation node['redmine']['database']['collation']
  action :create
end

node.set_unless['redmine']['database']['password'] = secure_password

mysql_database_user node['redmine']['database']['username'] do
  connection mysql_connection_info
  password node['redmine']['database']['password']
  action :create
end

mysql_database_user node['redmine']['database']['username'] do
  connection mysql_connection_info
  database_name node['redmine']['database']['name']
  privileges [
    :all
  ]
  action :grant
end

mysql_database 'flush mysql privileges' do
  connection mysql_connection_info
  database_name 'mysql'
  sql        'FLUSH PRIVILEGES'
  action     :query
end
