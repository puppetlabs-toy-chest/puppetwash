# puppetwash

A [Wash](https://puppetlabs.github.io/wash/) plugin for Puppet Enterprise

## Installation and configuration

1. clone this repo and cd to it
2. run `bundle install`
3. Add to `~/.puppetlabs/wash/wash.yaml`:

    ```yaml
    external-plugins:
        - script: '/path/to/puppetwash/puppet'
    ```

4. Configure one of more Puppet infrastructures in `~/.puppetwash.yaml` - see `puppetwash.example.yaml`:

    ```yaml
    my_pe_instance:
      puppetdb_url: https://pupetmaster.example.com:8081
      rbac_token: <my_rbac_token>
      cacert: /path/to/cacert.pem # from /etc/puppetlabs/puppet/ssl/certs/ca.pem on the master
    ```

5. Enjoy!


## Note 1

The `cacert` key in the config should point to a Puppet CA certificate file you can get from ` /etc/puppetlabs/puppet/ssl/certs/ca.pem on the master`

## Note 2

The hostname in `puppetdb_url` should match the master certname, otherwize you will get TLS errors. If you use a master with a non-resolvable certname, you can add an entry to your hosts file:
```bash
<my_master_ip> puppetmaster.example.com
```
