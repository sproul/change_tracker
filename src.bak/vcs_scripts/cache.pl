use strict;
use IO::File;

my $__trace = 0;

sub Log
{
  my($s) = @_;
  if ($__trace)
  {
    print "                     cache.pl: $s\n";
  }
}


sub write_file
{
  my($fn, $s) = @_;
  my $f = new IO::File("$fn", "w");
  $f->write($s);
  $f->close();
}

sub get_cached_output_path
{
  my($s) = @_;

  my $key = $s;

  my $fn_base = `printf "%s" "$key" | cksum`;

  Log("key=$key");
  chomp $fn_base;
  $fn_base =~ s/ .*//;

  my $fn = "$ENV{'TMP'}/cache." . $fn_base;

  if (! -f "$fn.cmd")
  {
    write_file("$fn.cmd", $key);
  }
  Log("get_cached_output_path resolved $key to $fn...");

  return $fn;
}

my @argv = @ARGV;

if ($argv[1] eq "-cache-clear")
{
  my $cached_output_stem = get_cached_output_path($argv[0]);
  die "empty output stem" unless $cached_output_stem;
  my $cmd = "rm -f $cached_output_stem* 2> /dev/null";
  Log("$cmd");
  print `$cmd`;
  exit(0);
}

my $cmd = join('" "', @argv);

$cmd =~ s/(" ")*$//g;
$cmd = '"' . $cmd . '"';
$cmd =~ s/"([-\w_#,\.\/]+)"/$1/g;

Log("cmd=$cmd");

my $cached_output = get_cached_output_path($cmd);
my $exit_code = 0;
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
  if (-f "$cache_data_override_fn.exit_code")
  {
    print "cp -p  $cache_data_override_fn.exit_code   $cached_output.exit_code\n";
    `cp -p "$cache_data_override_fn.exit_code" "$cached_output.exit_code"`;
    $exit_code = `cat $cached_output.exit_code`;
    Log("Got $exit_code from $cached_output.exit_code");
  }
  exit(0);
}
elsif (-f $cached_output)
{
  Log("using existing $cached_output");
  if (-f "$cached_output.exit_code")
  {
    $exit_code = `cat $cached_output.exit_code`;
    Log("setting cached exit_code = $exit_code");
  }
}
else
{
  my $cmd_with_redirects = "$cmd > $cached_output 2> $cached_output.err";
  `$cmd_with_redirects`;
  $exit_code = ${^CHILD_ERROR_NATIVE};
  Log("Executed $cmd_with_redirects (exit_code=$exit_code)");
  if ( `cat $cached_output.err` eq '' )
  {
    Log("No error output, so deleting $cached_output.err");
    unlink "$cached_output.err";
  }
}
print `cat $cached_output`;
if (-f "$cached_output.err")
{
  print STDERR `cat $cached_output.err`;
}
if ($exit_code != 0)
{
  Log("exit_code=$exit_code");
  if ($ENV{'USE_CACHED_DATA_EVEN_IF_FAILED'})
  {
    write_file("$cached_output.exit_code", "$exit_code");
    Log("saved $cached_output.exit_code since USE_CACHED_DATA_EVEN_IF_FAILED=$ENV{'USE_CACHED_DATA_EVEN_IF_FAILED'}");
  }
  else
  {
    unlink "$cached_output.err";
    unlink $cached_output;
    Log("removed all cache content for $cached_output since USE_CACHED_DATA_EVEN_IF_FAILED not set");
  }
  $exit_code = int($exit_code);
  if ($exit_code)
  {
    # I have a case where $exit_code = 32768, and for me on Linux w/ v5.10.1, the exit code is being reset to 0.  But if I set it to 1, that does make it through.
    $exit_code = 1;
  }
  Log("perl.exit($exit_code)");
  exit($exit_code);
}
