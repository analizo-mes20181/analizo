package Analizo::Extractor::Reference;

use strict;
use warnings;

use Analizo::Extractor::Utils qw(qualified_name);

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(uses model current_member));

sub new {
  my $class = shift;

  my $self = {
      uses => shift,
      model => shift,
      current_member => shift,
  };

  bless $self, $class;

  return $self;
}

sub extract_references_data {
  my ($self) = @_;

  my ($uses) = $self->uses;

  my ($uses_name) = keys %$uses;

  my $referenced_element_type = $self->uses->{$uses_name}->{type};

  my $defined_in = $self->uses->{$uses_name}->{defined_in};
  
  my $qualified_uses_name = qualified_name($defined_in, $uses_name);
  
  if ($self->_references_function($referenced_element_type)) {
    $self->_add_function_reference($qualified_uses_name);
  } elsif ($self->_references_a_variable($referenced_element_type)) {
    $self->_add_variable_reference($qualified_uses_name);
  }
}

sub _add_function_reference {
  my ($self, $qualified_uses_name) = @_;

  $self->model->add_call($self->current_member, $qualified_uses_name, 'direct');
}

sub _add_variable_reference {
  my ($self, $qualified_uses_name) = @_;

  $self->model->add_variable_use($self->current_member, $qualified_uses_name);
}

sub _references_function {
  my ($self, $referenced_element_type) = @_;
  if ($referenced_element_type eq 'function') {
    return 1;
  }

  return 0;
}

sub _references_a_variable {
    my ($self, $referenced_element_type) = @_;

    if ($referenced_element_type eq 'variable') {
        return 1;
    }

    return 0;
}

1;
