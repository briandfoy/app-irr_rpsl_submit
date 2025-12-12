use v5.30;
use utf8;
use lib qw(lib);
use experimental qw(signatures);
use Test::More;

my $class  = 'App::irr_rpsl_submit';
my $subclass = 'Local::App::irr_rpsl_submit';
my $method = 'process_options';

package Local::App::irr_rpsl_submit {
	our @ISA = 'App::irr_rpsl_submit';

	sub _exit ($self, $status) { return $status }
	}

subtest 'sanity' => sub {
	use_ok $class;
	can_ok $subclass, $method;

	isa_ok $subclass->new, $class;
	};

subtest 'options' => sub {
	my $obj = $subclass->new;

	subtest 'help' => sub {
		my $option = '--help';
		my $key    = 'help';

		subtest 'help_message' => sub {
			state $pattern = qr/Read RPSL submissions/;
			state $m = 'help_message';
			can_ok $obj, $m;
			like $obj->$m(), $pattern;
			};
			
		subtest 'process --help' => sub {
			my $opts = $obj->$method( [$option] );
			isa_ok $opts, ref {};
			ok exists $opts->{$key}, 'help option exists';
			is $opts->{$key}, 1, 'help option is true'
			};

		subtest "run $option" => sub {
			state $pattern = qr/Read RPSL submissions/;
			state $m = 'run';
			can_ok $obj, $m;
			open my $sfh, '>', \my $string;
			my $rc = $subclass->$m( { output_fh => $sfh }, $option );
			is $rc, 0, 'exited successfully';
			like $string, $pattern;
			};
		};

	subtest 'version' => sub {
		state $pattern = qr/Perl v5/;
		my $option = '--version';
		my $key    = 'version';

		subtest 'version_message' => sub {
			state $m = 'version_message';
			can_ok $obj, $m;
			like $obj->$m(), $pattern, 'output matches pattern';
			};

		subtest 'process --version' => sub {
			my $opts = $obj->$method( [$option] );
			isa_ok $opts, ref {};
			ok exists $opts->{$key}, 'version option exists';
			is $opts->{$key}, 1, 'version option is true'
			};
	
		subtest "run $option" => sub {
			state $m = 'run';
			can_ok $obj, $m;
			open my $sfh, '>', \my $string;
			my $rc = $subclass->$m( { output_fh => $sfh }, $option);
			is $rc, 0, 'exited successfully';
			like $string, $pattern;
			};
		};
	};

subtest 'environment' => sub {
	my $obj = $subclass->new;

	subtest 'IRR_RPSL_SUBMIT_DEBUG' => sub {
		my $env_key = 'IRR_RPSL_SUBMIT_DEBUG';
		my $opt_key = 'debug';
	
		subtest 'no env, no -d or -v' => sub {
			delete local $ENV{$env_key};
			my $opts = $obj->$method( [] );
			isa_ok $opts, ref {};
			ok exists $opts->{$opt_key}, "$opt_key option exists";
			ok ! defined $opts->{$opt_key}, "$opt_key option is undefined";
			};

		foreach my $env_value ( qw(1 0) ) {
			subtest "env = $env_value, no -d or -v" => sub {
				local $ENV{$env_key} = $env_value;
				my $opts = $obj->$method( [] );
				isa_ok $opts, ref {};
				ok exists $opts->{$opt_key}, "$opt_key option exists";
				is $opts->{$opt_key}, $env_value, "$opt_key option is from the option value";
				};
	
			subtest "env = $env_value, -d no -v" => sub {
				my $opt = '-d';
				local $ENV{$env_key} = $env_value;
				my $opts = $obj->$method( [ $opt ] );
				isa_ok $opts, ref {};
				ok exists $opts->{$opt_key}, "$opt_key option exists for $opt";
				is $opts->{$opt_key}, 1, "$opt_key option is from the option value";
				};
	
			subtest "env = $env_value, no -d, -v" => sub {
				my $opt = '-v';
				local $ENV{$env_key} = $env_value;
				my $opts = $obj->$method( [ $opt ] );
				isa_ok $opts, ref {};
				ok exists $opts->{$opt_key}, "$opt_key option exists for $opt";
				is $opts->{$opt_key}, 1, "$opt_key option is from the option value";
				};
			}	
		};
		
	subtest 'IRR_RPSL_SUBMIT_URL' => sub {
		my $env_key = 'IRR_RPSL_SUBMIT_URL';
		my $key = 'url';

		subtest 'no env, with -u' => sub {
			state $option = '-u';
			state $url = 'https://www.example.com/v1/';
			delete local $ENV{$env_key};
			my $opts = $obj->$method( [ $option => $url ] );
			isa_ok $opts, ref {};
			ok exists $opts->{$key}, "$key option exists";
			is $opts->{$key}, $url, "$key option is from the option value";
			};

		subtest 'env, with -u' => sub {
			state $option = '-u';
			state $url = 'https://www.example.com/v1/';
			local $ENV{$env_key} = 'http://www.foo.bar/v3/';
			my $opts = $obj->$method( [ $option => $url ] );
			isa_ok $opts, ref {};
			ok exists $opts->{$key}, "$key option exists";
			is $opts->{$key}, $url, "$key option is from the args";
			};

		subtest 'env, with -h' => sub {
			state $option = '-h';
			state $host = 'www.example.com';
			state $url  = "https://$host/v1/submit/";
			local $ENV{$env_key} = 'http://www.foo.bar/v3/';
			my $opts = $obj->$method( [ $option => $host ] );
			isa_ok $opts, ref {};
			ok exists $opts->{$key}, "$key option exists";
			is $opts->{$key}, $url, "$key option is from the args";
			};

		subtest 'env, without -u or -h' => sub {
			local $ENV{$env_key} = 'http://www.foo.bar/v3/';
			my $opts = $obj->$method( [ ] );
			isa_ok $opts, ref {};
			ok exists $opts->{$key}, "$key option exists";
			is $opts->{$key}, $ENV{$env_key}, "$key option is from the env var";
			};
		};

	subtest 'IRR_RPSL_SUBMIT_HOST' => sub {
		my $env_key = 'IRR_RPSL_SUBMIT_HOST';
		my $key = 'host';
		my $option = '-h';

		subtest 'no env, with -h' => sub {
			state $url = 'https://www.example.com/v1/';
			delete local $ENV{$env_key};
			my $opts = $obj->$method( [ $option => $url ] );
			isa_ok $opts, ref {};
			ok exists $opts->{$key}, "$key option exists";
			is $opts->{$key}, $url, "$key option is from the option value";
			};

		subtest 'env, with -h' => sub {
			state $url = 'https://www.example.com/v1/';
			local $ENV{$env_key} = 'http://www.foo.bar/v3/';
			my $opts = $obj->$method( [ $option => $url ] );
			isa_ok $opts, ref {};
			ok exists $opts->{$key}, "$key option exists";
			is $opts->{$key}, $url, "$key option is from the args";
			};

		subtest 'env, no -h' => sub {
			local $ENV{$env_key} = 'http://www.foo.bar/v3/';
			my $opts = $obj->$method( [] );
			isa_ok $opts, ref {};
			ok exists $opts->{$key}, "$key option exists";
			is $opts->{$key}, $ENV{$env_key}, "$key option is from the args";
			};
		};
	};

done_testing();
