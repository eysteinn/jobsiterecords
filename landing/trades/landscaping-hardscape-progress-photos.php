<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Trade</span>
    <h1>Hardscape photos that still make sense after the first freeze-thaw</h1>
    <p class="lead">Owners remember the pretty capstone. You remember the 3/4 crushed base depth because that is what keeps them from calling you in April when the pavers do the wave. Shoot the sandwich: geotextile, lifts, compactor passes if you can do it without staging fake sweat.</p>

    <h2>Drainage is the product</h2>
    <p>Inlets before sod, outlet pop, pitch to daylight—wide shots with a caption that names upstream/downstream. “Looks right” does not survive a rainy spring text thread.</p>

    <h2>Planting soil against veneer</h2>
    <p>If you know it is wrong, photograph the condition and the conversation recommendation—even if they insist. CYA without being a jerk about it.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Weather in a voice note beats guessing from sky later.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/trades/">All trades</a></li>
        <li><a href="/trades/concrete-flatwork-foundation-photo-records.php">Concrete &amp; flatwork</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Landscaping & hardscape progress photos',
    'description' => 'Landscape and hardscape documentation: base lifts, drainage, outlets, soil clearance from veneer—photos that survive weather.',
    'canonical_path' => '/trades/landscaping-hardscape-progress-photos.php',
    'body' => $body,
]);
