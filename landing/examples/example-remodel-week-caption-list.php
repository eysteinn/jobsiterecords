<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Example</span>
    <h1>Caption lines from one real kitchen week (fictional address)</h1>
    <p class="lead">Copy, butcher, reuse. These are written like a human thumb typed them.</p>

    <blockquote class="sample">
        <p>Mon — Demo: north wall cabinets out, plaster scar at window stool noted.<br>
        Tue — Elec: old range circuit capped; temp strip light hung.<br>
        Wed — Rough patch: two layers floor at peninsula, plan is 1/4 ply shim then CBU.<br>
        Thu — Drywall patch baked, primer on new only—no topcoat yet.<br>
        Fri — Walk with homeowner: niche height OK at 48 AFF, confirm shelf count.</p>
    </blockquote>

    <p>Notice none of them say “high quality craftsmanship.” They say where and what changed.</p>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/examples/">All examples</a></li>
        <li><a href="/guides/tag-and-caption-site-photos.php">Tag &amp; caption guide</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Example remodel week caption list',
    'description' => 'Sample one-line captions for a kitchen remodel week: demo, temp power, floor build-up, drywall, client walk.',
    'canonical_path' => '/examples/example-remodel-week-caption-list.php',
    'body' => $body,
]);
