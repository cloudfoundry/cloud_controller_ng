RSpec::Matchers.define :have_nested_routes do |association_routes, options={}|
  errors = []
  match do |controller|
    actual_to_manies = controller.send(:to_many_relationships)
    expected_to_manies = association_routes

    actual_to_manies.each do |association_name, attr|
      expected_actions_for_association = Array(expected_to_manies[association_name])

      actual_actions = Array(attr.route_for)
      extra_actions   = actual_actions - expected_actions_for_association
      missing_actions = expected_actions_for_association - actual_actions

      handle_errors(extra_actions, missing_actions, controller, association_name, errors)
    end

    expected_to_manies.each do |association_name, expected_actions|
      missing_route = association_name unless actual_to_manies.include?(association_name)

      if missing_route
        route_should_exist_error(missing_route, errors)
      else
        actual_actions = Array(actual_to_manies[association_name].route_for)
        extra_actions   = expected_actions - actual_actions
        missing_actions = actual_actions - expected_actions

        handle_errors(missing_actions, extra_actions, controller, association_name, errors)
      end
    end

    errors.length == 0
  end

  failure_message do |_|
    errors.join("\n")
  end

  private

  def handle_errors(actions_that_should_not_exist, actions_that_should_exist, controller, association_name, errors)
    error_root_path = "#{controller.path_guid}/#{association_name}"
    error_full_path = "#{error_root_path}/:guid"

    actions_that_should_not_exist.each do |action|
      error_path = action == :get ? error_root_path : error_full_path
      action_should_not_exist_error(error_path, errors)
    end

    actions_that_should_exist.each do |action|
      error_path = action == :get ? error_root_path : error_full_path
      action_should_exist_error(error_path, errors)
    end

    errors
  end

  def route_should_exist_error(route, errors)
    errors << "expected #{route} to exist"
  end

  def action_should_exist_error(path, errors)
    errors << "expected #{path} to exist"
  end

  def action_should_not_exist_error(path, errors)
    errors << "expected #{path} not to exist"
  end
end
