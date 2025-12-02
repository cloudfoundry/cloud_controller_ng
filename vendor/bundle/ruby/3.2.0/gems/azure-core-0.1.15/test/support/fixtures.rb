#-------------------------------------------------------------------------
# # Copyright (c) Microsoft and contributors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#--------------------------------------------------------------------------
require "azure/core/http/retry_policy"
require "pathname"

module Azure
  module Core
    Fixtures = Hash.new do |hash, fixture|
      if path = Fixtures.xml?(fixture)
        hash[fixture] = path.read
      elsif path = Fixtures.file?(fixture)
        hash[fixture] = path
      end
    end

    def Fixtures.root
      Pathname("../../fixtures").expand_path(__FILE__)
    end

    def Fixtures.file?(fixture)
      path = root.join(fixture)
      path.file? && path
    end

    def Fixtures.xml?(fixture)
      file?("#{fixture}.xml")
    end
    
    class FixtureRetryPolicy < Azure::Core::Http::RetryPolicy
      def initialize
        super &:should_retry?
      end

      def should_retry?(response, retry_data)
        retry_data[:error].inspect.include?('Error: Retry')
      end
    end

    class NewUriRetryPolicy < Azure::Core::Http::RetryPolicy
      def initialize
        @count = 1
        super &:should_retry?
      end

      def should_retry?(response, retry_data)
        retry_data[:uri] = URI.parse "http://bar.com"
        @count = @count - 1
        @count >= 0
      end
    end

  end
end
