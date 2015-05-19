Dir[File.expand_path('../../../app/transformers/**/*.rb', __FILE__)].each do |file|
  require file
end
