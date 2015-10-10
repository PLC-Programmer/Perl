# FM_raw-csv_into_another-csv_conversion.pl
# RSa, 2015-10-10
#
# Purpose of script:
#   Convert an exported csv file from Fund Manager v.2014 (https://www.fundmanagersoftware.com/)
#   into another csv format for better importability into (German) MS Excel 2007:
#     (a) convert column separating "," into "<Tab>" char sequences
#     (b) delete "," as US thousand separators
#     (c) convert US decimal fractional separator "." into German decimal separator ","
#     (d) leave <words> as <words>
#     (e) delete all string leading and trailing '"' chars
#
# 2.) helper with regular expressions (regexpr):
#     http://www.regexr.com/
#
# 3.) correct indication of imported ~.csv files with MS Excel (2007):
#     => only column A filled with no column separation
#      3a.) mark column A
#      3b.) go to: Data tab -> Data Tools -> Text to Column:
#      3c.) check the separator and other settings -> voilà!
#
#
# Test on Win7 (64Bit), Perl v5.16.3 (MSWin32-x86-multi-thread): OK

use strict;

my $in_file  = $ARGV[0];
my $out_file = $in_file . ".2.csv";

open( OUTPUT, ">$out_file" ) || die "$out_file cannot be created!\n";
open( INPUT, "$in_file" ) || die "$in_file cannot be opened!\n";


while ( <INPUT> ) {
  chomp;
  my @line = split( /","/ );        # split each line into its column strings: do (a), (e)
  my $i = @line;                    # number of column strings in each line
                                    #   -> decrementing counter of column strings
 
   my $col_string;                  # current column string under processing
  
  # loop over a line:
  my $new_line;                     # build a new line from each existing and processed line
  foreach $_ ( @line ) {
    $col_string = $_;
    $col_string =~ s/\"//g;         # do (e) for remaining '"' chars
    
    # test column string for a decimal number, e.g. "-1,989.95":
    my $is_number = 0;              # column string is not a decimal number
    if ( $col_string =~ /-*(\d+,*)+(\.\d+)/g ) {
      $col_string =~ s/\"//g;       # get rid of any '"' from the number
      $col_string =~ s/\,//g;       # do (b)
      $col_string =~ s/\./,/g;      # do (c)
            
      print "number: $col_string\n";
      $is_number = 1;
    }
    else { }                        # column string is not a number and doesn't need any processing
    
    $new_line .= $col_string;
    $i--;
    
    # do (a):
    $new_line .= "\t" if $i > 0;    # $i > 0: no '\t' before EOL
  } 

  print OUTPUT $new_line . "\n";
}


close( INPUT );
close( OUTPUT );


__END__


INPUT file e.g.:
"Investment","Beg Value + Acc Int","Contributions","Withdrawals","With-Distrib.","End Value + Acc Int","Gain","%Gain","Yield"
"PATRIZIA IMMOBILIEN NA ON","0.00","2,257.50","3,327.60","0.00","3,392.25","4,462.35","N.A.","22.05"
"Nexus AG Inh.","0.00","1,657.00","953.00","100.39","4,417.50","3,813.89","631.85","20.43"
"DEUTSCHE WOHNEN AG INH","0.00","2,070.68","0.00","222.99","4,908.42","3,060.73","165.65","27.42"
"SINGULUS TECHNOL.","0.00","2,948.25","463.10","0.00","495.20","-1,989.95","-80.07","-29.82"


OUTPUT file e.g.:
Investment  Beg Value + Acc Int  Contributions  Withdrawals  With-Distrib.  End Value + Acc Int  Gain  %Gain  Yield
PATRIZIA IMMOBILIEN NA ON  0,00  2257,50  3327,60  0,00  3392,25  4462,35  N.A.  22,05
Nexus AG Inh.  0,00  1657,00  953,00  100,39  4417,50  3813,89  631,85  20,43
DEUTSCHE WOHNEN AG INH  0,00  2070,68  0,00  222,99  4908,42  3060,73  165,65  27,42
SINGULUS TECHNOL.  0,00  2948,25  463,10  0,00  495,20  -1989,95  -80,07  -29,82


# end of FM_raw-csv_into_another-csv_conversion.pl
