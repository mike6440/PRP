#!/usr/bin/perl -w

use lib $ENV{DAQLIB};
use perltools::MRtime;

$da=sprintf "$ENV{HOME}/PRP_%s.tar.gz", dtstr(now(),'iso');
print"Archive file: $da\n";


system"tar -zcvf $da $ENV{DAQFOLDER}";
$str = `du -sk $da`;

print"EXPORT COMPLETE size (KB) Name = $str\n";

exit 0
