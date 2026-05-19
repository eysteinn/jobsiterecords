<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Example</span>
    <h1>What we put in a “job done” zip</h1>
    <p class="lead">Your exporter might name things differently—this is the shape that keeps homeowners from emailing “is the manual in there?”</p>

    <ul>
        <li><code>index.html</code> + <code>index.csv</code> — whatever your tool generates; people like a human-readable list.</li>
        <li><code>photos/</code> — curated jpgs/heic, not the whole camera roll.</li>
        <li><code>audio/</code> — voice notes if the client actually wants them (ask first; some do not).</li>
        <li><code>warranty/</code> — PDF scans of appliance cards if you collected them.</li>
        <li><code>README.txt</code> — two lines: who to call for what, and “photos dated in captions.”</li>
    </ul>

    <p>If the zip is huge, split by phase: <code>handoff_finish.zip</code> vs <code>handoff_mechanical.zip</code>. Email clients still act like it is 2004.</p>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/examples/">All examples</a></li>
        <li><a href="/guides/export-job-site-zip-html-csv.php">Zip contents (guide)</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Example handoff zip contents checklist',
    'description' => 'Example structure for a client handoff zip: index, photos, optional audio, warranty PDFs, short README.',
    'canonical_path' => '/examples/example-handoff-zip-contents-checklist.php',
    'body' => $body,
]);
