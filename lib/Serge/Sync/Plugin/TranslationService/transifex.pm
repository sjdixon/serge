package Serge::Sync::Plugin::TranslationService::transifex;
use parent Serge::Sync::Plugin::Base::TranslationService, Serge::Interface::SysCmdRunner;

use strict;

use Serge::Util qw(subst_macros);

sub name {
    return 'Transifex translation server (https://www.transifex.com) synchronization plugin';
}

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->{optimizations} = 1; # set to undef to disable optimizations
}

sub validate_data {
    my ($self) = @_;

    $self->SUPER::validate_data;
}

sub run_transifex_cli {
    my ($self, $action, $langs, $capture) = @_;

    my $command = $action;

    $command = 'tx '.$command;
    print "Running '$command'...\n";
    return $self->run_cmd($command, $capture);
}

sub pull_ts {
    my ($self, $langs) = @_;

    return $self->run_transifex_cli('pull', $langs);
}

sub push_ts {
    my ($self, $langs) = @_;

    $self->run_transifex_cli('push -s', $langs);
}

1;