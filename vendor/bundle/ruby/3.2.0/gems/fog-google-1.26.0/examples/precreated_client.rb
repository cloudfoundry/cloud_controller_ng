# All examples presume that you have a ~/.fog credentials file set up.
# More info on it can be found here: http://fog.io/about/getting_started.html

require "bundler"
Bundler.require(:default, :development)
# Uncomment this if you want to make real requests to GCE (you _will_ be billed!)
# WebMock.disable!

# This example shows how to work with fog using a pre-created Google API client
# with specific parameters, should you want to for any reason.

def test
  client = Google::APIClient.new(:application_name => "supress")
  connection = Fog::Compute.new(:provider => "Google", :google_client => client)

  begin
    p connection.client.discovered_apis
    p connection.servers
  rescue StandardError => e
    p e.message
  end
end

test
