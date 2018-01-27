package Serge::Sync::Plugin::TranslationService::mojito;
use parent Serge::Sync::Plugin::Base::TranslationService, Serge::Interface::SysCmdRunner;

use strict;

use Serge::Util qw(subst_macros);

sub name {
    return 'Mojito translation server (http://www.mojito.global/) synchronization plugin';
}

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->{optimizations} = 1;

    $self->merge_schema({
        project_id     => 'STRING',
        application_properties => 'STRING',
        source_files_path => 'STRING',
        localized_files_path => 'STRING',
        import_translations => 'BOOLEAN'
    });
}

sub validate_data {
    my ($self) = @_;

    $self->SUPER::validate_data;

    $self->{data}->{application_properties} = subst_macros($self->{data}->{application_properties});
    $self->{data}->{project_id} = subst_macros($self->{data}->{project_id});
    $self->{data}->{source_files_path} = subst_macros($self->{data}->{source_files_path});
    $self->{data}->{localized_files_path} = subst_macros($self->{data}->{localized_files_path});
    $self->{data}->{import_translations} = subst_macros($self->{data}->{import_translations});

    die "'project_id' not defined" unless defined $self->{data}->{project_id};

    if ($self->{data}->{application_properties} ne '') {
        die "'application_properties', which is set to '$self->{data}->{application_properties}', does not point to a valid file.\n" unless -f $self->{data}->{application_properties};
    }

    die "'source_files_path' not defined" unless defined $self->{data}->{source_files_path};
    die "'source_files_path', which is set to '$self->{data}->{source_files_path}', does not point to a valid directory.\n" unless -d $self->{data}->{source_files_path};

    die "'localized_files_path' not defined" unless defined $self->{data}->{localized_files_path};
    die "'localized_files_path', which is set to '$self->{data}->{localized_files_path}', does not point to a valid directory.\n" unless -d $self->{data}->{localized_files_path};

    $self->{data}->{import_translations} = 1 unless defined $self->{data}->{import_translations};
}

sub run_mojito_cli {
    my ($self, $action, $langs, $capture) = @_;

    my $command = $action;

    $command .= ' -r '.$self->{data}->{project_id};
    $command .= ' -s '.$self->{data}->{source_files_path};
    if ($self->{data}->{application_properties} ne '') {
        $command .= ' --spring.config.location='.$self->{data}->{application_properties};
    }

    $command = 'mojito '.$command;
    print "Running '$command'...\n";

    return $self->run_cmd($command, $capture);
}

sub pull_ts {
    my ($self, $langs) = @_;

    my $action = 'pull -t '.$self->{data}->{localized_files_path};

    return $self->run_mojito_cli($action, $langs);
}

sub push_ts {
    my ($self, $langs) = @_;

    my $cli_return = $self->run_mojito_cli('push', ());

    if ($cli_return != 0) {
        return $cli_return;
    }

    if ($self->{data}->{import_translations}) {
        my $action = 'import -t '.$self->{data}->{localized_files_path};

        $cli_return = $self->run_mojito_cli($action, $langs);
    }

    return $cli_return;
}

1;