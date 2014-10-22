package POE::Session::Attribute ;

use strict ;
use warnings ;

use	POE qw(Session) ;
use	Attribute::Handlers ;
use	Class::ISA ;

our $VERSION = '0.02';

my	$states = {} ;

sub	Object : ATTR(CODE) { shift->__mod_attr(@_) }
sub	Package : ATTR(CODE) { shift->__mod_attr(@_) }
sub	Inline : ATTR(CODE) { shift->__mod_attr(@_) }

sub	__pkg_states {
    	my	$pkg = shift ;
	my	$st = $states->{$pkg} ;

	if (!$st) {
	    $st = {} ;
	    for (Class::ISA::super_path($pkg)) {
		if (my $pst = $states->{$_}) {
		    $st = { %$pst } ;
		    last ;
		}
	    }
	    $states->{$pkg} = $st ;
	}
	return $st ;
}

sub	__mod_attr {
	my	($pkg, $sym, $sub, $attr, $data, $phase) = @_ ;
	my	$handler = $sym ? *{$sym}{NAME} : $sub ;
	my	@states ;

	if ($data) {
	    @states = ref($data) eq 'ARRAY' ? (@$data) : ($data) ;
	} else {
	    @states = (*{$sym}{NAME}) or die 'cannot determine state name' ;
	}

	die "cannot use unnamed $sub as $attr state"
	    if $attr ne 'Inline' && !$sym ;
	
	$pkg->__pkg_states->{$_} = [$attr, $handler] for @states ;
}

sub	new {
    	my	$class = shift ;
	return bless {}, $class ;
}

sub	spawn {
	my      $class = shift ;
	my	$self ;
	my	%opts ;

	while (my ($state, $ar) = each %{$class->__pkg_states}) {
	    my ($attr, $handler) = @$ar ;

	    if ($attr eq "Inline") {

		if (!ref($handler)) {
		    $handler = $class->can($handler) or
			die "$class can't `$handler'"
		}
		($opts{inline_states} ||= {})->{$state} = $handler ;
	    } elsif ($attr eq "Object") {
		my $t = ($opts{object_states} ||= [
			($self ||= $class->new(@_)) => {}
		]) ;
		$t->[1]->{$state} = $handler ;
	    } elsif ($attr eq "Package") {
		my $t = ($opts{package_states} ||= [$class => {}]) ;
		$t->[1]->{$state} = $handler ;
	    } else {
		die "unknown attribute `$attr' for method $class -> $handler" ;
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

  sub stop : Object(_stop) {     # object state, explicit state name
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

=item sub your_sub : B<Package(name, more_names, ...)>

Makes a package state. If C<name> is specified, it will be used as a state
name. You can specify several names here. Otherwise, the name of your
subroutine ("your_sub") will be used as state name.

=item sub your_sub : B<Inline>

=item sub your_sub : B<Inline(name, more_names, ...)>

Makes an inline state. If C<name> is specified, it will be used as a state
name. You can specify several names here. Otherwise, the name of your
subroutine ("your_sub") will be used as state name.

=item sub your_sub : B<Object>

=item sub your_sub : B<Object(name, more_names, ...)>

Makes an object state. If C<name> is specified, it will be used as a state
name. You can specify several names here. Otherwise, the name of your
subroutine ("your_sub") will be used as state name.

An instance of your class will be created by C<spawn()> method,
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

dmitry kim, E<lt>dmitry.kim(at)gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by dmitry kim

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut
