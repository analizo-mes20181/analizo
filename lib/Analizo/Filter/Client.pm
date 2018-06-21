package Analizo::Filter::Client;

use File::Find;

sub filters {
  my ($self, @new_filters) = @_;
  $self->{filters} ||= [];
  if (@new_filters) {
    push @{$self->{filters}}, @new_filters;
  }
  return $self->{filters};
}

sub has_filters {
  my ($self) = @_;
  return exists($self->{filters}) && exists($self->{filters}->[0]);
}

sub share_filters_with($$) {
  my ($self, $other) = @_;
  $other->{filters} = $self->{filters};
}

sub exclude {
  my ($self, @dirs) = @_;
  if (!$self->{excluding_dirs}) {
    $self->{excluding_dirs} = 1;
    $self->filters(Analizo::LanguageFilter->new);
  }
  $self->filters(Analizo::FilenameFilter->exclude(@dirs));
}

sub filename_matches_filters {
  my ($self, $filename) = @_;
  for my $filter (@{$self->filters}) {
    unless ($filter->matches($filename)) {
      return 0;
    }
  }
  return 1;
}

sub apply_filters {
  my ($self, @input) = @_;
  my @result = ();

  $self->filters(Analizo::FilenameFilter->check_filters()));

  for my $input (@input) {
    find_filename($input) 
  }
  
  return @result;
}

sub check_filters {
    # By default, only look at supported languages

  unless ($self->has_filters) {
    $self->filters(new Analizo::LanguageFilter('all'));
  }
}

sub find_filename(@input)  {
    find(
      { wanted => 
        $self->push_result(), 
      no_chdir => 1 },
      $input
    );
}

sub push_result {
    push @result, $_ if !-d $_ && $self->filename_matches_filters($_); }, 
}

1;
