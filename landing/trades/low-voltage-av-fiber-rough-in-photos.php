<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Trade</span>
    <h1>Low voltage: the trade everyone blames for Wi-Fi feelings</h1>
    <p class="lead">Homeruns, pull string left in smurf, bend radius on coax nobody uses anymore, AP locations relative to HVAC returns—document like someone will move a can light two inches and ruin a ceiling pull.</p>

    <h2>Rack dress rehearsal</h2>
    <p>Patch panels labeled, cable management before heat of closeout. Photo now; sparkle later.</p>

    <h2>TV blocking and power</h2>
    <p>Outlet height relative to mount, recessed box depth, conduit stub if spec wants it. Owners only remember the TV tilt.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Short voice IDs (“rack is north closet, patch 1A = living AP”) save spring commissioning meltdowns.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/trades/">All trades</a></li>
        <li><a href="/trades/electrical-contractor-field-documentation.php">Electrical rough</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Low voltage, AV & fiber rough-in photos',
    'description' => 'Low-voltage field photos: homeruns, smurf, rack labels, AP placement, TV power—rough-in evidence before drywall.',
    'canonical_path' => '/trades/low-voltage-av-fiber-rough-in-photos.php',
    'body' => $body,
]);
