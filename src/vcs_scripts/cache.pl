use strict;
use IO::File;

my $__trace = 0;

sub get_cached_output_path
{
  my($s) = @_;

  my $key = $s;
  
  my $fn_base = `printf "$key" | cksum`;
  
  print "key=$key\n" if $__trace;
  print "echo output is " . `echo -n "$key"` . "!!!\n" if $__trace;

  chomp $fn_base;
  $fn_base =~ s/ .*//;
  
  my $fn = "$ENV{'TMP'}/cache." . $fn_base;
  
  if (! -f "$fn.cmd")
  {
    my $f = new IO::File("$fn.cmd", "w");
    $f->write($key);
    $f->close();
  }
  print "get_cached_output_path resolved $key to $fn...\n" if $__trace;

  return $fn;
}

my @argv = @ARGV;

if ($argv[1] eq "-cache-clear")
{
  my $cached_output_stem = get_cached_output_path($argv[0]);
  die "empty output stem" unless $cached_output_stem;
  my $cmd = "rm -f $cached_output_stem* 2> /dev/null";
  print "$cmd\n" if $__trace;
  print `$cmd`;
  exit(0);
}

my $cmd = join('" "', @argv);

$cmd =~ s/(" ")*$//g;
$cmd = '"' . $cmd . '"';
$cmd =~ s/"([-\w_#,\.\/]+)"/$1/g;

print "cmd=$cmd\n" if $__trace;

my $cached_output = get_cached_output_path($cmd);

my $cache_data_override_fn = $ENV{'USE_CACHED_DATA_FROM_FILENAME'};
if ($cache_data_override_fn)
{
  if (! -f $cache_data_override_fn)
  {
    print STDERR "cache.pl error: could not find USE_CACHED_DATA_FROM_FILENAME file $cache_data_override_fn\n";
    exit(1);
  }
  print "Loading cache from $cache_data_override_fn\n";
  print "cp -p  $cache_data_override_fn   $cached_output\n";
  `      cp -p "$cache_data_override_fn" "$cached_output"`;
  exit(0);
}
elsif (-f $cached_output)
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
