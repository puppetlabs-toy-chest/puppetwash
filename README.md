# puppetwash

A Wash plugin for puppet

## Installation and configuration

1. clone this repo and cd to it
2. run `bundle install`
3. Add to `~/.puppetlabs/wash/wash.yaml`:

    ```yaml
    external-plugins:
        - script: '/path/to/puppetwash/puppet'
    ```

4. Configure one of more puppet infrastructures in `~/.puppetwash,yaml` - see `puppetwash.example.yaml`:

    ```yaml
    my_pe_instance:
      puppetdb_url: https://pupetmaster.example.com:8081
      rbac_token: <my_rbac_token>
      cacert: /path/to/cacert.pem
    ```

5. Enjoy!
