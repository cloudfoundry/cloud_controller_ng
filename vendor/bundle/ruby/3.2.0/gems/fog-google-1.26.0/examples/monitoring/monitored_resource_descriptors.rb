# All examples presume that you have a ~/.fog credentials file set up.
# # More info on it can be found here: http://fog.io/about/getting_started.html
#
require "bundler"
Bundler.require(:default, :development)
# Uncomment this if you want to make real requests to GCE (you _will_ be billed!)
# WebMock.disable!
#

def test
  connection = Fog::Google::Monitoring.new

  puts "Listing all MonitoredResourceDescriptors..."
  puts "--------------------------------"
  md = connection.monitored_resource_descriptors
  puts "Number of all monitored resource descriptors: #{md.length}"

  puts "\nListing MonitoredResourceDescriptors related to Google Compute Engine..."
  puts "-----------------------------------------------------------------"
  md = connection.monitored_resource_descriptors.all(:filter => 'resource.type = starts_with("gce_")')
  puts "Number of compute monitored resource : #{md.length}"
end

test
