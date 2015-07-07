#!/usr/bin/env perl
#
use warnings;
use strict;

open( my $cmd, '-|' , 'openssl rand 16 -hex' ) or die 'cannot invoke openssl command';

my $salt = <$cmd>;

chomp $salt;

$salt = '$6$'.$salt;

print STDERR "Please enter a password: ";
my $password = <STDIN>;
chomp $password;

print crypt($password,$salt)."\n";
