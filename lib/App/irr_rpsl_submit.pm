use v5.30;
use utf8;

package App::irr_rpsl_submit;
use experimental qw(signatures);

use Mojo::UserAgent;
use Mojo::File;
use Mojo::JSON;

our $VERSION = '0.001_01';

use constant {
	EX_SUCCESS	  =>  0,
	EX_REJECTED	  =>  1,
	EX_USAGE	  =>  2,
	EX_INPUT	  =>  4,
	EX_NETWORK	  =>  8,
	EX_UNEXPECTED => 16,
	EX_UNKNOWN	  => 32,
	};

=encoding utf8

=head1 NAME

App::irr_rpsl_submit - Perl program to submit RPSL to IRRdv4 (Irrdnet)

=head1 SYNOPSIS

This is a modulino, so you can call C<run> to execute like you would
a command-line program:

	use App::irr_rpsl_submit;
	App::irr_rpsl_submit->run(@args);

Or, you can load it and use the internals directly:

	use App::irr_rpsl_submit;

If you don't like how something works, subclass this and override the
parts you don't like.

=head1 DESCRIPTION

=head2 Arguments

=over 4

=item * -c CRYPT_PASS (legacy no op)

=item * -d (default: off)

=item * -D (legacy no op)

=item * -E ADMIN_EMAIL (legacy no op)

=item * -f CONFIG_FILE (legacy no op)

=item * -F FOOTER (legacy no op)

=item * -h HOST

=item * --help

=item * -j (default: off)

=item * -L LOG_DIR (legacy no op)

=item * -m KEY=VALUE,KEY2=VALUE2,...

=item * -M (legacy no op)

=item * -N (legacy no op)

=item * -O FORWARDING_HOST (legacy no op)

=item * -p PORT

=item * -r PGP_DIR (legacy no op)

=item * -R (legacy no op)

=item * -t (default: on)

=item * -u URL

=item * -v

=item * --version

=back

=head2 Enviroment

=over 4

=item * IRR_RPSL_SUBMIT_DEBUG

=item * IRR_RPSL_SUBMIT_HOST

=item * IRR_RPSL_SUBMIT_URL

=back

=head2 Methods

=over 4

=item * new

=cut

sub new ($class, %args) {
	state %defaults = ();
	my $self = bless {%defaults, %args}, $class;
	$self->{output_fh} //= \*STDOUT;
	$self;
	}

=item run

=cut

sub run ($class, @args) {
	my $args_to_new = ref $args[0] eq ref {} ? shift @args : {};

	my $irr_rpsl_submit = $class->new($args_to_new->%*);

	my $opts = $irr_rpsl_submit->process_options(\@args);

	if( $opts->{help} ) {
		$irr_rpsl_submit->output( $irr_rpsl_submit->help_message );
		$irr_rpsl_submit->_exit( EX_SUCCESS );
		}
	elsif( $opts->{version} ) {
		$irr_rpsl_submit->output( $irr_rpsl_submit->version_message );
		$irr_rpsl_submit->_exit( EX_SUCCESS );
		}
	}

sub _exit ($self, $status = EX_SUCCESS) {
	CORE::exit($status);
	}

sub help_message {
	<<~'HELP';
		Read RPSL submissions from stdin and return a response on stdout.
		Errors or debug info are printed to stderr. This program accepts
		the arguments for irrdv3's version of irr_rpsl_submit but ignores
		most of t,hem.

		You can also set three environment variables:

			IRR_RPSL_SUBMIT_DEBUG - turn on debugging
			IRR_RPSL_SUBMIT_URL	  - used if both -u and -h are unspecified
			IRR_RPSL_SUBMIT_HOST  - used if both -u and -h are unspecified
									and IRR_RPSL_SUBMIT_URL is not set

		The input format must be plain RPSL objects, separated by double
		newlines, as used in emails documented on
		https://irrd.readthedocs.io/en/stable/users/database-changes/#submitting-over-e-mail .

		The exit code is tells you what happened:

			 0 - complete success
			 1 - at least one change was rejected
			 2 - usage error
			 4 - input error
			 8 - network error
			16 - unexpected response
			32 - an unidentified error
		HELP
	}

sub output ($self, @messages) {
	print {$self->output_fh} @messages;
	}

sub output_fh ($self) {
	$self->{output_fh};
	}

sub process_options ($self, $args) {
	state $rc = require Getopt::Long;
	Getopt::Long::Configure(qw(no_ignore_case));
	my $opts = {};
	my $spec = {
		'c=s'     => \$opts->{crypt},
		'd|v'     => \$opts->{debug},
		'D'       => \$opts->{std},
		'E=s'     => \$opts->{admin_email},
		'f=s'     => \$opts->{config_file},
		'F=s'     => \$opts->{footer},
		'h=s'     => \$opts->{host},
		'help'    => \$opts->{help},
		'j'       => \$opts->{json},
		'L=s'     => \$opts->{log_dir},
		'm=s'     => \$opts->{meta},
		'M'       => \$opts->{M},
		'O'       => \$opts->{forwarding_host},
		'p=i'     => \$opts->{port},
		'r'       => \$opts->{pgp_dir},
		'R'       => \$opts->{R},
		't'       => \$opts->{text},
		'u=s'     => \$opts->{url},
		'version' => \$opts->{version},
		};

	my $ret =  Getopt::Long::GetOptionsFromArray( $args, $spec->%* );

	if( ! defined $opts->{debug} and exists $ENV{IRR_RPSL_SUBMIT_DEBUG} ) {
		$opts->{debug} = $ENV{IRR_RPSL_SUBMIT_DEBUG};
		}


	if( ! defined $opts->{host} and exists $ENV{IRR_RPSL_SUBMIT_HOST} ) {
		$opts->{'host'} = $ENV{IRR_RPSL_SUBMIT_HOST};
		}

	my $has_u_or_h = grep { defined $opts->{$_} } qw(url host);
	$opts->{url} = do {
		if( exists $ENV{IRR_RPSL_SUBMIT_URL} and ! $has_u_or_h ) {
			$opts->{url} = $ENV{IRR_RPSL_SUBMIT_URL};
			}
		elsif( exists $ENV{IRR_RPSL_SUBMIT_HOST} and ! $has_u_or_h ) {
			$opts->{url} = $ENV{IRR_RPSL_SUBMIT_HOST};
			}
		elsif( defined $opts->{'host'} ) {
			my $hostport = $opts->{'host'};
			$hostport .= ':' . $opts->{'port'} if defined $opts->{'port'};
			"https://$hostport/v1/submit/"
			}
		else {
			$opts->{'url'}
			}
		};

	return $opts;
	}

sub version_message ($self) {
	state $rc = require File::Basename;
	state $template = <<~'VERSION';
		%s version %s (Perl %s, App::irr_rpsl_submit)
		VERSION

	sprintf $template, File::Basename::basename($0), $VERSION, $^V
	}

=back

=head1 TO DO


=head1 SEE ALSO


=head1 SOURCE AVAILABILITY

This source is in Github:

	http://github.com/briandfoy/app-irr_rpsl_submit

=head1 AUTHOR

brian d foy, C<< <briandfoy@pobox.com> >>

=head1 COPYRIGHT AND LICENSE

Copyright © 2025-2026, brian d foy, All Rights Reserved.

You may redistribute this under the terms of the Artistic License 2.0.

=cut

1;
