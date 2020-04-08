Dir[File.expand_path('../../app/collection_transformers/**/*.rb', __dir__)].sort.each do |file|
  require file
end
