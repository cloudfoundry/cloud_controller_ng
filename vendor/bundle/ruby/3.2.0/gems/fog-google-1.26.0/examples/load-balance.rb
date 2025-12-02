# All examples presume that you have a ~/.fog credentials file set up.
# More info on it can be found here: http://fog.io/about/getting_started.html

require "bundler"
Bundler.require(:default, :development)
# Uncomment this if you want to make real requests to GCE (you _will_ be billed!)
# WebMock.disable!

def test
  # Config
  name = "fog-lb-test-#{Time.now.to_i}"
  zone = "europe-west1-d"
  region = "europe-west1"

  # Setup
  gce = Fog::Compute.new :provider => "Google"
  servers = []

  puts "Creating instances..."
  puts "--------------------------------"
  (1..3).each do |i|
    begin
      disk = gce.disks.create(
        :name => "#{name}-#{i}",
        :size_gb => 10,
        :zone_name => zone,
        :source_image => "debian-11-bullseye-v20220920"
      )
      disk.wait_for { disk.ready? }
    rescue
      puts "Failed to create disk #{name}-#{i}"
    end

    begin
      server = gce.servers.create(
        :name => "#{name}-#{i}",
        :disks => [disk.get_as_boot_disk(true, true)],
        :machine_type => "f1-micro",
        :zone_name => zone
      )
      servers << server
    rescue
      puts "Failed to create instance #{name}-#{i}"
    end
  end

  puts "Creating health checks..."
  puts "--------------------------------"
  begin
    health = gce.http_health_checks.new(:name => name)
    health.save
  rescue
    puts "Failed to create health check #{name}"
  end

  puts "Creating a target pool..."
  puts "--------------------------------"
  begin
    pool = gce.target_pools.new(
      :name => name,
      :region => region,
      :health_checks => [health.self_link],
      :instances => servers.map(&:self_link)
    )
    pool.save
  rescue
    puts "Failed to create target pool #{name}"
  end

  puts "Creating forwarding rules..."
  puts "--------------------------------"
  begin
    rule = gce.forwarding_rules.new(
      :name => name,
      :region => region,
      :port_range => "1-65535",
      :ip_protocol => "TCP",
      :target => pool.self_link
    )
    rule.save
  rescue
    puts "Failed to create forwarding rule #{name}"
  end

  # TODO(bensonk): Install apache, create individualized htdocs, and run some
  #                actual requests through the load balancer.

  # Cleanup
  puts "Cleaning up..."
  puts "--------------------------------"
  begin
    rule.destroy
  rescue
    puts "Failed to clean up forwarding rule."
  end

  begin
    pool.destroy
  rescue
    puts "Failed to clean up target pool."
  end

  begin
    health.destroy
  rescue
    puts "Failed to clean up health check."
  end

  begin
    servers.each(&:destroy)
  rescue
    puts "Failed to clean up instances."
  end
end

test
