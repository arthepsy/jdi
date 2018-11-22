#!/usr/bin/env perl
package ar_utils; ## no critic(NamingConventions::Capitalization)

use strict;
use warnings;
use version; our $VERSION = qv('1.0.0');

use Exporter qw(import);
our @EXPORT_OK = qw(get_valid_path check_bin_exists verify_bin_exists _log _log_pad _err);

## no critic(Subroutines::ProhibitUnusedPrivateSubroutines)

sub _trim
{
	my $s = shift;
	return ! defined $s ? q{} : $s =~ s/^\s+|\s+$//r;
}

sub _err
{
	my ($msg, $code) = @_;
	$code = ! defined $code ? 1 : int $code;
	print {*STDERR} $msg;
	exit $code;
}

my $LOG_PAD = 0;
sub _log_pad { $LOG_PAD = int _trim(shift); return; }
sub _log
{ ## no critic(Subroutines::RequireArgUnpacking)
	my $format = q{%} . ($LOG_PAD > 0 ? q{-} . int($LOG_PAD) : q{}) . "s %s \n";
	my (undef, undef, undef, $sub) = caller 1;
	if (! length($sub) > 0) {
		($sub) = caller 0;
	}
	return printf {*STDERR} $format, '[' . $sub . ']', @_;
}

sub get_valid_path
{
	my $s = _trim(shift);
	if (! length($s) > 0) {
		return '/nonexistent';
	}
	my $path;
	if ($s =~ /^\//) {
		$path = $s;
	} else {
		require File::Spec;
		my ($v, $d) = File::Spec->splitpath(File::Spec->rel2abs(__FILE__));
		my $dir = "$v.$d";
		$path = File::Spec->join($d, $s);
	}
	return $path;
}

sub check_bin_exists
{
	my $bin = _trim(shift);
	if (! length($bin) > 0) {
		_err("err: binary to check not defined.\n");
	}
	my $found = 0;
	foreach my $dir (split /:/, $ENV{PATH}) {
		if ( -x "$dir/$bin") {
			$found = 1;
			last;
		}
	}
	return $found;
}

sub verify_bin_exists
{
	my $bin = _trim(shift);
	my $found = check_bin_exists($bin);
	if ($found == 0) {
		_err("err: $bin not found.\n");
	}
	return;
}

1;
