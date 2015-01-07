RSpec::Matchers.define :have_nested_routes do |association_routes, options={}|
  errors = []

  match do |controller|
    to_manies = controller.send(:to_many_relationships)

    to_manies.each do |association_name, attr|
      expected_routes = Array(association_routes[association_name])

      extra_routes   = Array(attr.route_for) - expected_routes
      missing_routes = expected_routes - Array(attr.route_for)

      error_root_path = "#{controller.path_guid}/#{association_name}"
      error_full_path = "#{error_root_path}/:guid"

      extra_routes.each do |route|
        error_path = route == :get ? error_root_path : error_full_path
        should_not_exist_error(error_path, errors)
      end

      missing_routes.each do |route|
        error_path = route == :get ? error_root_path : error_full_path
        should_exist_error(error_path, errors)
      end
    end

    errors.length == 0
  end

  failure_message do |_|
    errors.join("\n")
  end

  def should_exist_error(path, errors)
    errors << "expected #{path} to exist"
  end

  def should_not_exist_error(path, errors)
    errors << "expected #{path} not to exist"
  end
end
