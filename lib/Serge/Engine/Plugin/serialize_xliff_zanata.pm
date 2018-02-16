package Serge::Engine::Plugin::serialize_xliff_zanata;
use parent Serge::Engine::Plugin::Base::Serializer;

use strict;

use Unicode::Normalize;

use Serge;
use Serge::Util;
use Serge::Util qw(xml_escape_strref xml_unescape_strref);
use XML::Twig;
use XML::Tidy;

sub name {
    return 'Zanata .XLIFF 1.1 Serializer';
}

sub serialize {
    my ($self, $units, $file, $lang) = @_;

    my $locale = locale_from_lang($lang);

    my $root_element = XML::Twig::Elt->new('xliff', {
            'xmlns' => "urn:oasis:names:tc:xliff:document:1.1",
            version => "1.1",
        });

    my $file_element = $root_element->insert_new_elt('file' => {original => $file, 'source-language' => 'en', 'target-language' => $locale, datatype => 'x-undefined'}, '');

    my $body_element = $file_element->insert_new_elt('body');

    my @reversed_units = reverse(@$units);

    foreach my $unit (@reversed_units) {
        my $key = $unit->{key};

        if ($unit->{context} ne '') {
            $key .= ':'.$unit->{context};
        }

        my $unit_element = $body_element->insert_new_elt('trans-unit' => {id => $key}, '');

        my $context_group_element;

        my $dev_comment = $unit->{hint};

        if ($dev_comment ne '') {
            $context_group_element = $unit_element->insert_new_elt('context-group' => {name => 'main'}, '');

            $context_group_element->insert_new_elt('context' => { 'context-type' => 'x-note' }, $dev_comment);
        }

        my $target_element = $unit_element->insert_new_elt('target' => {'xml:lang' => $locale}, $unit->{target});

        my $state = '';

        if ($unit->{target} ne '') {
            $state = 'translated';
        } else {
            $state = 'new';
        }

        if ($state ne '') {
            $target_element->set_att('state' => $state);
        }

        $unit_element->insert_new_elt('source' => {'xml:lang' => 'en'}, $unit->{source});
    }

    my $tidy_obj = XML::Tidy->new('xml' => $root_element->sprint);

    $tidy_obj->tidy('    ');

    return $tidy_obj->toString();
}

sub deserialize {
    my ($self, $textref) = @_;

    my @units;

    my $tree;
    eval {
        $tree = XML::Twig->new()->parse($$textref);
        $tree->set_indent(' ' x 4);
    };
    if ($@) {
        my $error_text = $@;
        $error_text =~ s/\t/ /g;
        $error_text =~ s/^\s+//s;

        die $error_text;
    }

    my $version = $tree->root->att('version');
    ($version =~ m/^(\d+)/) && ($version = $1);

    die "Unsupported XLIFF version: '$version'" unless $version eq 1;

    my @tran_units = $tree->findnodes('//trans-unit');
    foreach my $tran_unit (@tran_units) {
        my $context_group_element = $tran_unit->first_child('context-group');

        my $comment = '';
        my $context = '';

        if (defined $context_group_element) {
            my @note_units = $context_group_element->findnodes("//context[\@context-type='x-note']");

            if (@note_units) {
                $comment = $note_units[0];
            }
        }

        my $target = $tran_unit->first_child('target');

        # sanity check: the extracted key should match the generated one for given string/context

        my @id_parts = split(/:/, $tran_unit->att('id'));

        my $key = shift @id_parts;

        my $id_parts_size = scalar @id_parts;

        if ($id_parts_size > 0) {
            $context = join(':', @id_parts);
        }

        my $source = $tran_unit->first_child('source')->text;

        if ($key ne generate_key($source, $context)) {
            print "\t\t? [bad key] $key for context $context\n";
            next;
        }

        push @units, {
                key => $key,
                source => $source,
                context => $context,
                target => $target->text,
                comment => $comment,
                fuzzy => 0,
                flags => \(),
            };
    }

    return \@units;
}

1;