package POE::Session::Attribute ;

use strict ;
use warnings ;

use	base qw(Class::Data::Inheritable) ;
use	POE qw(Session) ;
use	Class::Inspector ;

__PACKAGE__->mk_classdata(qw(states)) ;
__PACKAGE__->states({}) ;

our $VERSION = '0.01';

sub	MODIFY_CODE_ATTRIBUTES {
    	my	($class, $code, $attr, @rest) = @_ ;
	$class->states->{$code} = $attr ;
	return (@rest) ;
}

sub	FETCH_CODE_ATTRIBUTES {
    	my	($self, $code) = @_ ;
	return ($self->states->{$code}) || () ;
}

sub	new {
    	my	$class = shift ;
	return bless {}, $class ;
}

sub	spawn {
	my      $class = shift ;
	my	$self ;
	my	$methods = Class::Inspector->methods($class) ;
	my	%opts ;

	for my $m (@$methods) {
	    my $sub = $class->can($m) or next ;
	    my $attr = $class->states->{$sub} or next ;
	    if ($attr eq "Inline") {
		($opts{inline_states} ||= {})->{$m} = $sub ;
	    } elsif ($attr eq "Object") {
		my $t = ($opts{object_states} ||= [
			($self ||= $class->new(@_)) => []
		]) ;
		push @{$t->[1]}, $m ;
	    } elsif ($attr eq "Package") {
		my $t = ($opts{package_states} ||= [$class => []]) ;
		push @{$t->[1]}, $m ;
	    } else {
		die "unknown attribute `$attr' for method $class -> $m" ;
	    }
	}
	$opts{args} = [ @_ ] ;
	my $sid = POE::Session->create(%opts) ;
	return (wantarray && $self) ? ($sid, $self) : $sid ;
}


# Preloaded methods go here.

1;
__END__

=head1 NAME

POE::Session::Attribute - Use attributes to define your POE Sessions

=head1 SYNOPSIS

  # in Some/Module.pm

  package Some::Module ;
  use base qw(POE::Session::Attribute) ;
  use POE ;

  sub _start : Package {   # package state
      my ($pkg, @args) = @_[OBJECT, ARG0 .. $#_] ;
      ...
  }

  sub _stop : Object {     # object state
      my ($self, ...) = @_[OBJECT, ...] ;
      ...
  }

  sub some_other_event : Inline {  # inline state
      print "boo hoo\n" ;
  }

  ...
  1 ;

  # meanwhile, in some other file

  use Some::Module ;
  use POE ;

  my $new_session_id =
      Some::Module->spawn("your", {arguments => "here"}) ;

  ...

  POE::Kernel->run() ;

  # Inheritance works, too
  package Some::Module::Subclass ;
  use base qw(Some::Module) ;

  sub _stop : Object {
      my ($self, @rest) = @_ ;
      do_some_local_cleanup() ;
      $self->SUPER::_stop(@rest) ;  # you can call parent method, too
  }


=head1 DESCRIPTION

This module's purpose is to save you some boilerplate code around POE::Session->create() method. Just inherit your class from POE::Session::Attribute and define some states using attributes.  Method C<spawn()> in your package will be provided by POE::Session::Attribute (of course, you can override it, if any).  

=head1 ATTRIBUTES

=over 4

=item sub your_sub : B<Package>

Makes a package state. Name of your subroutine ("your_sub") will be used as
state name.

=item sub your_sub : B<Inline>

Makes an inline state. Name of your subroutine ("your_sub") will be used as
state name.

=item sub your_sub : B<Object>

Makes an object state. Name of your subroutine ("your_sub") will be used as
state name. An instance of your class will be created by C<spawn()> method,
if at least one B<Object> state is defined in your package. Method C<new()>
from your package will be called to create the instance. Arguments for the
call to C<new()> will be the same as specified for C<spawn()> call.

=back

=head1 METHODS

=over 4

=item new()

POE::Session::Attribute provides a default constructor (C<bless {}, $class>). You can (and probably should) override it in your inheriting class. C<new()> will be called by C<spawn()> if at least one B<Object> state is defined.

=item spawn()

Creates a new POE::Session based on your class/package. An argument list for C<spawn()> method will be used for "args" parameter to L<POE::Session>->create(). The same argument list will be used to call C<new()>, if you have B<Object> states in your class/package.

Yes, it's probably somewhat messy. Suggest a fix.

When called in scalar context, returns a reference to a newly created
POE::Session (but make sure to read L<POE::Session> documentation to see why
you shouldn't use it). In list context, returns a reference to POE::Session and
a reference to a newly created instance of your class (in case it was really
created).

=back

=head1 SEE ALSO

L<POE>, L<POE::Session>, L<attributes>.

There is a somewhat similar module on CPAN, L<POE::Session::AttributeBased>.

=head1 AUTHOR

dmitry kim, E<lt>dmitry.kim@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by dmitry kim

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut
