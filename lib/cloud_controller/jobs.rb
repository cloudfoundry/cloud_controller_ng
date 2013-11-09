Dir[File.expand_path("../../../app/jobs/**/*.rb", __FILE__)].each do |file|
  require file
end

class LocalQueue < Struct.new(:config)
  def to_s
    "cc-#{config[:name]}-#{config[:index]}"
  end
end
