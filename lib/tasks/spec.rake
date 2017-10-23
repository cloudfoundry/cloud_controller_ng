desc 'Runs all specs'
task spec: 'spec:all'

namespace :spec do
  task all: ['db:pick', 'db:parallel:recreate'] do
    run_specs_parallel('spec', test_options: '--order rand --tag ~performance')
  end

  task serial: ['db:pick', 'db:recreate'] do
    run_specs('spec', test_options: '--tag ~performance')
  end

  task integration: ['db:pick', 'db:recreate'] do
    run_specs('spec/integration')
  end

  task performance: ['db:pick', 'db:recreate'] do
    run_specs('spec/performance')
  end

  desc 'Run only previously failing tests'
  task failed: 'db:pick' do
    run_failed_specs
  end

  def run_specs(path, test_options: '')
    sh "bundle exec rspec #{path} --require rspec/instafail --format RSpec::Instafail --format progress #{test_options}"
  end

  def run_specs_parallel(path, test_options: '')
    sh "bundle exec parallel_rspec --test-options '#{test_options}' --single spec/integration/ -- #{path}"
  end

  def run_failed_specs
    sh 'bundle exec rspec --only-failures --color --tty spec --require rspec/instafail --format RSpec::Instafail'
  end
end
