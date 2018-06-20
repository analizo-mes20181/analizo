package Analizo::Extractor::Module;

use strict;
use warnings;

use base qw(Class::Accessor::Fast);

use Analizo::Extractor::Utils qw(file_to_module);
use Analizo::Extractor::Definition;

__PACKAGE__->mk_accessors(qw(current_module current_member));

sub new {
  my $class = shift;

  my $self = {
      _yaml => shift,
      _full_filename => shift,
      _module => shift,
      _current_file => shift,
      _model => shift,
  };

  bless $self, $class;

  return $self;
}

sub _cpp_hack { 
  my ($self) = @_;
  if (defined($self->{_current_file}) && $self->{_current_file} =~ /^(.*)\.(h|hpp)$/) {
    my $prefix = $1;
    # look for a previously added .cpp/.cc/etc
    my @implementations = grep { /^$prefix\.(cpp|cxx|cc)$/ } @{$self->{files}};
    foreach my $file (@implementations) {
      $self->{_model}->declare_module($self->{_module}, $self->{_current_file});
    }
  }
  if (defined($self->{_current_file}) && $self->{_current_file} =~ /^(.*)\.(cpp|cxx|cc)$/) {
    my $prefix = $1;
    # look for a previously added .h/.hpp/etc
    my @implementations = grep { /^$prefix\.(h|hpp)$/ } @{$self->{files}};
    foreach my $file (@implementations) {
      $self->{_model}->declare_module($self->{_module}, $self->{_current_file});
    }
  }
}

sub extract_module_data {
  my ($self) = @_;

  my $modulename = file_to_module($self->{_module});

  my $module_reference = $self->{_yaml}->{$self->{_full_filename}}->{$self->{_module}};

  next if $self->_is_module_defined($module_reference) && 
    not $self->_is_module_mapped_as_hash($module_reference);
  
  $self->{current_module} = ($modulename);

  $self->_cpp_hack($modulename);

  # inheritance
  if ($self->_module_has_inheritance($module_reference)) {
    if ($self->_is_inheritance_multiple($module_reference)) {
      foreach my $inherits (@{ $self->{_yaml}->{$self->{_full_filename}}->{$self->{_module}}->{inherits} }) {
         $self->{_model}->add_inheritance( $self->{current_module}, $inherits);
      }
    }
    else {
      my $inherits = $self->{_yaml}->{$self->{_full_filename}}->{$self->{_module}}->{inherits};
       $self->{_model}->add_inheritance( $self->{current_module}, $inherits);
    }
  }

  # abstract class
  if (defined $self->{_yaml}->{$self->{_full_filename}}->{$self->{_module}}->{information}) {
    if ($self->_is_module_an_abstract_class($module_reference)) {
      $self->{_model}->add_abstract_class($self->{current_module});
    }
  }

  foreach my $definition (@{$self->{_yaml}->{$self->{_full_filename}}->{$self->{_module}}->{defines}}) {
      $self->_extract_definition_data($definition);
  }
}

sub _extract_definition_data {
    my ($self, $definition) = @_;

    my $definition_data = Analizo::Extractor::Definition->new($definition,  $self->{_model},  $self->{current_module});

    $definition_data->extract_definition_data();
    
    $self->current_member($definition_data->{_current_member});
}

sub _is_module_defined {
  my ($self, $module) = @_;

  if(defined $module) {
      return 1;
  }

  return 0;
}

sub _is_module_mapped_as_hash {
  my ($self, $module) = @_;

  if(ref($module) eq 'HASH') {
      return 1;
  }
  
  return 0;
}

sub _module_has_inheritance {
    my ($self, $module) = @_;

    if(defined $module->{inherits}) {
        return 1;
    }

    return 0;
}

sub _is_inheritance_multiple {
    my ($self, $module) = @_;

    if(ref $module->{inherits} eq 'ARRAY') {
        return 1;
    }

    return 0;
}

sub _is_module_an_abstract_class {
    my ($self, $module) = @_;

    if($module->{information} eq 'abstract class') {
        return 1;
    }

    return 0;
}

1;
