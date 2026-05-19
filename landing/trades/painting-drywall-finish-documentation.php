<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Trade</span>
    <h1>Paint and drywall: flash makes cowards of us all</h1>
    <p class="lead">Your finish is often fine; their inspection light is hostile. Photograph primer closure, patch feather edges before color, and final walls at angles owners actually use—hallways at night, not just sun-drenched Instagram corners.</p>

    <h2>Nail pops are a genre</h2>
    <p>Before repair, after repair, and the paint coat that buried them. Otherwise they come back like bad radio.</p>

    <h2>Touchup maps</h2>
    <p>Photo each wall with a tiny caption “SW agreeable gray / BM simply white trim” so you do not repaint the wrong room six months later from memory.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Tags like <code>Primer</code>, <code>Coat2</code>, <code>Punch</code> keep phases readable.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/trades/">All trades</a></li>
        <li><a href="/use-cases/warranty-punch-list-photo-trail.php">Warranty trail</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Painting & drywall finish documentation',
    'description' => 'Paint and drywall photo habits: primer, patches, flash angles, nail pop repairs, color captions per room.',
    'canonical_path' => '/trades/painting-drywall-finish-documentation.php',
    'body' => $body,
]);
