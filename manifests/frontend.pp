# == Define Resource Type: haproxy::frontend
#
# This type will setup a frontend service configuration block inside
#  the haproxy.cfg file on an haproxy load balancer.
#
# === Requirement/Dependencies:
#
# Currently requires the puppetlabs/concat module on the Puppet Forge and
#  uses storeconfigs on the Puppet Master to export/collect resources
#  from all balancer members.
#
# === Parameters
#
# [*name*]
#   The namevar of the defined resource type is the frontend service's name.
#    This name goes right after the 'frontend' statement in haproxy.cfg
#
# [*ports*]
#   Ports on which the proxy will listen for connections on the ip address
#    specified in the ipaddress parameter. Accepts either a single
#    comma-separated string or an array of strings which may be ports or
#    hyphenated port ranges.
#
# [*ipaddress*]
#   The ip address the proxy binds to. Empty addresses, '*', and '0.0.0.0'
#    mean that the proxy listens to all valid addresses on the system.
#
# [*mode*]
#   The mode of operation for the frontend service. Valid values are undef,
#    'tcp', 'http', and 'health'.
#
# [*bind_options*]
#   An array of options to be specified after the bind declaration in the
#    bind's configuration block.
#
# [*options*]
#   A hash of options that are inserted into the frontend service
#    configuration block.
#
# === Examples
#
#  Exporting the resource for a balancer member:
#
#  haproxy::frontend { 'puppet00':
#    ipaddress    => $::ipaddress,
#    ports        => '18140',
#    mode         => 'tcp',
#    bind_options => 'accept-proxy',
#    options      => {
#      'option'   => [
#        'tcplog',
#        'accept-invalid-http-request',
#      ],
#      'timeout client' => '30',
#      'balance'    => 'roundrobin'
#    },
#  }
#
# === Authors
#
# Gary Larizza <gary@puppetlabs.com>
#
define haproxy::frontend (
  $ports,
  $ipaddress        = [$::ipaddress],
  $mode             = undef,
  $bind_options     = undef,
  $collect_exported = true,
  $options          = {
    'option'  => [
      'tcplog',
    ],
  }
) {
  include haproxy
  # Template uses: $name, $ipaddress, $ports, $options
  concat::fragment { "${name}_frontend_block":
    order   => "15-${name}-00",
    target  => $haproxy::_managed_config_path,
    content => template('haproxy/haproxy_frontend_block.erb'),
  }
}
