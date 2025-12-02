require "rake/testtask"

Rake::TestTask.new do |t|
  t.description = "Run integration and unit tests"
  t.libs << "test"
  t.pattern = File.join("test", "**", "test_*.rb")
  t.warning = false
end

namespace :test do
  mock = ENV["FOG_MOCK"] || "true"
  task :travis do
    sh("bundle exec rake test:unit")
  end

  desc "Run all integration tests in parallel"
  multitask :parallel => ["test:compute",
                          "test:monitoring",
                          "test:pubsub",
                          "test:sql",
                          "test:storage"]

  Rake::TestTask.new do |t|
    t.name = "unit"
    t.description = "Run Unit tests"
    t.libs << "test"
    t.pattern = FileList["test/unit/**/test_*.rb"]
    t.warning = false
    t.verbose = true
  end

  # This autogenerates rake tasks based on test folder structures
  # This is done to simplify running many test suites in parallel
  COMPUTE_TEST_TASKS = []
  Dir.glob("test/integration/compute/**").each do |task|
    suite_collection = task.gsub(/test\/integration\/compute\//, "")
    component_name = task.gsub(/test\/integration\//, "").split("/").first
    Rake::TestTask.new(:"#{component_name}-#{suite_collection}") do |t|
      t.libs << "test"
      t.description = "Autotask - run #{component_name} integration tests - #{suite_collection}"
      t.pattern = FileList["test/integration/#{component_name}/#{suite_collection}/test_*.rb"]
      t.warning = false
      t.verbose = true
    end
    COMPUTE_TEST_TASKS << "#{component_name}-#{suite_collection}"
  end

  desc "Run Compute API tests"
  task :compute => COMPUTE_TEST_TASKS

  desc "Run Compute API tests in parallel"
  multitask :compute_parallel => COMPUTE_TEST_TASKS

  Rake::TestTask.new do |t|
    t.name = "monitoring"
    t.description = "Run Monitoring API tests"
    t.libs << "test"
    t.pattern = FileList["test/integration/monitoring/test_*.rb"]
    t.warning = false
    t.verbose = true
  end

  Rake::TestTask.new do |t|
    t.name = "pubsub"
    t.description = "Run PubSub API tests"
    t.libs << "test"
    t.pattern = FileList["test/integration/pubsub/test_*.rb"]
    t.warning = false
    t.verbose = true
  end

  # This autogenerates rake tasks based on test folder structures
  # This is done to simplify running many test suites in parallel
  SQL_TEST_TASKS = []
  Dir.glob("test/integration/sql/**").each do |task|
    suite_collection = task.gsub(/test\/integration\/sql\//, "")
    component_name = task.gsub(/test\/integration\//, "").split("/").first
    Rake::TestTask.new(:"#{component_name}-#{suite_collection}") do |t|
      t.libs << "test"
      t.description = "Autotask - run #{component_name} integration tests - #{suite_collection}"
      t.pattern = FileList["test/integration/#{component_name}/#{suite_collection}/test_*.rb"]
      t.warning = false
      t.verbose = true
    end
    SQL_TEST_TASKS << "#{component_name}-#{suite_collection}"
  end

  desc "Run SQL API tests"
  task :sql => SQL_TEST_TASKS

  desc "Run SQL API tests in parallel"
  multitask :sql_parallel => SQL_TEST_TASKS

  # TODO(temikus): Remove after v1 is renamed in pipeline
  desc "Run SQL API tests - v1 compat alias"
  task :"sql-sqlv2" => :sql

  Rake::TestTask.new do |t|
    t.name = "sql"
    t.description = "Run SQL API tests"
    t.libs << "test"
    t.pattern = FileList["test/integration/sql/test_*.rb"]
    t.warning = false
    t.verbose = true
  end

  Rake::TestTask.new do |t|
    t.name = "storage"
    t.description = "Run Storage API tests"
    t.libs << "test"
    t.pattern = FileList["test/integration/storage/test_*.rb"]
    t.warning = false
    t.verbose = true
  end
end
