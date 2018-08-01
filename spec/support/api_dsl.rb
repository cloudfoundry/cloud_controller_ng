require 'active_support/concern'

module RspecApiDocumentation
  class Example
    def has_body_parameters?
      respond_to?(:body_parameters) && body_parameters.present?
    end

    def has_parameter_type?
      body_parameters.each do |parameter|
        return true unless parameter[:parameter_type].nil?
      end
      false
    end
  end
end

module ApiDsl
  extend ActiveSupport::Concern

  def body_parameters
    body_parameters = example.metadata.fetch(:body_parameters, {}).inject({}) do |hash, param|
      set_param(hash, param)
    end
    body_parameters.merge!(extra_params)
    MultiJson.dump(body_parameters, pretty: true)
  end

  module ClassMethods
    def body_parameter(name, description='', options={})
      metadata[:body_parameters] = metadata[:body_parameters] ? metadata[:body_parameters].dup : []
      metadata[:body_parameters].push(options.merge(name: name.to_s, description: description))
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end
end
