package Directory::Monitor;

use 5.16.3;

use strict;
use warnings;

use Params::Validate qw/:all/;
use Const::Fast;
use Path::Tiny;
use Try::Tiny;

const my $ON_CREATE => 'oncreate';
const my $ON_DELETE => 'ondelete';
const my $ON_UPDATE => 'onupdate';
const my $ON_ANY    => 'all';

sub new {
    my $class  = shift;
    my %params = validate_with(
        params => \@_,
        spec   => {
            directory => { type => SCALAR },
        },
    );
    my $self      = bless {}, $class;
    my $directory = $params{directory};
    $self->_SetDirectory( directory => $directory );
    $self->_CreateEvents( events => [ $ON_CREATE, $ON_DELETE, $ON_UPDATE ] );
    return $self;
}

sub StartMonitor {
    my $self      = shift;
    my $directory = $self->{directory};
    $self->{know_files} = {};
    $self->Scan( without_trigger => 1, directory => $directory );
    while (1) {
        my $old_know_files = $self->{know_files};
        $self->{know_files} = {};
        $self->Scan( directory => $directory );
        for ( keys %$old_know_files ) {
            if ( !exists $self->{know_files}{$_} ) {
                $self->_EventActivation(
                    event           => $ON_DELETE,
                    callback_params => [
                        event        => $ON_DELETE,
                        file_name    => $_,
                        old_checksum => undef,
                        checksum     => undef,
                    ]
                );
            }
        }
    }
}

sub Scan {
    my $self   = shift;
    my %params = validate_with(
        params => \@_,
        spec   => {
            directory       => { type => SCALAR },
            without_trigger => { type => BOOLEAN, optional => 1 },
        },
    );
    my $directory       = $params{directory};
    my $without_trigger = $params{without_trigger};
    my @files           = path($directory)->children;
    for my $file (@files) {
        if ( $file->is_file ) {
            my $digest;
            next unless try {
                $digest = $file->digest('MD5');
                1;
            }
            catch {
                0;
            };
            if ( !$without_trigger ) {
                if ( !exists $self->{db_files}{"$file"} ) {
                    $self->_EventActivation(
                        event           => $ON_CREATE,
                        callback_params => [
                            event        => $ON_CREATE,
                            file_name    => "$file",
                            old_checksum => undef,
                            checksum     => $digest,
                        ]
                    );
                }
                else {
                    $self->_EventActivation(
                        event           => $ON_UPDATE,
                        callback_params => [
                            event        => $ON_UPDATE,
                            file_name    => "$file",
                            old_checksum => $self->{db_files}{"$file"},
                            checksum     => $digest,
                        ]
                    ) if $self->{db_files}{"$file"} ne $digest;
                }
            }
            $self->{db_files}{"$file"} = $digest;
        }
        elsif ( $file->is_dir ) {
            $self->Scan(
                directory       => "$file",
                without_trigger => $without_trigger,
            );
        }
        $self->{know_files}{$file} = undef;
    }
}

sub _SetDirectory {
    my $self   = shift;
    my %params = validate_with(
        params => \@_,
        spec   => {
            directory => { type => SCALAR },
        }
    );
    my $directory = $params{directory};
    -e $directory or die "No such file: $directory";
    -d $directory or die "$directory is not a folder";
    $self->{directory} = $directory;
}

sub _CreateEvents {
    my $self   = shift;
    my %params = validate_with(
        params => \@_,
        spec   => {
            events => { type => ARRAYREF },
        }
    );
    my $events = $params{events};
    for my $event (@$events) {
        $self->{events}{$event} //= [];
    }
}

sub GetEvents {
    my $self = shift;
    return $self->{events};
}

sub _EventActivation {
    my $self   = shift;
    my %params = validate_with(
        params => \@_,
        spec   => {
            event           => { type => SCALAR, },
            callback_params => { type => ARRAYREF, },
        }
    );
    my $event           = $params{event};
    my $callback_params = $params{callback_params};
    my $callbacks_array = $self->GetEvents->{$event};
    for my $callback (@$callbacks_array) {
        $callback->(@$callback_params);
    }
}

sub AddEventListener {
    my $self   = shift;
    my %params = validate_with(
        params => \@_,
        spec   => {
            event    => { type => SCALAR },
            callback => { type => CODEREF },
        }
    );
    my $event       = $params{event};
    my $callback    = $params{callback};
    my $events_hash = $self->GetEvents;
    if ( $event eq $ON_ANY ) {
        for my $key ( keys %{$events_hash} ) {
            push @{ $events_hash->{$key} }, $callback;
        }
        return;
    }
    exists $self->GetEvents->{$event} or die "No such event";
    push @{ $self->GetEvents->{$event} }, $callback;
}
1;

__END__

=encoding utf-8

=head1 NAME

Directory::Monitor - It is a event driven library made to be able to monitor directories seeking for changes and
do things with that changes.

=head1 SYNOPSIS

    use 5.16.3;

    use Directory::Monitor;

    my $monitor = Directory::Monitor->new(directory => 'a');
    $monitor->AddEventListener( 
        event => 'onupdate',
        callback => sub {
            my %params = @_;
            my $old_checksum = $params{old_checksum};
            my $checksum = $params{checksum};
            my $file_name = $params{file_name};
            say "Updated $file_name with new checksum: '$checksum' and old checksum '$old_checksum'";
        }
    );
    $monitor->StartMonitor;

=head1 DESCRIPTION

Directory::Monitor allows you to monitor a directory and execute code when a file is changed, deleted or created.

=cut

=head2 Available events.

There are four available events: B<oncreate>, B<ondelete>, B<onupdate> and B<all>.

=cut

=head1 LICENSE

Copyright © Sergio Iglesias.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

=head1 AUTHOR

Sergio Iglesias sergiotarxz at github.

=cut

