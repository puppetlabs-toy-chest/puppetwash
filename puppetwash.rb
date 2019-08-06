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
      Node.new(node['certname'], @pe_name)
    end
  end
end

class Node < Wash::Entry
  label 'node'
  parent_of 'FactsDir'
  state :pe_name

  def initialize(name, pe_name)
    @pe_name = pe_name
    @name = name
    prefetch :list
  end

  def list
    [
      Catalog.new('catalog.json', @name, @pe_name),
      FactsDir.new('facts', @name, @pe_name)
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

Wash.enable_entry_schemas
Wash.pretty_print
Wash.run(Puppetwash, ARGV)
