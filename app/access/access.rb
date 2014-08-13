require File.expand_path("base_access.rb", File.dirname(__FILE__))
require File.expand_path("service_instance_access.rb", File.dirname(__FILE__))

Dir[File.expand_path("**/*.rb", File.dirname(__FILE__))].each do |file|
  require file
end
