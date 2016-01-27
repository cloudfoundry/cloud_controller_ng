desc "Runs all specs"
task spec: %w[
              db:pick
              db:recreate
              spec:unit:fast
              spec:unit:controllers
              spec:unit:lib
              spec:unit:middleware
              spec:outer
            ]

namespace :spec do
  task all: "db:pick" do
    run_specs("spec")
  end

  desc "Generate the API documents, use path to generate docs for one file"
  task :api, [:path] => "db:pick" do |t, args|
    if args[:path]
      run_docs("documentation/#{args[:path]}")
    else
      run_docs
    end
  end

  desc "Run the acceptance tests"
  task acceptance: "db:pick" do
    run_specs("spec/acceptance")
  end

  desc "Run the integration tests"
  task integration: "db:pick" do
    run_specs("spec/integration")
  end

  desc "Run the request tests"
  task request: "db:pick" do
    run_specs("spec/request")
  end

  task outer: %w[api acceptance integration request]

  desc 'Run only previously failing tests'
  task failed: "db:pick" do
    run_failed_specs
  end

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

    desc "Run the unit middleware tests"
    task :middleware do
      run_specs("spec/unit/middleware")
    end
  end

  def run_specs(path)
    sh "bundle exec rspec #{path} --require rspec/instafail --format RSpec::Instafail"
  end

  def run_docs(path="")
    sh "bundle exec rspec spec/api/#{path} --format RspecApiDocumentation::ApiFormatter"
  end

  def run_failed_specs
    sh "bundle exec rspec --only-failures --color --tty spec --require rspec/instafail --format RSpec::Instafail"
  end
end
