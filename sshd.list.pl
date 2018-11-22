#!/usr/bin/env perl

use strict;
use warnings;
use version; our $VERSION = qv('1.0.0');

use English qw(-no_match_vars);
use File::Basename;
use lib dirname(__FILE__);
use ar_utils qw(get_valid_path verify_bin_exists _log _log_pad _err);

_log_pad(26);

## no critic(InputOutput::ProhibitBacktickOperators)
my $_debug = ((scalar @ARGV) > 0 && $ARGV[0] eq '-v' ? 1 : 0);
my $_tty_sublist_script = 'tty.sublist.pl';
my $_notfound = -1;

sub get_ppid
{
	my ($pid) = @_;
	$pid = int $pid;
	if (! ($pid > 0)) { return $_notfound; }
	my $ppid = (`ps -p "$pid" -o ppid=`) || $_notfound;
	chomp $ppid;
	return int $ppid;
}

sub get_tty
{
	my ($pid) = @_;
	$pid = int $pid;
	if (! ($pid > 0)) { return $_notfound; }
	my $tty_dev = (`ps -p "$pid" -o tty=`) || $_notfound;
	chomp $tty_dev;
	return $tty_dev;
}

sub get_cmd
{
	my ($pid) = @_;
	$pid = int $pid;
	if (! ($pid > 0)) { return q{}; }
	my $cmd = (`ps -p "$pid" -o command=`);
	chomp $cmd;
	return $cmd;
}

sub show_sshd
{
	my ($pid, $tty_list) = @_;
	print "$pid $tty_list\n";
	return;
}

sub get_sshd_processes
{
	my $c = 'ps x -o pid,command= | grep sshd';
	if ($_debug) { _log("- running command: $c"); };
	my @lines = split /\n/, `$c`;
	if ($_debug) {
		foreach my $line (@lines) {
			_log("  . output: $line");
		}
	}
	return @lines;
}

{
	my @sshd_processes;
	sub find_sshd_oftty
	{
		my ($tty_dev) = @_;
		if (not @sshd_processes) {
			@sshd_processes = get_sshd_processes();
		}
		if ($_debug) { _log("- searching for sshd of $tty_dev"); }
		foreach my $line (@sshd_processes) {
			if ($line =~ /(\d+)\s+sshd: (\S*)/) {
				my $pid = int $1;
				my $sshd_args = $2;
				if ($_debug) { _log("  o sshd_pid=[$pid] sshd_args=[$sshd_args]"); }
				if ($sshd_args =~ /\@notty$/) { next; }
				if ($sshd_args =~ /\@internal-sftp$/) { next; }
				if ($sshd_args =~ /\@$tty_dev$/) { return $pid; }
				if ($sshd_args =~ /\,$tty_dev,/) { return $pid; }
				if ($sshd_args =~ /\,$tty_dev$/) { return $pid; }
			}
		}
		return $_notfound;
	}
}


sub find_sshd_ofmux
{
	my ($pid) = @_;
	$pid = int $pid;
	my $script = get_valid_path($_tty_sublist_script);
	my $c = "$script $pid";
	if ($_debug) { _log("- running command: $c"); };
	my @lines = split /\n/, `env PERL_BADLANG=0 $c`;
	my %sshd_list;
	foreach my $line (@lines) {
		if ($_debug) { _log("  . output: $line"); }
		if ($line =~ /\S/) {
			my $tty_dev = $line;
			my $sshd_pid = int find_sshd_oftty($tty_dev);
			if ($_debug) { _log("  o found sshd pid=[$sshd_pid]"); }
			if ($sshd_pid > 0) {
				if (not defined $sshd_list{$sshd_pid}) {
					$sshd_list{$sshd_pid} = q{};
				}
				if (not $sshd_list{$sshd_pid} eq q{}) { $sshd_list{$sshd_pid} .= q{,}; }
				$sshd_list{$sshd_pid} .= $tty_dev;
			}
		}
	}
	foreach my $pid (keys %sshd_list) {
		my $tty_list = $sshd_list{$pid};
		if ($_debug) { _log(" - sshd pid=[$pid] tty_list=[$tty_list]"); }
		show_sshd($pid, $tty_list);
	}
	return;
}

sub find_sshd
{
	my ($pid) = @_;
	$pid = int $pid;
	if (! ($pid > 0)) {
		return -1;
	}
	my $ppid = get_ppid($pid);
	my $tty = get_tty($pid);
	my $cmd = get_cmd($pid);
	if ($_debug) { _log("- traverse: pid=[$pid] ppid=[$ppid] tty=[$tty] command=[$cmd]"); }
	if ($cmd =~ /^screen/i) {
		find_sshd_ofmux($pid);
	} elsif ($cmd =~ 'tmux: server ') {
		find_sshd_ofmux($pid);
	} elsif ($cmd =~ '^sshd: ([^\s]*)') {
		my $tty_list = $1;
		$tty_list =~ s/^[^@]+@//g;
		show_sshd($pid, $tty_list);
	} else {
		if ($ppid > 0) {
			find_sshd($ppid);
		}
	}
	return;
}

sub init
{
	my $script = get_valid_path($_tty_sublist_script);
	if (! -f $script) {
		_err("err: $_tty_sublist_script not found.\n");
	}
	if (! -x $script) {
		_err("err: $_tty_sublist_script not executable.\n");
	}
	return;
}

sub main
{
	my $pid = $PID;
	find_sshd($pid);
	return;
}

init();
main();
