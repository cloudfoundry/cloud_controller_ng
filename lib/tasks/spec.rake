desc "Runs all specs"
task spec: 'spec:all'

namespace :spec do
  task all: ['db:pick', 'db:parallel:recreate'] do
    run_specs_parallel("spec")
  end

  task serial: ['db:pick', 'db:recreate'] do
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

  desc 'Run only previously failing tests'
  task failed: "db:pick" do
    run_failed_specs
  end

  def run_specs(path)
    sh "bundle exec rspec #{path} --require rspec/instafail --format RSpec::Instafail"
  end

  def run_specs_parallel(path)
    sh "bundle exec parallel_rspec --test-options '--order rand' --single spec/integration/ -- #{path}"
  end

  def run_docs(path="")
    sh "bundle exec rspec spec/api/#{path} --format RspecApiDocumentation::ApiFormatter"
  end

  def run_failed_specs
    sh "bundle exec rspec --only-failures --color --tty spec --require rspec/instafail --format RSpec::Instafail"
  end
end
