# All examples presume that you have a ~/.fog credentials file set up.
# More info on it can be found here: http://fog.io/about/getting_started.html

require "bundler"
Bundler.require(:default, :development)

connection = Fog::Google::SQL.new

puts "Listing all Flags..."
puts "--------------------"
connection.flags
