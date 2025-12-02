# All examples presume that you have a ~/.fog credentials file set up.
# More info on it can be found here: http://fog.io/about/getting_started.html

require "bundler"
Bundler.require(:default, :development)

def example
  p "Connecting to Google API"
  connection = Fog::Compute.new(:provider => "Google")

  p "Creating disk"
  disk = connection.disks.create(
    :name => "fog-smoke-test-#{Time.now.to_i}",
    :size_gb => 10,
    :zone => "us-central1-f",
    :source_image => "debian-11-bullseye-v20220920"
  )

  p "Creating a second disk"
  attached_disk = connection.disks.create(
    :name => "fog-smoke-test-#{Time.now.to_i}",
    :size_gb => 10,
    :zone => "us-central1-f"
  )

  p "Waiting for disks to be ready"
  disk.wait_for { ready? }
  attached_disk.wait_for { ready? }

  p "Creating a server"
  server = connection.servers.create(
    :name => "fog-smoke-test-#{Time.now.to_i}",
    :disks => [disk.attached_disk_obj(boot: true),
               attached_disk.attached_disk_obj(boot: false,
                                               auto_delete: true)],
    :machine_type => "n1-standard-1",
    :private_key_path => File.expand_path("~/.ssh/id_rsa"),
    :public_key_path => File.expand_path("~/.ssh/id_rsa.pub"),
    :zone => "us-central1-f",
    # Will be simplified, see https://github.com/fog/fog-google/issues/360
    :network_interfaces => [{ :network => "global/networks/default",
                              :access_configs => [{
                                :name => "External NAT",
                                :type => "ONE_TO_ONE_NAT"
                              }] }],
    :username => ENV["USER"]
  )

  p "Deleting server"
  raise "Could not delete server." unless server.destroy
end

example
