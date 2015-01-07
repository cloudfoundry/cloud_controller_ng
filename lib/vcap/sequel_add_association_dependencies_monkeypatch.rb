require 'sequel'

# The AssociationDependencies plugin allows you do easily set up before and/or after
# destroy hooks for destroying, deleting, or nullifying associated model objects.
#
# However, the plugin has no way to return the association dependencies verbatim
# and instead returns its own representation of the dependencies as a hash with keys
# being associations, and values being Proc objects that define an action to be taken
# to implement the defined dependency.
#
# The following monkey patch provides a way to read the defined association dependencies back.
# This is used to provide a generic implementation of soft deletion feature in the App model class.
Sequel::Plugins::AssociationDependencies::ClassMethods.class_eval do
  alias_method :add_association_dependencies_original, :add_association_dependencies

  attr_reader :association_dependencies_hash

  def add_association_dependencies(hash)
    association_dependencies_hash.merge!(hash)
    add_association_dependencies_original(hash)
  end

  def association_dependencies_hash
    @association_dependencies_hash ||= {}
  end
end
