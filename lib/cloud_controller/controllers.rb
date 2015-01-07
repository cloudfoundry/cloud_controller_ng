require 'cloud_controller/rest_controller'

Dir[File.expand_path('../../../app/controllers/**/*.rb', __FILE__)].each do |file|
  require file
end
