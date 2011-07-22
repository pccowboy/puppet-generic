# Author: Kumina bv <support@kumina.nl>

# Class: gen_haproxy
#
# Parameters:
#	failover
#		Is this this haproxy in a failover setup?
#		This needs to be true if something like pacemaker controls HAProxy (i.e. we don't want puppet to start it)
#	customtag
#		The tag used when declaring gen_haproxy::site, so we can import the right config
#
# Actions:
#	Installs HAProxy and fetches its configuration based on the tag
#
# Depends:
#	gen_puppet
#
class gen_haproxy ($failover=false, $customtag="haproxy_${environment}"){
	# When haproxy is in a failover setup (e.g. in pacemaker/heartbeat), don't start or stop it from puppet.
	kservice { "haproxy":
		ensure     => $failover ? {
			false   => "running",
			default => false,
		},
	}

	# Yes, we would like to be able to start the service.....
	kfile { "/etc/default/haproxy":
		content => "ENABLED=1\n",
		require => Kpackage["haproxy"];
	}

	# These exported kfiles contain the configuration fragments
	# They should be exported on the webservers-to-be-loadbalanced
	Ekfile <<| tag == $customtag |>>
	concat { "/etc/haproxy/haproxy.cfg" :
		notify => $failover ? {
			true => undef,
			default => Kservice["haproxy"],
		};
	}

	# Some default configuration. Alter the templates and add the options when needed.
	concat::add_content {
		"globals":
			order      => 10,
			contenttag => $customtag,
			target     => "/etc/haproxy/haproxy.cfg",
			exported   => true,
			content    => template("gen_haproxy/global.erb");
		"defaults":
			order      => 11,
			contenttag => $customtag,
			target     => "/etc/haproxy/haproxy.cfg",
			exported   => true,
			content    => template("gen_haproxy/defaults.erb");
	}
}

# Define: gen_haproxy::site
#
# Actions:
#	This define exports the configuration for the load balancers. Use this to have webservers loadbalanced
#
# Parameters:
#	listenaddress
#		The external IP to listen to
#	port
#		The external port to listen on
#	cookie
#		The cookie option from HAProxy(see http://haproxy.1wt.eu/download/1.4/doc/configuration.txt)
#	httpcheck_uri
#		The URI to check if the backendserver is running
#	httpcheck_port
#		The port to check on whether the backendserver is running
#	servername
#		The hostname(or made up name) for the backend server
#	serverport
#		The port for haproxy to connect to on the backend server
#	serverip
#		The IP of the backend server
#	balance
#		The balancing-method to use
#	customtag="haproxy_${environment}"
#		Change this when there are multiple loadbalancers in one environment
#
# Depends:
#	gen_puppet
#
define gen_haproxy::site ($listenaddress, $port=80, $servername=$hostname, $serverport=80, $cookie=false, $httpcheck_uri=false, $httpcheck_port=false, $balance="static-rr", $serverip=$ipaddress_eth0, $customtag="haproxy_${environment}") {
	if $httpcheck_port and ! $httpcheck_uri {
		fail("Please specify a uri to check when you add a port to check on")
	}
	if !($balance in ["roundrobin","static-rr","source"]) {
		fail("${balance} is not a valid balancing type")
	}

	$safe_name = regsubst($name, " ", "_")
	gen_haproxy::proxyconfig {
		"site_${safe_name}_1_listen":
			content => template("gen_haproxy/listen.erb");
		"site_${safe_name}_2_server_${servername}":
			content => template("gen_haproxy/server.erb");
	}

	if $cookie {
		gen_haproxy::proxyconfig { "site_${safe_name}_3_cookie":
			content => "\tcookie ${cookie}";
		}
	}

	if $httpcheck_uri {
		gen_haproxy::proxyconfig { "site_${safe_name}_3_httpcheck":
			content => "\toption httpchk GET ${httpcheck_uri}";
		}
	}

	if $balance {
		gen_haproxy::proxyconfig { "site_${safe_name}_3_balance":
			content => "\tbalance ${balance}";
		}
	}
}

#
# Define: gen_haproxy::proxyconf
#
# Actions:
#	Exports the config, $customtag is passed implicitly (due to scoping) from gen_haproxy::site. This define should not be called from any other define than gen_haproxy::site
#
# Parameters:
#	content:
#		The content of the fragment
#
define gen_haproxy::proxyconfig ($content) {
	concat::add_content { "${name}":
		content    => $content,
		exported   => true,
		contenttag => $customtag,
		target     => "/etc/haproxy/haproxy.cfg";
	}
}
