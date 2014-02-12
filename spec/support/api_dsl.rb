require 'active_support/concern'

module ApiDsl
  extend ActiveSupport::Concern

  def validate_response(model, json, expect={})
    expect.each do |name, expected_value|
      # refactor: pass exclusions, and figure out which are valid to not be there
      next if name.to_s == "guid"

      # if a relationship is not present, its url should not be present
      next if field_is_url_and_relationship_not_present?(json, name)

      json.should have_key name.to_s
      json[name.to_s].should == expect[name.to_sym]
    end
  end

  def standard_list_response json, model
    standard_paginated_response_format? parsed_response
    parsed_response["resources"].each do |resource|
      standard_entity_response resource, model
    end
  end

  def standard_entity_response json, model, expect={}
    json.should include("metadata")
    json.should include("entity")
    standard_metadata_response_format? json["metadata"]
    validate_response model, json["entity"], expect
  end

  def standard_paginated_response_format? json
    validate_response VCAP::RestAPI::PaginatedResponse, json
  end

  def standard_metadata_response_format? json
    validate_response VCAP::RestAPI::MetadataMessage, json
  end

  def message_table model
    return model if model.respond_to? :fields
    "VCAP::CloudController::#{model.to_s.classify.pluralize}Controller::ResponseMessage".constantize
  end

  def parsed_response
    parse(response_body)
  end

  def field_is_url_and_relationship_not_present?(json, field)
    if field =~ /(.*)_url$/
      !json["#$1_guid".to_sym]
    end
  end

  def audited_event event
    attributes = event.columns.map do |column|
      if column == :metadata
        {attribute_name: column.to_s, value: JSON.pretty_generate(JSON.parse(event[column])), is_json: true}
      else
        {attribute_name: column.to_s, value: event[column], is_json: false}
      end
    end

    example.metadata[:audit_records] ||= []
    example.metadata[:audit_records] << {type: event[:type], attributes: attributes}
  end

  def fields_json(overrides = {})
    Yajl::Encoder.encode(required_fields.merge(overrides), pretty: true)
  end

  def required_fields
    self.class.metadata[:fields].inject({}) do |memo, field|
      memo[field[:name]] = (field[:valid_values] || field[:example_values]).first if field[:required]
      memo
    end
  end

  module ClassMethods
    def api_version
      "/v2"
    end

    def root(model)
      "#{api_version}/#{model.to_s.pluralize}"
    end

    def standard_model_list(model, controller)
      get root(model) do
        standard_list_parameters controller
        example_request "List all #{model.to_s.pluralize.titleize}" do
          standard_list_response parsed_response, model
        end
      end
    end

    def standard_model_get(model)
      get "#{root(model)}/:guid" do
        example_request "Retrieve a Particular #{model.to_s.capitalize}" do
          standard_entity_response parsed_response, model
        end
      end
    end

    def standard_model_delete(model)
      delete "#{root(model)}/:guid" do
        request_parameter :async, "Will run the delete request in a background job. Recommended: 'true'."

        example_request "Delete a Particular #{model.to_s.capitalize}" do
          expect(status).to eq 204
          after_standard_model_delete(guid) if respond_to?(:after_standard_model_delete)
        end
      end
    end

    def standard_model_delete_without_async(model)
      delete "#{root(model)}/:guid" do
        example_request "Delete a Particular #{model.to_s.capitalize}" do
          expect(status).to eq 204
          after_standard_model_delete(guid) if respond_to?(:after_standard_model_delete)
        end
      end
    end

    def standard_list_parameters(controller)
      if controller.query_parameters.size > 0
        query_parameter_description = "Parameters used to filter the result set."
        query_parameter_description += " Valid filters: #{controller.query_parameters.to_a.join(", ")}"
        request_parameter :q, query_parameter_description
      end
      request_parameter :page, "Page of results to fetch"
      request_parameter :'results-per-page', "Number of results per page"
      request_parameter :'inline-relations-depth', "0 - don't inline any relations and return URLs.  Otherwise, inline to depth N.", deprecated: true
    end

    def request_parameter(name, description, options = {})
      parameter name, description, options
      metadata[:request_parameters] ||= []
      metadata[:request_parameters].push(options.merge(:name => name.to_s, :description => description))
    end

    def field(name, description = "", options = {})
      metadata[:fields] ||= []
      metadata[:fields].push(options.merge(:name => name.to_s, :description => description))
    end

    def authenticated_request
      header "AUTHORIZATION", :admin_auth_header
    end
  end
end
