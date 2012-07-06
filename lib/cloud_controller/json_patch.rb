# Copyright (c) 2012-2012 VMware, Inc.

# FIXME: this is so gross
# Monkey-patching the monkeypatch: UAA gem is unhappy because yajl/json_gem
# ignores symbolize_names
# The UAA client gem should probably move to Yajl...
def JSON.parse(str, opts=JSON.default_options)
  if opts.delete(:symbolize_names)
    opts[:symbolize_keys] = true
  end
  Yajl::Parser.parse(str, opts)
end
