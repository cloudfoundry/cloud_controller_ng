# All examples presume that you have a ~/.fog credentials file set up.
# # More info on it can be found here: http://fog.io/about/getting_started.html
#
require "bundler"
Bundler.require(:default, :development)
# Uncomment this if you want to make real requests to GCE (you _will_ be billed!)
# WebMock.disable!

def test
  connection = Fog::Google::Pubsub.new

  puts "Creating a topic to subscribe to"
  puts "--------------------------------"
  topic = connection.topics.create(:name => "projects/#{connection.project}/topics/#{Fog::Mock.random_letters(16)}")

  puts "Creating a subscription"
  puts "-----------------------"
  subscription = connection.subscriptions.create(:name => "projects/#{connection.project}/subscriptions/#{Fog::Mock.random_letters(16)}", :topic => topic)

  puts "Getting a subscription"
  puts "----------------------"
  connection.subscriptions.get(subscription.name)

  puts "Listing all subscriptions"
  puts "-------------------------"
  connection.subscriptions.all

  puts "Publishing to topic"
  puts "-------------------"
  topic.publish(["test message"])

  puts "Pulling from subscription"
  puts "-------------------------"

  msgs = []
  msgs = subscription.pull while msgs.empty?

  puts "Acknowledging pulled messages"
  puts "-----------------------------"
  subscription.acknowledge(msgs)

  # Alternatively, received messages themselves can be acknowledged
  msgs.each(&:acknowledge)

  puts "Deleting the subscription"
  puts "-------------------------"
  subscription.destroy

  puts "Deleting the topic subscribed to"
  puts "--------------------------------"
  topic.destroy
end

test
