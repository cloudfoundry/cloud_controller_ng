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

  puts "Listing all MetricDescriptors..."
  puts "--------------------------------"
  md = connection.metric_descriptors
  puts "Number of all metric descriptors: #{md.length}"

  puts "\nListing all MetricDescriptors related to Google Compute Engine..."
  puts "-----------------------------------------------------------------"
  md = connection.metric_descriptors.all(:filter => 'metric.type = starts_with("compute.googleapis.com")')
  puts "Number of compute metric descriptors: #{md.length}"
end

test
