# All examples presume that you have a ~/.fog credentials file set up.
# More info on it can be found here: http://fog.io/about/getting_started.html

require "bundler"
Bundler.require(:default, :development)
# Uncomment this if you want to make real requests to GCE (you _will_ be billed!)
# WebMock.disable!

def test
  connection = Fog::Compute.new(:provider => "Google")

  puts "Listing snapshots..."
  puts "---------------------------------"
  snapshots = connection.snapshots.all
  raise "Could not LIST the snapshots" unless snapshots
  puts snapshots.inspect

  puts "Fetching a single snapshot..."
  puts "---------------------------------"
  snap = snapshots.first
  unless snap.nil?
    snap = connection.snapshots.get(snap)
    raise "Could not GET the snapshot" unless snap
    puts snap.inspect
  end
end

test
