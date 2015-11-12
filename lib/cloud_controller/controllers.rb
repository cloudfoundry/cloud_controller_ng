require 'cloud_controller/rest_controller'
require 'controllers/v3/application_controller'

Dir[File.expand_path('../../../app/controllers/**/*.rb', __FILE__)].each do |file|
  require file
end
