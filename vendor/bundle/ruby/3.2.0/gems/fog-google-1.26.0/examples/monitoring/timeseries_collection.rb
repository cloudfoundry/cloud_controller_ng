# All examples presume that you have a ~/.fog credentials file set up.
# # More info on it can be found here: http://fog.io/about/getting_started.html
#
require "bundler"
Bundler.require(:default, :development)
# Uncomment this if you want to make real requests to GCE (you _will_ be billed!)
# WebMock.disable!

def test
  connection = Fog::Google::Monitoring.new
  interval = {
    :start_time => (Time.now - 1).rfc3339,
    :end_time => Time.now.to_datetime.rfc3339
  }
  puts "Listing Timeseries from the last hour for metric compute.googleapis.com/instance/uptime..."
  puts "-------------------------------------------------------------------------------"
  tc = connection.timeseries_collection.all(:filter => 'metric.type = "compute.googleapis.com/instance/uptime"',
                                            :interval => interval)
  puts "Number of matches: #{tc.length}"

  puts "\nListing all Timeseries for metric compute.googleapis.com/instance/uptime &"
  puts "the region us-central1..."
  puts "------------------------------------------------------------------------------"
  filter = [
    'metric.type = "compute.googleapis.com/instance/uptime"',
    'resource.label.zone = "us-central1-c"'
  ].join(" AND ")
  tc = connection.timeseries_collection.all(:filter => filter, :interval => interval)
  puts "Number of matches: #{tc.length}"
end

test
