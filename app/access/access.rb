require File.expand_path("../../../app/access/base_access.rb", __FILE__)
Dir[File.expand_path("../../../app/access/**/*.rb", __FILE__)].each do |file|
  require file
end