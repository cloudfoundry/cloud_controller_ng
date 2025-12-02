# All examples presume that you have a ~/.fog credentials file set up.
# More info on it can be found here: http://fog.io/about/getting_started.html

require "bundler"
Bundler.require(:default, :development)

ZONE = "us-central1-f"
PROJECT = Fog.credentials[:google_project]

def example
  p "Connecting to Google API"
  connection = Fog::Compute.new(:provider => "Google")

  p "Creating disk"
  disk = connection.disks.create(
    :name => "fog-smoke-test-#{Time.now.to_i}",
    :size_gb => 10,
    :zone => ZONE,
    :source_image => "debian-11-bullseye-v20220920"
  )

  p "Creating a second disk"
  attached_disk = connection.disks.create(
    :name => "fog-smoke-test-#{Time.now.to_i}",
    :size_gb => 10,
    :zone => ZONE
  )

  p "Waiting for disks to be ready"
  disk.wait_for { ready? }
  attached_disk.wait_for { ready? }

  p "Creating a server"
  server = connection.servers.create(
    :name => "fog-smoke-test-#{Time.now.to_i}",
    :disks => [disk.attached_disk_obj(boot: true, auto_delete: true)],
    :machine_type => "n1-standard-1",
    :private_key_path => File.expand_path("~/.ssh/id_rsa"),
    :public_key_path => File.expand_path("~/.ssh/id_rsa.pub"),
    :zone => ZONE,
    # Will be simplified, see https://github.com/fog/fog-google/issues/360
    :network_interfaces => [{ :network => "global/networks/default",
                              :access_configs => [{
                                :name => "External NAT",
                                :type => "ONE_TO_ONE_NAT"
                              }] }],
    :username => ENV["USER"]
  )

  p "Attach second disk to the running server"
  device_name = "fog-smoke-test-device-#{Time.now.to_i}"
  # See https://github.com/fog/fog-google/blob/master/lib/fog/google/compute/models/disk.rb#L75-L107
  # See https://github.com/fog/fog-google/blob/master/lib/fog/google/compute/models/server.rb#L35-L50
  config_hash = {
    :device_name => device_name,
    :source => "https://www.googleapis.com/compute/v1/projects/#{PROJECT}/zones/#{ZONE}/disks/#{attached_disk.name}"
  }
  raise "Could not attach second disk" unless connection.attach_disk(server.name, ZONE, config_hash)

  p "Waiting for disk to be attached"
  attached_disk.wait_for { !users.nil? && users != [] }

  p "Detach second disk"
  raise "Could not detach second disk" unless connection.detach_disk(server.name, ZONE, device_name)

  p "Waiting for second disk to be detached"
  attached_disk.wait_for { users.nil? || users == [] }

  p "Deleting server"
  raise "Could not delete server." unless server.destroy

  p "Destroying second disk"
  raise "Could not delete second disk." unless attached_disk.destroy

  p "Waiting for second disk to be destroyed"
  begin
    rc = attached_disk.wait_for { status.nil? || status == "DELETING" }
  rescue StandardError => e
    if e.message !~ /not found/ && e.message !~ /notFound/
      raise e
    end
  end
end

example
