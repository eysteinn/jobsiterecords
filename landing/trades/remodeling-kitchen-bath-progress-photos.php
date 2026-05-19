<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Trade</span>
    <h1>Kitchen and bath: where marriages and change orders start</h1>
    <p class="lead">Homeowners feel cabinets and tile with their eyeballs at weird angles. Shoot what they will judge: seams at eye level, outlet symmetry mistakes, shower niche grout corners, undercabinet shadow lines. Also shoot what they will not notice until anger: waterproofing laps, blocking for grab bars, valve depth before tile.</p>

    <h2>Before you cover pretty</h2>
    <p>Framed rough openings, blocking, DWV stacks behind vanities. Nobody wants to core a finished backsplash because someone “assumed” blocking.</p>

    <h2>Finish photos need mean light</h2>
    <p>Flash at user height reveals paint holidays owners will find at 9pm with a lamp. You are not being petty—you are buying quiet.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Per-room tags keep bath vs kitchen exports sane.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/trades/">All trades</a></li>
        <li><a href="/use-cases/remodel-progress-photos-for-homeowners.php">Homeowner progress</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Kitchen & bath remodel progress photos',
    'description' => 'Remodel photo habits for kitchens and baths: waterproofing, blocking, finish angles, flash checks owners actually use.',
    'canonical_path' => '/trades/remodeling-kitchen-bath-progress-photos.php',
    'body' => $body,
]);
