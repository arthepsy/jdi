#!/usr/bin/env perl

use strict;
use warnings;
use version; our $VERSION = qv('1.0.0');

use English qw(-no_match_vars);
use File::Basename;
use lib dirname(__FILE__);
use ar_utils qw(verify_bin_exists _log _log_pad _err);

_log_pad(26);

## no critic(InputOutput::ProhibitBacktickOperators)
my $_debug = ((scalar @ARGV) > 0 && $ARGV[0] eq '-v' ? 1 : 0);
my $_ttyempty = q{-};
my $_ttyregex = q{-};
my $_filter   = q{-};

sub init
{
	verify_bin_exists('lsof');
	my $_ttyprefix = q{-};
	my $_os = $OSNAME;
	if ($_os eq 'openbsd') {
			$_ttyprefix = 'ttyp';
			$_filter = q{};
	} elsif ($_os eq 'netbsd') {
			$_ttyprefix = 'pts/';
			$_filter = '-a /dev/pts';
	} elsif ($_os eq 'freebsd') {
			$_ttyprefix = 'pts/';
			$_filter = '-a /dev';
	} else {
			print {*STDERR} "err: unsupported OS.\n";
			exit 1;
	}
	$_ttyregex = "\/dev\/(${_ttyprefix}([0-9]+))( \\(master\\))?";
	return;
}

sub match_tty
{
	my ($line, $prefix) = @_;
	my $regex = ($prefix == 1 ? q{^} : q{}) . $_ttyregex;
	if ($line =~ /$regex/) {
		my $tty_dev = $1;
		my $tty_num = $2;
		my $tty_sub = int(length(defined $3 ? $3 : q{}) == 0);
		if ($_debug) { _log("- gather: device = $tty_dev, number = $tty_num, subtty? = $tty_sub"); }
		return ($tty_dev, $tty_num, $tty_sub);
	}
	return (undef, undef, undef);
}

sub find_ttys
{
	my ($pid) = @_;
	$pid = int $pid;
	if (! ($pid > 0)) {
		print {*STDERR} "err: invalid PID\n";
		exit 1;
	}
	my %ttys;
	my $c = "lsof -w -Di -FnN -p ${pid} ${_filter}";
	if ($_debug) { _log("- running command: $c"); }
	my @lines = split /\n/, `$c`;
	my $node_id = q{};
	foreach my $line (@lines) {
		if ($_debug) { _log("  . output: $line"); }
		if ($line =~ /^N(.*)/) {
			$node_id = $1;
			if ($_debug) { _log("  o node = $node_id"); }
			$ttys{$node_id} = $_ttyempty;
		}
		if ($line =~ /^n(.*)/) {
			my $name = $line;
			if ($_debug) { _log("  o device = $name"); }
			delete $ttys{$node_id};
			my ($tty_dev, $tty_num, $tty_sub) = match_tty($1, 1);
			if ($tty_dev) {
				if ($tty_sub == 1) {
					$ttys{$node_id} = $tty_dev;
				}
			}
			$node_id = q{};
		}
	}
	return %ttys;
}

sub resolve_tty {
	my ($node_id) = @_;
	if ($node_id =~ /\S/) {
		my $c = "lsof -w -Di +fn |grep '$node_id'";
		if ($_debug) { _log("- running command: $c"); }
		my @lines = split /\n/, `$c`;
		foreach my $line (@lines) {
			if ($_debug) { _log("  . output: $line"); }
			my ($tty_dev, $tty_num, $tty_sub) = match_tty($line, 0);
			if ($tty_dev) {
				if ($tty_sub == 1) {
					return $tty_dev;
				}
			}
		}
	}
	return $_ttyempty;
}

sub usage
{
	return _err("usage: $PROGRAM_NAME [-v] <pid>\n");
}

sub main
{
	my $p = (scalar @ARGV) - 1;
	if ($p > 1) {
		usage();
	}
	my $pid = int $ARGV[$p];
	my %ttys = find_ttys($pid);
	if ($_debug) {
		foreach my $node_id (keys %ttys) {
			if ($_debug) { _log("- ttys: node[$node_id] = $ttys{$node_id}"); }
		}
	}
	foreach my $node_id (keys %ttys) {
		my $tty_dev = $ttys{$node_id};
		if ($tty_dev eq $_ttyempty) {
			if ($_debug) { _log("- resolving node: [$node_id]"); }
			$tty_dev = resolve_tty($node_id);
			if ($_debug) { _log("- node resolved: [$tty_dev]"); }
		}
		if (not $tty_dev eq $_ttyempty) {
			print "$tty_dev\n";
		}
	}
	return;
}

init();
main();
