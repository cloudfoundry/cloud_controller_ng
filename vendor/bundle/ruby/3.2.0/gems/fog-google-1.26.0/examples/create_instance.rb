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

  p "Waiting for disk to be ready"
  disk.wait_for { disk.ready? }

  p "Creating a server"
  server = connection.servers.create(
    :name => "fog-smoke-test-#{Time.now.to_i}",
    :disks => [disk],
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
    :username => ENV["USER"],
    :metadata => { :items => [{ :key => "foo", :value => "bar" }] },
    :tags => ["fog"],
    :service_accounts => { :scopes => %w(sql-admin bigquery https://www.googleapis.com/auth/compute) }
  )

  p "Waiting for server to be ready"
  # .sshable? requires 'net-ssh' gem to be added to the gemfile
  begin
    duration = 0
    interval = 5
    timeout = 600
    start = Time.now
    until server.sshable? || duration > timeout
      puts duration
      puts " ----- "

      server.reload

      p "ready?: #{server.ready?}"
      p "public_ip_address: #{server.public_ip_address.inspect}"
      p "public_key: #{server.public_key.inspect}"
      p "metadata: #{server.metadata.inspect}"
      p "sshable?: #{server.sshable?}"

      sleep(interval.to_f)
      duration = Time.now - start
    end
    raise "Could not bootstrap sshable server." unless server.ssh("whoami")
  rescue NameError
    server.wait_for { ready? }
  end

  p "Deleting server"
  raise "Could not delete server." unless server.destroy
end

example
