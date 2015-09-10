desc "Runs all specs"
task spec: %w[
              db:pick
              db:recreate
              spec:unit:fast
              spec:unit:controllers
              spec:unit:lib
              spec:outer
            ]

namespace :spec do
  task all: "db:pick" do
    run_specs("spec")
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
        jobs
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
end
