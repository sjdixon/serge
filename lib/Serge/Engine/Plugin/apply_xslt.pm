package Serge::Engine::Plugin::apply_xslt;
use parent Serge::Engine::Plugin::if;

use XML::LibXSLT;
use XML::LibXML;
use strict;
use utf8;

no warnings qw(uninitialized);

use Encode qw(decode_utf8);
use Serge::Util qw(subst_macros_strref);

sub name {
    return 'Generic xslt (https://www.w3.org/Style/XSL/) replacement plugin';
}

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->merge_schema({
        apply => {'' => 'LIST',
            '*'        => 'STRING'
        },
        if => {
            '*' => {
                then => {
                    apply => {'' => 'LIST',
                        '*'        => 'STRING'
                    },
                },
            },
        },
    });

    $self->add({
        after_load_file => \&check,
        before_save_localized_file => \&check,
    });

    $self->{stylesheets} = {};
}

sub validate_data {
    my ($self) = @_;

    $self->SUPER::validate_data;

    die "'apply' parameter is not specified and no 'if' blocks found" if !exists $self->{data}->{if} && !$self->{data}->{apply};

    if (exists $self->{data}->{if}) {
        foreach my $block (@{$self->{data}->{if}}) {
            die "'replace' parameter is not specified inside if/then block" if !$block->{then}->{apply};
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

    my $source = $parser->parse_string($$strref);

    my $apply_list = $block->{apply};
    foreach my $apply (@$apply_list) {

        if (not exists $self->{stylesheets}{$apply})
        {
            my $xslt = XML::LibXSLT->new();

            my $style_doc = $parser->parse_file($apply);
            my $stylesheet = $xslt->parse_stylesheet($style_doc);

            $self->{stylesheets}{$apply} = $stylesheet;
        }

        my $stylesheet = $self->{stylesheets}{$apply};

        $source = $stylesheet->transform($source);

        my $source_as_string = $stylesheet->output_string($source);

        $source_as_string = decode_utf8($source_as_string);

        $$strref = $source_as_string;
    }

    return (shift @_)->SUPER::process_then_block(@_);
}

sub check {
    my $self = shift;
    return $self->SUPER::check(@_);
}

1;