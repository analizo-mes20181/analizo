package Analizo::Extractor::Doxyparse;

use strict;
use warnings;

use parent qw(Analizo::Extractor);

use File::Temp qw/ tempfile /;
use Cwd;
use YAML::XS;

use Analizo::Extractor::Definition qw(new extract_definition_data);
use Analizo::Extractor::Reference;

sub new {
  my ($package, @options) = @_;
  return bless { files => [], @options }, $package;
}

sub _add_file {
  my ($self, $file) = @_;
  push(@{$self->{files}}, $file);
}

sub _cpp_hack {
  my ($self, $module) = @_;
  my $current = $self->current_file;
  if (defined($current) && $current =~ /^(.*)\.(h|hpp)$/) {
    my $prefix = $1;
    # look for a previously added .cpp/.cc/etc
    my @implementations = grep { /^$prefix\.(cpp|cxx|cc)$/ } @{$self->{files}};
    foreach my $file (@implementations) {
      $self->model->declare_module($module, $file);
    }
  }
  if (defined($current) && $current =~ /^(.*)\.(cpp|cxx|cc)$/) {
    my $prefix = $1;
    # look for a previously added .h/.hpp/etc
    my @implementations = grep { /^$prefix\.(h|hpp)$/ } @{$self->{files}};
    foreach my $file (@implementations) {
      $self->model->declare_module($module, $file);
    }
  }
}

sub _extract_definition_data {
    my ($self, $definition) = @_;

    my $definition_data = Analizo::Extractor::Definition->new($definition, $self->model, $self->current_module);

    $definition_data->extract_definition_data();
}



sub _extract_module_data {
  my ($self, $yaml, $full_filename, $module) = @_;

  my $modulename = _file_to_module($module);

  my $module_reference = $yaml->{$full_filename}->{$module};

  next if $self->_is_module_defined($module_reference) && 
    not $self->_is_module_mapped_as_hash($module_reference);
  $self->current_module($modulename);
  $self->_cpp_hack($modulename);

  # inheritance
  if ($self->_module_has_inheritance($module_reference)) {
    if ($self->_is_inheritance_multiple($module_reference)) {
      foreach my $inherits (@{ $yaml->{$full_filename}->{$module}->{inherits} }) {
        $self->model->add_inheritance($self->current_module, $inherits);
      }
    }
    else {
      my $inherits = $yaml->{$full_filename}->{$module}->{inherits};
      $self->model->add_inheritance($self->current_module, $inherits);
    }
  }

  # abstract class
  if (defined $yaml->{$full_filename}->{$module}->{information}) {
    if ($self->_is_module_an_abstract_class($module_reference)) {
      $self->model->add_abstract_class($self->current_module);
    }
  }

  foreach my $definition (@{$yaml->{$full_filename}->{$module}->{defines}}) {
      $self->_extract_definition_data($definition);
  }
}

sub _extract_file_data {
  my ($self, $yaml, $full_filename) = @_;
    
  # current module declaration
  foreach my $module (keys %{$yaml->{$full_filename}}) {
    $self->_extract_module_data($yaml, $full_filename, $module);
  }
}

sub feed {
  my ($self, $doxyparse_output, $line) = @_;
  my $yaml = undef;
  eval { $yaml = Load($doxyparse_output) };
  if ($@) {
    die $!;
  }
  foreach my $full_filename (sort keys %$yaml) {

    # current file declaration
    my $file = _strip_current_directory($full_filename);
    $self->current_file($file);
    $self->_add_file($file);

    $self->_extract_file_data($yaml, $full_filename);

  }
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

# concat module with symbol (e.g. main::to_string)
sub _qualified_name {
  my ($file, $symbol) = @_;
  _file_to_module($file) . '::' . $symbol;
}

# discard file suffix (e.g. .c or .h)
sub _file_to_module {
  my ($filename) = @_;
  $filename ||= 'unknown';
  $filename =~ s/\.\w+$//;
  return $filename;
}

sub _strip_current_directory {
  my ($file) = @_;
  my $pwd = getcwd();
  $file =~ s#^$pwd/##;
  return $file;
}

sub actually_process {
  my ($self, @input_files) = @_;
  my ($temp_handle, $temp_filename) = tempfile();
  foreach my $input_file (@input_files) {
    print $temp_handle "$input_file\n"
  }
  close $temp_handle;

  eval 'use Alien::Doxyparse';
  $ENV{PATH} = join(':', $ENV{PATH}, Alien::Doxyparse->bin_dir) unless $@;

  eval {
    open DOXYPARSE, "doxyparse - < $temp_filename |" or die "can't run doxyparse: $!";
    local $/ = undef;
    my $doxyparse_output = <DOXYPARSE>;
    close DOXYPARSE or die "doxyparse error";
    $self->feed($doxyparse_output);
    unlink $temp_filename;
  };
  if($@) {
    warn($@);
    exit -1;
  }
}

1;
