# frozen_string_literal: true

require 'rubocop'
require 'rubocop/sequel'
require 'rubocop/sequel/version'
require 'rubocop/sequel/plugin'

require_relative 'rubocop/cop/sequel/helpers/migration'

require 'rubocop/cop/sequel/concurrent_index'
require 'rubocop/cop/sequel/irreversible_migration'
require 'rubocop/cop/sequel/json_column'
require 'rubocop/cop/sequel/migration_name'
require 'rubocop/cop/sequel/save_changes'
require 'rubocop/cop/sequel/partial_constraint'
