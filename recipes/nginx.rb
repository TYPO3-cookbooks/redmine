#
# Cookbook Name:: redmine
# Recipe:: nginx
#
# Copyright 2013, Steffen Gebert / TYPO3 Association
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

include_recipe "chef_nginx"

template "/etc/nginx/sites-available/#{node['redmine']['hostname']}" do
  source "nginx/nginx-site.erb"
  notifies :reload, "service[nginx]"
end

template "/etc/nginx/conf.d/upstream_thin.conf" do
  source "nginx/upstream_thin.conf"
  notifies :reload, "service[nginx]"
end

nginx_site node['redmine']['hostname'] do
  enable true
end
