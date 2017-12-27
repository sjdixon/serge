package Serge::Sync::Plugin::TranslationService::crowdin;
use parent Serge::Sync::Plugin::Base::TranslationService, Serge::Interface::SysCmdRunner;

use strict;

use Serge::Util qw(subst_macros);

sub name {
    return 'Crowdin service synchronization plugin';
}

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->{optimizations} = 1; 

    $self->merge_schema({
        config_file => 'STRING',
    });
}

sub validate_data {
    my ($self) = @_;

    $self->SUPER::validate_data;

    $self->{data}->{config_file} = subst_macros($self->{data}->{config_file});

    die "'config_file' not defined" unless defined $self->{data}->{config_file};
    die "'config_file', which is set to '$self->{data}->{config_file}', does not point to a valid file.\n" unless -f $self->{data}->{config_file};
}

sub run_crowdin_cli {
    my ($self, $action, $langs, $capture) = @_;

    my $command = $action;

    if ($langs) {
        foreach my $lang (sort @$langs) {
            $lang =~ s/-(\w+)$/'-'.uc($1)/e; # convert e.g. 'pt-br' to 'pt-BR'
            $command .= " -l=$lang";
        }
    }

    $command .= ' --config '.$self->{data}->{config_file};

    $command = 'crowdin '.$command;
    print "Running '$command'...\n";
    return $self->run_cmd($command, $capture);
}

sub pull_ts {
    my ($self, $langs) = @_;

    return $self->run_crowdin_cli('download', $langs);
}

sub push_ts {
    my ($self, $langs) = @_;

    $self->run_crowdin_cli('upload sources', ());
}

1;