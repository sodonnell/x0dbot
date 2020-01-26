# x0dbot

A simple IRC Bot written in Perl.

[![Build Status](https://travis-ci.org/sodonnell/x0dbot.svg?branch=docker)](https://travis-ci.org/sodonnell/x0dbot)

This is an old project that I started back in 2004. I've revised some of the functionality and released it to the github/open source community.

## Features

### Chatbot::Eliza Integration

This bot will respond when messaged in a channel by reading scripts from the [Chatbot::Eliza](https://metacpan.org/pod/Chatbot::Eliza) perl module.

### Channel !Triggers

#### Public User Triggers

* !dadjoke - Display a random dad joke to the channel.
* !urban (term) - Look-up Urban Dictionary Terms.
* !f00d - Display a randomly user-added food suggestion or recipe. (use the !eat trigger to added items)
* !eat (something) - Add a food suggestion or recipe to suggest to others who use the !f00d trigger.
* !quote - display a random quote.
* !addquote - add a random quote.
* !fortune - Read a random fortune using the fortune command.

#### Private Master Triggers

* !uptime - display system uptime.
* !quit - instruct the bot quit IRC.
* !join #channel - instruct the bot to join a channel.
* !part #channel - instruct the bot to leave a channel.
* !md5 file - print the md5sum of a file on the system. (use wisely)
* Bot-Op Triggers:
** !kick user - kick a user from a channel.
** !op user - op a user in a channel.
** !deop user - deop a user in a channel.
