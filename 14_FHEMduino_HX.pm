##############################################
# $Id: 14_FHEMduino_HX.pm 3818 2014-06-24 $
package main;

use strict;
use warnings;

  # 10011 => 1. 2xDing-Dong
  # 10101 => 2. Telefonklingeln
  # 11001 => 3. Zirkusmusik
  # 11101 => 4. Banjo on my knee
  # 11110 => 5. Morgen kommt der Weihnachtsmann
  # 10110 => 6. It’s a small world
  # 10010 => 7. Hundebellen
  # 10001 => 8. Westminster

my %codes = (
  "XMIToff" 		=> "off",
  "XMITon" 		=> "on",
  "XMIThx1" 		=> "hx1",
  "XMIThx2" 		=> "hx2",
  "XMIThx3" 		=> "hx3",
  "XMIThx4" 		=> "hx4",
  "XMIThx5" 		=> "hx5",
  "XMIThx6" 		=> "hx6",
  "XMIThx7" 		=> "hx7",
  "XMIThx8" 		=> "hx8",
  );

my %elro_c2b;

my $hx_defrepetition = 14;   ## Default number of HX Repetitions

my $fa20rf_simple ="off on";
my %models = (
  Heidemann   => 'HX Series',
  );

#####################################
sub
FHEMduino_HX_Initialize($)
{
  my ($hash) = @_;
 
  foreach my $k (keys %codes) {
    $elro_c2b{$codes{$k}} = $k;
  }
  
  $hash->{Match}     = "H...\$";
  $hash->{SetFn}     = "FHEMduino_HX_Set";
  $hash->{StateFn}   = "FHEMduino_HX_SetState";
  $hash->{DefFn}     = "FHEMduino_HX_Define";
  $hash->{UndefFn}   = "FHEMduino_HX_Undef";
  $hash->{AttrFn}    = "FHEMduino_HX_Attr";
  $hash->{ParseFn}   = "FHEMduino_HX_Parse";
  $hash->{AttrList}  = "IODev HXrepetition do_not_notify:0,1 showtime:0,1 ignore:0,1 model:HX,RM150RF,KD101";
  $readingFnAttributes;
}

sub FHEMduino_HX_SetState($$$$){ ###################################################
  my ($hash, $tim, $vt, $val) = @_;
  $val = $1 if($val =~ m/^(.*) \d+$/);
  return "Undefined value $val" if(!defined($elro_c2b{$val}));
  return undef;
}

sub
FHEMduino_HX_Do_On_Till($@)
{
  my ($hash, @a) = @_;
  return "Timespec (HH:MM[:SS]) needed for the on-till command" if(@a != 3);

  my ($err, $hr, $min, $sec, $fn) = GetTimeSpec($a[2]);
  return $err if($err);

  my @lt = localtime;
  my $hms_till = sprintf("%02d:%02d:%02d", $hr, $min, $sec);
  my $hms_now = sprintf("%02d:%02d:%02d", $lt[2], $lt[1], $lt[0]);
  if($hms_now ge $hms_till) {
    Log 4, "on-till: won't switch as now ($hms_now) is later than $hms_till";
    return "";
  }

  my @b = ($a[0], "on");
  FHEMduino_HX_Set($hash, @b);
  my $tname = $hash->{NAME} . "_till";
  CommandDelete(undef, $tname) if($defs{$tname});
  CommandDefine(undef, "$tname at $hms_till set $a[0] off");

}

sub
FHEMduino_HX_On_For_Timer($@)
{
  my ($hash, @a) = @_;
  return "Seconds are needed for the on-for-timer command" if(@a != 3);

  # my ($err, $hr, $min, $sec, $fn) = GetTimeSpec($a[2]);
  # return $err if($err);
  
  my @lt = localtime;
  my @tt = localtime(time + $a[2]);
  my $hms_till = sprintf("%02d:%02d:%02d", $tt[2], $tt[1], $tt[0]);
  my $hms_now = sprintf("%02d:%02d:%02d", $lt[2], $lt[1], $lt[0]);
  
  if($hms_now ge $hms_till) {
    Log 4, "on-for-timer: won't switch as now ($hms_now) is later than $hms_till";
    return "";
  }

  my @b = ($a[0], "on");
  FHEMduino_HX_Set($hash, @b);
  my $tname = $hash->{NAME} . "_till";
  CommandDelete(undef, $tname) if($defs{$tname});
  CommandDefine(undef, "$tname at $hms_till set $a[0] off");

}

#####################################
sub
FHEMduino_HX_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  return "wrong syntax: define <name> FHEMduino_HX HX".int(@a)
		if(int(@a) < 2 || int(@a) > 5);

  my $name = $a[0];
  my $code = $a[2];
  my $bitcode = substr(unpack("B32", pack("N", $code)),-4);
  my $onHX = "";
  my $offHX = "";

  Log3 $hash, 4, "FHEMduino_HX_DEF: $name $code";

  if(int(@a) == 3) {
  }
  elsif(int(@a) == 5) {
    $onHX = $a[3];
    $offHX = $a[4];
  }
  else {
    return "wrong syntax: define <name> FHEMduino_HX <code>";
  }

  Log3 undef, 5, "Arraylenght:  int(@a)";

  $hash->{CODE} = $code;
  $hash->{DEF} = $code . " " . $onHX . " " . $offHX;
  $hash->{XMIT} = $bitcode;
  $hash->{BTN}  = $onHX;
  
  Log3 $hash, 4, "Define hascode: {$code} {$name}";
  $modules{FHEMduino_HX}{defptr}{$code} = $hash;
  $hash->{$elro_c2b{"on"}}  = $onHX;    # => 8. Westminster
  $hash->{$elro_c2b{"off"}} = $offHX;   # => 1. 2xDing-Dong
  $hash->{$elro_c2b{"hx1"}} = "10011";  # => 1. 2xDing-Dong
  $hash->{$elro_c2b{"hx2"}} = "10101";  # => 2. Telefonklingeln
  $hash->{$elro_c2b{"hx3"}} = "11001";  # => 3. Zirkusmusik
  $hash->{$elro_c2b{"hx4"}} = "11101";  # => 4. Banjo on my knee
  $hash->{$elro_c2b{"hx5"}} = "11110";  # => 5. Morgen kommt der Weihnachtsmann
  $hash->{$elro_c2b{"hx6"}} = "10110";  # => 6. It’s a small world
  $hash->{$elro_c2b{"hx7"}} = "10010";  # => 7. Hundebellen
  $hash->{$elro_c2b{"hx8"}} = "10001";  # => 8. Westminster
  $modules{FHEMduino_HX}{defptr}{$code}{$name} = $hash;

  if(!defined $hash->{IODev} ||!defined $hash->{IODev}{NAME}){
   AssignIoPort($hash);
  };  
  return undef;
}

#####################################
sub
FHEMduino_HX_Undef($$)
{
  my ($hash, $name) = @_;
  delete($modules{FHEMduino_HX}{defptr}{$hash->{CODE}}) if($hash && $hash->{CODE});
  return undef;
}

sub FHEMduino_HX_Set($@){ ##########################################################
  my ($hash, @a) = @_;
  my $ret = undef;
  my $na = int(@a);
  my $message;
  my $msg;
  my $hname = $hash->{NAME};
  my $name = $a[1];

  return "no set value specified" if($na < 2 || $na > 3);
  
  my $list = "";
  $list .= "on:noArg off:noArg on-till on-for-timer hx1:noArg hx2:noArg hx3:noArg hx4:noArg hx5:noArg hx6:noArg hx7:noArg hx8:noArg";

  return SetExtensions($hash, $list, $hname, @a) if( $a[1] eq "?" );
  return SetExtensions($hash, $list, $hname, @a) if( !grep( $_ =~ /^$a[1]($|:)/, split( ' ', $list ) ) );

  my $c = $elro_c2b{$a[1]};

  return FHEMduino_HX_Do_On_Till($hash, @a) if($a[1] eq "on-till");
  return "Bad time spec" if($na == 3 && $a[2] !~ m/^\d*\.?\d+$/);

  return FHEMduino_HX_On_For_Timer($hash, @a) if($a[1] eq "on-for-timer");
  # return "Bad time spec" if($na == 1 && $a[2] !~ m/^\d*\.?\d+$/);

  if(!defined($c)) {

   # Model specific set arguments
   if(defined($attr{$a[0]}) && defined($attr{$a[0]}{"model"})) {
     my $mt = $models{$attr{$a[0]}{"model"}};
     return "Unknown argument $a[1], choose one of "
     if($mt && $mt eq "sender");
     return "Unknown argument $a[1], choose one of $fa20rf_simple"
     if($mt && $mt eq "simple");
   }
   return "Unknown argument $a[1], choose one of " . join(" ", sort keys %elro_c2b);
 }
 my $io = $hash->{IODev};

 ## Do we need to change RFMode to SlowRF?? // Not implemented in fhemduino -> see fhemduino.pm
  if(defined($attr{$a[0]}) && defined($attr{$a[0]}{"switch_rfmode"})) {
  	if ($attr{$a[0]}{"switch_rfmode"} eq "1") {			# do we need to change RFMode of IODev
      my $ret = CallFn($io->{NAME}, "AttrFn", "set", ($io->{NAME}, "rfmode", "SlowRF"));
    }	
  }

  ## Do we need to change HXrepetition ??	
  if(defined($attr{$a[0]}) && defined($attr{$a[0]}{"HXrepetition"})) {
  	$message = "hr".$attr{$a[0]}{"HXrepetition"};
    $msg = CallFn($io->{NAME}, "GetFn", $io, (" ", "raw", $message));
    if ($msg =~ m/raw => $message/) {
 	  Log GetLogLevel($a[0],4), "FHEMduino_HX: Set HXrepetition: $message for $io->{NAME}";
    } else {
 	  Log GetLogLevel($a[0],4), "FHEMduino_HX: Error set HXrepetition: $message for $io->{NAME}";
    }
  }

  my $v = join(" ", @a);
  $message = "hs".$hash->{XMIT}."111".$hash->{$c};

  ## Log that we are going to switch InterTechno
  Log GetLogLevel($a[0],2), "FHEMduino_HX set $v IO_Name:$io->{NAME} CMD:$a[1] CODE:$c";
  (undef, $v) = split(" ", $v, 2);	# Not interested in the name...

  ## Send Message to IODev and wait for correct answer
  Log3 $hash, 4, "Messsage an IO senden Message raw: $message";
  $msg = CallFn($io->{NAME}, "GetFn", $io, (" ", "raw", $message));
  if ($msg =~ m/raw => $message/) {
    Log3 $hash, 5, "FHEMduino_HX: Answer from $io->{NAME}: $msg";
  } else {
    Log3 $hash, 5, "FHEMduino_HX: IODev device didn't answer is command correctly: $msg";
  }

  ## Do we need to change HXrepetition back??	
  if(defined($attr{$a[0]}) && defined($attr{$a[0]}{"HXrepetition"})) {
  	$message = "hr".$hx_defrepetition;
    $msg = CallFn($io->{NAME}, "GetFn", $io, (" ", "raw", $message));
    if ($msg =~ m/raw => $message/) {
 	  Log GetLogLevel($a[0],4), "FHEMduino_HX: Set HXrepetition back: $message for $io->{NAME}";
    } else {
 	  Log GetLogLevel($a[0],4), "FHEMduino_HX: Error HXrepetition back: $message for $io->{NAME}";
    }
  }

  # Look for all devices with the same code, and set state, timestamp
  $name = "$hash->{NAME}";
  my $code = "$hash->{XMIT}";
  my $tn = TimeNow();

  foreach my $n (keys %{ $modules{FHEMduino_HX}{defptr}{$code} }) {
    my $lh = $modules{FHEMduino_HX}{defptr}{$code}{$n};
    $lh->{CHANGED}[0] = $v;
    $lh->{STATE} = $v;
    $lh->{READINGS}{state}{TIME} = $tn;
    $lh->{READINGS}{state}{VAL} = $v;
    $modules{FHEMduino_HX}{defptr}{$code}{$name}  = $hash;
  }
  return $ret;
}

#####################################
sub
FHEMduino_HX_Parse($$)
{
  my ($hash,$msg) = @_;
  my @a = split("", $msg);

  my $deviceCode = "";

  if (length($msg) < 4) {
    Log3 "FHEMduino", 4, "FHEMduino_Env: wrong message -> $msg";
    return "";
  }
  my $bitsequence = "";
  my $bin = "";
  my $sound = "";
  my $hextext = substr($msg,1);

  # Bit 8..12 => Sound of door bell
  # 10011 => 1. 2xDing-Dong
  # 10101 => 2. Telefonklingeln
  # 11001 => 3. Zirkusmusik
  # 11101 => 4. Banjo on my knee
  # 11110 => 5. Morgen kommt der Weihnachtsmann
  # 10110 => 6. It’s a small world
  # 10010 => 7. Hundebellen
  # 10001 => 8. Westminster
  # 1111 111 11111
  # 0    4   7
  $bitsequence = hex2bin($hextext); # getting message string and converting in bit sequence
  $bin = substr($bitsequence,0,4);
  $deviceCode = sprintf('%X', oct("0b$bin"));
  $sound = substr($bitsequence,7,5);

  Log3 $hash, 4, "FHEMduino_HX: $msg";
  Log3 $hash, 4, "FHEMduino_HX: $hextext";
  Log3 $hash, 4, "FHEMduino_HX: $bitsequence $deviceCode $sound";

  
  my $def = $modules{FHEMduino_HX}{defptr}{$hash->{NAME} . "." . $deviceCode};
  $def = $modules{FHEMduino_HX}{defptr}{$deviceCode} if(!$def);
  if(!$def) {
    Log3 $hash, 1, "FHEMduino_HX UNDEFINED sensor HX detected, code $deviceCode";
    return "UNDEFINED HX_$deviceCode FHEMduino_HX $deviceCode";
  }
  
  $hash = $def;
  my $name = $hash->{NAME};
  return "" if(IsIgnored($name));
  
  Log3 $name, 5, "FHEMduino_HX: actioncode: $deviceCode";  
  
  $hash->{lastReceive} = time();
  $hash->{lastValues}{FREQ} = $sound;

  Log3 $name, 4, "FHEMduino_HX: $name: $sound:";

  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash, "state", $sound);
  readingsEndUpdate($hash, 1); # Notify is done by Dispatch

  return $name;
}

sub
FHEMduino_HX_Attr(@)
{
  my @a = @_;

  # Make possible to use the same code for different logical devices when they
  # are received through different physical devices.
  return if($a[0] ne "set" || $a[2] ne "IODev");
  my $hash = $defs{$a[1]};
  my $iohash = $defs{$a[3]};
  my $cde = $hash->{CODE};
  delete($modules{FHEMduino_HX}{defptr}{$cde});
  $modules{FHEMduino_HX}{defptr}{$iohash->{NAME} . "." . $cde} = $hash;
  return undef;
}

sub
hex2bin($)
{
  my $h = shift;
  my $hlen = length($h);
  my $blen = $hlen * 4;
  return unpack("B$blen", pack("H$hlen", $h));
}

sub
bin2dec($)
{
  my $h = shift;
  my $int = unpack("N", pack("B32",substr("0" x 32 . $h, -32))); 
  return sprintf("%d", $int); 
}

1;

=pod

=begin html

<a name="FHEMduino_HX"></a>
<h3>tbd</h3>
<ul>
</ul>

=end html

=begin html_DE

<a name="FHEMduino_HX"></a>
<h3>tbd</h3>
<ul>
</ul>

=end html_DE

=cut
