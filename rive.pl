#!/usr/bin/env perl
use strict;

use RiveScript;

# Create a new RiveScript interpreter.
my $rs = new RiveScript;

# Load a directory of replies.
#$rs->loadDirectory ("./replies");

# Load another file.
#$rs->loadFile ("./more_replies.rive");

# Stream in some RiveScript code.
$rs->stream (q~
    + hello bot
    - Hello, human.

    + hey there
    - hi there.
~);

# Sort all the loaded replies.
$rs->sortReplies;

# Chat with the bot.
while (1)
{
    print "You> ";
    chomp (my $msg = <STDIN>);

    my $reply = $rs->reply ('localuser',$msg);
    print "Bot> $reply\n";
}

