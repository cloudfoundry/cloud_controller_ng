require_relative 'validators'
require 'active_model'

module ProgrammerMistake
  class MissingMethod < StandardError; end
end

module VCAP::CloudController
  class NestedMessageValidator < ActiveModel::Validator
    include ActiveModel::Model
    include Validators

    attr_reader :record

    def initialize(*_)
    end

    def validate(record)
      @record = record
      return unless should_validate?
      return if self.valid?
      record.errors[error_key].concat self.errors.full_messages
    end

    private

    def should_validate?
      raise ProgrammerMistake::MissingMethod.new('Subclass must declare when it should be run.')
    end

    def error_key
      raise ProgrammerMistake::MissingMethod.new('Subclass must declare where in record errors should be stored.')
    end
  end
end
