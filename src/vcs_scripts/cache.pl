use strict;
use IO::File;

my $__trace = 0;

sub get_cached_output_path
{
  my($extra_key, $s) = @_;

  my $key = $extra_key . $s;
  
  my $fn_base = `echo $key | cksum`;
  chomp $fn_base;
  $fn_base =~ s/ .*//;
  
  my $fn = "$ENV{'TMP'}/cache." . $fn_base;
  
  my $f = new IO::File("$fn.cmd", "w");
  $f->write($key);
  $f->close();

  return $fn;
}

my @argv = @ARGV;
my $extra_key = $ENV{"CACHE_EXTRA_ARG"};
$extra_key = "" if !defined $extra_key;

if ($argv[1] eq "-cache-clear")
{
  my $cached_output_stem = get_cached_output_path($extra_key, $argv[0]);
  die "empty output stem" unless $cached_output_stem;
  my $cmd = "rm -f $cached_output_stem* 2> /dev/null";
  print "$cmd\n" if $__trace;
  print `$cmd`;
  exit(0);
}


my $cmd = join('" "', @argv);


$cmd =~ s/(" ")*$//g;
$cmd = '"' . $cmd . '"';
$cmd =~ s/"([\w_#,\.\/]+)"/$1/g;

print "cmd=$cmd\n" if $__trace;

my $cached_output = get_cached_output_path($extra_key, $cmd);

if (-f $cached_output)
{
  print "using existing $cached_output\n" if $__trace;
}
else
{
  my $cmd_with_redirects = "$cmd > $cached_output 2> $cached_output.err";
  `$cmd_with_redirects`;
  if ($__trace)
  {
    print "Executed $cmd_with_redirects\n";
  }
  if ( `cat $cached_output.err` eq '' )
  {
    if ($__trace)
    {
      print "No error output, so deleting $cached_output.err\n";
    }
    unlink "$cached_output.err";
  }
}
print `cat $cached_output`;
if (-f "$cached_output.err" )
{
  print STDERR `cat $cached_output.err`;
  # assume trouble if there was output to stderr, and remove the cached output:
  unlink "$cached_output.err";
  unlink $cached_output;
}
