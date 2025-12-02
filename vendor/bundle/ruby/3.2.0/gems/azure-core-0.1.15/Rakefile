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
require 'rake/testtask'
require 'rubygems/package_task'

gem_spec = eval(File.read('./azure-core.gemspec'))
Gem::PackageTask.new(gem_spec) do |pkg|
  pkg.need_zip = false
  pkg.need_tar = false
end

namespace :test do

  Rake::TestTask.new :unit do |t|
    t.pattern = 'test/unit/**/*_test.rb'
    t.verbose = true
    t.libs = %w(lib test)
  end

  namespace :unit do
    def component_task(component)
      Rake::TestTask.new component do |t|
        t.pattern = "test/unit/#{component}/**/*_test.rb"
        t.verbose = true
        t.libs = %w(lib test)
      end
    end

    component_task :core
  end

end

task :test => %w(test:unit)

task :default => :test
