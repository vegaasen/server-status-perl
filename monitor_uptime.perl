#!/usr/bin/perl
#
# Simple perl-script that does the following:
# -reads a domain-list that just issues a request to wherever specified. Then, it will just output this stuff to a specified file + 
# as output, mimc'd through a html-page with page-reload.
# 
# @author vegaasen
#

###########################################
package Result;

use warnings;
use strict;

sub new {
    my $class = shift;
    my $self  = { @_ };
    return bless $self, $class;
}

sub response {
	my $self = shift;
	return $self->{response};
}

sub responseTime {
	my $self = shift;
	return $self->{responseTime};
}

sub when {
	my $self = shift;
	return $self->{when};
}
###########################################
package main;

use warnings;
use strict;
use Tie::File;
use LWP::UserAgent;
use Time::Piece;

my $error_log  = 'uptime.err';
my $domains = 'domain.list';

my $response_limit = 5; 
my $consolePrint = 0;

die "File $domains is not exist\n" unless (-e $domains);
my $localtime     = localtime;
my @serverStatuses;
my @errors;
my ($day,$month,$date,$hour,$year) = split /\s+/,scalar localtime;
my $output_file = 'report-'.$date.'.'.$month.'.'.$year.'.out';
my (@all_addr) = ();
tie @all_addr, 'Tie::File', $domains or error("Cant open file {$domains} to read the list of domains");

if (-e $output_file) {
   open(OUT,">> $output_file") 
	  or error("Cant append to existing file $output_file");
} else {
   open(OUT,"> $output_file") 
	  or error("Cant write to file $output_file");
}

sub checkAddresses() {
	print OUT "\n+" .('-' x 84) . "+\n";
	print OUT   "|", ' ' x 30,"Time: $hour",' ' x 40,"|\n";
	print OUT   "|",' 'x 10,'HOST',' ' x 37,'STATUS',' ' x 7, "RESPONSE            |\n";
	print OUT   "+" .('-' x 84) . "+\n";
	for (0 .. $#all_addr) {
	 chop $all_addr[$_] if ($all_addr[$_] =~ /\s+$/);
	 next if ($all_addr[$_]  eq "");
	 if ($all_addr[$_] =~ /^(http(s)?):\/\/([\w]+.{0,1}|)([\w_\-]+)(.[\w]{0,})?.*/) {  
	   domainCheck($all_addr[$_]);
	 } else {
	   my $out_format = sprintf "| %-50.50s %-10s  %-20s|\n", $all_addr[$_], "WRONG", "N/A";
	   printf OUT $out_format;
	   printf $out_format;
			 push @errors, "$all_addr[$_] is WRONG Address.";
	 }
	}
}

sub domainCheck {
    my $target = $_[0];
	my $ua = LWP::UserAgent->new;
	$ua->agent("$0/0.1 " . $ua->agent);
	my $req = HTTP::Request->new(GET => "$target");
	$req->header('Accept' => '*/*');
	my $startTime = time;
	my $res = $ua->request($req);
	my $endTime = time;
	$endTime = ($endTime - $startTime);
	my $result = Result->new(response => $res, responseTime => $endTime, when => localtime($startTime)->strftime('%d.%m-%Y @ %H:%M:%S'));
	storeServerStatus($result);
	if ($res->is_success() || $res->is_redirect() || $res->is_info() || $res->code == 404) {
	  my $out_format;
	  if ($response_limit && ($response_limit <= $endTime)) {
		 push(@errors, "Slow response from $target\: $endTime seconds");
		 $out_format = sprintf "| %-50.50s %-10s %-20s |\n", $target, "SLOW", "Response $endTime seconds";
	  } else {
		 $out_format = sprintf "| %-50.50s %-10s %-20s |\n", 
			  $target, "ACCESSED", "Response $endTime seconds";
	  }
	  print OUT $out_format;
	  toss($out_format);
	} else {
	  my $out_format = sprintf "| %-50.50s %-10s %-20s |\n", $target, "DOWN", " N/A";
	  push(@errors, "$target is DOWN." . $res->status_line) or error("Cannot push error for DOWN");
	  print OUT $out_format;
	  toss($out_format);
    }
}

sub storeServerStatus() {
	push(@serverStatuses, $_[0]);
	toss("Added result");
}

sub error {
  my $error_msg = shift;
  open ERR,">> $error_log" or die "Cannot open log file $error_log : $!\n";
  print ERR "$localtime\: $error_msg : $!\n";
  close ERR or die "Cannot close log file $error_log : $!\n";
}

sub cleanUp() {
	my $err = join "\015\012",@errors;
	my $err_num = scalar @errors;
	untie @all_addr or error("Unable to close file $domains");

	close OUT or error("Unable to close file $output_file");
	toss("Server check is done");
}

sub toss() {
	my $what = $_[0];
	if($consolePrint == 1) {
		print $what;
	}
}

sub printAllStatuses() {
	print '<div class="wrapper">';
	print '<table class="table"><thead><tr><th>URL</th><th>Status</th><th>When Requested</th><th>Response Time</th></tr></thead><tbody>';
	foreach(@serverStatuses) {
		if ($_->response->is_success() || $_->response->is_info() || $_->response->code == 404) {
			print '<tr class="success">';
		} elsif ($_->response->is_redirect()) {
			print '<tr class="warning">';
		} else {
			print '<tr class="error">';
		}
		print '<td><a href="' . $_->response->request->uri() . '" target="_blank">' . $_->response->request->uri() . '</a></td><td>' . $_->response->status_line() . '</td><td>' . $_->when() . '</td><td>' . $_->responseTime() . 's</td></tr>';
	}
	print '</tbody></table>';
	print '</div>';
}

sub printHead() {
	print "Content-Type: text/html; charset=UTF-8\n\n";
	print "<!DOCTYPE html>\n<html>\n<head><title>Domain statusoverview</title><link href=\"https://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/css/bootstrap-combined.min.css\" rel=\"stylesheet\"></head>\n<body>\n";
	print "<h1>Domain status overview</h1>";
}

sub printTail() {
	print "<footer>&copy; <a href=\"http://www.vegaasen.com\" target=\"_blank\">vegaasen</a></footer>\n</body></html>\n";
}

# Start the thingie, plx!

checkAddresses();
cleanUp();
printHead();
printAllStatuses();
printTail();