<?php
declare(strict_types=1);

/**
 * Dynamic XML sitemap (same content as sitemap.xml).
 * Submit https://jobsiterecords.com/sitemap.xml — static file for hosts that ignore .htaccess.
 */

require_once __DIR__ . '/lib/sitemap-build.php';

header('Content-Type: application/xml; charset=utf-8');
header('Cache-Control: public, max-age=3600');

$xml = jobsiterecords_sitemap_xml();

// On shared hosts (e.g. 1984) .htaccess cannot map /sitemap.xml → this script.
// Write a static copy when htdocs is writable so /sitemap.xml works without FTP.
$static = __DIR__ . '/sitemap.xml';
if (is_writable(__DIR__) || (is_file($static) && is_writable($static))) {
    @file_put_contents($static, $xml);
}

echo $xml;
