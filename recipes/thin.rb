#
# Cookbook Name:: redmine
# Recipe:: thin
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


[
  "/etc/thin",
  "/var/log/thin",
].each do |dir|
  directory dir
end

template "/etc/init.d/thin-redmine" do
  source "thin/init.d.erb"
  mode 0755
  notifies :restart, "service[thin-redmine]"
end

template "/etc/thin/redmine.yml" do
  source "thin/redmine.yml"
  notifies :restart, "service[thin-redmine]"
end

[
"/var/run/thin",
"/var/run/redmine"
].each do |dir|
  directory dir do
    user "redmine"
    group "redmine"
    recursive true
  end
end

service "thin-redmine" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
  # finish the chef run only after service is available
  notifies :run, 'ruby_block[wait_until_ready]'
end

ruby_block "wait_until_ready" do
  block do
    wait_until_ready!
  end
  action :nothing
end
