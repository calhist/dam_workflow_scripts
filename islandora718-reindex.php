#!/usr/bin/php
<?php
require_once '/var/www/html/sites/all/libraries/tuque/RepositoryConnection.php';
require_once '/var/www/html/sites/all/libraries/tuque/Repository.php';
require_once '/var/www/html/sites/all/libraries/tuque/FedoraApi.php';
require_once '/var/www/html/sites/all/libraries/tuque/FedoraApiSerializer.php';
require_once '/var/www/html/sites/all/libraries/tuque/Cache.php';

$query = '
	PREFIX dc: <http://purl.org/dc/elements/1.1/>
	SELECT DISTINCT ?subject
	WHERE  { 
		?subject dc:identifier ?object .
		FILTER (!regex(?object, "^fedora-system:")) .
	} ORDER BY (?subject)
';

$connection = new RepositoryConnection();
$repository = new FedoraRepository(new FedoraApi($connection), new SimpleCache());

$users = simplexml_load_file('/usr/local/fedora/server/config/fedora-users.xml');

$curl = new CurlConnection();
$curl->username = 'fgsAdmin';
$curl->password = $users->xpath('/users/user[@name="fgsAdmin"]/@password')[0];

$objects = $repository->ri->sparqlQuery($query, -1);

foreach ( $objects as $k => $v ) {
	$uri = $v['subject']['uri'];
	$pid = $v['subject']['value'];

	$response = $curl->getRequest('http://127.0.0.1:8080/fedoragsearch/rest'
		. '?operation=updateIndex'
		. '&action=fromPid'
		. '&restXslt=copyXml'
		. "&value=$pid"
	);

	$xml = simplexml_load_string($response['content']);

	$warnCount   = $xml->updateIndex['warnCount'];
	$docCount    = $xml->updateIndex['docCount'];
	$deleteTotal = $xml->updateIndex['deleteTotal'];
	$updateTotal = $xml->updateIndex['updateTotal'];
	$insertTotal = $xml->updateIndex['insertTotal'];

	printf("%-40s insert %6s warn %6s docs %6s\n", $uri, $insertTotal, $warnCount, $docCount);
}
