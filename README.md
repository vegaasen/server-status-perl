server-status-perl
==================

Perl-based server status page. It is based on <<??>>.

This script is as easy as it gets. Just place a plain http://<whatevz>/ in a file named "domain.list". This file will the be loaded to memory. 
The script will then try to load all the statuses etc. for the required domain and write a little nice page on how stuff went.

We use this to just simply view what services is up at what point, simple as that. There is A LOT of improvements to be done, however that was not the 
main goal of this simple script. This simple script were designed to be .. simple :-).

# HTTP Server Configuration

## Apache (2.4+):

	<VirtualHost *:80>
    ServerAdmin me@youarethesh.it
    DocumentRoot "/path/to/folder/with/script/server-status-perl/"
    ServerName www.testing.local
    <Directory "/path/to/folder/with/script/server-status-perl/">
        Options Indexes FollowSymLinks Includes ExecCGI
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog "logs/www.testing.local.com-error_log"
    CustomLog "logs/www.testing.local-access_log" common
	</VirtualHost>

## Nginx

	todo.

# Examples

## The domain.list file

This file is actually quite simple, however it requires that you define it correctly (as with any other configuration-file..).
*Please note*: the code within domain-status.pl is far from the prettiest, so its also fragile.. this was never ment to be a "omg look what I can do"-thingie. its just a simple problemsolver - created within minutes :-)

### Allowed stuff:

The simplest list is as follows:

	http://www.thisis.it

Domain with some cool formatting and a label. This label and color will continue to the next name/color-combo comes along :-):

	#name:meh#color:#7A7A7A
	http://www.thisis.it

Domain with a label and the actual location:

	{label:Itz zomewherez,location:http://username:password@somewhere.no}

Domain with authentication:

	http://username:password@somewhere.no

### Example

Simple example:

	http://www.hardanger-folkeblad.no
	http://www.vg.no
	http://www.db.no
	http://www.aftenposten.no

Mixed example:

	#name:rndm#color:#7A7A7A
	{label:Itz zomewherez,location:http://username:password@somewhere.no}
	http://www.cool.com
	#name:githubRox#color:#43B12E
	http://www.github.com:22
	https://www.github.com:22
	#name:nwspprz#color:#FF7E7E
	http://www.vg.no