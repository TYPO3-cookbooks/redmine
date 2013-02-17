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

include_recipe "thin"

file "/usr/share/redmine/Gemfile.local" do
  owner "redmine"
  group "redmine"
  content 'gem "thin"'
  notifies :run, "execute[bundle install]"
end

template "/etc/thin/redmine.yml" do
  source "thin/redmine.yml"
  notifies :restart, "service[thin]"
end

[
  "/var/run/redmine",
  "/var/run/redmine/sockets"
].each do |dir|
  directory dir do
    user "redmine"
    group "redmine"
    recursive true
  end
end

