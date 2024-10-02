#!/usr/bin/perl
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(basename dirname);

my $VERSION = "0.11.0";
my $TARGET = "SailfishOS-4.6.0.11EA-aarch64.default";

my $DIR = dirname(abs_path($0));
my $EXEC = basename $0;

my $EXEC_SFDK = "$ENV{HOME}/SailfishOS/bin/sfdk";

my $IPMAGIC_NAME = "sx";

my $SPEC_FILE = "$DIR/rpm/lipstick2vnc.spec";

sub getBuiltRPM();
sub fail($);
sub run(@);

my $USAGE = "Usage:
  $EXEC -h | --help
    show this message

  $EXEC
    set version in $SPEC_FILE to $VERSION
    build RPM
    restore prevsion version in $SPEC_FILE

  $EXEC i | install | -i | --install
    set version in $SPEC_FILE to $VERSION
    build RPM
    restore prevsion version in $SPEC_FILE
    copy the RPM using ipmagic+sshc+rsync, and install with pkcon
";

sub main(@){
  my $install = 0;
  while(@_ > 0){
    my $arg = shift;
    if($arg =~ /^(-h|--help)$/){
      print $USAGE;
      exit 0;
    }elsif($arg =~ /^(i|install|-i|--install)$/){
      $install = 1;
    }else{
      fail "$USAGE\nERROR: unknown arg $arg\n";
    }
  }

  chdir $DIR;
  $ENV{CWD} = $DIR;

  fail "ERROR: $EXEC_SFDK exec not found\n" if not -x $EXEC_SFDK;

  my $rpm = getBuiltRPM();
  if(defined $rpm){
    run "rm", $rpm;
    $rpm = getBuiltRPM();
  }
  fail "ERROR: rpm already exists\n" if defined $rpm;


  my $oldVersion = getVersion();
  setVersion($VERSION);

  run "$EXEC_SFDK config target=$TARGET";
  run "$EXEC_SFDK build lipstick2vnc.pro";

  setVersion($oldVersion);

  $rpm = getBuiltRPM();
  fail "ERROR: rpm does not exist\n" if not defined $rpm;

  if($install){
    my $rpmName = basename $rpm;
    my $remoteRpm = "/tmp/$rpmName";
    my $host = `ipmagic $IPMAGIC_NAME`;
    chomp $host;

    run "sshc --rsync -avP $rpm $host:$remoteRpm";
    run "sshc $host sudo pkcon install-local $remoteRpm -y";
    run "sshc $host rm $remoteRpm";
  }

  print "\n\nRPM: $rpm\n";
  success();
}

sub getBuiltRPM(){
  my @rpms = glob "$DIR/RPMS/lipstick2vnc*.rpm";
  fail "too many RPMs\n" if @rpms > 1;
  return undef if @rpms != 1;
  my $rpm = $rpms[0];
  if(defined $rpm and -f $rpm){
    return $rpm;
  }else{
    return undef;
  }
}

sub getVersion(){
  my $spec = `cat $SPEC_FILE`;
  if($spec =~ /^Version:\s*(.+)$/m){
    return $1;
  }else{
    fail "ERROR: could not parse version in $SPEC_FILE\n";
  }
}

sub setVersion($){
  my ($version) = @_;
  my $spec = `cat $SPEC_FILE`;
  my $oldVersion;
  if($spec =~ s/^Version:(\s*)(.+)$/Version:$1$version/m){
    $oldVersion = $2;
  }else{
    fail "ERROR: could not replace version in $SPEC_FILE\n";
  }

  print "VERSION: $oldVersion => $version\n";
  open FH, "> $SPEC_FILE" or fail "ERROR: could not write $SPEC_FILE\n$!\n";
  print FH $spec;
  close FH;
}

sub success(){
  system "alarm -s success";
}

sub fail($){
  my $msg = shift;
  system "alarm -s failure";
  die $msg;
}

sub run(@){
  print "@_\n";
  system @_;
  fail "ERROR: '@_' failed\n" if $? != 0;
}

&main(@ARGV);
