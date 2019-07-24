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

def make_readable(fact_value)
  if fact_value.kind_of? String
    fact_value
  else
    JSON.pretty_generate(fact_value)
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
  parent_of 'Node'
  state :pe_name

  def initialize(name, pe_name)
    @name = name
    @pe_name = pe_name
    # puts "pe name: #{pe_name}"
  end

  def list
    response = client(@pe_name).request(
      '',
      'nodes {}'
    )
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
  end

  def list
    [FactsDir.new('facts', @name, @pe_name)]
  end

end

class FactsDir < Wash::Entry
  label 'facts_dir'
  parent_of 'Fact'
  state :node_name, :pe_name

  def initialize(name, node_name, pe_name)
    @name = name
    @node_name = node_name
    @pe_name = pe_name
  end

  def list
    response = client(@pe_name).request(
      "",
      "facts { certname = \"#{@node_name}\" }",
    )
    response.data.map do |fact|
      Fact.new(fact['name'], @node_name, @pe_name, make_readable(fact['value']).length)
    end
  end
end

class Fact < Wash::Entry
  label 'fact'
  attributes :size
  state :node_name, :pe_name

  def initialize(name, node_name, pe_name, size)
    @name = name
    @node_name = node_name
    @pe_name = pe_name
    @size = size
  end

  def read
    response = client(@pe_name).request(
      "",
      "facts { name = \"#{@name}\" and certname = \"#{@node_name}\" }",
    )
    make_readable(response.data.first['value'])
  end

end

Wash.enable_entry_schemas
Wash.pretty_print
Wash.run(Puppetwash, ARGV)
