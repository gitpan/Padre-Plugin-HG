package Padre::Plugin::HG;

use 5.008;
use warnings;
use strict;

use Padre::Config ();
use Padre::Wx     ();
use Padre::Plugin ();
use Padre::Util   ();

use Capture::Tiny  qw(capture_merged);
use File::Basename ();
use File::Spec;

use Padre::Plugin::HG::ProjectCommit;
use Padre::Plugin::HG::ProjectClone;
use Padre::Plugin::HG::UserPassPrompt;
my %projects;
our $VERSION = '0.01';
our @ISA     = 'Padre::Plugin';

my $VCS = "Mercurial";

my %VCSCommand = ( commit => 'hg commit -A -m"$message" $path ',
		add => 'hg add $path',
		status =>'hg status --all $path',
		root => 'hg root', 
		diff => 'hg diff $path',
		clone=> 'hg clone $path',
		pull =>'hg pull --update --noninteractive  ',
		push =>'hg push $path');
		
my %HGStatus = ( M => 'File Modified', 
A => 'File Added not Committed',
R => 'File Removed',
C => 'Up to Date',
'!' => 'Deleted But Still Tracked!',
'?' => 'Not Tracked',
I => 'ignored'
);

=pod

=head1 NAME

Padre::Plugin::HG - Mecurial interface for Padre

=head1 SYNOPSIS

cpan install Padre::Plugin::HG

Access it via Plugin/HG then View Project 


=head1 AUTHOR

Michael Mueller << <michael at muellers.net.au> >>

=head1 BUGS

Please report any bugs or feature requests to L<http://padre.perlide.org/>


=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 Michael Mueller
all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 METHODS

=cut


#####################################################################
# Padre::Plugin Methods

sub padre_interfaces {
	'Padre::Plugin' => 0.24
}

sub plugin_name {
	'HG';
}

sub menu_plugins_simple {
	my $self = shift;
	return $self->plugin_name => [
		'About'             => sub { $self->show_about },
		'View Project'	    => sub {$self->show_statusTree},
		'Add'		    => sub {$self->vcs_add},
		'Clone'		    => sub {$self->show_project_clone},
		'Commit...' 	  => sub { $self->show_commit_list},
	];
}

sub plugin_disable
{
  require Class::Unload;
  Class::Unload->unload('Padre::Plugin::HG::StatusTree;');
}

#####################################################################
# Custom Methods

sub show_about {
	my $self = shift;

	# Generate the About dialog
	my $about = Wx::AboutDialogInfo->new;
	$about->SetName("Padre::Plugin::HG");
	$about->SetDescription( <<"END_MESSAGE" );
Mecurial support for Padre
END_MESSAGE
	$about->SetVersion( $VERSION );

	# Show the About dialog
	Wx::AboutBox( $about );

	return;
}
=pod

=head2 vcs_commit

 performs the commit 
 $self->vcs_commit($filename, $dir);
 will prompt for the commit message.
 
=cut

sub vcs_commit {
	my ($self, $path, $dir ) = @_;
	my $main = Padre->ide->wx->main;
	
	if (!$self->_project_root($path))
	{
		$main->error("File not in a $VCS Project", "Padre $VCS" );
		return;
	}

	my $message = $main->prompt("$VCS Commit of $path", "Please type in your message", "MY_".$VCS."_COMMIT");
	if ($message) {
		
		my $command = eval "qq\0$VCSCommand{commit} $path\0";
		my $result = $self->vcs_execute($command, $dir);
		$main->message( $result, "$VCS Commiting $path" );
	}

	return;	
}

=pod

=head2 vcs_add

 Adds the file to the repository
 $self->vcs_add($filename, $dir);
 will prompt for the commit message.
 
=cut

sub vcs_add {
	my ($self, $path, $dir) = @_;
	my $main = Padre->ide->wx->main;
	my $command = eval "qq\0$VCSCommand{add} $path\0";
	my $result = $self->vcs_execute($command,$dir);
	$main->message( $result, "$VCS Adding to Repository" );
	return;	
}

=pod

=head2 vcs_add

 Adds the file to the repository
 $self->vcs_diff($filename, $dir);
 provides some basic diffing the current file agains the tip

=cut
sub vcs_diff {
	my ($self, $path, $dir) = @_;
	
	my $main = Padre->ide->wx->main;
	my $command = eval "qq\0$VCSCommand{diff} $path\0";
	return $main->error('File not in a $VCS Project', "Padre $VCS" ) if not $self->_project_root($path);
	my $result = $self->vcs_execute($command, $dir);
	use Padre::Wx::Dialog::Text;
	Padre::Wx::Dialog::Text->show($main, "$VCS Diff of $path", $result);
	return;
}

=pod

=head2 clone_project

 Adds the file to the repository
 $self->vcs_diff($repository, $destination_dir);
 Will clone a repository and place it in the destination dir
 
=cut
sub clone_project
{
	my ($self, $path, $dir) = @_;
	my $main = Padre->ide->wx->main;
	my $command = eval "qq\0$VCSCommand{clone}\0";
	my $result = $self->vcs_execute($command, $dir);
	$main->message( $result, "$VCS Cloning $path" );
	return;
}
=pod

=head2 pull_update_project

 Pulls updates to a project. 
 It will perform an update automatically on the repository
 $self->pull_update_project($file, $projectdir);
 Only pulls changes from the default repository, which is normally
 the one you cloned from.

=cut
sub pull_update_project
{
	my ($self, $path, $dir) = @_;
	my $main = Padre->ide->wx->main;
	return $main->error('File not in a $VCS Project', "Padre $VCS" ) if not $self->_project_root($path);
	my $command = eval "qq\0$VCSCommand{pull}\0";
	my $result = $self->vcs_execute($command, $dir);
	$main->message( $result, "$VCS Cloning $path" );
	return;
}
=pod

=head2 push_project

 Pushes updates to a remote repository. 
 Prompts for the username and password. 
 $self->push_project($file, $projectdir);
 Only pushes changes to the default remote repository, which is normally
 the one you cloned from.

=cut
sub push_project
{
	my ($self, $path, $dir) = @_;
	my $main = Padre->ide->wx->main;
	return $main->error('File not in a $VCS Project', "Padre $VCS" ) if not $self->_project_root($path);
	my $config_command = 'hg showconfig';
	my $result1 = $self->vcs_execute($config_command, $dir);	#overwriting path on purpose.
	#overwriting path on purpose.
	#gets the configured push path if it exists
	($path) = $result1 =~ /paths.default=(.*)/;
	return $main->error('No default push path', "Padre $VCS" ) if not $path;
	my ($default_username) = $path =~ /\/\/(.*)@/;
	my $prompt = Padre::Plugin::HG::UserPassPrompt->new(
			title=>'Mecurial Push',
			default_username=>$default_username, 
			default_password =>'');
	my $username = $prompt->{username};
	my $password = $prompt->{password};
	$path =~ s/\/(.*)@/\/\/$username:$password@/g;
	my $command = eval "qq\0$VCSCommand{push}\0";
	my $result = $self->vcs_execute($command, $dir);
	$main->message( $result, "$VCS Pushing $path" );
	return;
}

=pod

=head2 vcs_execute

 Executes a command after changing to the appropriate dir.
 $self->vcs_execute($command, $dir);
 All output is captured and returned as a string.

=cut
sub vcs_execute
{
	my ($self, $command, $dir) = @_;
	my $result = capture_merged(sub{chdir($dir);system($command)});
	return $result;
}

=pod

=head2 show_statusTree

 Displays a Project Browser in the side pane. The Browser shows the status of the
 files in HG and gives menu options to perform actions. 

=cut
sub show_statusTree
{	
	my ($self) = @_;
	require Padre::Plugin::HG::StatusTree;
	my $main = Padre->ide->wx->main;
	my $project_root = $self->_project_root(current_filename());

	return $main->error("Not a $VCS Project") if !$project_root;
	# we only want to add a tree for projects that don't already have one. 
	if (!exists($projects{$project_root}) )
	{
		$projects{$project_root} = Padre::Plugin::HG::StatusTree->new($self,$project_root);	
	}
}

=pod

=head2 show_commit_list

 Displays a list of all the files that are awaiting commiting. It will include
 not added and deleted files adding and removing them as required. 

=cut
sub show_commit_list
{	
	my ($self) = @_;
	my $main = Padre->ide->wx->main;
	 $self->{project_path} = $self->_project_root(current_filename());

	return $main->error("Not a $VCS Project") if ! $self->{project_path} ;
 
	Padre::Plugin::HG::ProjectCommit->showList($self);	

}

=pod

=head2 show_project_clone

 Dialog for project cloning

=cut

sub show_project_clone
{	
	my ($self) = @_;
	my $main = Padre->ide->wx->main;
	my $clone = Padre::Plugin::HG::ProjectClone->new($self);
	if ($clone->enter_repository())
	{
		$clone->choose_destination();
	}
	
	if ($clone->project_url()  and $clone->destination_dir())
	{
		$self->clone_project(
			$clone->project_url(),
			$clone->destination_dir()
			); 
	}
        
    
}	



=pod

=head2 _project_root

 $self->_project_root($filename);
 Calculates the project root.  if the file is not in a project it 
 will return 0 
 otherwise it returns the fully qualified path to the project. 

=cut

sub _project_root
{
	my ($self, $filename) = @_;
	my $dir = File::Basename::dirname($filename);
	my $project_root = $self->vcs_execute($VCSCommand{root}, $dir);
	#file in not in a HG project.
	if ($project_root =~ m/^abort:/)
	{
			$project_root = 0;
	}
	chomp ($project_root);
	return $project_root;
}

=pod

=head2 _get_hg_files

 $self->_get_hg_files(@hgStatus);
  Pass the output of hg status and it will give back an array
  each element of the array is [$status, $filename]

=cut

sub _get_hg_files
{
	my ($self, @hg_status) = @_;
	my @files;
	foreach my $line (@hg_status)
	{
		my ($filestatus, $path) = split(/\s/,$line);
		push (@files, ([$filestatus,$path]));
	}
	return @files;
}

=pod

=head2 current_filename

 $self->current_filename();
  returns the path of the file with the current attention 
  in the ide.

=cut


sub current_filename {

	my $main = Padre->ide->wx->main;
	my $doc = $main->current->document;
	
	my $filename = $doc->filename;
	return $main->error("No document found") if not $filename;
        return ($filename); 
}

=pod

=head2 object_for_testing

 creates a blessed object so we can run our tests. 

=cut

sub object_for_testing
{
	my ($class) = @_;
	my $self = {};
	bless $self,$class;
	
	
}

1;

# Copyright 2008-2009 Michael Mueller.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

