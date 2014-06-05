desc "Runs all specs"
task spec: %w[
              db:recreate
              spec:outer
              spec:unit:fast
              spec:unit:lib
              spec:unit:controllers:services
              spec:unit:controllers:runtime
            ]

namespace :spec do
  task api: "db:pick" do
    sh "bundle exec rspec spec/api --order rand:$RANDOM --format RspecApiDocumentation::ApiFormatter"
  end

  task acceptance: "db:pick" do
    run_specs("spec/acceptance")
  end

  task integration: "db:pick" do
    run_specs("spec/integration")
  end

  task outer: %w[api acceptance integration]

  namespace :unit do
    fast_suites = %w[
        access
        jobs
        models
        presenters
        repositories
      ]

    fast_suites.each do |layer_name|
      task layer_name => "db:pick" do
        run_specs("spec/unit/#{layer_name}")
      end
    end

    task fast: fast_suites

    task :lib do
      run_specs("spec/unit/lib")
    end

    namespace :controllers do
      task :services do
        run_specs("spec/unit/controllers/services")
      end

      task :runtime do
        run_specs("spec/unit/controllers/base spec/unit/controllers/runtime")
      end
    end
  end

  def run_specs(path)
    sh "bundle exec rspec #{path} --order rand:1234 --require rspec/instafail --format RSpec::Instafail"
  end
end
