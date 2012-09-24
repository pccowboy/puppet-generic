# Author: Kumina bv <support@kumina.nl>

# Class: gen_postfix
#
# Actions:
#  Set up Postfix
#
# Parameters:
#  certs         The Puppet location and name (without extension) of the certificates for Dovecot. Only used and has to be set when mode is primary
#  relayhost     Same as Postfix, see http://www.postfix.org/postconf.5.html#relayhost. Absent by default
#  myhostname    Same as Postfix, see http://www.postfix.org/postconf.5.html#myhostname. Defaults to $fqdn
#  mynetworks    Same as Postfix, see http://www.postfix.org/postconf.5.html#mynetworks. Defaults to 127.0.0.0/8 [::1]/128
#  mydestination Same as Postfix, see http://www.postfix.org/postconf.5.html#mydestination. Defaults to $fqdn, $hostname, localhost.localdomain, localhost. The default is appended when this param is set
#  mode          Set to primary for a full mailserver, secondary for a backup mailserver, false otherwise. Defaults to false
#  always_bcc    Same as Postfix, see http://www.postfix.org/postconf.5.html#always_bcc. Absent by default
#  mysql_user    The MySQL username used for virtual_aliases, virtual_domains and virtual_mailboxes. Only used and has to be set when mode is primary
#  mysql_pass    The MySQL password used for virtual_aliases, virtual_domains and virtual_mailboxes. Only used and has to be set when mode is primary
#  mysql_db      The MySQL database used for virtual_aliases, virtual_domains and virtual_mailboxes. Only used and has to be set when mode is primary
#  mysql_host    The MySQL host used for virtual_aliases, virtual_domains and virtual_mailboxes. Only used and has to be set when mode is primary
#  relay_domains Same as Postfix, see http://www.postfix.org/postconf.5.html#relay_domains. Only used when mode is primary or secondary. Defaults to false (which means '$mydestination' in Postfix)
#
# Depends:
#  gen_puppet
#
class gen_postfix($certs=false, $relayhost=false, $myhostname=false, $mynetworks=false, $mydestination=false, $mode=false, $always_bcc=false,
    $mysql_user=false, $mysql_pass=false, $mysql_db=false, $mysql_host=false, $relay_domains=false) {
  if $mode == 'primary' {
    if ! $certs {
      fail('When using primary mode for gen_postfix, $certs must be set')
    } else {
      $key_name = regsubst($certs,'^(.*)/(.*)$','\2')
    }
  }

  package { 'nullmailer':
    ensure => absent;
  }

  kservice { 'postfix':
    pattern => '/usr/lib/postfix/master';
  }

  file {
    '/etc/postfix/main.cf':
      content => template('gen_postfix/main.cf'),
      require => Package['postfix'],
      notify  => Exec['reload-postfix'];
    '/var/spool/postfix/dovecot':
      ensure  => directory,
      owner   => 'postfix',
      group   => 'mail',
      require => Package['postfix'];
  }

  exec {
    'newaliases':
      refreshonly => true,
      path        => '/usr/bin';
    'postmap-transport':
      refreshonly => true,
      command     => '/usr/sbin/postmap /etc/postfix/transport';
  }

  if $mode == 'primary' {
    file {
      '/etc/postfix/virtual_aliases.cf':
        content => template('gen_postfix/virtual_aliases.cf'),
        group   => 'postfix',
        mode    => 640,
        require => Package['postfix'],
        notify  => Exec['reload-postfix'];
      '/etc/postfix/virtual_domains.cf':
        content => template('gen_postfix/virtual_domains.cf'),
        group   => 'postfix',
        mode    => 640,
        require => Package['postfix'],
        notify  => Exec['reload-postfix'];
      '/etc/postfix/virtual_mailboxes.cf':
        content => template('gen_postfix/virtual_mailboxes.cf'),
        group   => 'postfix',
        mode    => 640,
        require => Package['postfix'],
        notify  => Exec['reload-postfix'];
      '/etc/postfix/master.cf':
        content => template('gen_postfix/master.cf'),
        require => Package['postfix'],
        notify  => Exec['reload-postfix'];
    }
  }
}

# Define: gen_postfix:alias
#
# Actions:
#  Add a Postfix alias
#
# Parameters:
#  name   The line to add to the aliases file, the format should be 'foo: bar@mydomain'
#  ensure Standard Puppet ensure
#
# Depends:
#  gen_puppet
#
define gen_postfix::alias($ensure = 'present') {
  line { $name:
    ensure => $ensure,
    file   => '/etc/aliases',
    notify => Exec['newaliases'];
  }
}


# Define: gen_postfix:transport
#
# Actions:
#  Add a Postfix transport
#
# Parameters:
#  name   postfix transport entry, e.g. "lists.kumina.nl mailman:"
#  ensure Standard Puppet ensure
#
# Depends:
#  gen_puppet
#
define gen_postfix::transport($ensure='present') {
  line { $name:
    ensure  => $ensure,
    file    => '/etc/postfix/transport',
    require => Package['postfix'],
    notify  => Exec['postmap-transport'];
  }
}
