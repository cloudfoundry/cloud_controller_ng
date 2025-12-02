# All examples presume that you have a ~/.fog credentials file set up.
# More info on it can be found here: http://fog.io/about/getting_started.html

require "bundler"
Bundler.require(:default, :development)

connection = Fog::Google::SQL.new

puts "Create a Instance..."
puts "--------------------"
instance = connection.instances.create(:name => Fog::Mock.random_letters(16), :tier => "D1")
instance.wait_for { ready? }

puts "Delete the Instance..."
puts "----------------------"
operation = instance.destroy

puts "Get the Operation..."
puts "--------------------"
connection.operations.get(operation.identity)

puts "Listing all Operations..."
puts "-------------------------"
connection.operations.all(instance.identity)
