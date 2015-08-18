# Private class
class haproxy::config inherits haproxy {
  if $caller_module_name != $module_name {
    fail("Use of private class ${name} by ${caller_module_name}")
  }

  $config_file = '/etc/haproxy/haproxy.cfg'
  $base_config_file = '/etc/haproxy/haproxy.cfg.base'

  concat { $base_config_file:
    owner   => '0',
    group   => '0',
    mode    => '0644',
  }

  # Simple Header
  concat::fragment { '00-header':
    target  => $base_config_file,
    order   => '01',
    content => "# This file managed by Puppet\n",
  }

  # Template uses $global_options, $defaults_options
  concat::fragment { 'haproxy-base':
    target  => $base_config_file,
    order   => '10',
    content => template('haproxy/haproxy-base.cfg.erb'),
  }

  file { $config_file:
    require => File[$base_config_file],
    source  => $base_config_file,
    replace => false,
  }

  if $global_options['chroot'] {
    file { $global_options['chroot']:
      ensure => directory,
      owner  => $global_options['user'],
      group  => $global_options['group'],
    }
  }
}
