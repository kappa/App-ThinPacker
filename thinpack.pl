#! /usr/bin/perl
use strict;
use warnings;

use PPI;

$ARGV[0] or die "Usage: $0 [options] <script.pl>\n";
my($args, $file);
if(@ARGV > 1) {
    $file = pop;
    $args = join ' ', @ARGV;
}
else {
    $file = shift;
    $args = '';
}

my $ppi = PPI::Document->new($file);
my $includes = $ppi->find('PPI::Statement::Include');

my $deps = join ' ',
    grep { $_ ne 'strict' && $_ ne 'warnings' }
    map { $_->module }
    @$includes;

my $inject = join '', map { s/%%DEPS%%/$deps/; s/%%ARGS%%/$args/g; $_ } <DATA>;

open my $script, '<', $file or die "Cannot open $file: $!\n";
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
    	eval "require App::cpanminus";
    	if ($@) {
            my $sock = IO::Socket::INET->new('kapranoff.ru:80');
            print $sock join "\r\n", "GET /cpanm HTTP/1.0",
                                     "Connection: close",
                                     "\r\n";
            my $cpanm = do { local $/; <$sock> };
            close $sock;
            open my $perl, '|perl - --self-upgrade %%ARGS%%';
            print $perl $cpanm;
            close $perl;
        }
        system(qw/cpanm %%ARGS%%/, @inst);
    }
