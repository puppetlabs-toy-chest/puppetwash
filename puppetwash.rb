#!/usr/bin/env ruby

require 'puppetdb'
require 'json'
require 'yaml'
require 'thor'

# OpenSSL::debug = true

# logger = Logger.new(STDOUT)
# logger.level = Logger::DEBUG

class Puppetwash < Thor
  class_option :verbose, type: :boolean, aliases: '-v'

  desc 'init [STATE]', 'init plugin'
  def init(_state = {})
    puts({ methods: ['list'] }.to_json)
  end

  desc 'list PATH [STATE]', 'list entries at PATH with state STATE'
  def list(path, state = {})
    read_config
    if path == '/puppet'
      list_puppet_instances
    else
      state = JSON.parse(state) unless state.nil? || state.empty?
      case state['type']
      when 'pe'
        new_state = { type: 'nodes', pe: state['name'] }
        puts([{ name: 'nodes', methods: ['list'], state: JSON.dump(new_state) }].to_json)
      when 'nodes'
        list_nodes(state['pe'])
      when 'node'
        new_state = { type: 'facts', node: state['name'], pe: state['pe'] }
        puts([{ name: 'facts', methods: ['list'], state: JSON.dump(new_state) }].to_json)
      when 'facts'
        list_node_facts(state['pe'], state['node'])
      end
    end
  end

  desc 'read PATH STATE', 'read entry at PATH with state STATE'
  def read(_path, state)
    read_config
    state = JSON.parse(state) unless state.nil? || state.empty?
    case state['type']
    when 'fact'
      response = client(state['pe']).request(
        "",
        "facts { name = \"#{state['name']}\" and certname = \"#{state['node']}\" }",
      )
      puts(make_readable(response.data.first['value']))
    end
  end

  no_commands do
    def read_config
      @config = YAML.load_file("#{ENV['HOME']}/.puppetwash.yaml")
    end

    def client(pe_name)
      client = PuppetDB::Client.new(
        {
          server: @config[pe_name]['puppetdb_url'],
          token: @config[pe_name]['rbac_token'],
          cacert: @config[pe_name]['cacert']
        }
      )
      client
    end

    def list_puppet_instances
      entries = []
      @config.keys.each do |key|
        entries << {
          name: key,
          methods: ['list'],
          type_id: 'pe',
          state: JSON.dump(type: 'pe', name: key)
        }
      end
      puts JSON.pretty_generate(entries)
    end

    def node_to_json(node, pe_name)
      result = {
        name: node['certname'],
        methods: ['list', 'metadata'],
        attributes: {
          mtime: DateTime.rfc3339(node['facts_timestamp']).to_time.to_i,
          meta: {
            LastModifiedTime: DateTime.rfc3339(node['facts_timestamp']).to_time.to_i
          }
        },
        type_id: 'node',
        state: JSON.dump(type: 'node', name: node['certname'], pe: pe_name)
      }
      result
    end

    def list_nodes(pe_name)
      # require 'pry'; binding.pry
      response = client(pe_name).request(
        '',
        'nodes {}'
        # {:limit => 1000}
      )
      node_entries = []
      response.data.each do |node|
        node_entries << node_to_json(node, pe_name)
      end
      # puts JSON.pretty_generate(response.data)
      puts JSON.pretty_generate(node_entries)
    end

    def make_readable(fact_value)
      if fact_value.kind_of? String
        fact_value
      else
        JSON.pretty_generate(fact_value)
      end
    end

    def fact_to_json(fact, pe_name, node_name)
      value = make_readable(fact['value'])

      result = {
        name: fact['name'],
        methods: ['read'],
        attributes: {
          size: value.length
        },
        type_id: 'fact',
        state: JSON.dump(type: 'fact', name: fact['name'], pe: pe_name, node: node_name)
      }
      result
    end

    def list_node_facts(pe_name, node_name)
      response = client(pe_name).request(
        "",
        "facts { certname = \"#{node_name}\" }",
        # {:limit => 1000}
      )
      fact_entries = []
      response.data.each do |fact|
        fact_entries << fact_to_json(fact, pe_name, node_name)
      end

      puts JSON.pretty_generate(fact_entries)
    end
  end
end

Puppetwash.start(ARGV)
