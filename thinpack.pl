#! /usr/bin/perl
use strict;
use warnings;

use PPI;

$ARGV[0] or die "Usage: $0 <script.pl>\n";

my $ppi = PPI::Document->new($ARGV[0]);
my $includes = $ppi->find('PPI::Statement::Include');

my $deps = join ' ',
    grep { $_ ne 'strict' && $_ ne 'warnings' }
    map { $_->module }
    @$includes;

my $inject = join '', map { s/%%DEPS%%/$deps/; $_ } <DATA>;

open my $script, '<', $ARGV[0] or die "Cannot open $ARGV[0]: $!\n";
my $not_injected = 1;
while (my $line = <$script>) {
    if ($line =~ /^use / && $not_injected) {
        print "BEGIN {\n$inject\n};\n";
        $not_injected = 0;
    }

    print $line;
}

__DATA__
    package main;
    use IO::Socket::INET;
    my @deps = qw(%%DEPS%%);
    my @inst;
    for my $dep (@deps) {
    	eval "require $dep";
    	push @inst, $dep if $@;
    }
    if (@inst) {
        local $@;
    	eval "require App::cpanminus";
    	if ($@) {
            my $sock = IO::Socket::INET->new('kapranoff.ru:80');
            print $sock join "\r\n", "GET /cpanm HTTP/1.0",
                                     "Connection: close",
                                     "\r\n";
            my $cpanm = do { local $/; <$sock> };
            close $sock;
            open my $sudoperl, '|perl - --self-upgrade --sudo';
            print $sudoperl $cpanm;
            close $sudoperl;
        }
        system(qw/cpanm --sudo/, @inst);
    }
