# All examples presume that you have a ~/.fog credentials file set up.
# More info on it can be found here: http://fog.io/about/getting_started.html

require "bundler"
Bundler.require(:default, :development)
# Uncomment this if you want to make real requests to GCE (you _will_ be billed!)
# WebMock.disable!

def test
  connection = Fog::Compute.new(:provider => "Google")

  puts "Listing images in all projects..."
  puts "---------------------------------"
  images = connection.images.all
  raise "Could not LIST the images" unless images
  puts images.inspect

  puts "Listing current (non-deprecated) images in all projects..."
  puts "----------------------------------------------------------"
  images = connection.images.current
  raise "Could not LIST current images" unless images
  puts images.inspect

  puts "Fetching a single image from a global project..."
  puts "------------------------------------------------"
  img = connection.images.get("debian-11-bullseye-v20220920")
  raise "Could not GET the image" unless img
  puts img.inspect

  # First, get the name of an image that is in the users 'project' (not global)
  custom_img_name = images.detect { |i| i.project.eql? i.service.project }
  # Run the next test only if there is a custom image available
  if custom_img_name
    puts "Fetching a single image from the custom project"
    puts "----------------------------------------------"
    img = connection.images.get(custom_img_name.name)
    raise "Could not GET the (custom) image" unless img
    puts img.inspect
  end
end

test
