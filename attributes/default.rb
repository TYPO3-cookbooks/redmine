# Cookbook Name:: redmine
# Attributes:: default
#
# Copyright 2021, Steffen Gebert / TYPO3 Association
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'openssl'

pw = String.new

while pw.length < 20
  pw << OpenSSL::Random.random_bytes(1).gsub(/\W/, '')
end

default['redmine']['rails_env'] = "production"
default['redmine']['thin_servers'] = "1"

default['redmine']['dir'] = "/usr/share/redmine"
default['redmine']['deploy_to'] = "/usr/local/share/redmine"

default['redmine']['hostname'] = fqdn

default['redmine']['database']['type']     = "mysql"
default['redmine']['database']['name']     = "redmine"
default['redmine']['database']['username'] = "redmine"
default['redmine']['database']['password'] = nil
default['redmine']['database']['hostname'] = "localhost"


default['redmine']['branch'] = "2.2"
default['redmine']['source']['repository'] = "git://github.com/redmine/redmine.git"
default['redmine']['source']['reference']  = "2.2-stable"

default['redmine']['deploy']['additional_symlinks'] = {}
