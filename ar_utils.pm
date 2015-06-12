package ar_utils; ## no critic(NamingConventions::Capitalization)

use strict;
use warnings;

use Exporter qw(import);
our $VERSION   = 1.0;
our @EXPORT_OK = qw(get_valid_path verify_bin_exists _log);

my $LOG_PAD = 0;

## no critic(Subroutines::ProhibitUnusedPrivateSubroutines)

sub _trim
{
	my $s = shift;
	return ! defined $s ? q{} : $s =~ s/^\s+|\s+$//r;
}

sub log_pad
{
	my ($s) = @_;
	$s = ! defined $s ? q{} : $s =~ s/^\s+|\s+$//r;
	$LOG_PAD = int $s;
	return;
}

sub _log
{ ## no critic(Subroutines::RequireArgUnpacking)
	my $format = q{%} . ($LOG_PAD > 0 ? q{-} . int($LOG_PAD) : q{}) . "s %s \n";
	return printf {*STDERR} $format, '[' . (caller 1)[3] . ']', @_;
}

sub get_valid_path
{
	my ($s) = @_;
	if (! defined $s) { $s = q{}; } else { $s =~ s/^\s+//; }
	if (! length($s) > 0) {
		return '/nonexistent';
	}
	my $path;
	if ($s =~ /^\//) {
		$path = $s;
	} else {
		require File::Basename;
		require File::Spec;
		$path = File::Spec->join(File::Spec->rel2abs(dirname(__FILE__)), $s);
	}
	return $path;
}

sub verify_bin_exists
{
	my $bin = _trim(shift);
	if (! length($bin) > 0) {
		print {*STDERR} "err: binary to check not defined.\n";
		exit 1;
	}
	my $found = 0;
	foreach my $dir (split /:/, $ENV{PATH}) {
		if ( -x "$dir/$bin") {
			$found = 1;
			last;
		}
	}
	if ($found == 0) {
		print {*STDERR} "err: $bin not found.\n";
		exit 1;
	}
}

1;
