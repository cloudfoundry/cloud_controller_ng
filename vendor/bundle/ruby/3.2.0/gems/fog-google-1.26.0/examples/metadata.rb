# All examples presume that you have a ~/.fog credentials file set up.
# More info on it can be found here: http://fog.io/about/getting_started.html

require "bundler"
Bundler.require(:default, :development)
# Uncomment this if you want to make real requests to GCE (you _will_ be billed!)
# WebMock.disable!

def test
  connection = Fog::Compute.new(:provider => "Google")

  name = "fog-smoke-test-#{Time.now.to_i}"

  disk = connection.disks.create(
    :name => name,
    :size_gb => 10,
    :zone_name => "us-central1-f",
    :source_image => "debian-11-bullseye-v20220920"
  )

  disk.wait_for { disk.ready? }

  server = connection.servers.create(
    :name => name,
    :disks => [disk],
    :machine_type => "n1-standard-1",
    :zone_name => "us-central1-f",
    :private_key_path => File.expand_path("~/.ssh/id_rsa"),
    :public_key_path => File.expand_path("~/.ssh/id_rsa.pub")
  )

  server.wait_for { ready? }

  server.metadata["test"] = "foo"

  raise "Metadata was not set." unless server.metadata["test"] == "foo"
  raise "Could not delete server." unless server.destroy
end

test
