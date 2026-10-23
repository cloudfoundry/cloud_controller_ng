#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'pathname'

DOCS_DIR = Pathname.new('docs/v3/source/includes/resources')
OPENAPI_DIR = Pathname.new('docs/openapi')

RESOURCE_TO_OPENAPI_FILE = {
  'apps' => 'apps',
  'app_features' => 'app_features',
  'app_usage_events' => 'app_usage_events',
  'audit_events' => 'events',
  'buildpacks' => 'buildpacks',
  'builds' => 'builds',
  'deployments' => 'deployments',
  'domains' => 'domains',
  'droplets' => 'droplets',
  'environment_variable_groups' => 'environment_variable_groups',
  'feature_flags' => 'feature_flags',
  'info' => 'info',
  'isolation_segments' => 'isolation_segments',
  'jobs' => 'jobs',
  'manifests' => 'app_manifests',
  'organization_quotas' => 'organization_quotas',
  'organizations' => 'organizations',
  'packages' => 'packages',
  'processes' => 'processes',
  'resource_matches' => 'resource_matches',
  'revisions' => 'revisions',
  'roles' => 'roles',
  'routes' => 'routes',
  'security_groups' => 'security_groups',
  'service_brokers' => 'service_brokers',
  'service_credential_bindings' => 'service_credential_bindings',
  'service_instances' => 'service_instances',
  'service_offerings' => 'service_offerings',
  'service_plan_visibility' => 'service_plan_visibility',
  'service_plans' => 'service_plans',
  'service_route_bindings' => 'service_route_bindings',
  'service_usage_events' => 'service_usage_events',
  'sidecars' => 'sidecars',
  'space_features' => 'space_features',
  'space_quotas' => 'space_quotas',
  'spaces' => 'spaces',
  'stacks' => 'stacks',
  'tasks' => 'tasks',
  'users' => 'users'
}

SKIP_FILES = %w[
  _header _object _permissions _flags _valid_roles _supported_features
  _visibility_types _jobs _health_check_object _readiness_health_check_object
  _stats_object _process_instance_object _destination_object _route_options_object
  _visibility
]

def read_header(resource_dir)
  header_file = Dir.glob(resource_dir.join('_header.md*')).first
  return nil unless header_file

  content = File.read(header_file, encoding: 'UTF-8')
  lines = content.lines.map(&:strip).reject(&:empty?)
  lines.shift if lines.first&.start_with?('##')
  lines.join(' ').strip
end

def parse_operation_file(filepath)
  content = File.read(filepath, encoding: 'UTF-8')

  title_match = content.match(/^###\s+(.+)$/)
  title = title_match ? title_match[1].strip : nil

  definition_match = content.match(/^`(GET|POST|PUT|PATCH|DELETE)\s+(.+?)`/)
  return nil unless definition_match

  http_method = definition_match[1].downcase
  path_template = definition_match[2].strip

  openapi_path = path_template
    .split('?').first
    .gsub(/:([a-z_]+(?:-[a-z_]+)*)/) { "{#{$1.tr('-', '_')}}" }
  openapi_path = "/v3#{openapi_path}" unless openapi_path.start_with?('/v3')
  openapi_path = openapi_path
    .gsub(/<%= @[a-z_]+ %>/, '')
    .gsub('{route_guid}', '{guid}')
    .gsub('{quota_guid}', '{guid}')

  description = extract_description(content)
  params = extract_query_params(content)

  {
    title: title,
    http_method: http_method,
    path: openapi_path,
    description: description,
    query_params: params
  }
end

def extract_description(content)
  lines = content.lines
  definition_idx = lines.index { |l| l.strip.start_with?('#### Definition') }
  return nil unless definition_idx

  desc_lines = []
  i = definition_idx - 1
  while i >= 0
    stripped = lines[i].strip
    break if stripped.empty? || stripped.start_with?('```') || stripped.start_with?('#')
    desc_lines.unshift(stripped) unless stripped.start_with?('<')
    i -= 1
  end

  return clean_markdown(desc_lines.join(' ').strip) unless desc_lines.empty?

  after_definition = false
  after_def_line = false
  lines.each do |line|
    stripped = line.strip
    if stripped.start_with?('#### Definition')
      after_definition = true
      next
    end
    if after_definition && !after_def_line && stripped.match?(/^`(GET|POST|PUT|PATCH|DELETE)/)
      after_def_line = true
      next
    end
    if after_def_line
      if stripped.start_with?('####') || stripped.start_with?('###')
        break
      end
      next if stripped.empty?
      next if stripped.start_with?('<')
      desc_lines << stripped
    end
  end

  desc_lines.empty? ? nil : clean_markdown(desc_lines.join(' ').strip)
end

def extract_query_params(content)
  params = {}
  in_params = false
  in_table = false

  content.each_line do |line|
    stripped = line.strip

    if stripped.match?(/^####\s+(Query parameters|Optional parameters|Required parameters)/)
      in_params = true
      in_table = false
      next
    end

    if in_params && stripped.match?(/^----/)
      in_table = true
      next
    end

    next if in_params && stripped.match?(/^Name\s+\|/)

    if in_params && in_table
      if stripped.start_with?('####') || stripped.start_with?('###') || stripped.empty?
        in_params = false
        in_table = false
        next
      end

      parts = stripped.split('|').map(&:strip)
      next if parts.length < 3

      name = parts[0].gsub(/\*\*/, '').strip
      description = parts[2]&.strip
      description = clean_markdown(description) if description

      params[name] = description if description && !description.empty?
    end
  end

  params
end

def clean_markdown(text)
  return nil if text.nil?

  text
    .gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
    .gsub(/<br\s*\/?>/, ' ')
    .gsub(/`([^`]+)`/, '\1')
    .gsub(/_([^_]+)_/, '\1')
    .gsub(/\*\*([^*]+)\*\*/, '\1')
    .strip
end

MANUAL_OVERRIDES = {
  ['put', '/v3/tasks/{_}/cancel'] => {
    title: 'Cancel a task',
    description: 'Cancel a running task.'
  },
  ['get', '/v3/apps/{_}/processes/{_}'] => {
    title: 'Get a process',
    description: 'Retrieves a process scoped to an app by type.'
  },
  ['patch', '/v3/apps/{_}/processes/{_}'] => {
    title: 'Update a process',
    description: 'Updates a process scoped to an app by type.'
  },
  ['post', '/v3/apps/{_}/processes/{_}/actions/scale'] => {
    title: 'Scale a process',
    description: 'Scales a process scoped to an app by type.'
  },
  ['delete', '/v3/processes/{_}/instances/{_}'] => {
    title: 'Terminate a process instance',
    description: 'Terminates a process instance.'
  },
  ['get', '/v3/processes/{_}/stats'] => {
    title: 'Get stats for a process',
    description: 'Retrieves stats for a process.'
  },
  ['get', '/v3/processes/{_}/process_instances'] => {
    title: 'Get process instances',
    description: 'Retrieves process instances.'
  },
  ['get', '/v3/service_credential_bindings'] => {
    title: 'List service credential bindings',
    description: 'Retrieve all service credential bindings the user has access to.'
  },
  ['get', '/v3/service_route_bindings'] => {
    title: 'List service route bindings',
    description: 'Retrieve all service route bindings the user has access to.'
  },
  ['delete', '/v3/apps/{_}/processes/{_}/instances/{_}'] => {
    title: 'Terminate a process instance',
    description: 'Terminates a process instance scoped to an app by type.'
  },
  ['get', '/v3/apps/{_}/processes/{_}/stats'] => {
    title: 'Get stats for a process',
    description: 'Retrieves stats for a process scoped to an app by type.'
  },
  ['get', '/v3/apps/{_}/processes/{_}/process_instances'] => {
    title: 'Get process instances',
    description: 'Retrieves process instances scoped to an app by type.'
  }
}

def normalize_path_for_comparison(path)
  path.gsub(/\{[^}]+\}/, '{_}')
end

def paths_match?(doc_path, openapi_path)
  normalize_path_for_comparison(doc_path) == normalize_path_for_comparison(openapi_path)
end

puts "=== Phase 1: Parsing documentation ==="

all_operations = []
resource_descriptions = {}

RESOURCE_TO_OPENAPI_FILE.each do |resource, openapi_name|
  resource_dir = DOCS_DIR.join(resource)
  next unless resource_dir.exist?

  resource_descriptions[openapi_name] = read_header(resource_dir)

  operation_files = Dir.glob(resource_dir.join('*.md.erb')) + Dir.glob(resource_dir.join('*.md'))
  operation_files.each do |filepath|
    basename = File.basename(filepath, '.md.erb')
    basename = File.basename(basename, '.md')
    next if SKIP_FILES.any? { |skip| basename == skip }
    next if basename == '_header'

    op = parse_operation_file(filepath)
    next unless op

    all_operations << op
    puts "  Found: #{op[:http_method].upcase} #{op[:path]} -> #{op[:title]}"
  end
end

puts "\nParsed #{all_operations.length} operations from documentation."

puts "\n=== Phase 2: Applying to OpenAPI specs ==="

openapi_files = Dir.glob(OPENAPI_DIR.join('*.yaml')).reject { |f|
  name = File.basename(f)
  name == 'swagger-config.yaml' || name.end_with?('.rb.yaml') || name == '_skip.yaml'
}

enriched_count = 0
openapi_files.each do |openapi_file|
  basename = File.basename(openapi_file, '.yaml')
  spec = YAML.load_file(openapi_file, permitted_classes: [Date, Time])
  next unless spec && spec['paths']

  modified = false

  desc = resource_descriptions[basename]
  if desc
    spec['info'] ||= {}
    if spec['info']['description'] != desc
      spec['info']['description'] = desc
      modified = true
    end

    first_tag = nil
    spec['paths'].each do |_path, methods|
      methods.each do |_method, op|
        next unless op.is_a?(Hash) && op['tags']
        first_tag = op['tags'].first
        break if first_tag
      end
      break if first_tag
    end

    if first_tag
      spec['tags'] ||= []
      existing = spec['tags'].find { |t| t['name'] == first_tag }
      if existing
        if existing['description'] != desc
          existing['description'] = desc
          modified = true
        end
      else
        spec['tags'] << { 'name' => first_tag, 'description' => desc }
        modified = true
      end
    end
  end

  spec['paths'].each do |path, methods|
    methods.each do |method, op_spec|
      next unless op_spec.is_a?(Hash)

      matching_op = all_operations.find { |o| o[:http_method] == method && paths_match?(o[:path], path) }

      normalized_key = [method, normalize_path_for_comparison(path)]
      override = MANUAL_OVERRIDES[normalized_key]

      next unless matching_op || override

      title = matching_op&.dig(:title) || override&.dig(:title)
      desc_text = matching_op&.dig(:description) || override&.dig(:description)
      query_params = matching_op&.dig(:query_params) || {}

      if title && op_spec['summary'] != title
        op_spec['summary'] = title
        modified = true
      end

      if desc_text && op_spec['description'] != desc_text
        op_spec['description'] = desc_text
        modified = true
      end

      if !query_params.empty? && op_spec['parameters']
        op_spec['parameters'].each do |param|
          if param['in'] == 'query'
            doc_desc = query_params[param['name']]
            if doc_desc && param['description'] != doc_desc
              param['description'] = doc_desc
              modified = true
            end
          end

          if param['in'] == 'path' && !param['description']
            param['description'] = 'Unique identifier for the resource'
            modified = true
          end
        end
      end
    end
  end

  if modified
    File.write(openapi_file, YAML.dump(spec))
    enriched_count += 1
    puts "  Updated: #{File.basename(openapi_file)}"
  else
    puts "  No changes: #{File.basename(openapi_file)}"
  end
end

puts "\nDone! Updated #{enriched_count} OpenAPI files."
