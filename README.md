# puppetwash

A [Wash](https://puppetlabs.github.io/wash/) plugin for managing your Puppet instances
(both PE and open source). This plugin will iterate all nodes from PuppetDB and expose
information about them such as their facts, last run report, and the current catalog.

```
wash . ❯ stree puppet
puppet
└── [instance]
    └── nodes
        └── [node]
            ├── catalog
            ├── facts
            │   └── [fact]
            └── reports
                └── [report]
```

Here's an example that shows off the `puppetwash` plugin's features.

```
wash . ❯ ls puppet/instance_one/nodes
base-graham.delivery.puppetlabs.net/
choosy-cat.delivery.puppetlabs.net/
fugual-apology.delivery.puppetlabs.net/
lunar-scoundrel.delivery.puppetlabs.net/
sturdy-romp.delivery.puppetlabs.net/
wash . ❯ cat puppet/instance_one/nodes/base-graham.delivery.puppetlabs.net/catalog.json
{
  "catalog_uuid": "663da32b-b146-4d7a-8367-52849cb4ed5f",
  "producer": "sturdy-romp.delivery.puppetlabs.net",
  "hash": "ae8bef9977cd10c85a949cb8af97f3d27739bdc9",
...
wash . ❯ cat puppet/instance_one/nodes/base-graham.delivery.puppetlabs.net/reports/2020-02-07T18\:26\:31.789Z
[
  {
    "catalog_uuid": "663da32b-b146-4d7a-8367-52849cb4ed5f",
    "receive_time": "2020-02-07T18:26:32.375Z",
    "producer": "sturdy-romp.delivery.puppetlabs.net",
    "hash": "9a0ea00afed5b00e0d6fe8130534c6dda08beccc",
    "transaction_uuid": "d103e05c-1bd7-41eb-a333-cea4fb26fd57",
...
wash . ❯ ls puppet/instance_one/nodes/base-graham.delivery.puppetlabs.net/facts
aio_agent_build
aio_agent_version
architecture
augeas
augeasversion
bios_release_date
...
wash . ❯ cat puppet/instance_one/nodes/base-graham.delivery.puppetlabs.net/facts/aio_agent_build
6.12.0.177.g77ef0268
```

## Installation and configuration

1. `gem install puppetwash`
2. Get the path to the puppetwash script with `gem contents puppetwash`.
3. Add to `~/.puppetlabs/wash/wash.yaml`

    ```yaml
    external-plugins:
        - script: '/path/to/puppetwash/puppet.rb'
    puppet:
      # Uncomment this to add the 'my_pe_instance' PE instance
      #my_pe_instance:
      #  puppetdb_url: https://puppetmaster.example.com:8081
      #  rbac_token: <my_rbac_token>
      #  cacert: /path/to/cacert.pem # from /etc/puppetlabs/puppet/ssl/certs/ca.pem on the master
      #
      # Uncomment this to add the 'my_oss_instance' open source instance
      #my_oss_instance:
      #  puppetdb_url: https://puppetdb.example.com:8081
      #  cacert: /path/to/cacert.pem # maybe /etc/puppetlabs/puppetdb/ssl/certs/ca.pem
      #  cert: /path/to/cert.pem
      #  key: /path/to/key.pem
    ```
4. Enjoy!

> If you're a developer, you can use the puppetwash plugin from source with `bundle install` and set `script: /path/to/puppetwash/puppet`.

## Note 1

For PE instances: The `cacert` key in the config should point to a Puppet CA certificate file you can get from ` /etc/puppetlabs/puppet/ssl/certs/ca.pem on the master`

## Note 2

The hostname in `puppetdb_url` should match the master certname, otherwize you will get TLS errors. If you use a master with a non-resolvable certname, you can add an entry to your hosts file:
```bash
<my_master_ip> puppetmaster.example.com
```

## Future improvements

* Include facts in node metadata so that you can use `find` to filter your nodes on their facts
* For PE instances: view tasks + jobs
* Anything else that you think could be useful. Please file an issue!
