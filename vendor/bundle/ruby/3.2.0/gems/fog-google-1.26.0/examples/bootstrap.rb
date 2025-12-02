# All examples presume that you have a ~/.fog credentials file set up.
# More info on it can be found here: http://fog.io/about/getting_started.html
# Code can be ran by simply invoking `ruby bootstrap.rb`
# Note: this example will require 'net-ssh' gem to be installed

require "bundler"
Bundler.require(:default, :development)

p "Connecting to google..."
p "======================="
connection = Fog::Compute.new(:provider => "Google")

p "Bootstrapping a server..."
p "========================="
server = connection.servers.bootstrap

p "Waiting for server to be sshable..."
p "==================================="
server.wait_for { sshable? }

p "Trying to send an SSH command..."
p "================================"
raise "Could not bootstrap sshable server." unless server.ssh("whoami")

p "Deleting a server..."
p "===================="
raise "Could not delete server." unless server.destroy
