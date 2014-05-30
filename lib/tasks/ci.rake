namespace :ci do
  task basics: %w[rubocop spec:api]

  task :rubocop do
    Rake::Task["rubocop"].invoke
  end

  namespace :spec do
    task api: "db:pick" do
      sh "bundle exec rspec spec/api --order rand:$RANDOM --format RspecApiDocumentation::ApiFormatter"
    end

    task integration: "db:pick" do
      run_specs(include: %w[type:integration])
    end

    namespace :services do
      task transactional: "db:pick" do
        run_specs(include: %w[team:services], exclude: %w[non_transactional type:integration])
      end

      task non_transactional: "db:pick" do
        run_specs(include: %w[non_transactional team:services], exclude: %w[type:integration])
      end
    end

    namespace :non_services do
      task transactional: "db:pick"  do
        run_specs(exclude: %w[non_transactional team:services type:integration])
      end

      task non_transactional: "db:pick" do
        run_specs(include: %w[non_transactional], exclude: %w[team:services type:integration])
      end
    end

    def run_specs(options)
      options = {exclude: [], include: []}.merge(options)

      tags = options[:include].map { |tag| "--tag #{tag}" } +
          options[:exclude].map { |tag| "--tag ~#{tag}" }

      sh "bundle exec rspec spec #{tags.join(" ")} --order rand:1234 --require rspec/instafail --format RSpec::Instafail"
    end
  end

  namespace :db do
    task :pick do
      ENV["DB"] ||= %w[sqlite mysql postgres].sample
      puts "Using #{ENV["DB"]}"
    end

    task create: :pick do
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

    task drop: :pick do
      case ENV["DB"]
        when "postgres"
          sh "psql -U postgres -c 'drop database if exists cc_test_;'"
        when "mysql"
          if ENV["TRAVIS"] == "true"
            sh "mysql -e 'drop database if exists cc_test_;'"
          else
            sh "mysql -e 'drop database if exists cc_test_;' -u root --password=password"
          end
      end
    end

    task recreate: %w[drop create]
  end
end
