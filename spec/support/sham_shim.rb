require 'securerandom'

# Compatibility shim for legacy `Sham.<name>` calls. The original Sham
# generators were defined inside `spec/support/fakes/blueprints.rb` as
# part of machinist. After the machinist removal, blueprints.rb is gone
# but a few hundred call sites still call `Sham.foo`. Each method here
# delegates to a FactoryBot `:sham_*` sequence defined in
# spec/support/factories.rb that mirrors the original Sham.define block.
module Sham
  module_function

  def email = FactoryBot.generate(:sham_email)
  def name = FactoryBot.generate(:sham_name)
  def label = FactoryBot.generate(:sham_label)
  def token = FactoryBot.generate(:sham_token)
  def auth_username = FactoryBot.generate(:sham_auth_username)
  def auth_password = FactoryBot.generate(:sham_auth_password)
  def provider = FactoryBot.generate(:sham_provider)
  def port = FactoryBot.generate(:sham_port)
  def url = FactoryBot.generate(:sham_url)
  def type = FactoryBot.generate(:sham_type)
  def description = FactoryBot.generate(:sham_description)
  def long_description = FactoryBot.generate(:sham_long_description)
  def version = FactoryBot.generate(:sham_version)
  def service_credentials = FactoryBot.generate(:sham_service_credentials)
  def uaa_id = FactoryBot.generate(:sham_uaa_id)
  def domain = FactoryBot.generate(:sham_domain)
  def host = FactoryBot.generate(:sham_host)
  def guid = FactoryBot.generate(:sham_guid)
  def extra = FactoryBot.generate(:sham_extra)
  def instance_index = FactoryBot.generate(:sham_instance_index)
  def unique_id = FactoryBot.generate(:sham_unique_id)
  def status = FactoryBot.generate(:sham_status)
  def error_message = FactoryBot.generate(:sham_error_message)
  def sequence_id = FactoryBot.generate(:sham_sequence_id)
  def stack = FactoryBot.generate(:sham_stack)
end
