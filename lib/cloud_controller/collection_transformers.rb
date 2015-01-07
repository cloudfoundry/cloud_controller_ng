Dir[File.expand_path('../../../app/collection_transformers/**/*.rb', __FILE__)].each do |file|
  require file
end
