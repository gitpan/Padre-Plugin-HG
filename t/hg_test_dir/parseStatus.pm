#!/usr/bin/perl
use 5.006;
use strict;
use warnings;
use File::Basename ();

  

my %dirTree;


$dirTree{root} = 'root';# = treectrl->AppendRoot('.');





sub createBranch
{
  
  my (@dir) = @_;
  my $count = 0;
  my %parentChild;
  foreach my $item (@dir)
  {
    my $parent = '';
    if ($count == 0 ) 
    { 
      $parent = $dirTree{root}; 
    }
    else
    {
      $parent= join('/',@dir[0..$count -1 ]);
    }
    my $node = join('/',@dir[0..$count]);
    if (!exists($dirTree{$node}))
    {

	     $dirTree{$node} = [$item, $parent];
	   #  $parentChild{$node} = $item;
	  #   print "$parent  >> $item\n";
	     #$dirTree{$item} = '';# $treectrl->AppendItem( $parent, $item );
    }
    
     $count ++;
  }
  return %dirTree;
}

1;