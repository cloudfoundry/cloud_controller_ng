#--
# Cloud Foundry
# Copyright (c) [2009-2014] Pivotal Software, Inc. All Rights Reserved.
#
# This product is licensed to you under the Apache License, Version 2.0 (the "License").
# You may not use this product except in compliance with the License.
#
# This product includes a number of subcomponents with
# separate copyright notices and license terms. Your use of these
# subcomponents is subject to the terms and conditions of the
# subcomponent's license, as noted in the LICENSE file.
#++

require "rspec/core/rake_task"
require "bundler/gem_tasks" # only available in bundler >= 1.0.15
require "ci/reporter/rake/rspec"

ENV['CI_REPORTS'] = File.expand_path("spec_reports")
COV_REPORTS = File.expand_path("coverage")

task :default => [:test]
task :tests => [:test]
task :spec => [:test]

RSpec::Core::RakeTask.new("test") do |t|
  t.rspec_opts = ["--format", "documentation", "--colour"]
  t.pattern = "spec/**/*_spec.rb"
end

task :ci => [:pre_coverage, :rcov_reports, "ci:setup:rspec", :test]
task :cov => [:pre_coverage, :test, :view_coverage]
task :coverage => [:pre_coverage, :test]

task :pre_coverage do
  rm_rf COV_REPORTS
  ENV['COVERAGE'] = "exclude-spec exclude-vendor"
end

task :rcov_reports do
  ENV['COVERAGE'] += " rcov"
end

task :view_coverage do
  `firefox #{File.join(COV_REPORTS, 'index.html')}`
end
