#!/usr/bin/env perl

use 5.16.3;

use strict;
use warnings;

use Directory::Monitor;

my $directory_monitor = Directory::Monitor->new( directory => $ENV{HOME}.'/ahora' );
$directory_monitor->AddEventListener(
    event    => 'all',
    callback => sub {
        my %params = @_;
        my $file   = $params{file_name};
        my $event  = $params{event};
        say $event=~ s/^on//r . " " . $file;
    }
);
$directory_monitor->StartMonitor;

