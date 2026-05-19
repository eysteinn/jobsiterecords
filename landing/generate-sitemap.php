<?php
declare(strict_types=1);

/**
 * Regenerate landing/sitemap.xml after adding guides or resource pages.
 * Run from repo root: php landing/generate-sitemap.php
 */

require_once __DIR__ . '/lib/sitemap-build.php';

$out = __DIR__ . '/sitemap.xml';
$xml = jobsiterecords_sitemap_xml();

if (file_put_contents($out, $xml) === false) {
    fwrite(STDERR, "Failed to write {$out}\n");
    exit(1);
}

echo "Wrote " . count(jobsiterecords_sitemap_entries(site_public_origin(), __DIR__)) . " URLs to {$out}\n";
