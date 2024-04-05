RSpec::Matchers.define :add_index_options do
  description { 'options for add_index' }

  match do |passed_options|
    options = passed_options.keys
    !options.delete(:name).nil? && (options - %i[where if_not_exists concurrently]).empty?
  end
end

RSpec::Matchers.define :drop_index_options do
  description { 'options for drop_index' }

  match do |passed_options|
    options = passed_options.keys
    !options.delete(:name).nil? && (options - %i[if_exists concurrently]).empty?
  end
end
