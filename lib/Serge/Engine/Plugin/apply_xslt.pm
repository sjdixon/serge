package Serge::Engine::Plugin::apply_xslt;
use parent Serge::Engine::Plugin::if;

use XML::LibXSLT;
use XML::LibXML;
use strict;

no warnings qw(uninitialized);

use Serge::Util qw(subst_macros_strref);

sub name {
    return 'Generic xslt (https://www.w3.org/Style/XSL/) replacement plugin';
}

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->merge_schema({
        xslt              => 'STRING',
        if => {
            '*' => {
                then => {
                    xslt              => 'STRING'
                },
            },
        },
    });

    $self->add({
        after_load_file => \&check,
        before_save_localized_file => \&check,
    });
}

sub validate_data {
    my ($self) = @_;

    $self->SUPER::validate_data;

    die "'xslt' not defined" unless defined $self->{data}->{xslt};
    die "'xslt', which is set to '$self->{data}->{xslt}', does not point to a valid file.\n" unless -f $self->{data}->{xslt};

    if (exists $self->{data}->{if}) {
        foreach my $block (@{$self->{data}->{if}}) {
            die "'xslt' parameter is not specified inside if/then block" unless defined $block->{then}->{xslt};
            die "'xslt', inside if/then block, which is set to '$self->{data}->{xslt}', does not point to a valid file.\n" unless -f $block->{then}->{xslt};
        }
    }
}

sub adjust_phases {
    my ($self, $phases) = @_;

    $self->SUPER::adjust_phases($phases);

    # this plugin makes sense only when applied to a single phase
    # (in addition to 'before_job' phase inherited from Serge::Engine::Plugin::if plugin)
    die "This plugin needs to be attached to only one phase at a time" unless @$phases == 2;
}

sub process_then_block {
    my ($self, $phase, $block, $file, $lang, $strref) = @_;

    #print "::process_then_block(), phase=[$phase], block=[$block], file=[$file], lang=[$lang], strref=[$strref]\n";

    my $parser = XML::LibXML->new();
    my $xslt = XML::LibXSLT->new();

    my $source = $parser->parse_string($$strref);

    my $style_doc = $parser->parse_file($block->{xslt});
    my $stylesheet = $xslt->parse_stylesheet($style_doc);

    my $results = $stylesheet->transform($source);

    $$strref = $stylesheet->output_string($results);

    return (shift @_)->SUPER::process_then_block(@_);
}

sub check {
    my $self = shift;
    return $self->SUPER::check(@_);
}

1;