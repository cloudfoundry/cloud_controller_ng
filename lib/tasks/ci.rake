namespace :ci do
  task :rubocop do
    Rake::Task["rubocop"].invoke
  end

  namespace :spec do
    namespace :services do
      task :transactional do
        sh "bundle exec rspec spec --tag team:services --tag ~non_transactional --order rand:1234 --require rspec/instafail --format RSpec::Instafail"
      end

      task :non_transactional do
        sh "bundle exec rspec spec --tag team:services --tag non_transactional  --order rand:1234 --require rspec/instafail --format RSpec::Instafail"
      end
    end

    namespace :non_services do
      task :transactional do
        sh "bundle exec rspec spec --tag ~team:services --tag ~non_transactional --order rand:1234 --require rspec/instafail --format RSpec::Instafail"
      end

      task :non_transactional do
        sh "bundle exec rspec spec --tag ~team:services --tag non_transactional  --order rand:1234 --require rspec/instafail --format RSpec::Instafail"
      end
    end

    task :api do
      sh "bundle exec rspec spec/api --tag ~non_transactional --order rand:$RANDOM --format RspecApiDocumentation::ApiFormatter"
    end
  end
end
