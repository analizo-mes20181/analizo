package Analizo::Metric::AfferentConnections;
use strict;
use Graph;
use parent qw(Class::Accessor::Fast Analizo::ModuleMetric);

=head1 NAME

Analizo::Metric::AfferentConnections - Afferent Connections per Class (ACC) metric

=head1 DESCRIPTION

The metric calculation is based on the following article and calculates the
class conectivity.

Article: I<Monitoring of source code metrics in open source projects> by Paulo
Roberto Miranda Meirelles.

See the adaptation of the paragraph about Afferente Connections per Class in
the article:

Measures the connectivity of a class. If a class C<Cc> access a method or
attribute of a class C<Cs>, consider C<Cc> a client of the supplier class
C<Cs>, denoting C<< Cc => Cs >>.  Consider the follow function:

  client(Ci, Cj) = 1, if (Ci => Cj) and (Ci != Cj)
  client(Ci, Cj) = 0, otherwise.

So C<ACC(C) = (sum(client(Ci, Cj)), i = 1 to N)>, where C<N> is the total
number of system classes. If the value of this metric is large, a change in the
class has substantially more side effects, making maintenance more difficult.

=cut

__PACKAGE__->mk_accessors(qw( model analized_module hashmap graph_modules));

sub new {
  my ($package, %args) = @_;
   my @instance_variables = (
    model => $args{model},
    analized_modules => undef,
    hashmap => {},
    graph_modules => Graph->new()
  );
  return bless { @instance_variables }, $package;
}

sub description {
  return 'Afferent Connections per Class (used to calculate COF - Coupling Factor)';
}

sub calculate {
  my ($self, $module) = @_;
  $self->analized_module($module);

  my $number_of_caller_modules = $self->_number_of_modules_that_call_module();
  my $number_of_modules_on_inheritance_tree = $self->_recursive_number_of_children($self->analized_module);

  foreach my $key (keys %{$self->hashmap} ) {
      delete $self->hashmap->{$key};
  }

  return $number_of_caller_modules + $number_of_modules_on_inheritance_tree;
}

sub _number_of_modules_that_call_module {
  my ($self) = @_;

  if ($self->graph_modules->has_vertex($self->analized_module)){
    return $self->graph_modules->in_degree($self->analized_module);
  }else{
    $self->graph_modules->add_vertex($self->analized_module);
  }

  for my $caller_member (keys(%{$self->model->calls})){
    $self->_push_member_module_if_it_calls_analized_module($caller_member);
  }

  return $self->graph_modules->in_degree($self->analized_module);
}

sub _push_member_module_if_it_calls_analized_module {
  my ($self, $caller_member) = @_;

  my $caller_module = $self->model->members->{$caller_member};
  $self->_member_calls_analized_module($caller_member, $caller_module)
}

sub _member_calls_analized_module {
  my ($self, $caller_member, $caller_module) = @_;

  for my $called_member (keys(%{$self->model->calls->{$caller_member}})) {
    my $called_module = $self->model->members->{$called_member};
    if ($caller_module && $called_module && $caller_module ne $called_module){
      $self->graph_modules->add_edge($caller_module, $called_module);
    }
  }
}

sub _recursive_number_of_children {
  my ($self, $module) = @_;

  my $number_of_children = 0;

  if (defined $self->hashmap->{$module}){
    return $self->hashmap->{$module};
  }

  for my $other_module ($self->model->module_names){
    if ($self->_module_parent_of_other($module, $other_module)) {
      $number_of_children += $self->_recursive_number_of_children($other_module) + 1;
    }
  }

  $self->hashmap->{$module} = $number_of_children;

  return $number_of_children;
}

sub _module_parent_of_other {
  my ($self, $module, $other_module) = @_;
  return grep {$_ eq $module} $self->model->inheritance($other_module);
}

1;

