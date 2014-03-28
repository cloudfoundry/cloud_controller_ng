desc "Runs all specs"
task spec: [:rubocop] do
  sh "bundle exec parallel_rspec spec -s 'integration|acceptance' -o \"--require rspec/instafail --format RSpec::Instafail\""
end
