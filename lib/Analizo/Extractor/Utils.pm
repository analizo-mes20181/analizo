package Analizo::Extractor::Utils;

use strict;
use warnings;
use Exporter qw(import);
our @EXPORT = qw(add qualified_name);



# discard file suffix (e.g. .c or .h)
sub file_to_module {
  my ($filename) = @_;
  $filename ||= 'unknown';
  $filename =~ s/\.\w+$//;
  return $filename;
}

# concat module with symbol (e.g. main::to_string)
sub qualified_name {
  my ($file, $symbol) = @_;
  file_to_module($file) . '::' . $symbol;
}

1;
