desc 'Runs all specs'
task spec: 'spec:all'

namespace :spec do
  task all: ['db:pick', 'db:parallel:recreate'] do
    if ARGV[1]
      run_specs(ARGV[1])
    else
      run_specs_parallel('spec')
      # Run isolated specs separately since they might affect other tests
      run_specs('spec/isolated_specs')
    end
  end

  task serial: ['db:pick', 'db:recreate'] do
    run_specs(ARGV[1] || 'spec')
  end

  task integration: ['db:pick', 'db:recreate'] do
    run_specs('spec/integration')
  end

  desc 'Run only previously failing tests'
  task failed: 'db:pick' do
    run_failed_specs
  end

  desc 'Run tests on already migrated databases'
  task without_migrate: ['db:pick'] do
    # We exclude specs that test migration behaviour since this breaks/alters the DB in the middle of a test
    if ARGV[1]
      run_specs(ARGV[1], 'NO_DB_MIGRATION=true')
    else
      run_specs_parallel('spec', 'NO_DB_MIGRATION=true')
      # Run isolated specs separately since they might affect other tests
      run_specs('spec/isolated_specs')
    end
  end

  def run_specs(path, env_vars='')
    sh "#{env_vars} bundle exec rspec #{path} --require rspec/instafail --format RSpec::Instafail --format progress"
  end

  def run_specs_parallel(path, env_vars='')
    command = <<~CMD
      #{env_vars} bundle exec parallel_rspec \
      --test-options '--order rand' \
      --single spec/integration/ \
      --single spec/acceptance/ \
      --exclude-pattern 'spec/isolated_specs/' \
      -- #{path}
    CMD

    sh command
  end

  def run_failed_specs
    sh 'bundle exec rspec --only-failures --color --tty spec --require rspec/instafail --format RSpec::Instafail'
  end
end
