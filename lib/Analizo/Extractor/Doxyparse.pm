package Analizo::Extractor::Doxyparse;

use strict;
use warnings;

use parent qw(Analizo::Extractor);

use File::Temp qw/ tempfile /;
use Cwd;
use YAML::XS;

use Analizo::Extractor::Module;

sub new {
  my ($package, @options) = @_;
  return bless { files => [], @options }, $package;
}

sub _add_file {
  my ($self, $file) = @_;
  push(@{$self->{files}}, $file);
}

sub _extract_module_data {
  my ($self, $yaml, $full_filename, $module) = @_;

  my $module_data = Analizo::Extractor::Module->new($yaml, $full_filename, $module, $self->current_file, $self->model, $self->{files});

  $module_data->extract_module_data();

  $self->current_module($module_data->current_module);
  $self->{current_member} = $module_data->current_member;
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
