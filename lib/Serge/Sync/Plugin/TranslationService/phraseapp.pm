package Serge::Sync::Plugin::TranslationService::phraseapp;
use parent Serge::Sync::Plugin::Base::TranslationService, Serge::Interface::SysCmdRunner;

use strict;

use Serge::Util qw(subst_macros);

sub name {
    return 'PhraseApp translation server (https://phraseapp.com) synchronization plugin';
}

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->{optimizations} = 1; # set to undef to disable optimizations
}

sub run_phraseapp_cmd {
    my ($self, $action, $langs, $capture) = @_;

    my $command = $action;

    $command = 'phraseapp '.$command;
    print "Running '$command'...\n";
    return $self->run_cmd($command, $capture);
}

sub pull_ts {
    my ($self, $langs) = @_;

    return $self->run_phraseapp_cmd('pull', $langs);
}

sub push_ts {
    my ($self, $langs) = @_;

    $self->run_phraseapp_cmd('push', $langs);
}

1;