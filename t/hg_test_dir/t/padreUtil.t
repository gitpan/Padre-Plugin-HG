use Padre::Util;
use File::Find;
print Padre::Util::get_project_rcs('/home/mm/hg');


 finddepth(\&wanted,  ('/home/mm/hg'));
 
 sub wanted
 {
  
	print $File::Find::dir ."\n";
    if -e File::Spec->catfile( $dir, 'Makefile.PL' );

 }