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

include_recipe "git"

# @todo: support other ruby implementations (jruby, rbenv, ...)
%w{
  ruby
  rubygems
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
gem_package "bundler" do
  options("--no-ri --no-rdoc")
end





#######################
# Redmine
#######################

case node['redmine']['database']['type']
  when "sqlite"
    include_recipe "sqlite"
  when "mysql", "mysql2"
    include_recipe "mysql::client"
    include_recipe "redmine::mysql"
end

if node['redmine']['release'].nil?
  redmine_release = node['redmine']['source']['reference'].gsub(/[^\d\.].*/, '')
  if redmine_release.nil?
    Chef::Log.fatal("Could not detect the redmine release. Specify it in node['redmine']['release'].")
  end
else
  redmine_release = node['redmine']['release']
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

  secret_token_file = Gem::Version.new(redmine_release) < Gem::Version.new('2.0.0') ? 'session_store.rb' : 'secret_token.rb'

  symlink_before_migrate({
      "config/database.yml" => "config/database.yml",
      "config/#{secret_token_file}" => "config/initializers/#{secret_token_file}"
  })

  purge_before_symlink %w{log files}
  symlinks({
      "files" => "files",
      "log" => "log",
      "config/configuration.yml" => "config/configuration.yml"
  }.merge(node['redmine']['deploy']['additional_symlinks']))

  before_migrate do

    # Chef runs before_migrate, then symlink_before_migrate, then migrations,
    # yet our before_migrate needs database.yml and secret_token.rb to exist
    # (and must complete before migrations).

    execute "symlink_before_before_migrate" do
      # This is a workaround for the problem mentioned above:
      # - add database.yml symlink manually
      # - copy the secret_token_file from shared/config/ and ignore if it's missing (it will be created by generate_secret_token in this case)
      command <<-EOH
        ln -s ../../../shared/config/database.yml config/database.yml
        cp -a ../../shared/config/#{secret_token_file} config/initializers/#{secret_token_file} || true
      EOH
      cwd release_path
      environment new_resource.environment
      user "redmine"
    end

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

    # we just bundle as user and "fake" --deployment to gain some more flexibility on existance and state of Gemfile.lock
    execute "bundle install --binstubs --path=vendor/bundle --without development test" do
      cwd release_path
      environment new_resource.environment
      user "redmine"
    end

    # handle generate_session_store / secret_token
    # @todo improve way to get redmine version
    if Gem::Version.new(redmine_release) < Gem::Version.new('2.0.0')
      execute 'bundle exec rake generate_session_store' do
        environment new_resource.environment
        cwd release_path
        user "redmine"
        not_if { ::File.exists?("#{release_path}/config/initializers/session_store.rb") }
      end
    else
      execute 'bundle exec rake generate_secret_token' do
        environment new_resource.environment
        cwd release_path
        user "redmine"
        not_if { ::File.exists?("#{release_path}/config/initializers/secret_token.rb") }
      end
    end

    execute "symlink_after_before_migrate" do
      # This is part 2 of an ugly workaround, see symlink_before_before_migrate:
      # - copy the secret_token_file back to shared/config/
      # - database.yml and secret_token_file will be overwritten by symlink_before_migrate, so a further cleanup is not needed
      command <<-EOH
        cp -a config/initializers/#{secret_token_file} #{node['redmine']['deploy_to']}/shared/config/#{secret_token_file}
      EOH
      cwd release_path
      environment new_resource.environment
      user "redmine"
    end
  end

  migrate true

  if Gem::Version.new(redmine_release) < Gem::Version.new('2.0.0')
    migration_command 'bundle exec rake db:migrate db:migrate:plugins tmp:cache:clear tmp:sessions:clear'
  else
    migration_command 'bundle exec rake db:migrate redmine:plugins:migrate redmine:plugins:assets tmp:cache:clear tmp:sessions:clear'
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
include_recipe "redmine::logrotate"
