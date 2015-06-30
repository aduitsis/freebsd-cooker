#!/usr/bin/env perl
#
use warnings;
use strict;

print "Please enter salt (no \$'s, just a random string): ";
my $salt = '$6$'.<STDIN>;

print "Now please enter a password: ";
my $password = <STDIN>;

print crypt($password,$salt)."\n";
