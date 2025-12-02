# All examples presume that you have a ~/.fog credentials file set up.
# More info on it can be found here: http://fog.io/about/getting_started.html

require "bundler"
Bundler.require(:default, :development)

connection = Fog::Google::SQL.new

puts "Create a Instance..."
puts "--------------------"
instance = connection.instances.create(:name => Fog::Mock.random_letters(16), :tier => "db-n1-standard-1")
instance.wait_for { ready? }

puts "Create a SSL certificate..."
puts "---------------------------"
ssl_cert = connection.ssl_certs.create(:instance => instance.name, :common_name => Fog::Mock.random_letters(16))

puts "Get the SSL certificate..."
puts "--------------------------"
connection.ssl_certs.get(instance.name, ssl_cert.sha1_fingerprint)

puts "List all SSL certificate..."
puts "---------------------------"
connection.ssl_certs.all(instance.name)

puts "Delete the SSL certificate..."
puts "-----------------------------"
ssl_cert.destroy

puts "Delete the Instance..."
puts "----------------------"
instance.destroy
