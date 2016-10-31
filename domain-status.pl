#!/usr/bin/perl
#
# Simple perl-script that does the following:
# -reads a domain-list that just issues a request to wherever specified. Then, it will just output this stuff to a specified file + 
# as output, mimc'd through a html-page with page-reload.
#
# Note#1: You might need the LWP::Https scheme in order to allow https-connections flow through the application itself.
# Error#1: Getting the following error in Apache?
# --End of script output before headers
# Error#1-solution: chmod 777 *
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

sub label {
	my $self = shift;
	return $self->{label};
}

sub color {
	my $self = shift;
	return $self->{color};
}

sub host {
	my $self = shift;
	return $self->{host};
}

sub placeholder {
	my $self = shift;
	return $self->{placeholder};
}

###########################################
package main;

use warnings;
use strict;
use Tie::File;
use LWP::UserAgent;
use Time::Piece;
use URI::URL;

my $appTitle = "#statusScreen";
my $error_log  = 'uptime.err';
my $domains = 'domain.list';
my $localtime     = localtime;
my @serverStatuses;
my @errors;
my ($day,$month,$date,$hour,$year) = split /\s+/,scalar localtime;
my $output_file = 'report-'.$date.'.'.$month.'.'.$year.'.out';
my (@all_addr) = ();
my $response_limit = 5; 
my $timeotLimit = 10;
# configure the look of the screen
my $bigScreen = 1;
my $blackMode = 1;
# configure logging
my $consolePrint = 0; #<-- Print stuff to console as well - for debugging purposes
my $logPrint = 0; #<-- Print stuff to a file, if not - then CBA.

die "File $domains is not exist\n" unless (-e $domains);

sub configure() {
	tie @all_addr, 'Tie::File', $domains or error("Cant open file {$domains} to read the list of domains");
	if($logPrint != 0) {
		if (-e $output_file) {
		   open(OUT,">> $output_file") or error("Cant append to existing file $output_file");
		} else {
		   open(OUT,"> $output_file") or error("Cant write to file $output_file");
		}
	}
}

sub checkAllDomains() {
	tossToFile("\n+" .('-' x 84) . "+\n");
	
	tossToFile("|", ' ' x 30,"Time: $hour",' ' x 40,"|\n");
	tossToFile("|",' 'x 10,'HOST',' ' x 37,'STATUS',' ' x 7, "RESPONSE\t|\n");
	tossToFile("+" .('-' x 84) . "+\n");
	my $name = "";
	my $color = "#7A7A7A";
	for (0 .. $#all_addr) {
		my $currentLine = $all_addr[$_];
	 chop $currentLine if ($currentLine =~ /\s+$/);
	 next if ($currentLine  eq "");
	 if ($currentLine =~ /^((.*)#{1,1}name:([\w\-\_]+)#.*)/) {
	 	$name = (split /^((.*)#{1,1}name:([\w\-\_]+)#.*)/, $currentLine)[3, 3];
	 }
	 if ($currentLine =~ /^((.*)#{1,1}color:(.*))/) {
		$color = (split /^((.*)#{1,1}color:(.*))/, $currentLine)[3, 3];
	 }
	 	if ($currentLine =~ /^(http(s)?):\/\/([\w]+.{0,1}|)([\w_\-]+)(.[\w]{0,})?.*/ || $currentLine =~ /^\{.*\:(http.*)}/) {
	   		checkSingleDomain(getDomain($currentLine), $name, $color, getLabel($currentLine));
 		} else {
		   my $out_format = sprintf "| %-50.50s %-10s  %-20s|\n", $currentLine, "<--INCORRECT", "N/A";
		   tossToFile($out_format);
		   toss($out_format);
		   push @errors, "$currentLine is not a valid domain.";
	 	}
	}
}

sub getDomain() {
	my $potential = $_[0];
	if ($potential =~ /^(http(s)?):\/\/([\w]+.{0,1}|)([\w_\-]+)(.[\w]{0,})?.*/) {
		toss("No changes detected");
	} elsif ($potential =~ /^\{.*location\:(http.*)}/) {
		$potential = (split /^\{.*location\:(http.*)}/, $potential)[1, 1];
	}
	toss("Found location, returning $potential");
	return $potential;
}

sub getLabel() {
	my $potential;
	if (length $_[0]) {
		$potential = $_[0];
		if ($potential =~ /^\{.*label\:([\w\s]+),.*}/) {
			$potential = (split /^\{.*label\:([\w\s]+),.*}/, $potential)[1, 1];
			toss("Found label, returning $potential");
		}else{
			$potential = "";
		}
	}else{
		$potential = "";
		toss("Label not found. Returning empty");
	}
	return $potential;
}

sub checkSingleDomain {
    my $targetUrl = new URI::URL $_[0];
    my $target = $targetUrl->as_string();
    my $label = $_[1];
    my $color = $_[2];
    my $placeholder = $_[3];
	my $ua = LWP::UserAgent->new(ssl_opts => {verify_hostname => 0, timeout => $timeotLimit, Timeout => $timeotLimit}, timeout => $timeotLimit, keep_alive => 0, agent => "DomainStatusPerl/0.1-SNAPSHOT");
	my $req = HTTP::Request->new(GET => "$target");
	$req->header('Accept' => '*/*');
	my $startTime = time;
	my $res = $ua->request($req);
	my $endTime = time;
	$endTime = ($endTime - $startTime);
	my $result = Result->new(response => $res, responseTime => $endTime, when => localtime($startTime)->strftime('%d.%m-%Y @ %H:%M:%S'), label => $label, color => $color, host => $targetUrl->host(), placeholder => $placeholder);
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
	  tossToFile($out_format);
	  toss($out_format);
	} else {
	  my $out_format = sprintf "| %-50.50s %-10s %-20s |\n", $target, "DOWN", " N/A";
	  push(@errors, "$target is DOWN." . $res->status_line) or error("Cannot push error for DOWN");
	  tossToFile($out_format);
	  toss($out_format);
    }
}

sub cleanUp() {
	my $err = join "\015\012",@errors;
	my $err_num = scalar @errors;
	untie @all_addr or error("Unable to close file $domains");
	if($logPrint != 0) {
		close OUT or error("Unable to close file $output_file");
	}
	toss("Server cleanUp is complete");
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

sub toss() {
	my $what = $_[0];
	if($consolePrint == 1) {
		print "$what";
	}
}

sub tossToFile() {
	if($logPrint != 0) {
		my $what = $_;
		print OUT $what;
	}
}

sub printAllStatuses() {
	my $status = "glyphicon glyphicon-minus";
	print '<table class="table table-striped table-hover"><thead><tr><th>DNS/Domain/Entity</th><th>Label</th><th>Status</th><th>Requested</th><th>Response (in seconds)</th></tr></thead><tbody>';
	foreach(@serverStatuses) {
		if ($_->response->is_success() || $_->response->is_info()) {
			print '<tr class="successful faded">';
			$status = "glyphicon glyphicon-thumbs-up";
		} elsif ($_->response->is_redirect() || $_->response->code == 404) {
			print '<tr class="warning">';
			$status = "glyphicon glyphicon-flash";
		} else {
			$status = "glyphicon glyphicon-fire";
			print '<tr class="danger">';
		}
		print '<td>' . printPlaceholderLink($_) . '</td><td><span class="label label-success" style="background-color:' . $_->color() . '">' . $_->label() . '</span></td><td><span class="' . $status . '"><!--' . $_->response->status_line() . '--></span></td><td>' . $_->when() . '</td><td><span class="badge pull-right">~ ' . $_->responseTime() . 's</span></td></tr>';
	}
	print '</tbody></table>';
}

sub printPlaceholderLink() {
	my $result = $_[0];
	if(defined $result) {
		if(length $result->placeholder) {
			return '<a href="' . $_->response->request->uri() . '" target="_blank">' . $_->placeholder() . '</a>';
		}else{
			return '<a href="' . $_->response->request->uri() . '" target="_blank">' . $_->host() . '</a>';
		}
	}
}

sub printHeaders() {
	print "Content-Type: text/html; charset=UTF-8\n\n";
}

sub printHead() {
	print "<!DOCTYPE html>\n<html>\n<head><meta http-equiv='refresh' content='60'><title>$appTitle</title><link rel=\"stylesheet\" href=\"http://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap.min.css\"><style>.bigified {font-size:2em;}.faded{opacity:0.5;}.faded:hover{opacity:1;}</style></head>\n<body>\n";
	if ($bigScreen == 1) {
		print '<div class="container-fluid bigified">';
	}else{
		print '<div class="container">';
	}
	print "<h1>$appTitle</h1>";

}

sub printTail() {
	print '</div>';
	print "<footer class=\"text-right\">&copy; <a href=\"http://www.vegaasen.com\" target=\"_blank\">vegaasen</a> | last updated <em>" . $serverStatuses[0]->when() . "</em></footer>\n</body></html>\n";
}

configure();
checkAllDomains();
cleanUp();

printHeaders();
printHead();
printAllStatuses();
printTail();
