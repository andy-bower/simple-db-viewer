#!/usr/bin/perl -Tw

use strict;
use warnings;
use YAML;
use DBI;
use CGI;
use lib("perl5/lib");
use XML::LibXML;

my $conf = YAML::LoadFile("user/conf.yaml");
my $q = CGI->new;

sub logon {
    my $cred = shift;
    my $dsn = "dbi:mysql:".join(";", map { "$_=$cred->{$_}" } ("database", "host"));
    my $dbh = DBI->connect($dsn, $cred->{'user'}, $cred->{'password'});
    return $dbh
}

sub process_table_subst {
    my $dbh = shift;
    my $prefix = shift;
    my $sql = shift;

    my @parts = split /[\[\]]/, $sql;
    for my $i (0 .. int($#parts / 2)-1) {
	$parts[1 + $i * 2] = $dbh->quote_identifier($prefix.$parts[1 + $i * 2]);
    }
    return join("", @parts);
}

my $prefix = $conf->{'db'}->{'prefix'} // '';
my $struct = $conf->{'struct'};
my $ui = $conf->{'ui'};
my $table = $q->param('table') // $struct->{'default_table'} // '';
my $start = $q->param('start') // 0;
my $limit = $q->param('limit') // $ui->{'page_size'} // 100;

# Connect to database
my $dbh = logon($conf->{'db'});
my $sth;
my $view = $struct->{'views'}->{$table};

if (defined($view) && $view->{'view'}) {
    # View query

    my $sql = $view->{'sql'};
    $sql = process_table_subst($dbh, $prefix, $sql);
    my $where = '';
    my @values = ();
    if ($view->{'keys'}) {
	my @keys = split /\s/, $view->{'keys'};
	my @supplied = grep { defined($q->param($_)) } @keys;
	!$view->{'key_required'} || (scalar @keys) == (scalar @supplied) || die "Keys compulsory";
	$where = "where ".join(',', map { "$_=?" } @supplied);
        @values = map { scalar $q->param($_) } @supplied;
    }
    my $order_by = defined($view->{'order_by'}) ? "order by $view->{'order_by'}" : "";
    $sth = $dbh->prepare("$sql $where $order_by limit ? offset ?");
    $sth->execute(@values, $limit, $start) or die $!;
} else {
    $view = $struct->{'tables'}->{$table};
    if (defined($view) && $table->{'view'}) {

	# Table query
	
	my $safetable;
	$safetable = $dbh->quote_identifier($prefix.$table);
	$sth = $dbh->prepare("SELECT * from $safetable limit ? offset ?");
	$sth->execute($limit, $start) or die $!;
    } else {
	die "Not a viewable table: $table";
    }
}

my $fieldnames = $sth->{'NAME'};
my @fields;
for my $field (@$fieldnames) {
    my %def = ( 'name' => $field );
    my $link = ($view->{'links'} // {})->{$field};
    if (defined $link) {
	$def{'link'} = $link;
    }
    push @fields, \%def;
}

# Format result

sub format_plain {
    my $fconf = shift;
    my $fields = shift;
    my $data = shift;
    
    print $q->header('text/plain');
    print join(" ", map { $_{'name'} } @$fields)."\n";
    for my $row (@$data) {
	print join(" ", @$row)."\n";
    }
}

sub format_xml {
    my $fconf = shift;
    my $fields = shift;
    my $data = shift;
    
    my $doc = XML::LibXML::Document->new('1.0', 'utf-8');

    if (defined($fconf->{'stylesheet'})) {
	my $pi = $doc->createProcessingInstruction("xml-stylesheet");
	$pi->setData("type" => "text/xsl", href => "$fconf->{'stylesheet'}");
	$doc->appendChild($pi);
    }

    my $root = $doc->createElement('result');
    $doc->setDocumentElement($root);
    my $table = $doc->createElement('table');
    $root->appendChild($table);
    my $heading = $doc->createElement('heading');
    $table->appendChild($heading);
    for my $field (@$fields) {
	$heading->appendTextChild("field", $field->{'name'});
    }
    
    for my $record (@$data) {
	my $row = $doc->createElement('record');
	$table->appendChild($row);
	for my $i (0 .. (scalar @$fields)-1) {
	    my $cell = $doc->createElement('value');
	    my $text = $doc->createTextNode($$record[$i] // '');
	    $cell->appendChild($text);
	    my $link = $fields[$i]->{'link'};
	    if (defined($link)) {
		$cell->setAttribute('href', CGI::url(-relative=>1).
				    "?table=".CGI::escapeHTML($link->{'target'}).
				    ";".CGI::escapeHTML($link->{'other_key'}).
				    "=".CGI::escapeHTML($$record[$i]));
	    }
	    $row->appendChild($cell);
	}
    }
    
    print $q->header('text/xml');
    print $doc->toString();
}

format_xml($conf->{"format_xml"}, \@fields, $sth->fetchall_arrayref());
    
$sth->finish;
