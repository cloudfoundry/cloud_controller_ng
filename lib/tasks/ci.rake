namespace :ci do
  task :spec, [:seed] do |_, args|
    sh "bundle exec rspec spec --seed #{args[:seed]} --format progress"
  end

  task :api_docs, [:seed] do |_, args|
    sh "bundle exec rspec spec/api --seed #{args[:seed]} --format RspecApiDocumentation::ApiFormatter"
  end
end
