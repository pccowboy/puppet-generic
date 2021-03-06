# Author: Kumina bv <support@kumina.nl>

# Class: gen_softflowd
#
# Actions:
#  Configure softflowd
#
# Parameters:
#   interface  The network interface to listen on (default 'eth0')
#   host       IP of NetFlow collector (default '127.0.0.1')
#   port       UDP port of the collector (default '9995')
#   version    Netflow version (default '9')
#   maxlife    Max lifetime of a flow (default '5m' (= five minutes))
#   expint     Flow expire interval, expint=0 means expire immediately (default '0')
#   maxflows   Maximum flows concurrently tracked (softflowd's default is 8192)
#
# Depends:
#  gen_puppet
#
class gen_softflowd ($interface='eth0', $host='127.0.0.1', $port='9995', $version='9', $maxlife='5m', $expint='0', $maxflows=false) {
  $nf_collector = "${host}:${port}"

  kservice { 'softflowd':
    hasstatus => false,
    pattern   => 'softflowd';
  }

  file { '/etc/default/softflowd':
    content => template('gen_softflowd/default'),
    require => Package['softflowd'],
    notify  => Service['softflowd'];
  }
}
