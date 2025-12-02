# All examples presume that you have a ~/.fog credentials file set up.
# # More info on it can be found here: http://fog.io/about/getting_started.html
#
require "bundler"
Bundler.require(:default, :development)
# Uncomment this if you want to make real requests to GCE (you _will_ be billed!)
# WebMock.disable!

def test
  connection = Fog::Google::Pubsub.new

  puts "Creating a topic"
  puts "----------------"
  topic = connection.topics.create(:name => "projects/#{connection.project}/topics/#{Fog::Mock.random_letters(16)}")

  puts "Getting a topic"
  puts "---------------"
  connection.topics.get(topic.name)

  puts "Listing all topics"
  puts "------------------"
  connection.topics.all

  puts "Publishing to topic"
  puts "-------------------"
  topic.publish(["test message"])

  puts "Delete the topic"
  puts "----------------"
  topic.destroy
end

test
