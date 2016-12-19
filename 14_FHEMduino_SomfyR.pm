###########################################
# FHEMduino SomfyR Modul (window shades - currently only receive)
# Special case SOMFYR will only support mapping of somfy remotes to the real devices in FHEM 
# receives the signal from a SOMFY remote and maps this to the device in FHEM 
# 2016-12-09 - added rolling code as reading

use strict;
use warnings;


#####################################
sub
FHEMduino_SomfyR_Initialize($)
{
  my ($hash) = @_;

# Msg format:
# Ys AB 2C 004B 010010
# address needs bytes 1 and 3 swapped
  $hash->{Match}     = "^Ys .. .. .... ......\$";
  $hash->{DefFn}     = "FHEMduino_SomfyR_Define";
  $hash->{UndefFn}   = "FHEMduino_SomfyR_Undef";
  $hash->{AttrFn}    = "FHEMduino_SomfyR_Attr";
  $hash->{ParseFn}   = "FHEMduino_SomfyR_Parse";
  $hash->{AttrList}  = "IODev do_not_notify:0,1 showtime:0,1 ignore:0,1 rawDevice ".
                       $readingFnAttributes;
}


#####################################
sub
FHEMduino_SomfyR_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);

  # fail early and display syntax help
	if ( int(@a) != 3 ) {
		return "wrong syntax: define <name> SomfyR address ";
	}
	# check address format (6 hex digits)
	if ( ( $a[2] !~ m/^[a-fA-F0-9]{6}$/i ) ) {
		return "Define $a[0]: wrong address format: specify a 6 digit hex value "
	}

	# group devices by their address
	my $name  = $a[0];
	my $address = $a[2];

	my $tn = TimeNow();
	
	$hash->{ADDRESS} = uc($address);

  $modules{FHEMduino_SomfyR}{defptr}{$address} = $hash;
  AssignIoPort($hash);
  if(defined($hash->{IODev}->{NAME})) {
    Log3 $name, 4, "$name: I/O device is " . $hash->{IODev}->{NAME};
  } else {
    Log3 $name, 1, "$name: no I/O device";
  }

  return undef;
}

#############################
sub FHEMduino_SomfyR_Undef($$) {
	my ( $hash, $name ) = @_;

  my $addr = $hash->{ADDRESS};

  delete( $modules{FHEMduino_SomfyR}{defptr}{$addr} );

	return undef;
}


#############################
sub FHEMduino_SomfyR_Parse($$){ 

# Msg format:
# Ys AB 2C 004B 010010
# address HAS ALREADY bytes 1 and 3 swapped

	my ($hash, $msg) = @_;

	if (substr($msg, 0, 3) ne "Ys " ) {
		# NOt matching command Ys
		Log3 $hash, 1, "FHEMduino_SomfyR can't decode $msg";
		return "";
	}
	# get address
#	my $address = uc(substr($msg, 14, 6));
	my $address = uc(substr($msg, 18, 2) . substr($msg, 16, 2) . substr($msg, 14, 2));

	# get command and adapt
	my $cmd = sprintf("%X", hex(substr($msg, 6, 2)) & 0xF0);
	if ($cmd eq "10") {
		$cmd = "11"; # use "stop" instead of "go-my"
	}

  # Only command and address are needed	
	my $rolling = substr($msg, 9, 4);

	# Identify the SomfyRemote module
	my $srh;
  $srh = $modules{FHEMduino_SomfyR}{defptr}{$hash->{NAME} . "." . $address};
  $srh = $modules{FHEMduino_SomfyR}{defptr}{$address} if(!$srh);

	# Identify the SomfyRemote module by assigned raw device and then assign as ignored
  if(!$srh) {
    foreach my $d (keys %defs) {
      if($defs{$d}{TYPE} eq "FHEMduino_SomfyR") {
				my $rd = AttrVal( $defs{$d}{NAME}, 'rawDevice', undef );
					if ( defined( $rd )) {
					Log3 $hash, 5, "FHEMduino_SomfyR check for rawdevice in " . $defs{$d}{NAME} . " - " . $rd;
					if( $address eq uc($rd) ) {
						Log3 $hash,  4, "FHEMduino_SomfyR found right address " . $defs{$d}{NAME};
						$srh = $defs{$d};
					}
				}
			}
    }
		if($srh) {
			# Special case found the address only in RAWDEVICE
			# no further processing, since this command is coming from 
			return $srh->{NAME};
		}
	}
	
  if(!$srh) {
    Log3 $hash, 1, "FHEMduino_SomfyR undefined sensor detected, address $address";
    return "UNDEFINED FHEMduino_SomfyR_$address FHEMduino_SomfyR $address";
  }
  
  $hash = $srh;

	# set text command
	my $txtcmd = "stop";
	if ( $cmd == 20 ) {
		$txtcmd =  "off";
	} elsif ( $cmd == 40 ) {
		$txtcmd =  "on";
	} elsif ( $cmd == 80 ) {
		$txtcmd =  "prog";
	}

	# detect duplicate message
	if ( $msg eq $hash->{lastMsg}) {
    Log3 $hash, 4, "FHEMduino_SomfyR reject duplicate message :$msg:";
		return $hash->{NAME};
	}
	$hash->{lastMsg} = $msg;
	
  # Identify the SOMFY device by using rawdevice	
	my $name = $hash->{NAME};
	my $rawdAttr = AttrVal($name,'rawDevice',undef);

	# check if rdev is defined and exists
  if( defined($rawdAttr) ) {

		# normalize address in rawdev
		$rawdAttr = uc( $rawdAttr );

    my @rawdevs = split( /\s+/, $rawdAttr );
    
    foreach my $rawdev ( @rawdevs ) {

      my $slist =  $modules{SOMFY}{defptr}{$rawdev};
      if ( defined($slist)) {
        foreach my $n ( keys %{ $slist } ) {

          my $rawhash = $modules{SOMFY}{defptr}{$rawdev}{$n};

          Log3 $hash, 4, "FHEMduino_SomfyR - " .  $name . " found SOMFY device " . $rawhash->{NAME} . " sent command :$txtcmd:";
          # convert message to change address (leave rest unchanged)  ????
          
          my $rawadr = $rawhash->{ADDRESS};
          # build Ys meesage for disptching in Somfy Parse   ????
          my $rawmsg = "YsA0" . sprintf( "%X", $cmd ) . "00000" . substr($rawadr, 4, 2) . substr($rawadr, 2, 2) . substr($rawadr, 0, 2);

          Log3 $name, 4, "$name: call setFn virtual in " . $rawhash->{TYPE} . "   - " . $rawmsg;

          # third try add virtual as modifier to set command and directly call send
          my $module = $modules{$rawhash->{TYPE}};
          no strict "refs"; 
          my @result = &{$module->{SetFn}}($rawhash,$rawhash->{NAME}, "virtual", $txtcmd);
          use strict "refs";
        }

      } else {
        Log3 $hash, 1, "FHEMduino_SomfyR SOMFY rawDevice $rawdev not found from $name";
      }
    }  
	} else {
		Log3 $hash, 1, "FHEMduino_SomfyR No rawDevice set in $name";
	}
		
  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash, "state", $cmd);
  readingsBulkUpdate($hash, "command", $cmd);
  readingsBulkUpdate($hash, "rollingcode", $rolling);
  readingsEndUpdate($hash, 1); # Notify is done by Dispatch

  return $hash->{NAME};
}


#############################
sub FHEMduino_SomfyR_Attr($$){ 

	my ($cmd,$name,$aName,$aVal) = @_;
	my $hash = $defs{$name};

	return "\"SOMFY Attr: \" $name does not exist" if (!defined($hash));

	# $cmd can be "del" or "set"
	# $name is device name
	# aName and aVal are Attribute name and value
	if ($cmd eq "set") {

		if ($aName eq 'rawDevice') {
			$attr{$name}{'rawDevice'} = $aVal;
		}
	}

	return undef;
}

##########################################################################
##########################################################################

1;


=pod
=begin html

<a name="FHEMduino_SomfyR"></a>
<h3>FHEMduino_SomfyR</h3>
<ul>
  The FHEMduino_SomfyR module interprets SomfyRTS messages received by the FHEMduino and propagates them to the corresponding SOMFY device to update state.
  <br><br>

  To allow steering of Somfy devices with Somfy Manual Remotes and FHEM in parallel, two devices are needed one FHEMduino_SomfyR device representing the manual remote control and in addition the corresponding <a href="#SOMFY">SOMFY</a> RTS device both representing (and controlling) the same physical SOMFY receiver. Both devices in FHEM have different addresses. The connection is achieved by adding the address of the <a href="#SOMFY">SOMFY</a> RTS device as value for the rawDevice attribute in the FHEMduino_SomfyR device.

  <br>
  <br>

  <a name="FHEMduino_SomfyRdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; FHEMduino_SomfyR &lt;address&gt;</code> <br>

    <br>
    &lt;address&gt; is the address of the corresponding somfy device that is sent with every message
  </ul>
  <br>

  <a name="FHEMduino_SomfyRset"></a>
  <b>Set</b> <ul>N/A</ul><br>

  <a name="FHEMduino_SomfyRget"></a>
  <b>Get</b> <ul>N/A</ul><br>

  <a name="FHEMduino_SomfyRattr"></a>
  <b>Attributes</b>
  <ul>
    <a name="rawDevice"></a>
    <li>rawDevice<br>
        Specifies the address (or multiple addresses by space separated) of the <a href="#SOMFY">SOMFY</a> RTS device. <br>
			  The corresponding command is then forwarded as virtual command to the SOMFY device to update state there. 
				The specific modifier virtual is added to the set command on the SOMFY device to avoid any IO being sent.
				So instead of <br><br>
					<code>set &lt;somfy-device&gt; &lt;command e.g. close|on&gt;</code> <br><br>
				the following command is send (via function invocation in SOMFY)	<br><br>
					<code>set &lt;somfy-device&gt; virtual &lt;command e.g. close|on&gt;</code> <br>
		</li><br>

    <a name="ignore"></a>
    <li>ignore<br>
        Ignore this device, e.g. if it belongs to your neighbour. The device
        won't trigger any FileLogs/notifys, issued commands will silently
        ignored (no RF signal will be sent out, just like for the <a
        href="#attrdummy">dummy</a> attribute). The device won't appear in the
        list command (only if it is explicitely asked for it), nor will it
        appear in commands which use some wildcard/attribute as name specifiers
        (see <a href="#devspec">devspec</a>). You still get them with the
        "ignored=1" special devspec.
        </li><br>


    <li><a href="#IODev">IODev</a></li>
    <li><a href="#do_not_notify">do_not_notify</a></li>
    <li><a href="#eventMap">eventMap</a></li>
    <li><a href="#showtime">showtime</a></li>
  </ul>
</ul>

=end html
=cut



