package Serge::Sync::Plugin::TranslationService::zanata;
use parent Serge::Sync::Plugin::Base::TranslationService, Serge::Interface::SysCmdRunner;

use strict;

use Serge::Util qw(subst_macros);

sub name {
    return 'Zanata translation server (http://zanata.org/) synchronization plugin';
}

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->{optimizations} = 1;
}

sub run_zanata_cli {
    my ($self, $action, $langs, $capture) = @_;

    my $command = $action;

    $command = 'zanata-cli '.$command;
    print "Running '$command'...\n";
    return $self->run_cmd($command, $capture);
}

sub pull_ts {
    my ($self, $langs) = @_;

    return $self->run_zanata_cli('pull', $langs);
}

sub push_ts {
    my ($self, $langs) = @_;

    $self->run_zanata_cli('push --push-type source', ());
}

1;