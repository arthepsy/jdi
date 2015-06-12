#!/usr/bin/env perl

use strict;
use warnings;
use version; our $VERSION = qv('1.0.0');

use ar_utils qw(get_valid_path verify_bin_exists _log _log_pad _err);

_log_pad(30);

## no critic(InputOutput::ProhibitBacktickOperators)
my $_debug = ((scalar @ARGV) > 0 && $ARGV[0] eq q{-v} ? 1 : 0);
my $_list_sshd_script = 'sshd.list.pl';

sub get_sshd_forward_ports
{
	my ($pid) = @_;
	$pid = int $pid;
	my @ports;
	if ($pid > 0) {
		my $c = "lsof -w -Fn -nP -i 4 -a -p $pid";
		if ($_debug) { _log("- running command: $c") };
		my @lines = split /\n/, `$c`;
		foreach my $line (@lines) {
			if ($line =~ /^n(.*)/ && $line !~ /->/) {
				my ($host, $port) = split /:/, $1;
				push @ports, $port;
			}
		}
	}
	return @ports;
}

sub init
{
	my $script = get_valid_path($_list_sshd_script);
	if (! -f $script) {
		_err("err: $_list_sshd_script not found.\n");
	}
	if (! -x $script) {
		_err("err: $_list_sshd_script not executable.\n");
	}
	return;
}

sub main
{
	verify_bin_exists('lsof');
	my $c = get_valid_path($_list_sshd_script);
	if ($_debug) { _log("- running command: $c") };
	my @lines = split /\n/, `env PERL_BADLANG=0 $c`;
	foreach my $line (@lines) {
		if ($_debug) { _log("  . output: $line"); }
		my ($pid, $tty) = split / /, $line;
		$pid = int $pid;
		if (! ($pid > 0)) { next; }
		my @ports = get_sshd_forward_ports($pid);
		foreach my $port (@ports) {
			print $port . "\n";
		}
	}
	return;
}

init();
main();

