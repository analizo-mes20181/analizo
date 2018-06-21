package Analizo::Extractor::Module;

use strict;
use warnings;

use base qw(Class::Accessor::Fast);

use Analizo::Extractor::Utils qw(file_to_module);
use Analizo::Extractor::Definition;

__PACKAGE__->mk_accessors(
    qw(current_module current_member current_file yaml full_filename module model module_reference));

sub new {
  my $class = shift;

  my $self = {
      yaml => shift,
      full_filename => shift,
      module => shift,
      current_file => shift,
      model => shift,
      files => shift,
  };

  bless $self, $class;

  return $self;
}

sub _declare_modules_for_cpp { 
  my ($self) = @_;

  if ($self->_is_file_defined($self->current_file)){
    $self->_declare_cpp_module();
    $self->_declare_hpp_module();
  }
}

sub _declare_hpp_module {
  my ($self) = @_;

  my $current = $self->current_file;

  if ($current =~ /^(.*)\.(cpp|cxx|cc)$/) {
    my $prefix = $1;
    
    # look for a previously added .h/.hpp/etc
    my @implementations = grep { /^$prefix\.(h|hpp)$/ } @{$self->{files}};
    foreach my $file (@implementations) {
      $self->model->declare_module($self->current_module, $file);
    }
  }
}

sub _declare_cpp_module {
  my ($self) = @_;

  my $current = $self->current_file;

  if($current =~ /^(.*)\.(h|hpp)$/) {
    my $prefix = $1;
    
    # look for a previously added .cpp/.cc/etc
    my @implementations = grep { /^$prefix\.(cpp|cxx|cc)$/ } @{$self->{files}};
    foreach my $file (@implementations) {
      $self->model->declare_module($self->current_module, $file);
    }
  }
}

sub _is_file_defined {
  my ($self, $current_file) = @_;

  if(defined ($current_file)) {
    return 1;
  }

  return 0;
}

sub extract_module_data {
  my ($self) = @_;

  $self->_set_current_module();

  $self->_set_module_direct_reference();

  next if $self->_is_module_defined($self->module_reference) && not $self->_is_module_mapped_as_hash($self->module_reference);
  
  $self->_declare_modules_for_cpp();

  # inheritance
  $self->_add_possible_inheritances();

  # abstract class
  $self->_add_possible_abstract_classes();

  $self->_extract_module_definitions();
  
}

sub _extract_module_definitions {
  my ($self) = @_;

  foreach my $definition (@{$self->module_reference->{defines}}) {
      $self->_extract_definition_data($definition);
  }
}

sub _set_module_direct_reference {
  my ($self) = @_;

  my $module_reference = $self->yaml->{$self->full_filename}->{$self->module};

  if(defined $module_reference) {
    $self->module_reference($module_reference);
  } else {
    $self->module_reference({});
  }
}

sub _add_possible_abstract_classes {
  my ($self) = @_;

  if (defined $self->module_reference->{information}) {
    if ($self->_is_module_an_abstract_class($self->module_reference)) {
      $self->model->add_abstract_class($self->current_module);
    }
  }
}

sub _add_possible_inheritances {
  my ($self) = @_;
  
  if ($self->_module_has_inheritance($self->module_reference)) {
    if ($self->_is_inheritance_multiple($self->module_reference)) {
      $self->_add_multiple_inheritance();
    }
    else {
      $self->_add_single_inheritance();  
    }
  }
}

sub _add_multiple_inheritance {
  my ($self) = @_;

  foreach my $inherits (@{$self->module_reference->{inherits}}) {
    $self->model->add_inheritance( $self->current_module, $inherits);
  }
}

sub _add_single_inheritance {
  my ($self) = @_;

  my $inherits = $self->module_reference->{inherits};
  $self->model->add_inheritance($self->current_module, $inherits);
}

sub _set_current_module {
  my ($self) = @_;

  my $current_module = file_to_module($self->module);

  $self->current_module($current_module);
}

sub _extract_definition_data {
    my ($self, $definition) = @_;

    my $definition_data = Analizo::Extractor::Definition->new($definition,  $self->{model},  $self->{current_module});

    $definition_data->extract_definition_data();
    
    $self->current_member($definition_data->current_member);
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
