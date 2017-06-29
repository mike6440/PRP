#!/usr/bin/perl -w

my $setup = shift();

my $ip = FindInfo($setup,"SERIAL HUB URL", ":");
print "<<$ip>>\n";

exit 0;

#*************************************************************/
sub FindInfo
# sub FindInfo;
# Search through a file line by line looking for a string
# When the string is found, remove $i characters after the string.
# ==== CALLING ====
# $strout = FindInfo( $file, $string, [$splt],  [$ic] )
# ==== INPUT ===
# $file is the file name with full path
# $string is the search string (NOTE: THIS IS A REGEX STRING,
# $splt (optional) is the regex for the split of the line. (typically :)
# $ic (optional) is the number of characters to extract after the split.
#    If $ic is negative then characters before the string are extracted.
#
# ver1.2 rmr 060718 -- preset $strout to default;
# ver 1.3 rmr 061013 -- remove leading spaces
{
	my @v = @_;
	my @cwds;
	my ($fn, $strin, $splt, $strout, $ic, $str, $rec);
	$fn = shift;  
	$strin = shift; 
	if ( $#v > 1 ) { 
		$splt = shift;
		if ( $#v > 2 ) { $ic = shift } else { $ic = 0 }	
	} else {
		$splt = $strin;
		$ic = 0;
	}
# 	print "FindInfo: fn=$fn, strin=$strin, splt = $splt,  ic=$ic\n";
	$strout = 'String not found';
	# OPEN THE CAL FILE
	open(Finfo, "<$fn") or die("FILEINFO OPEN FILE FAILS, $fn");
	$rec=0;
	while ( <Finfo>) {
		$rec++;
		if ( $rec >= 500 ) { 
			$strout = 'String not found in first 100 records';
			last;
		}
		else {
			# clean the line (a.k.a. record)
			chomp($str=$_);
			#print "$rec: $str\n";
			
			# check to see if this record matches
			if ( $str =~ /$strin/ ) {
				#print "FOUND $strin\n";
				
				# if so, remove all of the string after the split string, usually ': '
				@cwds = split(/$splt/, $str);
# 				foreach(@cwds){print "$_\n"}

				# simple, read the entire string following the match
				if ( $ic == 0 ) { $strout = $cwds[1] }
				# read only the next ic characters after the match
				if ($ic > 0) { $strout = substr($cwds[1],0,$ic) }
				# read the ic characters before the match
				if ( $ic < 0 ) { $strout = substr( $cwds[0],-1,$ic ) }
				
				## remove leading spaces
				$strout =~ s/^\s+//;
				last;
			}
		}
	}
	
	close(Finfo);
	return $strout;
}
