package Padre::Plugin::HG::ProjectClone;






=pod

=head1 NAME

Module::Name - My author was too lazy to write an abstract

=head1 SYNOPSIS

  my $object = Module::Name->new(
      foo  => 'bar',
      flag => 1,
  );
  
  $object->dummy;

=head1 DESCRIPTION

The author was too lazy to write a description.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

our $VERSION = '0.01';

use Wx qw[:everything];
use base 'Wx::Panel';

=pod

=head2 new

  my $object = Module::Name->new(
      foo => 'bar',
  );

The C<new> constructor lets you create a new B<Module::Install> object.

So no big surprises there...

Returns a new B<Module::Install> or dies on error.

=cut

sub new
{
    my ($class, $hg) = @_; 
    my $self       = $class->SUPER::new( Padre::Current->main);
    $self->{hg} = $hg;
    $self->enter_repository();
    if ($self->{project_url})
    {
        $self->choose_destination();
        $self->clone();
    }
    
    
    return $self;
}

sub clone
{
    my ($self) = @_;
   if ($self->{project_url}  and $self->{selected_dir})
   {
         $self->{hg}->clone_project($self->{project_url},$self->{destination_dir}); 
   }
        
    
}

sub enter_repository
{
 my ($self) = @_;
 my $main = Padre->ide->wx->main;
 my $message = $main->prompt("Clone Project", "Enter the Project URL to clone", 'http://');    
 $self->{project_url} = $message ; 
    
}

sub choose_destination
{
    my ($self) = @_;
    my $dialog = Wx::DirDialog->new($self, 'Choose a Destination Directory');
    $dialog->ShowModal();
    $self->{destination_dir} = $dialog->GetPath();
}
=pod

=head2 dummy

This method does something... apparently.

=cut



1;

=pod

=head1 SUPPORT

No support is available

=head1 AUTHOR

Copyright 2008 Anonymous.

=cut
