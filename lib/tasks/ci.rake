namespace :ci do
  task basics: %w[rubocop spec:api]

  task :rubocop do
    Rake::Task["rubocop"].invoke
  end

  namespace :spec do
    task :api do
      sh "bundle exec rspec spec/api --tag ~non_transactional --order rand:$RANDOM --format RspecApiDocumentation::ApiFormatter"
    end

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
  end
end
