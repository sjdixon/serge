package Serge::Engine::Plugin::serialize_xliff2;
use parent Serge::Engine::Plugin::Base::Serializer;

use strict;

use Unicode::Normalize;

use Serge;
use Serge::Util;
use Serge::Util qw(xml_escape_strref xml_unescape_strref generate_hash);
use XML::Twig;
use XML::Tidy;

sub name {
    return '.XLIFF 2.0 Serializer';
}

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->merge_schema({
        use_hint_for_name => 'BOOLEAN',
        context_strategy => 'STRING',
        valid_states => 'STRING',
        file_datatype => 'STRING',
        state_translated => 'STRING',
        state_translated_fuzzy => 'STRING',
        sub_state_fuzzy => 'STRING',
        state_untranslated => 'STRING',
        no_target_for_untranslated => 'BOOLEAN'
    });
}

sub validate_data {
    my $self = shift;

    $self->SUPER::validate_data;

    $self->{data}->{use_hint_for_name} = 1 unless defined $self->{data}->{use_hint_for_name};

    $self->{data}->{file_datatype} = 'x-unknown' unless defined $self->{data}->{file_datatype};

    $self->{data}->{context_strategy} = 'metadata' unless defined $self->{data}->{context_strategy};

    if (($self->{data}->{context_strategy} ne 'metadata') and ($self->{data}->{context_strategy} ne 'name')) {
        die "'context_strategy', which is set to $self->{data}->{context_strategy}, is not one of the valid options: 'metadata' or 'name'";
    }

    $self->{data}->{state_translated} = 'translated' unless defined $self->{data}->{state_translated};

    $self->{data}->{state_translated_fuzzy} = $self->{data}->{state_translated} unless defined $self->{data}->{state_translated_fuzzy};

    $self->{data}->{state_untranslated} = 'initial' unless defined $self->{data}->{state_untranslated};

    $self->{data}->{sub_state_fuzzy} = 'srg:fuzzy' unless defined $self->{data}->{sub_state_fuzzy};

    $self->{data}->{no_target_for_untranslated} = 1 unless defined $self->{data}->{no_target_for_untranslated};
}

sub serialize {
    my ($self, $units, $file, $lang) = @_;

    my $use_hint_for_name = $self->{data}->{use_hint_for_name};

    my $source_lang = $self->{parent}->{source_language};

    my $source_locale = locale_from_lang($source_lang);
    my $target_locale = locale_from_lang($lang);

    my $root_element = XML::Twig::Elt->new('xliff', {
            'xmlns' => 'urn:oasis:names:tc:xliff:document:2.0',
            'xmlns:mda' => 'urn:oasis:names:tc:xliff:metadata:2.0',
            version => '2.0',
            srcLang => $source_locale,
            trgLang => $target_locale
        });

    my $file_id = generate_hash($file);
    my $file_element = $root_element->insert_new_elt('file' => {original => $file, 'id' => $file_id}, '');

    my @reversed_units = reverse(@$units);

    foreach my $unit (@reversed_units) {
        my $key = $unit->{key};

        my $unit_element = $file_element->insert_new_elt(unit => {'id' => $key}, '');

        my $segment_element = $unit_element->insert_new_elt(segment => {}, '');

        my $dev_comment = $unit->{hint};

        if ($dev_comment ne '') {
            my @dev_comment_lines = split('\n', $dev_comment);

            my $dev_comment_lines_size = 0;

            if ($use_hint_for_name and ($self->{data}->{context_strategy} eq 'metadata')) {
                my $name = $dev_comment_lines[0];

                $unit_element->set_att(name => $name);

                $dev_comment_lines_size = scalar @dev_comment_lines;

                if ($dev_comment_lines_size > 1) {
                    shift(@dev_comment_lines);
                }
                else {
                    @dev_comment_lines = \();
                }
            }

            $dev_comment_lines_size = scalar @dev_comment_lines;

            if ($dev_comment_lines_size > 0) {
                my $notes_element = $unit_element->insert_new_elt('notes' => {}, '');

                foreach my $dev_comment_line (reverse(@dev_comment_lines)) {
                    $notes_element->insert_new_elt('note' => {category => 'developer'}, $dev_comment_line);
                }
            }
        }

        my $state = '';

        if ($source_lang ne $lang) {
            if ($unit->{target} ne '') {
                $state = $unit->{fuzzy} ? $self->{data}->{state_translated_fuzzy} : $self->{data}->{state_translated};
            } else {
                $state = $self->{data}->{state_untranslated};
            }
        }

        if ($unit->{target} eq '' and $self->{data}->{no_target_for_untranslated}) {
        } else {
            $segment_element->insert_new_elt('target' => {'xml:lang' => $target_locale}, $unit->{target});
        }

        if ($state ne '') {
            $segment_element->set_att('state' => $state);

            if ($unit->{fuzzy}) {
                $segment_element->set_att('subState' => $self->{data}->{sub_state_fuzzy});
            }
        }

        $segment_element->insert_new_elt('source' => {'xml:lang' => $source_locale}, $unit->{source});

        if ($unit->{context} ne '') {
            if ($self->{data}->{context_strategy} eq 'name') {
                $unit_element->set_att(name => $unit->{context});
            } elsif ($self->{data}->{context_strategy} eq 'metadata') {
                my $metadata_element = $unit_element->insert_new_elt('mda:metadata' => {}, '');
                my $metagroup_element = $metadata_element->insert_new_elt('mda:metaGroup' => {category => 'serge_io'}, '');
                $metagroup_element->insert_new_elt('mda:meta' => {type => 'context'}, $unit->{context});
            }
        }
    }

    my $tidy_obj = XML::Tidy->new('xml' => $root_element->sprint);

    $tidy_obj->tidy('    ');

    return $tidy_obj->toString();
}

sub deserialize {
    my ($self, $textref) = @_;

    my @valid_states = \();

    if ($self->{data}->{valid_states} ne '') {
        @valid_states = split(' ', $self->{data}->{valid_states}); # final
    }

    my @units;

    my $tree;
    eval {
        $tree = XML::Twig->new(map_xmlns => {'urn:oasis:names:tc:xliff:metadata:2.0' => "mda"})->parse($$textref);
        $tree->set_indent(' ' x 4);
    };
    if ($@) {
        my $error_text = $@;
        $error_text =~ s/\t/ /g;
        $error_text =~ s/^\s+//s;

        die $error_text;
    }

    my $version = $tree->root->att('version');
    die "Unsupported XLIFF version: '$version'" unless '2.0' eq $version;

    my @unit_elements = $tree->findnodes('//unit');
    foreach my $unit_element (@unit_elements) {
        my $key = $unit_element->att('id');;
        my $context = '';
        my $comment = '';

        my $segment_element = $unit_element->first_child('segment');

        if (not defined $segment_element) {
            print "\t\t? [missing segment] for $key\n";

            next;
        }

        $comment .= $self->get_comment($unit_element->first_child('notes'));

        my $source_element = $segment_element->first_child('source');
        my $target_element = $segment_element->first_child('target');

        my @flags = \();
        my $state = $segment_element->att('state');
        my $sub_state = $segment_element->att('subState');
        my $target = '';

        if ($target_element) {
            $target = $target_element->text;
        } else {
            print "\t\t? [missing target] for $key\n";
        }

        my $source = '';

        if ($source_element) {
            $source = $source_element->text;
        }

        if ($self->{data}->{context_strategy} eq 'name') {
            $context = $unit_element->att('name');
        }  elsif ($self->{data}->{context_strategy} eq 'metadata') {
            my $metadata_element = $unit_element->first_child('mda:metadata');
            my $metagroup_element;
            my $meta_element;

            if (defined $metadata_element) {
                $metagroup_element = $metadata_element->first_child("mda:metaGroup[\@category='serge_io']");
            }

            if (defined $metagroup_element) {
                $meta_element = $metagroup_element->first_child("mda:meta[\@type='context']");
            }

            if (defined $meta_element) {
                $context = $meta_element->text;
            }
        }

        if ($key eq '') {
            print "\t\t? [empty key]\n";
            next;
        }

        if ($key ne generate_key($source, $context)) {
            print "\t\t? [bad key] $key for context $context\n";

            next;
        }

        my $fuzzy = ($state eq $self->{data}->{state_translated_fuzzy}) and ($sub_state eq $self->{data}->{sub_state_fuzzy});

        if ($state ne '' and @valid_states) {
            my $is_valid_state = $state ~~ @valid_states;

            if (not $is_valid_state) {
                print "\t\t? [invalid state] for $key for with state $state\n";
                $target = '';
            }
        }

        next unless ($target or $comment);

        push @units, {
                key => $key,
                source => $source,
                context => $context,
                target => $target,
                comment => $comment,
                fuzzy => $fuzzy,
                flags => @flags,
            };
    }

    return \@units;
}

sub get_comment {
    my ($self, $node) = @_;

    return '' unless defined $node;

    my $note_node = $node->first_child('note');

    my @notes;

    if (defined $note_node) {
        map {
            push @notes, $_->text;
        } $node->children('note');
    }

    return join('\n', @notes);
}


1;