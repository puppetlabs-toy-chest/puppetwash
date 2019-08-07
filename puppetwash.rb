#!/usr/bin/env ruby

require 'wash'
require 'puppetdb'
require 'json'
require 'yaml'

def config
  YAML.load_file("#{ENV['HOME']}/.puppetwash.yaml")
end

def client(pe_name)
  pe_config = config
  client = PuppetDB::Client.new(
    {
      server: pe_config[pe_name]['puppetdb_url'],
      token: pe_config[pe_name]['rbac_token'],
      cacert: pe_config[pe_name]['cacert']
    }
  )
  client
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

  def init(_wash_config)
  end

  def list
    config.keys.map do |name|
       PEInstance.new(name)
    end
  end
end

class PEInstance < Wash::Entry
  label 'pe_instance'
  parent_of 'NodesDir'

  def initialize(name)
    @name = name
  end

  def list
    [NodesDir.new('nodes', name)]
  end
end

class NodesDir < Wash::Entry
  label 'nodes_dir'
  is_singleton
  parent_of 'Node'
  state :pe_name

  def initialize(name, pe_name)
    @name = name
    @pe_name = pe_name
  end

  def list
    response = client(@pe_name).request('nodes', nil)
    response.data.map do |node|
      Node.new(node, @pe_name)
    end
  end
end

class Node < Wash::Entry
  label 'node'
  parent_of 'Catalog', 'FactsDir', 'ReportsDir'
  state :pe_name
  attributes :meta

  def initialize(node, pe_name)
    @name = node['certname']
    @pe_name = pe_name
    @meta = node
    prefetch :list
  end

  def list
    [
      Catalog.new('catalog.json', @name, @pe_name),
      FactsDir.new('facts', @name, @pe_name),
      ReportsDir.new('reports', @name, @pe_name)
    ]
  end
end

class Catalog < Wash::Entry
  label 'catalog'
  is_singleton
  state :node_name, :pe_name

  def initialize(name, node_name, pe_name)
    @name = name
    @node_name = node_name
    @pe_name = pe_name
  end

  def read
    response = client(@pe_name).request("catalogs/#{@node_name}", nil)
    make_readable(response.data)
  end
end

class FactsDir < Wash::Entry
  label 'facts_dir'
  is_singleton
  parent_of 'Fact'
  state :node_name, :pe_name

  def initialize(name, node_name, pe_name)
    @name = name
    @node_name = node_name
    @pe_name = pe_name
  end

  def list
    response = client(@pe_name).request(
      'facts',
      [:'=', :certname, @node_name]
    )
    response.data.map do |fact|
      Fact.new(fact['name'], fact['value'], @node_name, @pe_name)
    end
  end
end

class Fact < Wash::Entry
  label 'fact'
  state :node_name, :pe_name

  def initialize(name, value, node_name, pe_name)
    @name = name
    @value = value
    @node_name = node_name
    @pe_name = pe_name
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
  state :node_name, :pe_name

  def initialize(name, node_name, pe_name)
    @name = name
    @node_name = node_name
    @pe_name = pe_name
  end

  def list
    response = client(@pe_name).request(
      'reports',
      [:extract,
        METADATA_FIELDS.keys,
        [:'=', :certname, @node_name]]
    )
    response.data.map do |report|
      Report.new(report, @node_name, @pe_name)
    end
  end
end

class Report < Wash::Entry
  label 'report'
  attributes :meta, :mtime
  meta_attribute_schema(
      type: 'object',
      properties: METADATA_FIELDS.map { |k, v| [k, { type: v }] }.to_h
  )
  state :node_name, :pe_name, :hash

  def initialize(report, node_name, pe_name)
    @name = report['end_time']
    @node_name = node_name
    @pe_name = pe_name
    @hash = report['hash']
    @meta = report
    @mtime = Time.parse(report['end_time'])
  end

  def read
    response = client(@pe_name).request(
      'reports',
      [:and, [:'=', :certname, @node_name], [:'=', :hash, @hash]]
    )
    make_readable(response.data)
  end
end

Wash.enable_entry_schemas
Wash.pretty_print
Wash.run(Puppetwash, ARGV)
