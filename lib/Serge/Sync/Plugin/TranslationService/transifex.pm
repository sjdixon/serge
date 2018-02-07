package Serge::Sync::Plugin::TranslationService::transifex;
use parent Serge::Sync::Plugin::Base::TranslationService, Serge::Interface::SysCmdRunner;

use strict;

use File::chdir;
use Serge::Util qw(subst_macros);

sub name {
    return 'Transifex translation server (https://www.transifex.com) synchronization plugin';
}

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->{optimizations} = 1; # set to undef to disable optimizations

    $self->merge_schema({
        root_directory => 'STRING',
        push_translations => 'BOOLEAN'
    });
}

sub validate_data {
    my ($self) = @_;

    $self->SUPER::validate_data;

    $self->{data}->{root_directory} = subst_macros($self->{data}->{root_directory});
    $self->{data}->{push_translations} = subst_macros($self->{data}->{push_translations});

    die "'root_directory' not defined" unless defined $self->{data}->{root_directory};
    die "'root_directory', which is set to '$self->{data}->{root_directory}', does not point to a valid file.\n" unless -d $self->{data}->{root_directory};

    $self->{data}->{push_translations} = 1 unless defined $self->{data}->{push_translations};
}

sub run_transifex_cli {
    my ($self, $action, $langs, $capture) = @_;

    my $cli_return = 0;

    my $command = $action;

    $command .= ' --root '.$self->{data}->{root_directory};

    $command = 'tx '.$command;
    print "Running '$command'...\n";

    $cli_return = $self->run_cmd($command, $capture);

    return $cli_return;
}

sub pull_ts {
    my ($self, $langs) = @_;

    return $self->run_transifex_cli('pull', $langs);
}

sub push_ts {
    my ($self, $langs) = @_;

    my $cli_return = 0;

    if ($self->{data}->{push_translations}) {
        $cli_return = $self->run_transifex_cli('push --source --translations', $langs);
    } else {
        $cli_return = $self->run_transifex_cli('push --source', $langs);
    }

    return $cli_return;
}

1;