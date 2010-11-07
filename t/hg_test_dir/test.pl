use File::Basename  ();
use Data::Dumper;
$filename = '/home/mm/hg/test.pl';
print File::Basename::dirname($filename);


$filename = '/home/mm/hg';
print File::Basename::dirname($filename);

my @test = qw (1 2 3 4 5 6 7);

print join('/', @test[0..4]);