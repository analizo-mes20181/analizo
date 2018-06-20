package Analizo::Extractor::Definition;

use strict;
use warnings;

use Analizo::Extractor::Utils qw(qualified_name);
use Analizo::Extractor::Reference;

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(definition model current_module current_member definition_reference));

sub new {
  my $class = shift;

  my $self = {
      definition => shift,
      model => shift,
      current_module => shift,
  };

  bless $self, $class;

  return $self;
}

sub extract_definition_data {
  my ($self) = @_;

  my $definition = $self->definition;

  my ($name) = keys %$definition;

  $self->_set_current_member($name);

  $self->_set_definition_direct_reference($name);

  $self->_declare_possible_functions_or_variables();
  $self->_declare_public_members();
  $self->_declare_loc();
  $self->_declare_parameters();
  $self->_declare_number_of_conditional_paths();
  
  $self->_extract_definition_references();
}

sub _declare_loc() {
  my ($self) = @_;
  
  if ($self->_has_lines_of_code($self->definition_reference)) {
    $self->model->add_loc($self->current_member, $self->definition_reference->{lines_of_code});
  }
}

sub _declare_parameters() {
  my ($self) = @_;

  if ($self->_has_parameters($self->definition_reference)) {
    $self->model->add_parameters($self->current_member, $self->definition_reference->{parameters});
  }
}

sub _declare_number_of_conditional_paths() {
  my ($self) = @_;

  if ($self->_has_conditional_paths($self->definition_reference)) {
    $self->model->add_conditional_paths($self->current_member, $self->definition_reference->{conditional_paths});
  }
}

sub _extract_definition_references() {
  my ($self) = @_;
  
  foreach my $uses (@{ $self->definition_reference->{uses} }) {
    $self->_extract_references_data($uses);
  }
}

sub _declare_public_members {
  my ($self) = @_;

  if (defined $self->definition_reference->{protection}) {
    my $protection = $self->definition_reference->{protection};
    $self->model->add_protection($self->current_member, $protection);
  }
}

sub _declare_possible_functions_or_variables {
  my ($self) = @_;

  if ($self->_is_a_funcion($self->definition_reference)) { 
    $self->model->declare_function($self->current_module, $self->current_member);
  }
  elsif ($self->_is_a_variable($self->definition_reference)) {
    $self->model->declare_variable($self->current_module, $self->current_member);
  }
  #FIXME: Implement define treatment (no novo doxyparse identifica como type = "macro definition")
  # define declarations
  elsif ($self->_is_macro($self->definition_reference)) {
    #$self->{current_member} = $qualified_name;
  }
}

sub _set_current_member {
  my ($self, $name) = @_;

  my $qualified_name = qualified_name($self->current_module, $name);

  $self->current_member($qualified_name);
}

sub _set_definition_direct_reference {
  my ($self, $name) = @_;

  my $definition_reference = $self->definition->{$name};

  $self->definition_reference($definition_reference);
}

sub _is_macro {
  my ($self, $definition) = @_;

  if($definition->{type} eq 'macro definition') {
    return 1;
  }

  return 0;
}

sub _has_parameters {
  my ($self, $definition) = @_;

  if(defined $definition->{parameters}) {
    return 1;
  }

  return 0;
}

sub _has_lines_of_code {
  my ($self, $definition) = @_;

  if(defined $definition->{lines_of_code}) {
    return 1;
  } 

  return 0;
}

sub _has_conditional_paths {
  my ($self, $definition) = @_;

  my $lord = $definition->{conditional_paths};

  if (defined $definition->{conditional_paths}) {
    return 1;
  }

  return 0;
}

sub _is_a_funcion {
  my ($self, $definition) = @_;

  if($definition->{type} eq 'function') {
    return 1;
  }

  return 0;
}

sub _is_a_variable {
  my ($self, $definition) = @_;

  if($definition->{type} eq 'variable') {
    return 1;
  }

  return 0;
}

sub _extract_references_data {
  my ($self, $uses) = @_;

  my ($uses_name) = keys %$uses;

  my $reference = Analizo::Extractor::Reference->new($uses, $self->model, $self->current_member);
  
  $reference->extract_references_data();
}

1;
