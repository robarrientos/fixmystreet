package FixMyStreet::App::View::Web;
use base 'Catalyst::View::TT';

use strict;
use warnings;

use mySociety::Locale;
use FixMyStreet;
use Utils;

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.html',
    INCLUDE_PATH       => [
        FixMyStreet->path_to( 'templates', 'web', 'base' ),
    ],
    ENCODING       => 'utf8',
    render_die     => 1,
    expose_methods => [
        'loc', 'nget', 'tprintf', 'prettify_dt',
        'version', 'decode',
    ],
    FILTERS => {
        add_links => \&add_links,
        escape_js => \&escape_js,
        html      => \&html_filter,
        html_para => \&html_paragraph,
    },
    COMPILE_EXT => '.ttc',
    STAT_TTL    => FixMyStreet->config('STAGING_SITE') ? 1 : 86400,
);

=head1 NAME

FixMyStreet::App::View::Web - TT View for FixMyStreet::App

=head1 DESCRIPTION

TT View for FixMyStreet::App.

=cut

# Override parent function so that errors are only logged once.
sub _rendering_error {
    my ($self, $c, $err) = @_;
    my $error = qq/Couldn't render template "$err"/;
    # $c->log->error($error);
    $c->error($error);
    return 0;
}

=head2 loc

    [% loc('Some text to localize', 'Optional comment for translator') %]

Passes the text to the localisation engine for translations.

=cut

sub loc {
    my ( $self, $c, $msgid ) = @_;
    return _($msgid);
}

=head2 nget

    [% nget( 'singular', 'plural', $number ) %]

Use first or second srting depending on the number.

=cut

sub nget {
    my ( $self, $c, @args ) = @_;
    return mySociety::Locale::nget(@args);
}

=head2 tprintf

    [% tprintf( 'foo %s bar', 'insert' ) %]

sprintf (different name to avoid clash)

=cut

sub tprintf {
    my ( $self, $c, $format, @args ) = @_;
    @args = @{$args[0]} if ref $args[0] eq 'ARRAY';
    return sprintf $format, @args;
}

=head2 Utils::prettify_dt

    [% pretty = prettify_dt( $dt, $short_bool ) %]

Return a pretty version of the DateTime object.

    $short_bool = 1;     # 16:02, 29 Mar 2011
    $short_bool = 0;     # 16:02, Tuesday 29 March 2011

=cut

sub prettify_dt {
    my ( $self, $c, $epoch, $short_bool ) = @_;
    return Utils::prettify_dt( $epoch, $short_bool );
}

=head2 add_links

    [% text | add_links | html_para %]

Add some links to some text (and thus HTML-escapes the other text.

=cut

sub add_links {
    my $text = shift;
    $text =~ s/\r//g;
    $text = html_filter($text);
    $text =~ s{(https?://)([^\s]+)}{"<a href=\"$1$2\">$1" . _space_slash($2) . '</a>'}ge;
    return $text;
}

sub _space_slash {
    my $t = shift;
    $t =~ s{/(?!$)}{/ }g;
    return $t;
}

=head2 escape_js

Used to escape strings that are going to be put inside JavaScript.

=cut

sub escape_js {
    my $text = shift;
    my %lookup = (
        '\\' => 'u005c',
        '"'  => 'u0022',
        "'"  => 'u0027',
        '<'  => 'u003c',
        '>'  => 'u003e',
    );
    $text =~ s/([\\"'<>])/\\$lookup{$1}/g;

    $text =~ s/(?:\r\n|\n|\r)/\\n/g; # replace newlines

    return $text;
}

=head2 html_filter

Same as Template Toolkit's html_filter, but escapes ' too, as we don't (and
shouldn't have to) know whether we'll be used inbetween single or double
quotes.

=cut

sub html_filter {
    my $text = shift;
    for ($text) {
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
        s/"/&quot;/g;
        s/'/&#39;/g;
    }
    return $text;
}

=head2 html_paragraph

Same as Template Toolkit's html_paragraph, but converts single newlines
into <br>s too.

=cut

sub html_paragraph  {
    my $text = shift;
    my @paras = split(/(?:\r?\n){2,}/, $text);
    s/\r?\n/<br>\n/ for @paras;
    $text = "<p>\n" . join("\n</p>\n\n<p>\n", @paras) . "</p>\n";
    return $text;
}

my %version_hash;
sub version {
    my ( $self, $c, $file ) = @_;
    _version_get_mtime($file);
    if ($version_hash{$file} && $file =~ /\.js$/) {
        # See if there's an auto.min.js version and use that instead if there is
        (my $file_min = $file) =~ s/\.js$/.auto.min.js/;
        _version_get_mtime($file_min);
        $file = $file_min if $version_hash{$file_min} >= $version_hash{$file};
    }
    my $admin = $self->template->context->stash->{admin} ? FixMyStreet->config('ADMIN_BASE_URL') : '';
    return "$admin$file?$version_hash{$file}";
}

sub _version_get_mtime {
    my $file = shift;
    unless ($version_hash{$file} && !FixMyStreet->config('STAGING_SITE')) {
        my $path = FixMyStreet->path_to('web', $file);
        $version_hash{$file} = ( stat( $path ) )[9] || 0;
    }
}

sub decode {
    my ( $self, $c, $text ) = @_;
    utf8::decode($text) unless utf8::is_utf8($text);
    return $text;
}

1;

