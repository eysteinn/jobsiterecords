<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Trade</span>
    <h1>Roofing: where gravity keeps score</h1>
    <p class="lead">Ice and water laps, nail line discipline on architectural shingles, step flashing behind siding, cricket geometry if you are fancy—get it while the ladder is already wrong. Drone shots are optional; close-ups of penetrations are not.</p>

    <h2>Gutter handoffs</h2>
    <p>Drip edge, fascia condition you did not bid to replace, rotten corner post someone “forgot” to mention. Photo it before metal hides the sin.</p>

    <h2>Cleanup is part of the product</h2>
    <p>Magnet sweep, dump trailer, nails in driveway—one photo of a clean driveway saves ten angry texts.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Tag <code>Dry-in</code> separate from <code>Final</code> so exports match draws.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/trades/">All trades</a></li>
        <li><a href="/use-cases/safety-site-walk-documentation.php">Site walk photos</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Roofing installation job photos',
    'description' => 'Roofing documentation: ice and water, nail lines, flashing, penetrations, fascia, cleanup—photos tied to draws.',
    'canonical_path' => '/trades/roofing-installation-job-photos.php',
    'body' => $body,
]);
