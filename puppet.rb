#!/usr/bin/env ruby

require 'wash'
require 'puppetdb'
require 'json'
require 'yaml'

def client(config)
  if config[:rbac_token]
    # PE token-based auth
    PuppetDB::Client.new({
      server: config[:puppetdb_url],
      token:  config[:rbac_token],
      cacert: config[:cacert]
    })
  else
    # Cert-based auth
    PuppetDB::Client.new({
      server: config[:puppetdb_url],
      pem: {
        'ca_file' => config[:cacert],
        'key'     => config[:key],
        'cert'    => config[:cert]
      }
    })
  end
end

def make_readable(value)
  if value.kind_of? String
    value
  else
    JSON.pretty_generate(value)
  end
end

class Puppetwash < Wash::Entry
  label 'puppet'
  is_singleton
  parent_of 'PEInstance'
  state :config

  def init(config)
    @config = config
  end

  def list
    @config.map do |name, instance_config|
       PEInstance.new(name, instance_config)
    end
  end
end

class PEInstance < Wash::Entry
  label 'pe_instance'
  parent_of 'NodesDir'
  state :config

  def initialize(name, config)
    @name = name
    @config = config
  end

  def list
    [NodesDir.new('nodes', @config)]
  end
end

class NodesDir < Wash::Entry
  label 'nodes_dir'
  is_singleton
  parent_of 'Node'
  state :config

  def initialize(name, config)
    @name = name
    @config = config
  end

  def list
    response = client(@config).request('nodes', nil)
    response.data.map do |node|
      Node.new(node, @config)
    end
  end
end

class Node < Wash::Entry
  label 'node'
  parent_of 'Catalog', 'FactsDir', 'ReportsDir'
  state :config

  def initialize(node, config)
    @name = node['certname']
    @config = config
    @partial_metadata = node
    prefetch :list
  end

  def list
    [
      Catalog.new('catalog.json', @name, @config),
      FactsDir.new('facts', @name, @config),
      ReportsDir.new('reports', @name, @config)
    ]
  end
end

class Catalog < Wash::Entry
  label 'catalog'
  is_singleton
  state :node_name, :config

  def initialize(name, node_name, config)
    @name = name
    @node_name = node_name
    @config = config
  end

  def read
    response = client(@config).request("catalogs/#{@node_name}", nil)
    make_readable(response.data)
  end
end

class FactsDir < Wash::Entry
  label 'facts_dir'
  is_singleton
  parent_of 'Fact'
  state :node_name, :config

  def initialize(name, node_name, config)
    @name = name
    @node_name = node_name
    @config = config
  end

  def list
    response = client(@config).request(
      'facts',
      [:'=', :certname, @node_name]
    )
    response.data.map do |fact|
      Fact.new(fact['name'], fact['value'], @node_name, @config)
    end
  end
end

class Fact < Wash::Entry
  label 'fact'
  state :node_name, :config

  def initialize(name, value, node_name, config)
    @name = name
    @value = value
    @node_name = node_name
    @config = config
    prefetch :read
  end

  def read
    make_readable(@value)
  end
end

# Report relies on end_time and hash. The others are included as useful metadata.
METADATA_FIELDS = {
  'end_time': 'string',
  'environment': 'string',
  'status': 'string',
  'noop': 'boolean',
  'puppet_version': 'string',
  'producer': 'string',
  'hash': 'string'
}

class ReportsDir < Wash::Entry
  label 'reports_dir'
  is_singleton
  parent_of 'Report'
  state :node_name, :config

  def initialize(name, node_name, config)
    @name = name
    @node_name = node_name
    @config = config
  end

  def list
    response = client(@config).request(
      'reports',
      [:extract,
        METADATA_FIELDS.keys,
        [:'=', :certname, @node_name]]
    )
    response.data.map do |report|
      Report.new(report, @node_name, @config)
    end
  end
end

class Report < Wash::Entry
  label 'report'
  attributes :mtime
  partial_metadata_schema(
      type: 'object',
      properties: METADATA_FIELDS.map { |k, v| [k, { type: v }] }.to_h
  )
  state :node_name, :config, :hash

  def initialize(report, node_name, config)
    @name = report['end_time']
    @node_name = node_name
    @config = config
    @hash = report['hash']
    @partial_metadata = report
    @mtime = Time.parse(report['end_time'])
  end

  def read
    response = client(@config).request(
      'reports',
      [:and, [:'=', :certname, @node_name], [:'=', :hash, @hash]]
    )
    make_readable(response.data)
  end
end

Wash.enable_entry_schemas
Wash.prefetch_entry_schemas
Wash.pretty_print
Wash.run(Puppetwash, ARGV)
