package Analizo::Extractor::Definition;

use strict;
use warnings;
use Analizo::Extractor::Utils qw(qualified_name);
use Analizo::Extractor::Reference;

sub new {
  my $class = shift;

  my $self = {
      _definition => shift,
      _model => shift,
      _current_module => shift,
  };

  bless $self, $class;

  return $self;
}

sub extract_definition_data {
  my ($self) = @_;

  my $definition = $self->{_definition};

  my ($name) = keys %$definition;

  my $qualified_name = qualified_name($self->{_current_module}, $name);
  
  $self->{_current_member} = $qualified_name;

  my $definition_reference = $definition->{$name};
       
  # function declarations
  if ($self->_is_a_funcion($definition_reference)) {
    $self->{_model}->declare_function($self->{_current_module}, $qualified_name);
  }
  
  # variable declarations
  elsif ($self->_is_a_variable($definition_reference)) {
    $self->{_model}->declare_variable($self->{_current_module}, $qualified_name);
  }
        
  #FIXME: Implement define treatment (no novo doxyparse identifica como type = "macro definition")
  # define declarations
  elsif ($self->_is_macro($definition_reference)) {
    #$self->{current_member} = $qualified_name;
  }
  # public members
  if (defined $definition->{$name}->{protection}) {
    my $protection = $definition->{$name}->{protection};
    $self->{_model}->add_protection($self->{_current_module}, $protection);
  }

  # method LOC
  if ($self->_has_lines_of_code($definition_reference)) {
    $self->{_model}->add_loc($self->{_current_module}, $definition->{$name}->{lines_of_code});
  }
  # method parameters
  if ($self->_has_parameters($definition_reference)) {
    $self->{_model}->add_parameters($self->{_current_module}, $definition->{$name}->{parameters});
  }

  # method conditional paths
  if ($self->_has_conditional_paths($definition_reference)) {
    $self->{_model}->add_conditional_paths($self->{_current_module}, $definition->{$name}->{conditional_paths});
  }

  foreach my $uses (@{ $definition->{$name}->{uses} }) {
    $self->_extract_references_data($uses);
  }
}

sub _is_macro {
    my ($self) = @_;

    if($self->{_definition}->{type} eq 'macro definition') {
        return 1;
    }

    return 0;
}

sub _has_parameters {
    my ($self) = @_;

    if(defined $self->{_definition}->{parameters}) {
        return 1;
    }

    return 0;
}

sub _has_lines_of_code {
    my ($self) = @_;

    if(defined $self->{_definition}->{lines_of_code}) {
        return 1;
    } 

    return 0;
}

sub _has_conditional_paths {
  my ($self) = @_;

  if (defined $self->{_definition}->{conditional_paths}) {
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

  my ($a) = keys %$uses;
  my ($uses_name) = keys %$uses;

  my $reference = Analizo::Extractor::Reference->new($uses, $self->{_model}, $self->{_current_member});
  
  $reference->extract_references_data();
}

1;
