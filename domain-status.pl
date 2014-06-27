#!/usr/bin/perl
#
# Simple perl-script that does the following:
# -reads a domain-list that just issues a request to wherever specified. Then, it will just output this stuff to a specified file + 
# as output, mimc'd through a html-page with page-reload.
#
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

###########################################
package main;

use warnings;
use strict;
use Tie::File;
use LWP::UserAgent;
use Time::Piece;
use URI::URL;

my $appTitle = "#domainStatus";
my $error_log  = 'uptime.err';
my $domains = 'domain.list';
my $response_limit = 5; 
my $consolePrint = 0;
my $localtime     = localtime;
my @serverStatuses;
my @errors;
my ($day,$month,$date,$hour,$year) = split /\s+/,scalar localtime;
my $output_file = 'report-'.$date.'.'.$month.'.'.$year.'.out';
my (@all_addr) = ();

die "File $domains is not exist\n" unless (-e $domains);

sub configure() {
	tie @all_addr, 'Tie::File', $domains or error("Cant open file {$domains} to read the list of domains");
	if (-e $output_file) {
	   open(OUT,">> $output_file") 
		  or error("Cant append to existing file $output_file");
	} else {
	   open(OUT,"> $output_file") 
		  or error("Cant write to file $output_file");
	}
}

sub checkAllDomains() {
	print OUT "\n+" .('-' x 84) . "+\n";
	print OUT   "|", ' ' x 30,"Time: $hour",' ' x 40,"|\n";
	print OUT   "|",' 'x 10,'HOST',' ' x 37,'STATUS',' ' x 7, "RESPONSE\t|\n";
	print OUT   "+" .('-' x 84) . "+\n";
	my $name;
	my $color = "#7A7A7A";
	for (0 .. $#all_addr) {
	 chop $all_addr[$_] if ($all_addr[$_] =~ /\s+$/);
	 next if ($all_addr[$_]  eq "");
	 if ($all_addr[$_] =~ /^((.*)#{1,1}name:([\w]+)#.*)/) {
	 	$name = (split /^((.*)#{1,1}name:([\w]+)#.*)/, $all_addr[$_])[3, 3];
	 }
	 if ($all_addr[$_] =~ /^((.*)#{1,1}color:(.*))/) {
		$color = (split /^((.*)#{1,1}color:(.*))/, $all_addr[$_])[3, 3];
	 }
	 if ($all_addr[$_] =~ /^(http(s)?):\/\/([\w]+.{0,1}|)([\w_\-]+)(.[\w]{0,})?.*/) {  
	   checkSingleDomain($all_addr[$_], $name, $color);
	 } else {
	   my $out_format = sprintf "| %-50.50s %-10s  %-20s|\n", $all_addr[$_], "<--INCORRECT", "N/A";
	   printf OUT $out_format;
	   toss($out_format);
	   push @errors, "$all_addr[$_] is not a valid domain.";
	 }
	}
}

sub checkSingleDomain {
    my $targetUrl = new URI::URL $_[0];
    my $target = $targetUrl->as_string();
    my $label = $_[1];
    my $color = $_[2];
	my $ua = LWP::UserAgent->new(ssl_opts => {verify_hostname => 0});
	$ua->agent("DomainStatusPerl/0.1-SNAPSHOT");
	my $req = HTTP::Request->new(GET => "$target");
	$req->header('Accept' => '*/*');
	my $startTime = time;
	my $res = $ua->request($req);
	my $endTime = time;
	$endTime = ($endTime - $startTime);
	my $result = Result->new(response => $res, responseTime => $endTime, when => localtime($startTime)->strftime('%d.%m-%Y @ %H:%M:%S'), label => $label, color => $color, host => $targetUrl->host());
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

sub cleanUp() {
	my $err = join "\015\012",@errors;
	my $err_num = scalar @errors;
	untie @all_addr or error("Unable to close file $domains");

	close OUT or error("Unable to close file $output_file");
	toss("Server check is complete");
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
		print $what;
	}
}

sub printAllStatuses() {
	my $status = "glyphicon glyphicon-minus";
	print '<table class="table table-striped table-hover"><thead><tr><th>DNS/Domain</th><th>Label</th><th>Status</th><th>Requested</th><th>Response (in seconds)</th></tr></thead><tbody>';
	foreach(@serverStatuses) {
		if ($_->response->is_success() || $_->response->is_info() || $_->response->code == 404) {
			print '<tr class="successful">';
			$status = "glyphicon glyphicon-thumbs-up";
		} elsif ($_->response->is_redirect()) {
			print '<tr class="warning">';
			$status = "glyphicon glyphicon-flash";
		} else {
			$status = "glyphicon glyphicon-fire";
			print '<tr class="danger">';
		}
		print '<td><a href="' . $_->response->request->uri() . '" target="_blank">' . $_->host() . '</a></td><td><span class="label label-success" style="background-color:' . $_->color() . '">' . $_->label() . '</span></td><td><span class="' . $status . '"><!--' . $_->response->status_line() . '--></span></td><td>' . $_->when() . '</td><td><span class="badge pull-right">~' . $_->responseTime() . 's</span></td></tr>';
	}
	print '</tbody></table>';
}

sub printHeaders() {
	print "Content-Type: text/html; charset=UTF-8\n\n";
}

sub printHead() {
	print "<!DOCTYPE html>\n<html>\n<head><meta http-equiv='refresh' content='1000'><title>$appTitle</title><link rel=\"stylesheet\" href=\"http://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap.min.css\"></head>\n<body>\n";
	print '<div class="container">';
	print "<h1>$appTitle</h1>";

}

sub printTail() {
	print '</div>';
	print "<footer class=\"text-right\">&copy; <a href=\"http://www.vegaasen.com\" target=\"_blank\">vegaasen</a> | last updated <em>" . $serverStatuses[0]->when() . "</em></footer>\n</body></html>\n";
}

# Start the thingie, plx!

configure();
checkAllDomains();
cleanUp();

printHeaders();
printHead();
printAllStatuses();
printTail();