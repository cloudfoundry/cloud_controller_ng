namespace :ci do
  task basics: %w[spec:api spec:acceptance spec:integration]

  namespace :spec do
    task api: "db:pick" do
      sh "bundle exec rspec spec/api --order rand:$RANDOM --format RspecApiDocumentation::ApiFormatter"
    end

    task acceptance: "db:pick" do
      run_specs(path: "spec/acceptance")
    end

    task integration: "db:pick" do
      run_specs(include: %w[type:integration])
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
          run_specs(path: "spec/unit/#{layer_name}")
        end
      end

      task fast: fast_suites

      task :lib do
        run_specs(path: "spec/unit/lib")
      end

      namespace :controllers do
        task :services do
          run_specs(path: "spec/unit/controllers/services")
        end

        task :runtime do
          run_specs(path: "spec/unit/controllers/runtime")
        end
      end
    end

    def run_specs(options)
      options = {exclude: [], include: [], path: "spec"}.merge(options)

      tags = options[:include].map { |tag| "--tag #{tag}" } +
          options[:exclude].map { |tag| "--tag ~#{tag}" }

      sh "bundle exec rspec #{options[:path]} #{tags.join(" ")} --order rand:1234 --require rspec/instafail --format RSpec::Instafail"
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
