<?php
declare(strict_types=1);

require_once __DIR__ . '/seo-layout.php';

/** @return list<array{loc: string, changefreq: string, priority: string}> */
function jobsiterecords_sitemap_entries(string $base, string $landingDir): array
{
    $entries = [];

    $entries[] = ['loc' => $base . '/', 'changefreq' => 'weekly', 'priority' => '1.0'];
    $entries[] = ['loc' => $base . '/guides/', 'changefreq' => 'weekly', 'priority' => '0.9'];

    $addSection = static function (string $baseUrl, string $root, string $sectionDir) use (&$entries): void {
        $fullDir = $root . '/' . $sectionDir;
        if (!is_dir($fullDir)) {
            return;
        }
        $entries[] = [
            'loc' => $baseUrl . '/' . $sectionDir . '/',
            'changefreq' => 'weekly',
            'priority' => '0.85',
        ];
        foreach (glob($fullDir . '/*.php') ?: [] as $full) {
            $name = basename($full);
            if ($name === 'index.php') {
                continue;
            }
            $entries[] = [
                'loc' => $baseUrl . '/' . $sectionDir . '/' . rawurlencode($name),
                'changefreq' => 'monthly',
                'priority' => '0.75',
            ];
        }
    };

    foreach (resource_section_paths() as $prefix) {
        $addSection($base, $landingDir, trim($prefix, '/'));
    }

    $guideDir = $landingDir . '/guides';
    if (is_dir($guideDir)) {
        foreach (glob($guideDir . '/*.php') ?: [] as $full) {
            $name = basename($full);
            if ($name === 'index.php') {
                continue;
            }
            $entries[] = [
                'loc' => $base . '/guides/' . rawurlencode($name),
                'changefreq' => 'monthly',
                'priority' => '0.8',
            ];
        }
    }

    usort($entries, static fn (array $a, array $b): int => strcmp($a['loc'], $b['loc']));

    return $entries;
}

function jobsiterecords_sitemap_xml(?string $lastmod = null): string
{
    $base = site_public_origin();
    $today = $lastmod ?? gmdate('Y-m-d');
    $landingDir = dirname(__DIR__);
    $entries = jobsiterecords_sitemap_entries($base, $landingDir);

    $xml = '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
    $xml .= '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' . "\n";

    foreach ($entries as $e) {
        $xml .= '  <url>' . "\n";
        $xml .= '    <loc>' . h($e['loc']) . '</loc>' . "\n";
        $xml .= '    <lastmod>' . h($today) . '</lastmod>' . "\n";
        $xml .= '    <changefreq>' . h($e['changefreq']) . '</changefreq>' . "\n";
        $xml .= '    <priority>' . h($e['priority']) . '</priority>' . "\n";
        $xml .= '  </url>' . "\n";
    }

    $xml .= '</urlset>' . "\n";

    return $xml;
}
