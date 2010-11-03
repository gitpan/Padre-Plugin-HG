package Padre::Plugin::HG::StatusTree;
=pod

=head1 NAME

Padre::Plugin::HG::StatusTree
Displays the status of the current hg project in a tree format

=head1 SYNOPSIS

 my $object = Padre::Plugin::HG::StatusTree->new($self,$project_root);

=head1 DESCRIPTION

This module diplays a tree in the left panel of the ide that shows
the mecurial status of each file.  
Right clicking on a file will give you options to perform actions.  Right clicking the
project root will give you project wide options. 

=head1 METHODS

=cut

use strict;
use warnings;

our $VERSION = '0.01';

use Padre::Wx;
use Padre::Util qw/_T/;
use Wx qw/WXK_UP WXK_DOWN wxTR_HAS_BUTTONS  wxTR_HIDE_ROOT  /;
use base 'Wx::Panel';
use Padre::Plugin::My;
use File::Spec;
use File::Basename;
my $HG;
my %dirTree;
my $project_name;
my %WxTree;
my $ThisTree;


  #setup the image list 
  my $images = Wx::ImageList->new( 16, 16 );
        my $file_types = {
                M => $images->Add(
	                        Wx::ArtProvider::GetBitmap( 'wxART_TIP', 'wxART_OTHER_C', [ 16, 16 ] ),
                ),
                dir => $images->Add(
                        Wx::ArtProvider::GetBitmap( 'wxART_FOLDER', 'wxART_OTHER_C', [ 16, 16 ] ),
                ),
                C => $images->Add(
                        Wx::ArtProvider::GetBitmap( 'wxART_TICK_MARK', 'wxART_OTHER_C', [ 16, 16 ] ),
                ),
                '?' => $images->Add(
                        Wx::ArtProvider::GetBitmap( 'wxART_MISSING_IMAGE', 'wxART_OTHER_C', [ 16, 16 ] ),
                ),
          };
  



my @root = qw (root root);

=pod

=head2 new

 Creates and displays the status tree
 $tree = Padre::Plugin::HG::StatusTree->new($self, $project_root);

=cut

sub new
{
  my ($class, $hg, $root) = @_;
  $project_name = $root;
  $HG = $hg;

  my $self       = $class->SUPER::new( Padre::Current->main->left );
  my $box        = Wx::BoxSizer->new(Wx::wxVERTICAL);
  my $treectrl = Wx::TreeCtrl->new( $self, -1 );
  $treectrl->AssignImageList($images);

  $self->drawTree($treectrl);
  Wx::Event::EVT_TREE_ITEM_MENU(
         $treectrl, $treectrl,
         \&_on_tree_item_menu,
  );
  
  #Double Click
  Wx::Event::EVT_TREE_ITEM_ACTIVATED(
            $treectrl, $treectrl,
             \&_on_tree_item_activated
  );
  
  $box->Add( $treectrl, 1, Wx::wxGROW );

  $self->SetSizer($box);  
  Padre::Current->main->left->show($self);
  $ThisTree = $self;
  return $self;
   
}


=pod

=head2 gettext_label

        Works out what to name the tab for the project.

=cut

sub gettext_label {
        
         my @dirs = File::Spec->splitdir( $project_name );
         my $name = File::Spec->catdir(('..',$dirs[-2], $dirs[-1]));
         chomp $name;
        return "(HG) ".$name;
}

=pod

=head2 getWxNode

        Add the nodes to the tree. 
        getWxNode($treectrl,[name,parent,type],path);
=cut

sub getWxNode
{
    my ($treectrl,$node,$path) = @_;
    
    my $name = $node->[0];
    my $parent = $node->[1];
    my $type = $node->[2];
    chomp $path;
    chomp $name;
    if (exists($WxTree{$path}))
    {
      return $WxTree{$path};
      # $WxTree{$path} = $treectrl->AppendItem( $WxTree{$parent}, $name);
      
    }else
    {
        $WxTree{$path} = $treectrl->AppendItem( 
                  getWxNode($treectrl, $dirTree{$parent}, $parent), 
                            $name, 
                            $file_types->{$type},
                             -1,
                             Wx::TreeItemData->new(
                                            {   name => $name,
                                                path  => $path,
	                                        type => $type,
	                                }));
    }
  
  
}

=pod

=head2 parseHgStatus

 $self->parseHgstatus(@hgstatus);
 parses the output of HGstatus and calls create branch for each item.
 
=cut

sub parseHgStatus
{
      my (@hgstatus) = @_;
      
      foreach my $line (@hgstatus)
      {
        my ($filestatus, $path) = split(/\s/,$line);
        chomp $path;
        my @dir =  split(/\//,$path);
        createBranch(\@dir,$filestatus);
               
      }
  
  
  
}

=pod

=head2 createBranch

 $self->parseHgstatus(@hgstatus);
 parses the output of HGstatus and calls create branch for each item.
 
=cut


sub createBranch
{
  
  my ($dirRef, $status) = @_;
  my @dir = @$dirRef;
  my $count = 0;
  my %parentChild;
  foreach my $item (@dir)
  {
    my $type;
    my $parent = '';
    if ($count == 0 ) 
    { 
      $parent = $dirTree{root}->[0]; 
    }
    else
    {
      $parent= join('/',@dir[0..$count -1 ]);
    }
    my $node = join('/',@dir[0..$count]);
    if (!exists($dirTree{$node}))
    {

	     if ($count < (scalar(@dir) -1))
	     {
	       $type = 'dir';
	     }
	     else
	     {
	       $type = $status;
	     }
	     $dirTree{$node} = [$item, $parent, $type];
    }
    
     $count ++;
  }
  #return %dirTree;
}

=pod

=head2 drawTree

 $self->drawTree($treectrl);
 creates the Tree from the output of the vcs status
 
=cut

sub drawTree {
  my ($self,$treectrl) = @_;
  
  %WxTree = ();
  $WxTree{root} = $treectrl->AddRoot( 
                        $project_name, 
                        $file_types->{dir},
                        -1,
                        Wx::TreeItemData->new(
                                            {   name => 'root',
                                                path  => '',
	                                        type => 'root',
	                                })  ); 
    
 
  %dirTree = ();
  $dirTree{root} = ['root', 'root', 'dir'];
  chdir ($project_name);
  my @hgStatus = `hg status --all`;
  chomp (@hgStatus);
  parseHgStatus(@hgStatus);
  foreach my $file  (keys(%dirTree))
  {
       my $path = File::Spec->catdir($project_name,$file);
       my $dir = File::Basename::dirname($path);
       print $path."\n";
       getWxNode($treectrl, $dirTree{$file}, $file);      
  }


}
=pod

=head2 _on_tree_item_activated

        Performs actions when the users double clicks on a tree node
        
 
=cut
 
sub _on_tree_item_activated
{
	
	my ( $self, $event,$me ) = @_;
	my $node      = $event->GetItem;
        my $node_data = $self->GetPlData($node);
	my $selected_path  = $node_data->{path};
        my $selected_file = $node_data->{name};
        my $selected_type = $node_data->{type};
        my $full_path = File::Spec->catdir(($project_name,$selected_path));

        if ($selected_type ne 'dir' and $selected_type ne 'root')
        {
                open_file($full_path);
        }
        

}

=pod

=head2  _on_tree_item_menu

        Called when a user right clicks a node in the tree
        Shows different options depending if a file/dir or root
        is selected. 
        
 
=cut
sub _on_tree_item_menu {
        my ( $self, $event,$me ) = @_;
        my $node      = $event->GetItem;
        my $node_data = $self->GetPlData($node);
        my $menu          = Wx::Menu->new;
        # Default action - same when the item is activated
        my $selected_path  = $node_data->{path};
        my $selected_file = $node_data->{name};
        my $selected_type = $node_data->{type};
        my $full_path = File::Spec->catdir(($project_name,$selected_path));
        print "selected Path = $selected_path\n";
        my $parent_dir = File::Basename::dirname($full_path);
        #Commit
        if ($selected_type eq 'root')
        {
               print "ParentDir". $parent_dir ."\n";
                my $default = $menu->Append(
                        -1,
                       Wx::gettext( 'Refresh' ));
                    
                Wx::Event::EVT_MENU(
                       $self, $default,
                       sub { $ThisTree->refresh($self) }
               );   
               my $pull = $menu->Append(
                        -1,
                       Wx::gettext( 'Pull & Update' ));
                    
                Wx::Event::EVT_MENU(
                       $self, $pull,
                        sub {  $HG->pull_update_project($selected_file, $project_name) }
               );    
               my $push = $menu->Append(
                        -1,
                       Wx::gettext( 'Push' ));
                    
                Wx::Event::EVT_MENU(
                       $self, $push,
                       sub {  $HG->push_project($selected_file, $project_name) }
               );   
        }
        
        elsif ($selected_type ne 'dir' and $selected_type ne 'root')
        {
                my $default = $menu->Append(
                        -1,
                       Wx::gettext( 'Commit' ));
                    
                Wx::Event::EVT_MENU(
                       $self, $default,
                       sub { $HG->vcs_commit($selected_file, $parent_dir ); $ThisTree->refresh($self)}
               );
               
               #Add
               my $add = $menu->Append(
                         -1,
                       Wx::gettext( 'Add' ));
                    
                Wx::Event::EVT_MENU(
                       $self, $add,
                       sub { $HG->vcs_add($selected_file, $parent_dir);$ThisTree->refresh($self)}
               );   
               
               #diff (just diffs current file to Tip) 
               my $diff = $menu->Append(
                         -1,
                       Wx::gettext( 'Diff to Tip' ));
                    
                Wx::Event::EVT_MENU(
                       $self, $diff,
                       sub { $HG->vcs_diff($selected_file, $parent_dir);}
               );  
               
               #open 
               my $open = $menu->Append(
                         -1,
                       Wx::gettext( 'Open' ));
                    
                Wx::Event::EVT_MENU(
                       $self, $open,
                       sub{open_file($full_path)}
               ); 
               
                 
       }
       
       
        my $x = $event->GetPoint->x;
        my $y = $event->GetPoint->y;
        $self->PopupMenu( $menu, $x, $y );
        

}


=pod

=head2  open_file

        open_file($path)
        opens the file in the editor. 
        
 
=cut
sub open_file
{ 
     	 my ($path) = @_;
     	        my $main = Padre->ide->wx->main;
	        if ( my $id = $main->find_editor_of_file($path) ) {
	                my $page = $main->notebook->GetPage($id);
	                $page->SetFocus;
	        } else {
	                $main->setup_editors($path);
	        }
}

=pod

=head2  refresh

        $self->refresh();
        refreshes the tree control by deleteing all items and 
        readding them. 
 
=cut

sub refresh {
    my ($self, $treeCtrl) = @_;
        $treeCtrl->DeleteAllItems;
        $self->drawTree($treeCtrl); 
    return ();
}
1;