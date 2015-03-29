###########################################
# FHEMduino SomfyR Modul (window shades - currently only receive)
# Special case SOMFYR will only support mapping of somfy remotes to the real devices in FHEM 
# receives the signal from a SOMFY remote and maps this to the device in FHEM 


# TODO? : propagate to SOMFY
# TODO? : check if IODev is needed as attr{$name}
# TODO? : check org-addr


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
    Log3 $name, 3, "$name: I/O device is " . $hash->{IODev}->{NAME};
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
		Log3 $hash, 5, "FHEMduino_SomfyR can't decode $msg";
		return "";
	}
	# get address
	my $address = uc(substr($msg, 14, 6));

	# get command and adapt
	my $cmd = sprintf("%X", hex(substr($msg, 6, 2)) & 0xF0);
	if ($cmd eq "10") {
		$cmd = "11"; # use "stop" instead of "go-my"
	}

  # Only command and address are needed	

	# Identify the SomfyRemote module
  my $def = $modules{FHEMduino_SomfyR}{defptr}{$hash->{NAME} . "." . $address};
  $def = $modules{FHEMduino_SomfyR}{defptr}{$address} if(!$def);
  if(!$def) {
    Log3 $hash, 1, "FHEMduino_SomfyR undefined sensor detected, address $address";
    return "UNDEFINED FHEMduino_SomfyR_$address FHEMduino_SomfyR $address";
  }
  
  $hash = $def;

  # Identify the SOMFY device by using rawdevice	
	my $name = $hash->{NAME};
	my $rawdev = AttrVal($name,'rawDevice',undef);

	# check if rdev is defined and exists
  if( defined($rawdev) ) {
		my $rawhash = $defs{$rawdev};
		if ( defined($rawhash)) {
			# convert message to change address (leave rest unchanged)  ????
			
			my $rawadr = $rawhash->{ADDRESS};
			# build Ys meesage for disptching in Somfy Parse   ????
			my $rawmsg = "YsA0" . sprintf( "%X", $cmd ) . "00000" . substr($rawadr, 4, 2) . substr($rawadr, 2, 2) . substr($rawadr, 0, 2);

      Log3 $name, 1, "$name: call parseFn in " . $rawhash->{TYPE} . "   - " . $rawmsg;

			# third try add nosend as modifier to set command and directly call send
			my $txtcmd = "stop";
			if ( $cmd == 20 ) {
				$txtcmd =  "off";
			} elsif ( $cmd == 40 ) {
				$txtcmd =  "on";
			} elsif ( $cmd == 80 ) {
				$txtcmd =  "prog";
  		}

		  my $module = $modules{$rawhash->{TYPE}};
			no strict "refs"; 
			my @result = &{$module->{SetFn}}($rawhash,$rawhash->{NAME}, "nosend", $txtcmd);
			use strict "refs";
			


			# second try call parseFN of module directly
#		  my $module = $modules{$rawhash->{TYPE}};
#			no strict "refs"; 
#			my @result = &{$module->{ParseFn}}($rawhash,$rawmsg);
#			use strict "refs";
			# dispatch again (recursive ???)
#      Dispatch($defs{$rawdev}, $rawmsg, undef);
		} else {
			Log3 $hash, 1, "FHEMduino_SomfyR SOMFY rawDevice not found $rawdev";
		}
	} else {
		Log3 $hash, 1, "FHEMduino_SomfyR No rawDevice set";
	}
		
  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash, "state", $cmd);
  readingsBulkUpdate($hash, "command", $cmd);
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

  <br>

</ul>

=end html
=cut



