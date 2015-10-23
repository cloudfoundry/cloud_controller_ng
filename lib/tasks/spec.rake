desc "Runs all specs, not stopping for failures"
task :spec do
  %w[
      db:pick
      db:recreate
      spec:unit:fast
      spec:unit:controllers
      spec:unit:lib
      spec:outer
  ].each do |task_name|
    begin
      Rake::Task[task_name].invoke
    rescue
    end
  end
  puts 'Re-running failed specs to aggregate failures...'
  run_failed_specs
end

namespace :spec do
  task all: "db:pick" do
    run_specs("spec")
  end

  task failfast: %w[
    db:pick
    db:recreate
    spec:unit:fast
    spec:unit:controllers
    spec:unit:lib
    spec:outer
  ]

  desc 'Run only previously failing tests'
  task failed: "db:pick" do
    run_failed_specs
  end

  desc "Generate the API documents"
  task api: "db:pick" do
    sh "bundle exec rspec spec/api --format RspecApiDocumentation::ApiFormatter"
  end

  desc "Run the acceptance tests"
  task acceptance: "db:pick" do
    run_specs("spec/acceptance")
  end

  desc "Run the integration tests"
  task integration: "db:pick" do
    run_specs("spec/integration")
  end

  task outer: %w[api acceptance integration]

  namespace :unit do
    fast_suites = %w[
        access
        actions
        collection_transformers
        jobs
        messages
        models
        presenters
        queries
        repositories
      ]

    fast_suites.each do |layer_name|
      task layer_name => "db:pick" do
        run_specs("spec/unit/#{layer_name}")
      end
    end

    desc "Run the fast_suites"
    task fast: fast_suites

    desc "Run the unit lib tests"
    task :lib do
      run_specs("spec/unit/lib")
    end

    desc "Run the unit controllers tests"
    task :controllers do
      run_specs("spec/unit/controllers")
    end
  end

  def run_specs(path)
    sh "bundle exec rspec #{path} --require rspec/instafail --format RSpec::Instafail"
  end

  def run_failed_specs
    test_command =  "bundle exec rspec --only-failures --color --tty spec --require rspec/instafail --format RSpec::Instafail"

    output = ''
    IO.popen(test_command).each do |line|
      output << "#{line}"
    end.close
    if $? != 0
      puts output
      abort
    else
      puts 'All tests are passing!'
    end
  end
end
