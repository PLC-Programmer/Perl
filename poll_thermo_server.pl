#############################################################################
#
# UDP_thermo_server.pl
#
# formally checked with: perlcritic -5 poll_thermo_server.pl
#
# poll temperature data (via UPD messaging) from Ethernetbox Ethernet Thermometer, i.e. network server
# so far only one sensor is being read: see $sensor
#
# RSa, 2012-12-29, 2013-01-05, 2016-10-27/28/29/31
#
# needs installed Perl modules: none
#
# Test on Win7, SP1, Perl v5.22.2: OK
#
# Test on Ubuntu 16.04 LTS with Perl v5.22.1 implementation: OK
#   - autostart with /etc/rc.local (which is systemd compliant):
#       cd /home/booser/scripts/UDP_thermo_client
#       (/usr/bin/perl /home/booser/scripts/UDP_thermo_client/poll_thermo_server.pl)&
#   - test: OK, but doesn't work anymore when user booser is logged out from the GUI!
#
#   => better to have a dedicated Unit file "UDP_thermo_server.service" in dir /etc/systemd/system/
#      (Ubuntu systemd service since v.15.04):
#
#       [Unit]
#       Description=Running poll_thermo_server.pl script
#
#       [Service]
#       WorkingDirectory=/home/booser/scripts/UDP_thermo_client
#       ExecStart=/usr/bin/perl /home/booser/scripts/UDP_thermo_client/poll_thermo_server.pl 2>&1 >> /var/log/UDP_thermo_server.log
#       Restart=always
#
#       [Install]
#       WantedBy=multi-user.target
#
#     - save "UDP_thermo_server.service" as a UNIX file with new line at its end <<<<<<<<<<<<<<<<<<
#     - sudo chmod 755 /etc/systemd/system/UDP_thermo_server.service
#     - first, test if this job is known:
#       $ systemctl daemon-reload
#       $ systemctl enable UDP_thermo_server.service
#       $ systemctl start UDP_thermo_server.service
#       => test: OK
#     => test after a reboot: OK
#
#
# further developments:
#   -
#
#
#############################################################################

use strict;
use warnings;

### adapt here: #############################################################
use constant THERMOMETER  => '192.168.0.119';  # this is the IP address of the thermometer
use constant ASK_PORT     => '4000';           # this is the standard port number of the network server
use constant WAIT_OUT     => '60';             # this is the time interval in seconds between 2 individual polls
use constant AVERAGE      => 15;               # number of temperature values for one average temperature
                                               #   => write a temp.value every [AVERAGE] minutes
my $COM                   = 'com1';            # define the COM port of the Ethernetbox
my $sensor                = '1';               # define the port number with the temp. sensor
my $log_file              = "/home/booser/scripts/UDP_thermo_client/temperature_log.txt";
my $calib_file            = "calib.txt";
#############################################################################


my $channel               = 'pcmeasure.' . $COM . '.' . $sensor;
# print "\nchannel: $channel";


use constant MAX_MSG_LEN => 2096;
use IO::Socket::INET;


# read the calibration values into the @calib array:
my $i = 0;
my @lines;
my @calib;
open my $CAL, '<', "$calib_file" || die "cannot open $calib_file.txt $!";
while ( <$CAL> ) {
  chomp;
  if ( /^\d/ ) {
    @lines = split( /\t/ );
    $calib[$i][0] = $lines[0];
    $calib[$i][1] = $lines[1];
    $i++;
  }
}
close( $CAL );
my $amount_calib_values = $i;


my $average_cnt  = 0;          # counter for average temperature values
my $request;
my $data;
my $peer_addr;
my @temp_data;


# infinite loop
# wait 1 minute between requests => append 1 average temperature value with time stamp every 15 minutes to a log file
while ( 1 ) {

  my $sock = IO::Socket::INET->new
                      (PeerAddr  =>  THERMOMETER,
                       PeerPort  =>  ASK_PORT
                     # Proto     =>  'udp' #DON'T SET THE PROTOCOL HERE !!!!!!
                      ) || die "cannot bind socket: $@";
  # print "\nsocket: $sock";
  # print "\nprotocol: ", $sock->protocol;


  # should return the number of chars sent  or  undefined value:
  defined ( $request = $sock->send($channel,0) ) || die "send: $!";
  # print "\nnumber of chars sent: $request";

  # should return the address of the sender if SOCKET's protocol supports this; returns an empty string otherwise
  # if there's an error, returns the undefined value:
  defined ($peer_addr = $sock->recv($data,MAX_MSG_LEN,0)) || die "recv: $!";

  my $sensor_match = 'value= \d+\.\d+';      # for extracting the sensor temperature value
  my $valid_value  = 'valid=1;';            # pattern for a valid sensor value
  # print "\ndata = $data";

  if ( $data =~ /$valid_value/ ) {

    my $temperature  = '-100.00';            # dummy to show invalid temperature
    if ( $data =~ /$sensor_match/ ) {
      $temperature  = $&;
      $temperature  =~ s/value\= //;
    }

    $temperature  += &calibration( $temperature );  # "calibration"

    # filling the temperature array up to AVERAGE elements
    if ( $average_cnt < AVERAGE - 1 ) {
      push( @temp_data, $temperature );  #
      $average_cnt++;
    }
    else {
      push( @temp_data, $temperature );
      my $sum = 0;                            # building the average
      foreach ( @temp_data ) {
        # print "\n  $_";
        $sum  += $_;
      }
      $temperature = $sum / AVERAGE;
      @temp_data  = ( 0 );

      my $day   = sprintf("%02u", (localtime)[3]);
      my $month = sprintf("%02u", (localtime)[4] + 1);
      my $year  = sprintf("%02u", (localtime)[5] + 1900);
      my $date  = "$year/$month/$day";      # this order is for easier sorting later

      my $time  = sprintf("%02u", (localtime)[2]) . ":" . sprintf("%02u", (localtime)[1]) . ":" . sprintf("%02u", (localtime)[0]);

      my $format_temp  = sprintf( "%2.2f", $temperature );

      open my $LOG, '>>', "$log_file" || die "cannot open $log_file $!";
      print $LOG "\n$format_temp\t$date\t$time";
      close( $LOG );

      $average_cnt = 0;
    }
    # print "\naverage_cnt = $average_cnt";
  }

  $sock->close;

  sleep WAIT_OUT;
}


sub calibration {
  my @input = @_;
  my $x  = $input[0];

  # linear interpolation:
  # limit check:
  die "Temperature out of calibration limits!\n" if ( $x < $calib[0][0] or $x > $calib[4][0] );

  # look up lower limit
  for ( $i = 0; $i < $amount_calib_values; $i++ ) {
    last if $x > $calib[$i][0];
  }
  $i -= 1;

  my $y  = $calib[$i][1] + ($calib[$i+1][1] - $calib[$i][1]) * ($x - $calib[$i][0]) / ($calib[$i+1][0] - $calib[$i][0]);

  return $y;
}



__END__


# Win7. 2016-10-27, 22:33h:
f:\XDi_Scripts\Perl\UDP thermo client>perl -w poll_thermo_server.pl

channel: pcmeasure.com1.1
socket: IO::Socket::INET=GLOB(0x4ec6f0)
protocol: 6
number of chars sent: 16
host replied: valid=1;value= 24.6;

f:\XDi_Scripts\Perl\UDP thermo client>

# temperature_log.txt:

24.92	2016/10/28	17:22:50
24.85	2016/10/28	17:37:53
24.85	2016/10/28	17:52:55
24.92	2016/10/28	18:07:57
24.88	2016/10/28	18:22:59
24.88	2016/10/28	18:38:02

# end of UDP_thermo_server.pl