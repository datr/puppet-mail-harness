# -*- mode: puppet -*-
# vi: set ft=puppet :

class webmail {
  # Redirect all outgoing SMTP traffic to the localhost.
  firewall { '100 redirect outgoing smtp traffic':
    table       => 'nat',
    chain       => 'OUTPUT',
    proto       => 'tcp',
    destination => '94.126.104.204',
    dport       => '25',
    jump        => 'REDIRECT',
    toports     => '25',
  }

  # Set up our own SMTP server to deal with that traffic and configure it to
  # redirect all of the outgoing mail to vagrant@localhost.
  package { "postfix" : }

  service { "postfix" :
    ensure  => "running",
    enable  => "true",
    require => Package["postfix"],
  }

  file { "/etc/postfix/main.cf" :
    owner => "root",
    group => "root",
    mode => 644,
    source => "puppet://${server}/modules/webmail/etc/postfix/main.cf",
    require => Package["postfix"],
    notify  => Service["postfix"],
  }

  file { "/etc/postfix/virtual_alias_map" :
    owner => "root",
    group => "root",
    mode => 644,
    source => "puppet://${server}/modules/webmail/etc/postfix/virtual_alias_map",
    require => Package["postfix"],
    notify  => Service["postfix"],
  }

  # Create an empty mbox for the vagrant user. This normally isn't created until
  # postfix handles the first email address but dovecot will error if the user
  # tries to connect before then.
  # @todo populate this with a welcome email for the user.
  file { "/var/mail/vagrant" :
    ensure => "present",
    owner => "vagrant",
    group => "mail",
    mode => 600,
  }

  # Allow access to that mailbox via imap.
  package { "dovecot-imapd" : }

  service { "dovecot" :
    ensure => "running",
    enable => "true",
    require => Package["dovecot-imapd"],
  }

  # Tell dovecot to look for mbox mail in /var/mail
  file { "/etc/dovecot/conf.d/10-mail.conf" :
    owner => "root",
    group => "root",
    mode => 644,
    source => "puppet://${server}/modules/webmail/etc/dovecot/conf.d/10-mail.conf",
    notify => Service["dovecot"],
  }

  # Enable logging
  file { "/etc/dovecot/conf.d/10-logging.conf" :
    owner => "root",
    group => "root",
    mode => 644,
    source => "puppet://${server}/modules/webmail/etc/dovecot/conf.d/10-logging.conf",
    notify => Service["dovecot"],
  }

  # Set up a simple static username and password for authentication.
  file { "/etc/dovecot/conf.d/10-auth.conf" :
    owner => "root",
    group => "root",
    mode => 644,
    source => "puppet://${server}/modules/webmail/etc/dovecot/conf.d/10-auth.conf",
    notify => Service["dovecot"],
  }

  file { "/etc/dovecot/conf.d/auth-static.conf.ext" :
    owner => "root",
    group => "root",
    mode => 644,
    source => "puppet://${server}/modules/webmail/etc/dovecot/conf.d/auth-static.conf.ext",
    notify => Service["dovecot"],
  }

  # Now lets set up a web-based imap client.
  # @todo: Keep an eye on http://www.hajomail.com/ as a possible alternative.
  package { "roundcube" : }
  package { "roundcube-mysql" : }

  # Set up roundcube to use our local imap server.
  file { "/etc/roundcube/main.inc.php" :
    owner => "root",
    group => "www-data",
    mode => 640,
    source => "puppet://${server}/modules/webmail/etc/roundcube/main.inc.php",
    require => Package['roundcube'],
  }

  # Copy accross an auto-login script for round cube so that we don't have to
  # deal with usernames and passwords.
  # @todo: convert this into a package.
  file { "/etc/roundcube/plugins/autologin" :
    owner => "root",
    group => "www-data",
    mode => 640,
    source => "puppet://${server}/modules/webmail/etc/roundcube/plugins/autologin",
    recurse => true,
    require => Package['roundcube'],
  }

  file { '/var/lib/roundcube/plugins/autologin' :
    ensure => 'link',
    target => '/etc/roundcube/plugins/autologin',
    require => File["/etc/roundcube/plugins/autologin"],
  }

  # Enable the apache directory alias
  file { "/etc/roundcube/apache.conf" :
    owner => "root",
    group => "www-data",
    mode => 640,
    source => "/vagrant/files/etc/roundcube/apache.conf",
    require => Package['roundcube'],
    notify => Service['apache2'],
  }

  # Archiving utility to prevent mail boxes from getting too big.
  package { "archmbox" : }

  # Set up a cron job to remove any mail older than 15 days.
  cron { "delete old mail" :
    command => "archmbox -k -o 15 /var/mail/vagrant",
    user => root,
    minute => 0,
    require => Package['archmbox'],
  }
}