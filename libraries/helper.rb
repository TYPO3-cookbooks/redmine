#
# Cookbook Name:: gerrit
# Library:: helpers
#
# Copyright 2017, TYPO3 Association
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
#

require 'timeout'

module Redmine
  module Helpers

    class ConnectTimeout < Timeout::Error; end

    class ServiceNotReady < StandardError
      def initialize(endpoint, timeout)
        super "The service at '#{endpoint}' did not become ready within #{timeout} seconds."
      end
    end

    def wait_until_ready!
      timeout = 60
      endpoint = "http://localhost:80"
      Timeout.timeout(timeout, ConnectTimeout) do
        begin
          open(endpoint)
        rescue SocketError,
          Errno::ECONNREFUSED,
          Errno::ECONNRESET,
          Errno::ENETUNREACH,
          Timeout::Error,
          OpenURI::HTTPError => e
          # If authentication has been enabled, the server will return an HTTP
          # 403. This is "OK", since it means that the server is actually
          # ready to accept requests.
          return if e.message =~ /^403/

          Chef::Log.debug("Service is not accepting requests - #{e.message}")
          sleep(0.5)
          retry
        end
      end
    rescue ConnectTimeout
      raise ServiceNotReady.new(endpoint, timeout)
    end

  end
end

Chef::Node::Attribute.send(:include, ::Redmine::Helpers)
Chef::Recipe.send(:include, ::Redmine::Helpers)
Chef::Resource.send(:include, ::Redmine::Helpers)
Chef::Provider.send(:include, ::Redmine::Helpers)
