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

  namespace :db do
    task :create do
      case ENV["DB"]
        when "postgres"
          sh "psql -U postgres -c 'create database cc_test_;'"
        when "mysql"
          if ENV["TRAVIS"] == "true"
            sh "mysql -e 'create database cc_test_;'"
          else
            sh "mysql -e 'create database cc_test_;' -u root --password=password"
          end
      end
    end

    task :drop do
      case ENV["DB"]
        when "postgres"
          sh "psql -U postgres -c 'drop database cc_test_;'"
        when "mysql"
          if ENV["TRAVIS"] == "true"
            sh "mysql -e 'drop database cc_test_;'"
          else
            sh "mysql -e 'drop database cc_test_;' -u root --password=password"
          end
      end
    end

    task recreate: %w[drop create]
  end
end
