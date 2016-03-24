#/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use Pod::Usage;
use Getopt::Long;
use Data::Dumper;

sub assert {
    my ($condition, $msg) = ($_[0] // 0, $_[1]);
    unless ($condition) {
        say $msg if $msg;
        exit;
    }
}

# Available output formats
my %output_subs = (
    c => \&out_c_define,
    text => \&out_text,
);

# Parse command line
my $print_help;
my $out_format = 'c';
my $get_opt_res = GetOptions(
    'h|help' => \$print_help,
    'f|fmt=s' => \$out_format,
);
assert($get_opt_res, "Use -h or --help for usage info");

# Print usage help, if required
if ($print_help) {
    pod2usage(-verbose => 1);
}

# Check command line arguments
assert(defined $output_subs{$out_format},
    "Unknown output format: $out_format\n" .
    "Use -h or --help for usage info");

#
# parse_line(<line>)
#
# Extract a (parameter, value) pair from a line of input.
#  <line> - a line of input to parse
# Output:
#  (parameter, value), if it exists within the line
#  (),                 if no parameter-value pair is found
#  
sub parse_line {
    die "parse_line(): incorrect number of arguments" unless @_ == 1;
    my $line = shift;

    # Remove comments
    $line =~ s/#.*//;
    
    my @result = ();    
    if ($line =~ /^\s*(.*\S+)\s*=\s*(.*\S+)\s*/) {
        my ($param, $value) = ($1, $2);
        
        # Transform parameter to a name suitable for a C macro
        $param = uc $param;
        $param =~ s/\s/_/g;
        
        # Decide on the type of value. If it's a number, leave it as is.
        # If it's something else, transform it to a string.
        if ($value !~ /^(0x)?\d+$/) {
            $value = qq["$value"];
        }
        
        @result = ($param, $value);
    }
    
    return @result;
}

sub out_c_define {
    my $list = shift;
    
    for my $pair (@$list) {
        my ($param, $value) = @$pair;
        say "#define $param $value";
    }
}

sub out_text {
    my $list = shift;

    for my $pair (@$list) {
        my ($param, $value) = @$pair;
        say "[$param] = [$value]";
    }    
}

# Parse input files

my %params_hash;
my @params_list;
while (my $line = <>) {
    my @par_val = parse_line($line);
    next unless @par_val;
    
    my ($param, $value) = @par_val;
    if (defined $params_hash{$param}) {
        warn "Parameter '$param' is overwritten:\n" .
             "  Previous value: $params_hash{$param}\n" .
             "  New value: $value\n";
        $params_hash{$param}[1] = $value;
    } else {
        my $new_pair = [ $param, $value ];
        push @params_list, $new_pair;
        $params_hash{$param} = $new_pair;
    }
}
$output_subs{$out_format}(\@params_list);

=pod

=head1 NAME

B<slaconf.pl> - Generate C headers form configuration files

=head1 SYNOPSIS

B<slaconf.pl> [B<-h>] [I<FILE ...>] 

=head1 DESCRIPTION

slaconf.pl converts a configuration file to a C header.

=head1 OPTIONS

=over

=item -h, --help

Print basic help and usage options.

=back

=cut