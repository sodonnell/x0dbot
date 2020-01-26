#!/usr/bin/perl
#
# x0dbot.pl
#
# Author: Sean O'Donnell <sean@seanodonnell.com>
#

use strict;
use warnings;

# cpan modules
use Switch;
use Number::Format;
use POE qw(Component::IRC);
use LWP::UserAgent;
use Digest::MD5;
use Chatbot::Eliza; # a wee-bit of AI experiment and trickery ;p
use DBI;
use Regexp::Common qw/URI/;
use pQuery;
use feature qw(include);

my $nickname;
my $ircname;
my $server;
my $master;
my @channels;

# Custom HTTP User Agent string
my $agent = "x0dbot/1.0";

our $line;

# !quote/!addquote trigger db
our $fquotes = "quotes.txt";

# !f00d trigger db
our $ff00d = "f00d.txt";

# !dadjoke trigger db
our $fdadjokes = "dadjokes.txt";

#
# irc config (editing required)
#
# Using the switch below, you can add support
# for multiple IRC servers. Although this bot
# doesn't currently support connecting to multiple
# servers in a single instance, it has the potential to.
# 
# For now, it's just a single server per-process/instance.
#
# You can add additional IRC servers, using the case below.
#
switch($ARGV[0])
{
	case /^-e|^--efnet/ {
		include 'config.efnet.pl';
	}
	case /^-f|^--freenode/ {
		include 'config.freenode.pl';
	}
	else {
		print "Usage: $0 [-e|--efnet|-f|--freenode]\n";
		include 'config.pl';
	}
}

# database config DEPRECATED
my $db_user = 'x0dbot';
my $db_pass = 'x0db0t';
my $db_host = 'localhost';
my $db_name = 'x0dbot';
my $db_dsn = 'DBI:mysql:'. $db_name .':'.$db_host;
our $db_conn;

my $md5 = Digest::MD5->new;

my $lwp = LWP::UserAgent->new;
$lwp->agent($agent);

my $eliza = Chatbot::Eliza->new;

# We create a new PoCo-IRC object
my $irc = POE::Component::IRC->spawn( 
    nick => $nickname,
    ircname => $ircname,
    server => $server,
) or die "Error spawning the POE IRC Component: $!";

POE::Session->create(
     package_states => [
         main => [ qw(_default _start irc_001 irc_public) ],
     ],
     heap => { irc => $irc },
 );
 
$poe_kernel->run();

#######
#
# end procedures (main())
# start subrouties
#
#######

# We registered for all events, this will produce some debug info.
sub _default 
{
	my ($event, $args) = @_[ARG0 .. $#_];
	my @output = ( "$event: " );
	
	for my $arg (@$args) 
	{
		if ( ref $arg eq 'ARRAY' ) 
		{
			push( @output, '[' . join(', ', @$arg ) . ']' );
		}
		else 
		{
			push ( @output, "'$arg'" );
		}
	}

	print join ' ', @output, "\n";
	return 0;
}

sub _start 
{
     my $heap = $_[HEAP];

     # retrieve our component's object from the heap where we stashed it
     my $irc = $heap->{irc};

     $irc->yield( register => 'all' );
     $irc->yield( connect => { } );
     return;
}

sub irc_001 
{
     my $sender = $_[SENDER];

     # Since this is an irc_* event, we can get the component's object by
     # accessing the heap of the sender. Then we register and connect to the
     # specified server.
     my $irc = $sender->get_heap();

     print "Connected to ", $irc->server_name(), "\n";

     # we join our channels
     $irc->yield( join => $_ ) for @channels;
     return;
 }
 
sub irc_public 
{
 	master_filter(@_);
 	return;
}
### mysql database table structure...
#
# CREATE TABLE `x0d_logs` (
#  `id` mediumint(11) NOT NULL auto_increment,
#  `nick` varchar(25) default NULL,
#  `address` varchar(100) NOT NULL,
#  `chan` varchar(50) default NULL,
#  `server` varchar(50) default NULL,
#  `textinput` varchar(255) default NULL,
#  `logstamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
#  PRIMARY KEY  (`id`),
#  KEY `textinput` (`textinput`)
# ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='IRC logs via Irssi';
#
###
sub master_filter
{
	my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
	
	my $nick = ( split /!/, $who )[0];
	my $channel = $where->[0];

	if ($db_conn)
	{
		my $sql_log = "INSERT INTO x0d_logs (nick,chan,address,server,textinput) VALUES ('$nick','$channel','','','$what');";
		db_query($sql_log);
	}

	if ($nick eq $master || $nick eq "+$master" || $nick eq "\@$master")
	{
		# botmaster triggers
		if ($what eq "!uptime")
		{
			$irc->yield( privmsg => $channel => "$nick: As you wish, master." );
			my $uptime = `uptime`;
			$irc->yield( privmsg => $channel => "$nick: $uptime" );
		}
		elsif ($what eq "!quit")
		{
			$irc->yield( privmsg => $channel => "$nick: As you wish, master." );
			$irc->yield( quit => msg => "Nuked by: $nick" );
			print "Exiting. The !quit command was executed by: $nick\n";
			exit; 
		}
		elsif ($what =~ /^!join/)
		{
			my $whereto = $what;
			$whereto =~ s/^!join //;
			print "Joining: $whereto\n";
			$irc->yield( join => "$whereto" );
		}
                elsif ($what =~ /^!part/)
                {
                        my $whereto = $what;
                        $whereto =~ s/^!part //;
                        print "Parting $whereto\n";
                        $irc->yield( part => "$whereto" => msg => "$whereto Peace out!" );
                }
		elsif ($what =~ /^!kick/)
		{
			my $who = $what;
			$who =~ s/^!kick //;
			print "Kicking: $who\n";
			$irc->yield( kick => $channel => msg => "$who *b00ted*" );
		}
		elsif ($what =~ /^!op/)
		{
			my $who = $what;
			$who =~ s/^!op //;
			if ($who)
			{
				print "Op'ing Minion: $who\n";
			}
			else
			{
				$who = $master;
				print "Op'ing Master: $who\n";
			}
			$irc->yield( mode => $channel => "+o $who" );
		}
		elsif ($what =~ /^!deop/)
		{
			my $who = $what;
			$who =~ s/^!deop //;
			if ($who)
			{
				print "deop'ing Minion: $who\n";
			}
			else
			{
				$who = $master;
				print "deop'ing Master: $who\n";
			}
			$irc->yield( mode => $channel => "-o $who" );
		}
		elsif ($what =~ /^!md5/)
		{
			my $file = $what;
			$file =~ s/^!md5 //;
			my $md5sum = md5sum($file);
			$irc->yield( privmsg => $channel => "$md5sum" );
		}
	}
	else
	{
		# public (non-master) triggers
		
		if ($what =~ /^!bitly/)
		{
			# DEPRECATED - saved for simple API calls via LWP example.
			my $bitly_api_login;
			my $bitly_api_key;

			my $url = $what;

			$url =~ s/^!bitly //;

			my $url_bitly;

			my $api_src = "http://api.bit.ly/shorten?version=2.0.1&longUrl=".$url."&login=".$bitly_api_login."&apiKey=".$bitly_api_key;
			
			my $response = $lwp->get($api_src);
			
			if ($response->is_success)
			{
				my $raw_data = $response->decoded_content;
			
				foreach my $line (split(/\n/,$raw_data))
				{
					if ($line =~ m/shortURL/i)
					{
						$line =~ s/\"//g;
						$line =~ s/,//g;
				
						my ($var,$url_bitly) = split(/:/,$line,2);
			
						$url_bitly =~ s/ //g;
						$url_bitly =~ s/\t//g;
			
						#print "url: $url\nbitly: $url_bitly\n";
						$irc->yield( privmsg => $channel => "$nick (URL=SUCCESS): $url_bitly" );
						$irc->yield( privmsg => $channel => "$line" );
			
						last;
					}
				}
				print "Transformed $url to $url_bitly\n";
			}
			else
			{
				print "An error occurred while making the HTTP Request: $response->errstr\n";
				$irc->yield( privmsg => $channel => "$nick (URL=FAIL): $response->errstr" );
			}
		}
		elsif ($what =~ /^!say/)
		{
			my $say = $what;
			$say =~ s/^!say //;
			$irc->yield( privmsg => $channel => "$say" );
		}
	}

	# all user accessible triggers
	if ($what =~ /http/)
	{
		my ($uri) = $what =~ /$RE{URI}{-keep}/;

		if ($uri)
		{
				$irc->yield( privmsg => $channel =>  pQuery->get($uri)->title );
		}

	}
	if ($what =~ /^!addquote/)
	{
	   $what =~ s/!addquote //g;
	   $who =~ s/\!.*//g;
	   add_quote($what);
	   $irc->yield( privmsg => $channel => "Quote added. Thank you, $who." );
	}
	if ($what =~ /^!quote/)
	{
		my $quote = read_quote();
		$irc->yield( privmsg => $channel => "$quote" );
	}
	if ($what =~ /^!eat/)
	{
	   $what =~ s/!eat //g;
	   $who =~ s/\!.*//g;
	   add_food($what);
	   $irc->yield( privmsg => $channel => "Food added. Thank you, $who." );
	}
	if ($what =~ /^!f00d/)
	{
		my $quote = read_food();
		$irc->yield( privmsg => $channel => "$quote" );
	}
	if ($what =~ /^!dadjoke/)
	{
		my $quote = read_dadjoke();
		$irc->yield( privmsg => $channel => "$quote" );
	}
	if ($what =~ /$nickname/)
	{
		# AI testing with Eliza
		$what =~ s/$nickname//;
		my $reply = $eliza->transform($what);
		$irc->yield( privmsg => $channel => "$nick: $reply" );
	}
	if ($what =~ /^!m00say/)
	{
				my $say = $what;
				$say =~ s/^!m00say //;
		my $cowsay = `cowsay $say`;
		$irc->yield( privmsg => $channel => "$cowsay" );
	}
	if ($what =~ /^!fortune/)
	{
		my $fortune = `fortune`;
		$irc->yield( privmsg => $channel => "$fortune" );
	}
	if ($what =~ /^!urban/)
	{
		$what =~ s/!urban //g;
		my $urbanlookup = "https://www.urbandictionary.com/define.php?term=". $what;
		my $dom = pQuery->get($urbanlookup)->content;
		my $return = pQuery->get($urbanlookup)->title;
		my $x=0;
		pQuery('div.meaning', $dom)->each(sub {
			my $i = shift;
			($x < 1) ? $return .= ": ". pQuery($_)->text() : last;
			$x++;
		});
		$irc->yield( privmsg => $channel => "$return" );
	}
	return;
}

sub add_quote
{
    my ($quote) = @_;
    open(QUOTES, '>>', $fquotes) or print "Error opening $fquotes file.";
    print QUOTES $quote."\n";
    close(QUOTES);
}

sub read_quote
{
    open(QUOTES, '<', $fquotes) or print "Error opening $fquotes file.";
    rand($.)<1 and ($line=$_) while <QUOTES>;
    close(QUOTES);
    return $line;
}

sub add_food
{
    my ($quote) = @_;
    open(QUOTES, '>>', $ff00d) or print "Error opening $ff00d file.";
    print QUOTES $quote."\n";
    close(QUOTES);
}

sub read_food
{
    open(QUOTES, '<', $ff00d) or print "Error opening $ff00d file.";
    rand($.)<1 and ($line=$_) while <QUOTES>;
    close(QUOTES);
    return $line;
}

sub read_dadjoke
{
    open(QUOTES, '<', $fdadjokes) or print "Error opening $fdadjokes file.";
    rand($.)<1 and ($line=$_) while <QUOTES>;
    close(QUOTES);
    return $line;
}
# this routine returns the md5sum of a specified file.
sub md5sum
{
	#my $this = shift;
	my ($file) = @_;

	if (-e $file)
	{
		open(FILE, $file) or die "Can't open '$file': $!";
		binmode(FILE);
		while (<FILE>) 
		{ 
			$md5->add($_);
		}
		close(FILE);
		return $md5->b64digest;
	}
	else
	{
		return "error: file not found. ($file)";
	}
}

# perform MD5sum check to compare feed data between the 
# most recent and current XML data for the selected feed.
sub md5checksum
{
	my $this = shift;
	my ($file1,$file2) = @_;

	if (((-e $file1) && (-e $file2)) && ($this->md5sum($file1) eq $this->md5sum($file2)))
	{
		return 1;
	}
	else
	{
		return 0;
	}
}

sub db_conn
{
		my $db = DBI->connect($db_dsn, $db_user, $db_pass) 
			or return 'Connection Error: $DBI::err($DBI::errstr)';
		return $db;
}

sub db_disconn
{
		# my $db_conn = shift;
		$db_conn->disconnect();
}

sub db_query
{
	# my ($db_conn,$sql) = @_;
	my $sql = shift;
	
	if ($sql)
	{
		my $db_query = $db_conn->prepare($sql) 
			or return 'SQL Error: $DBI::err($DBI::errstr)';
		$db_query->execute() 
			or return 'Query Error: $DBI::err($DBI::errstr)';
		$db_query->finish();
	}
	return;
}

#######
#
# end subroutines
#
#######
