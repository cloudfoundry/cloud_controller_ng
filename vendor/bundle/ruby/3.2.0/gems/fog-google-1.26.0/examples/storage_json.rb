# All examples presume that you have a ~/.fog credentials file set up.
# More info on it can be found here: http://fog.io/about/getting_started.html

require "bundler"
Bundler.require(:default, :development)
# Uncomment this if you want to make real requests to GCE (you _will_ be billed!)
# WebMock.disable!

# This specific example needs google_storage_access_key_id: and google_storage_secret_access_key to be set in ~/.fog
# One can request those keys via Google Developers console in:
# Storage -> Storage -> Settings -> "Interoperability" tab -> "Create a new key"

def test
  connection = Fog::Google::Storage.new

  puts "Put a bucket..."
  puts "----------------"
  connection.put_bucket("fog-smoke-test", predefined_acl: "publicReadWrite")

  puts "Get the bucket..."
  puts "-----------------"
  connection.get_bucket("fog-smoke-test")

  puts "Put a test file..."
  puts "---------------"
  connection.put_object("fog-smoke-test", "my file", "THISISATESTFILE")

  puts "Delete the test file..."
  puts "---------------"
  connection.delete_object("fog-smoke-test", "my file")

  puts "Delete the bucket..."
  puts "------------------"
  connection.delete_bucket("fog-smoke-test")
end

test
