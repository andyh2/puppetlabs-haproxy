# Private class
class haproxy::config inherits haproxy {
  if $caller_module_name != $module_name {
    fail("Use of private class ${name} by ${caller_module_name}")
  }

  $config_file = '/etc/haproxy/haproxy.cfg'
  $base_config_file = '/etc/haproxy/haproxy.cfg.base'

  if $haproxy::dynamic_config {
    file { $config_file:
      require => File[$base_config_file],
      source  => $base_config_file,
      replace => false, # Config file is managed 
    }
    
    # TODO subscribe to base_config_file changes and run merge script
    
    $config_write_path = $base_config_file
  } else {
    $config_write_path = $config_file
  }

  concat { $config_write_path:
    owner   => '0',
    group   => '0',
    mode    => '0644',
  }

  # Simple Header
  concat::fragment { '00-header':
    target  => $config_write_path,
    order   => '01',
    content => "# This file managed by Puppet\n",
  }

  # Template uses $global_options, $defaults_options
  concat::fragment { 'haproxy-base':
    target  => $config_write_path,
    order   => '10',
    content => template('haproxy/haproxy-base.cfg.erb'),
  }

  if $global_options['chroot'] {
    file { $global_options['chroot']:
      ensure => directory,
      owner  => $global_options['user'],
      group  => $global_options['group'],
    }
  }
}
