# Private class
class haproxy::config inherits haproxy {
  if $caller_module_name != $module_name {
    fail("Use of private class ${name} by ${caller_module_name}")
  }

  $live_config = '/etc/haproxy/haproxy.cfg'

  if $dynamic_config {
    file { $live_config:
      require => File[$_managed_config_path],
      source  => $_managed_config_path,
      replace => false, # After initial provision, live config file is managed by haproxy-update.sh
    }
  }

  concat { $_managed_config_path:
    owner   => '0',
    group   => '0',
    mode    => '0644',
  }

  # Simple Header
  concat::fragment { '00-header':
    target  => $_managed_config_path,
    order   => '01',
    content => "# This file managed by Puppet\n",
  }

  # Template uses $global_options, $defaults_options
  concat::fragment { 'haproxy-base':
    target  => $_managed_config_path,
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
